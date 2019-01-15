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

#pragma once

#include <QObject>
#include <QThread>

#include "wallet/common.h"
#include "wallet/wallet.h"
#include "wallet/wallet_db.h"
#include "wallet/wallet_network.h"
#include "wallet/wallet_model_async.h"

struct WalletStatus
{
    beam::Amount available = 0;
    beam::Amount receiving = 0;
    beam::Amount sending = 0;
    beam::Amount maturing = 0;

    struct
    {
        beam::Timestamp lastTime;
        int done;
        int total;
    } update;

    beam::Block::SystemState::ID stateID;
};

class WalletModel
    : public QThread
    , private beam::IWalletObserver
    , private IWalletModelAsync
{
    Q_OBJECT
public:

    using Ptr = std::shared_ptr<WalletModel>;

    WalletModel(beam::IWalletDB::Ptr walletDB, const std::string& nodeAddr);
    ~WalletModel();

    void run() override;

public:
    
    IWalletModelAsync::Ptr getAsync();
    bool check_receiver_address(const std::string& addr);

    QString GetErrorString(beam::wallet::ErrorType type);

signals:
    void onStatus(const WalletStatus& status);
    void onTxStatus(beam::ChangeAction, const std::vector<beam::TxDescription>& items);
    void onSyncProgressUpdated(int done, int total);
    void onChangeCalculated(beam::Amount change);
    void onAllUtxoChanged(const std::vector<beam::Coin>& utxos);
    void onAdrresses(bool own, const std::vector<beam::WalletAddress>& addresses);
    void onGeneratedNewAddress(const beam::WalletAddress& walletAddr);
    void onChangeCurrentWalletIDs(beam::WalletID senderID, beam::WalletID receiverID);
    void nodeConnectionChanged(bool isNodeConnected);
    void onWalletError(beam::wallet::ErrorType error);
    void sendMoneyVerified();
    void cantSendToExpired();

private:
    void onCoinsChanged() override;
    void onTransactionChanged(beam::ChangeAction action, std::vector<beam::TxDescription>&& items) override;
    void onSystemStateChanged() override;
    void onAddressChanged() override;
    void onSyncProgress(int done, int total) override;

    void sendMoney(const beam::WalletID& receiver, const std::string& comment, beam::Amount&& amount, beam::Amount&& fee) override;
    void syncWithNode() override;
    void calcChange(beam::Amount&& amount) override;
    void getWalletStatus() override;
    void getUtxosStatus() override;
    void getAddresses(bool own) override;
    void cancelTx(const beam::TxID& id) override;
    void deleteTx(const beam::TxID& id) override;
    void saveAddress(const beam::WalletAddress& address, bool bOwn) override;
    void changeCurrentWalletIDs(const beam::WalletID& senderID, const beam::WalletID& receiverID) override;
    void generateNewAddress() override;
    void deleteAddress(const beam::WalletID& id) override;
    void saveAddressChanges(const beam::WalletID& id, const std::string& name, bool isNever, bool makeActive, bool makeExpired) override;
    void setNodeAddress(const std::string& addr) override;
    void changeWalletPassword(const beam::SecString& password) override;
    void getNetworkStatus() override;

    void onNodeConnectedStatusChanged(bool isNodeConnected);
    void onNodeConnectionFailed(const beam::proto::NodeConnection::DisconnectReason&);

    void onStatusChanged();
    WalletStatus getStatus() const;
    std::vector<beam::Coin> getUtxos() const;
private:

    beam::IWalletDB::Ptr _walletDB;
    beam::io::Reactor::Ptr _reactor;
    IWalletModelAsync::Ptr _async;
    std::weak_ptr<beam::proto::FlyClient::INetwork> _nodeNetwork;
    std::weak_ptr<beam::IWalletNetwork> _walletNetwork;
    std::weak_ptr<beam::Wallet> _wallet;
    beam::io::Timer::Ptr _logRotateTimer;
    bool _isConnected;
    boost::optional<beam::wallet::ErrorType> _walletError;

    std::string _nodeAddrStr;
};
