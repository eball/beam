// Copyright 2018 The Beam Team
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include "stratum_server.h"
#include "utility/helpers.h"
#include "utility/io/sslserver.h"
#include <boost/filesystem.hpp>
#include <boost/algorithm/string/trim.hpp>
#include <fstream>

#define LOG_VERBOSE_ENABLED 1
#include "utility/logger.h"

#include <assert.h>

namespace beam {

std::unique_ptr<IExternalPOW> IExternalPOW::create(
    const IExternalPOW::Options& o, io::Reactor& reactor, io::Address listenTo
) {
    return std::make_unique<stratum::Server>(o, reactor, listenTo);
}

namespace stratum {

static const uint64_t SERVER_RESTART_TIMER = 1;
static const uint64_t ACL_REFRESH_TIMER = 2;
static const unsigned SERVER_RESTART_INTERVAL = 1000;
static const unsigned ACL_REFRESH_INTERVAL = 5000;

static const char STS[] = "stratum server ";

Server::Server(const IExternalPOW::Options& o, io::Reactor& reactor, io::Address listenTo) :
    _options(o),
    _reactor(reactor),
    _bindAddress(listenTo),
    _timers(reactor, 100),
    _fw(4096, 0, [this](io::SharedBuffer&& buf){ _currentMsg.push_back(buf); }),
    _acl(o.apiKeysFile)
{
    _timers.set_timer(SERVER_RESTART_TIMER, 0, BIND_THIS_MEMFN(start_server));
    if (!o.apiKeysFile.empty()) {
        _timers.set_timer(ACL_REFRESH_TIMER, 0, BIND_THIS_MEMFN(refresh_acl));
    }
}

void Server::start_server() {
    try {
        if (_options.privKeyFile.empty() || _options.certFile.empty()) {
            LOG_WARNING() << STS << "TLS disabled!";
            _server = io::TcpServer::create(
                _reactor,
                _bindAddress,
                BIND_THIS_MEMFN(on_stream_accepted)
            );
        } else {
            _server = io::SslServer::create(
                _reactor,
                _bindAddress,
                BIND_THIS_MEMFN(on_stream_accepted),
                _options.certFile.c_str(),
                _options.privKeyFile.c_str()
            );
        }
        LOG_INFO() << STS << "listens to " << _bindAddress;
    } catch (const std::exception& e) {
        LOG_ERROR() << STS << "cannot start server: " << e.what() << " restarting in  " << SERVER_RESTART_INTERVAL << " msec";
        _timers.set_timer(SERVER_RESTART_TIMER, SERVER_RESTART_INTERVAL, BIND_THIS_MEMFN(start_server));
    }
}

void Server::refresh_acl() {
    _acl.refresh();
    _timers.set_timer(ACL_REFRESH_TIMER, ACL_REFRESH_INTERVAL, BIND_THIS_MEMFN(refresh_acl));
}

void Server::on_stream_accepted(io::TcpStream::Ptr&& newStream, io::ErrorCode errorCode) {
    if (errorCode == 0) {
        auto peer = newStream->peer_address();
        LOG_DEBUG() << STS << "+peer " << peer;
        _connections[peer.u64()] = std::make_unique<Connection>(
            *this,
            peer.u64(),
            std::move(newStream)
        );
    } else {
        LOG_ERROR() << STS << io::error_str(errorCode) << ", restarting server in  " << SERVER_RESTART_INTERVAL << " msec";
        _timers.set_timer(SERVER_RESTART_TIMER, SERVER_RESTART_INTERVAL, BIND_THIS_MEMFN(start_server));
    }
}

bool Server::on_login(uint64_t from, const Login& login) {
    assert(_connections.count(from) > 0);

    if (_acl.check(login.api_key)) {
        auto& conn = _connections[from];
        conn->set_logged_in();

        // TODO send result first
        return _connections[from]->send_msg(_recentJob.msg, true);
    } else {
        LOG_INFO() << STS << "peer login failed, key=" << login.api_key;
        Result res(login.id, login_failed);
        append_json_msg(_fw, res);
        _connections[from]->send_msg(_currentMsg, false, true);
        _currentMsg.clear();
    }
    return false;
}

bool Server::on_solution(uint64_t from, const Solution& sol) {

	LOG_DEBUG() << TRACE(sol.nonce) << TRACE(sol.output);

	_recentResult.id = sol.id;
    sol.fill_pow(_recentResult.pow);
    _recentResult.resultFrom = from;

    LOG_INFO() << STS << "solution to " << sol.id << " from " << io::Address::from_u64(from);
	_recentResult.onBlockFound();
    return true;
}

void Server::on_bad_peer(uint64_t from) {
    LOG_INFO() << STS << "-peer " << io::Address::from_u64(from);
    _connections.erase(from);
}

void Server::new_job(
    const std::string& id,
    const Merkle::Hash& input,
    const Block::PoW& pow,
    const Height& height,
    const BlockFound& callback,
    const CancelCallback& /* cancelCallback */
) {
    _recentJob.id = id;
    _recentResult.onBlockFound = callback;

    LOG_INFO() << STS << "new job " << id << " will be sent to " << _connections.size() << " connected peers";

    Job jobMsg(id, input, pow, height);
    append_json_msg(_fw, jobMsg);
	_recentJob.msg.swap(_currentMsg);
    _currentMsg.clear();

    for (auto& p : _connections) {
        if (!p.second->send_msg(_recentJob.msg, true)) {
            _deadConnections.push_back(p.first);
        }
    }

    for (auto c : _deadConnections) {
        _connections.erase(c);
    }
    _deadConnections.clear();

    // TODO job cancel policy - timer
}

void Server::solution_result(const std::string& jobID, 
        bool accepted, const beam::Block::SystemState::ID& blockId) {

    if (!accepted){
        Result res(jobID, solution_rejected);
        append_json_msg(_fw, res);
    }else{
        char buf[80] = {0};
        to_hex(buf, blockId.m_Hash.m_pData, 32);

        SolutionResult res(jobID, solution_accepted, buf, blockId.m_Height);
        append_json_msg(_fw, res);
    }

    _connections[_recentResult.resultFrom]->send_msg(_currentMsg, true);
    _currentMsg.clear();

}


void Server::get_last_found_block(std::string& jobID, Block::PoW& pow) {
    jobID = _recentResult.id;
    pow = _recentResult.pow;
}

void Server::stop_current() {
    _recentJob.id.clear();
}

void Server::stop() {
    stop_current();
    _server.reset();
}

Server::AccessControl::AccessControl(const std::string &keysFileName) :
    _enabled(!keysFileName.empty()),
    _keysFileName(keysFileName),
    _lastModified(0)
{
    refresh();
}

void Server::AccessControl::refresh() {
    using namespace boost::filesystem;

    if (!_enabled) return;

    try {
        path p(_keysFileName);
        auto t = last_write_time(p);
        if (t <= _lastModified) {
            return;
        }
        _lastModified = t;
        std::ifstream file(_keysFileName);
        std::string line;
        std::set<std::string> keys;
        while (std::getline(file, line)) {
            boost::algorithm::trim(line);

            //TODO 1) min key length as a parameter 2) storing hashes in the file

            if (line.size() < 8) continue;
            keys.insert(line);
        }
        _keys.swap(keys);
    } catch (std::exception& e) {
        LOG_ERROR() << STS << e.what();
    }
}

bool Server::AccessControl::check(const std::string& key) {
    if (!_enabled) return true;
    return _keys.count(key) > 0;
}

Server::Connection::Connection(ConnectionToServer& owner, uint64_t id, io::TcpStream::Ptr&& newStream) :
    _owner(owner),
    _id(id),
    _stream(std::move(newStream)),
    _lineReader(BIND_THIS_MEMFN(on_raw_message)),
    _loggedIn(false)
{
    _stream->enable_keepalive(2);
    _stream->enable_read(BIND_THIS_MEMFN(on_stream_data));
}

bool Server::Connection::on_stream_data(io::ErrorCode errorCode, void* data, size_t size) {
    if (errorCode != 0) {
        LOG_INFO() << STS << "peer disconnected, code=" << io::error_str(errorCode);
        _owner.on_bad_peer(_id);
        return false;
    }
    if (!_lineReader.new_data_from_stream(data, size)) {
        _owner.on_bad_peer(_id);
        return false;
    }
    return true;
}

bool Server::Connection::send_msg(const io::SerializedMsg& msg, bool onlyIfLoggedIn, bool shutdown) {
    if (onlyIfLoggedIn && !_loggedIn) return true;
    bool sent = _stream && _stream->write(msg);
    if (sent && shutdown) {
        _stream->shutdown();
    }
    return sent;
}

bool Server::Connection::on_message(const stratum::Login& login) {
    return _owner.on_login(_id, login);
}

bool Server::Connection::on_message(const stratum::Solution& solution) {
    return _owner.on_solution(_id, solution);
}

bool Server::Connection::on_raw_message(void* data, size_t size) {
    LOG_VERBOSE() << "got " << std::string((char*)data, size-1);
    return stratum::parse_json_msg(data, size, *this);
}

bool Server::Connection::on_stratum_error(stratum::ResultCode code) {
    // TODO what to do with other errors
    LOG_ERROR() << STS << "got stratum error: " << code << " " << stratum::get_result_msg(code);
    return true;
}

bool Server::Connection::on_unsupported_stratum_method(stratum::Method method) {
    LOG_INFO() << STS << "ignoring unsupported stratum method: " << stratum::get_method_str(method);
    return true;
}

}} //namespaces
