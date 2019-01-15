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

#include "wallet_model.h"
#include "app_model.h"
#include "utility/logger.h"
#include "utility/bridge.h"
#include "utility/io/asyncevent.h"

using namespace beam;
using namespace beam::io;
using namespace std;

namespace
{
    static const unsigned LOG_ROTATION_PERIOD = 3 * 60 * 60 * 1000; // 3 hours

    template<typename Observer, typename Notifier>
    struct ScopedSubscriber
    {
        ScopedSubscriber(Observer* observer, const std::shared_ptr<Notifier>& notifier)
            : m_observer(observer)
            , m_notifier(notifier)
        {
            m_notifier->subscribe(m_observer);
        }

        ~ScopedSubscriber()
        {
            m_notifier->unsubscribe(m_observer);
        }
    private:
        Observer * m_observer;
        std::shared_ptr<Notifier> m_notifier;
    };

    using WalletSubscriber = ScopedSubscriber<IWalletObserver, beam::IWallet>;

    beam::wallet::ErrorType GetWalletError(proto::NodeProcessingException::Type exceptionType)
    {
        switch (exceptionType)
        {
        case proto::NodeProcessingException::Type::Incompatible:
            return beam::wallet::ErrorType::NodeProtocolIncompatible;
		case proto::NodeProcessingException::Type::TimeOutOfSync:
			return beam::wallet::ErrorType::TimeOutOfSync;
        default:
            return beam::wallet::ErrorType::NodeProtocolBase;
        }
    }

    beam::wallet::ErrorType GetWalletError(io::ErrorCode errorCode)
    {
        switch (errorCode)
        {
        case EC_ETIMEDOUT:
            return beam::wallet::ErrorType::ConnectionTimedOut;
        case EC_ECONNREFUSED:
            return beam::wallet::ErrorType::ConnectionRefused;
        default:
            return beam::wallet::ErrorType::NodeProtocolBase;
        }
    }
}

struct WalletModelBridge : public Bridge<IWalletModelAsync>
{
    BRIDGE_INIT(WalletModelBridge);

    void sendMoney(const beam::WalletID& receiverID, const std::string& comment, beam::Amount&& amount, beam::Amount&& fee) override
    {
        tx.send([receiverID, comment, amount{ move(amount) }, fee{ move(fee) }](BridgeInterface& receiver_) mutable
        {
            receiver_.sendMoney(receiverID, comment, move(amount), move(fee));
        });
    }

    void syncWithNode() override
    {
        tx.send([](BridgeInterface& receiver_) mutable
        {
            receiver_.syncWithNode();
        });
    }

    void calcChange(beam::Amount&& amount) override
    {
        tx.send([amount{move(amount)}](BridgeInterface& receiver_) mutable
        {
            receiver_.calcChange(move(amount));
        });
    }

    void getWalletStatus() override
    {
        tx.send([](BridgeInterface& receiver_) mutable
        {
            receiver_.getWalletStatus();
        });
    }

    void getUtxosStatus() override
    {
        tx.send([](BridgeInterface& receiver_) mutable
        {
            receiver_.getUtxosStatus();
        });
    }

    void getAddresses(bool own) override
    {
        tx.send([own](BridgeInterface& receiver_) mutable
        {
            receiver_.getAddresses(own);
        });
    }

    void cancelTx(const beam::TxID& id) override
    {
        tx.send([id](BridgeInterface& receiver_) mutable
        {
            receiver_.cancelTx(id);
        });
    }

    void deleteTx(const beam::TxID& id) override
    {
        tx.send([id](BridgeInterface& receiver_) mutable
        {
            receiver_.deleteTx(id);
        });
    }

    void saveAddress(const WalletAddress& address, bool bOwn) override
    {
        tx.send([address, bOwn](BridgeInterface& receiver_) mutable
        {
            receiver_.saveAddress(address, bOwn);
        });
    }

    void changeCurrentWalletIDs(const beam::WalletID& senderID, const beam::WalletID& receiverID) override
    {
        tx.send([senderID, receiverID](BridgeInterface& receiver_) mutable
        {
            receiver_.changeCurrentWalletIDs(senderID, receiverID);
        });
    }

    void generateNewAddress() override
    {
        tx.send([](BridgeInterface& receiver_) mutable
        {
            receiver_.generateNewAddress();
        });
    }

    void deleteAddress(const beam::WalletID& id) override
    {
        tx.send([id](BridgeInterface& receiver_) mutable
        {
            receiver_.deleteAddress(id);
        });
    }

    void saveAddressChanges(const beam::WalletID& id, const std::string& name, bool isNever, bool makeActive, bool makeExpired) override
    {
        tx.send([id, name, isNever, makeActive, makeExpired](BridgeInterface& receiver_) mutable
        {
            receiver_.saveAddressChanges(id, name, isNever, makeActive, makeExpired);
        });
    }

    void setNodeAddress(const std::string& addr) override
    {
        tx.send([addr](BridgeInterface& receiver_) mutable
        {
            receiver_.setNodeAddress(addr);
        });
    }

    void changeWalletPassword(const SecString& pass) override
    {
        // TODO: should be investigated, don't know how to "move" SecString into lambda
        std::string passStr(pass.data(), pass.size());

        tx.send([passStr](BridgeInterface& receiver_) mutable
        {
            receiver_.changeWalletPassword(passStr);
        });
    }

    void getNetworkStatus() override
    {
        tx.send([](BridgeInterface& receiver_) mutable
        {
            receiver_.getNetworkStatus();
        });
    }
};

WalletModel::WalletModel(IWalletDB::Ptr walletDB, const std::string& nodeAddr)
    : _walletDB(walletDB)
    , _reactor{ Reactor::create() }
    , _async{ make_shared<WalletModelBridge>(*(static_cast<IWalletModelAsync*>(this)), *_reactor) }
    , _isConnected(false)
    , _nodeAddrStr(nodeAddr)
{
    qRegisterMetaType<WalletStatus>("WalletStatus");
    qRegisterMetaType<ChangeAction>("beam::ChangeAction");
    qRegisterMetaType<vector<TxDescription>>("std::vector<beam::TxDescription>");
    qRegisterMetaType<Amount>("beam::Amount");
    qRegisterMetaType<vector<Coin>>("std::vector<beam::Coin>");
    qRegisterMetaType<vector<WalletAddress>>("std::vector<beam::WalletAddress>");
    qRegisterMetaType<WalletID>("beam::WalletID");
    qRegisterMetaType<WalletAddress>("beam::WalletAddress");
    qRegisterMetaType<beam::wallet::ErrorType>("beam::wallet::ErrorType");
}

WalletModel::~WalletModel()
{
    try
    {
        if (_reactor)
        {
            _reactor->stop();
            wait();
        }
    }
    catch (...)
    {

    }
}

WalletStatus WalletModel::getStatus() const
{
    WalletStatus status;

    status.available = _walletDB->getAvailable();
    status.receiving = _walletDB->getTotal(Coin::Incoming);
    status.sending = _walletDB->getTotal(Coin::Outgoing);
    status.maturing = _walletDB->getTotal(Coin::Maturing);

    status.update.lastTime = _walletDB->getLastUpdateTime();

    ZeroObject(status.stateID);
    _walletDB->getSystemStateID(status.stateID);

    return status;
}

void WalletModel::run()
{
    try
    {
        std::unique_ptr<WalletSubscriber> wallet_subscriber;

        io::Reactor::Scope scope(*_reactor);
        io::Reactor::GracefulIntHandler gih(*_reactor);

        emit onStatus(getStatus());
        emit onTxStatus(beam::ChangeAction::Reset, _walletDB->getTxHistory());

        _logRotateTimer = io::Timer::create(*_reactor);
        _logRotateTimer->start(
            LOG_ROTATION_PERIOD, true,
            []() {
            Logger::get()->rotate();
        });

        auto wallet = make_shared<Wallet>(_walletDB);
        _wallet = wallet;

        struct MyNodeNetwork :public proto::FlyClient::NetworkStd {

            MyNodeNetwork(proto::FlyClient& fc, WalletModel& wm)
                : proto::FlyClient::NetworkStd(fc)
                , m_walletModel(wm)
            {
            }

            WalletModel& m_walletModel;

            void OnNodeConnected(size_t, bool bConnected) override
            {
                m_walletModel.onNodeConnectedStatusChanged(bConnected);
            }

            void OnConnectionFailed(size_t, const proto::NodeConnection::DisconnectReason& reason) override
            {
                m_walletModel.onNodeConnectionFailed(reason);
            }
        };

        auto nodeNetwork = make_shared<MyNodeNetwork>(*wallet, *this);

        Address nodeAddr;
        if (nodeAddr.resolve(_nodeAddrStr.c_str()))
        {
            nodeNetwork->m_Cfg.m_vNodes.push_back(nodeAddr);
        }
        else
        {
            LOG_ERROR() << "Unable to resolve node address: " << _nodeAddrStr;
        }

        _nodeNetwork = nodeNetwork;

        auto walletNetwork = make_shared<WalletNetworkViaBbs>(*wallet, *nodeNetwork, _walletDB);
        _walletNetwork = walletNetwork;
        wallet->set_Network(*nodeNetwork, *walletNetwork);

        wallet_subscriber = make_unique<WalletSubscriber>(static_cast<IWalletObserver*>(this), wallet);

        if (AppModel::getInstance()->shouldRestoreWallet())
        {
            AppModel::getInstance()->setRestoreWallet(false);
            // no additional actions required, restoration is automatic and contiguous
        }

        nodeNetwork->Connect();

        _reactor->run();
    }
    catch (const runtime_error& ex)
    {
        LOG_ERROR() << ex.what();
        AppModel::getInstance()->getMessages().addMessage(tr("Failed to start wallet. Please check your wallet data location"));
    }
    catch (...)
    {
        LOG_ERROR() << "Unhandled exception";
    }
}

IWalletModelAsync::Ptr WalletModel::getAsync()
{
    return _async;
}

void WalletModel::onStatusChanged()
{
    emit onStatus(getStatus());
}

void WalletModel::onCoinsChanged()
{
    emit onAllUtxoChanged(getUtxos());
    // TODO may be it needs to delete
    onStatusChanged();
}

void WalletModel::onTransactionChanged(ChangeAction action, std::vector<TxDescription>&& items)
{
    emit onTxStatus(action, move(items));
    onStatusChanged();
}

void WalletModel::onSystemStateChanged()
{
    onStatusChanged();
}

void WalletModel::onAddressChanged()
{
    emit onAdrresses(true, _walletDB->getAddresses(true));
    emit onAdrresses(false, _walletDB->getAddresses(false));
}

void WalletModel::onSyncProgress(int done, int total)
{
    emit onSyncProgressUpdated(done, total);
}

void WalletModel::onNodeConnectedStatusChanged(bool isNodeConnected)
{
    _isConnected = isNodeConnected;
    emit nodeConnectionChanged(isNodeConnected);
}

void WalletModel::onNodeConnectionFailed(const proto::NodeConnection::DisconnectReason& reason)
{
    _isConnected = false;

    // reason -> wallet::ErrorType
    if (proto::NodeConnection::DisconnectReason::ProcessingExc == reason.m_Type)
    {
        _walletError = GetWalletError(reason.m_ExceptionDetails.m_ExceptionType);
        emit onWalletError(*_walletError);
        return;
    }

    if (proto::NodeConnection::DisconnectReason::Io == reason.m_Type)
    {
        _walletError = GetWalletError(reason.m_IoError);
        emit onWalletError(*_walletError);
        return;
    }

    LOG_ERROR() << "Unprocessed error: " << reason;
}

void WalletModel::sendMoney(const beam::WalletID& receiver, const std::string& comment, Amount&& amount, Amount&& fee)
{
    try
    {
        auto receiverAddr = _walletDB->getAddress(receiver);

        if (receiverAddr)
        {
            if (receiverAddr->isExpired())
            {
                emit cantSendToExpired();
                return;
            }
        }
        else
        {
            WalletAddress peerAddr;
            peerAddr.m_walletID = receiver;
            peerAddr.m_createTime = getTimestamp();
            peerAddr.m_label = comment;

            saveAddress(peerAddr, false);
        }

        WalletAddress senderAddress = wallet::createAddress(_walletDB);
        senderAddress.m_label = comment;
        saveAddress(senderAddress, true); // should update the wallet_network

        ByteBuffer message(comment.begin(), comment.end());

        assert(!_wallet.expired());
        auto s = _wallet.lock();
        if (s)
        {
            s->transfer_money(senderAddress.m_walletID, receiver, move(amount), move(fee), true, 120, move(message));
        }

        emit sendMoneyVerified();
    }
    catch (...)
    {

    }
}

void WalletModel::syncWithNode()
{
    assert(!_nodeNetwork.expired());
    auto s = _nodeNetwork.lock();
    if (s)
        s->Connect();
}

void WalletModel::calcChange(beam::Amount&& amount)
{
    auto coins = _walletDB->selectCoins(amount, false);
    Amount sum = 0;
    for (auto& c : coins)
    {
        sum += c.m_ID.m_Value;
    }
    if (sum < amount)
    {
        emit onChangeCalculated(0);
    }
    else
    {
        emit onChangeCalculated(sum - amount);
    }
}

void WalletModel::getWalletStatus()
{
    emit onStatus(getStatus());
    emit onTxStatus(beam::ChangeAction::Reset, _walletDB->getTxHistory());
    emit onAdrresses(false, _walletDB->getAddresses(false));
}

void WalletModel::getUtxosStatus()
{
    emit onStatus(getStatus());
    emit onAllUtxoChanged(getUtxos());
}

void WalletModel::getAddresses(bool own)
{
    emit onAdrresses(own, _walletDB->getAddresses(own));
}

void WalletModel::cancelTx(const beam::TxID& id)
{
    auto w = _wallet.lock();
    if (w)
    {
        static_pointer_cast<IWallet>(w)->cancel_tx(id);
    }
}

void WalletModel::deleteTx(const beam::TxID& id)
{
    auto w = _wallet.lock();
    if (w)
    {
        static_pointer_cast<IWallet>(w)->delete_tx(id);
    }
}

void WalletModel::saveAddress(const WalletAddress& address, bool bOwn)
{
    _walletDB->saveAddress(address);

    if (bOwn)
    {
        auto s = _walletNetwork.lock();
        if (s)
        {
            static_pointer_cast<WalletNetworkViaBbs>(s)->AddOwnAddress(address);
        }
    }
}

void WalletModel::changeCurrentWalletIDs(const beam::WalletID& senderID, const beam::WalletID& receiverID)
{
    emit onChangeCurrentWalletIDs(senderID, receiverID);
}

void WalletModel::generateNewAddress()
{
    try
    {
        WalletAddress address = wallet::createAddress(_walletDB);

        emit onGeneratedNewAddress(address);
    }
    catch (...)
    {

    }
}

void WalletModel::deleteAddress(const beam::WalletID& id)
{
    try
    {
        auto pVal = _walletDB->getAddress(id);
        if (pVal)
        {
            if (pVal->m_OwnID)
            {
                auto s = _walletNetwork.lock();
                if (s)
                {
                    static_pointer_cast<WalletNetworkViaBbs>(s)->DeleteOwnAddress(pVal->m_OwnID);
                }
            }
            _walletDB->deleteAddress(id);
        }
    }
    catch (...)
    {
    }
}

void WalletModel::saveAddressChanges(const beam::WalletID& id, const std::string& name, bool isNever, bool makeActive, bool makeExpired)
{
    try
    {
        auto addr = _walletDB->getAddress(id);

        if (addr)
        {
            if (addr->m_OwnID)
            {
                addr->m_label = name;
                if (makeExpired)
                {
                    assert(addr->m_createTime < getTimestamp() - 1);
                    addr->m_duration = getTimestamp() - addr->m_createTime - 1;
                }
                else if (isNever)
                {
                    addr->m_duration = 0;
                }
                else if (addr->m_duration == 0 || makeActive)
                {
                    // set expiration date to 24h since now
                    addr->m_createTime = getTimestamp();
                    addr->m_duration = 24 * 60 * 60; //24h
                }  

                _walletDB->saveAddress(*addr);

                auto s = _walletNetwork.lock();
                if (s)
                {
                    static_pointer_cast<WalletNetworkViaBbs>(s)->AddOwnAddress(*addr);
                }
            }
            else
            {
                LOG_ERROR() << "It's not implemented!";
            }
        }
        else
        {
            LOG_ERROR() << "Address " << to_string(id) << " is absent.";
        }
    }
    catch (...)
    {
    }
}


void WalletModel::setNodeAddress(const std::string& addr)
{
    io::Address nodeAddr;

    if (nodeAddr.resolve(addr.c_str()))
    {
        assert(!_nodeNetwork.expired());
        auto s = _nodeNetwork.lock();
        if (s)
        {
            s->Disconnect();

            static_cast<proto::FlyClient::NetworkStd&>(*s).m_Cfg.m_vNodes.clear();
            static_cast<proto::FlyClient::NetworkStd&>(*s).m_Cfg.m_vNodes.push_back(nodeAddr);

            s->Connect();
        }
    }
    else
    {
        LOG_ERROR() << "Unable to resolve node address: " << addr;
    }
}

vector<Coin> WalletModel::getUtxos() const
{
    vector<Coin> utxos;
    _walletDB->visit([&utxos](const Coin& c)->bool
    {
        utxos.push_back(c);
        return true;
    });
    return utxos;
}

void WalletModel::changeWalletPassword(const SecString& pass)
{
    _walletDB->changePassword(pass);
}

void WalletModel::getNetworkStatus()
{
    if (_walletError.is_initialized() && !_isConnected)
    {
        emit onWalletError(*_walletError);
        return;
    }

    emit nodeConnectionChanged(_isConnected);
}

bool WalletModel::check_receiver_address(const std::string& addr)
{
    WalletID walletID;
    return
        walletID.FromHex(addr) &&
        walletID.IsValid();
}

QString WalletModel::GetErrorString(beam::wallet::ErrorType type)
{
    // TODO: add more detailed error description
    switch (type)
    {
    case wallet::ErrorType::NodeProtocolBase:
        return tr("Node protocol error!");
    case wallet::ErrorType::NodeProtocolIncompatible:
        return tr("You are trying to connect to incompatible peer.");
	case wallet::ErrorType::TimeOutOfSync:
		return tr("System time not synchronized.");
    case wallet::ErrorType::ConnectionTimedOut:
        return tr("Connection timed out.");
    case wallet::ErrorType::ConnectionRefused:
        return tr("Cannot connect to node: ") + _nodeAddrStr.c_str();
    default:
        return tr("Unexpected error!");
    }
}