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
#include <QSettings>
#include <QQmlListProperty>

#include "model/settings.h"

class DeviceItem : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString name       READ getName     CONSTANT )
    Q_PROPERTY(bool enabled       READ getEnabled WRITE setEnabled     NOTIFY enableChanged)

public:

    DeviceItem() = default;
    DeviceItem(const QString& name, int32_t index, bool enabled);
    virtual ~DeviceItem();

    QString getName() const;
    bool getEnabled() const;
    void setEnabled(bool value);
    int32_t getIndex() const;
    

signals:
    void enableChanged();

private:
    QString m_name;
    int32_t m_index;
    bool m_enabled;
};

class SettingsViewModel : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString nodeAddress READ getNodeAddress WRITE setNodeAddress NOTIFY nodeAddressChanged)
    Q_PROPERTY(QString version READ getVersion CONSTANT)
    Q_PROPERTY(bool localNodeRun READ getLocalNodeRun WRITE setLocalNodeRun NOTIFY localNodeRunChanged)
    Q_PROPERTY(uint localNodePort READ getLocalNodePort WRITE setLocalNodePort NOTIFY localNodePortChanged)
    Q_PROPERTY(uint localNodeMiningThreads READ getLocalNodeMiningThreads WRITE setLocalNodeMiningThreads NOTIFY localNodeMiningThreadsChanged)
    Q_PROPERTY(bool isChanged READ isChanged NOTIFY propertiesChanged)
    Q_PROPERTY(QStringList localNodePeers READ getLocalNodePeers NOTIFY localNodePeersChanged)
    Q_PROPERTY(int lockTimeout READ getLockTimeout WRITE setLockTimeout NOTIFY lockTimeoutChanged)
    Q_PROPERTY(QString walletLocation READ getWalletLocation CONSTANT)
    Q_PROPERTY(bool useGpu READ getUseGpu WRITE setUseGpu NOTIFY localNodeUseGpuChanged)
    Q_PROPERTY(QQmlListProperty<DeviceItem> supportedDevices READ getSupportedDevices NOTIFY localNodeUseGpuChanged)
    Q_PROPERTY(bool isLocalNodeRunning READ isLocalNodeRunning  NOTIFY localNodeRunningChanged)
public:

    SettingsViewModel();

    QString getNodeAddress() const;
    void setNodeAddress(const QString& value);
    QString getVersion() const;
    bool getLocalNodeRun() const;
    void setLocalNodeRun(bool value);
    uint getLocalNodePort() const;
    void setLocalNodePort(uint value);
    uint getLocalNodeMiningThreads() const;
    void setLocalNodeMiningThreads(uint value);
    int getLockTimeout() const;
    void setLockTimeout(int value);

    QStringList getLocalNodePeers() const;
    void setLocalNodePeers(const QStringList& localNodePeers);
    QString getWalletLocation() const;
    void setUseGpu(bool value);
    bool getUseGpu() const;
    bool isLocalNodeRunning() const;

    QQmlListProperty<DeviceItem> getSupportedDevices();

    bool isChanged() const;

    Q_INVOKABLE uint coreAmount() const;
    Q_INVOKABLE void addLocalNodePeer(const QString& localNodePeer);
    Q_INVOKABLE void deleteLocalNodePeer(int index);
    Q_INVOKABLE void openUrl(const QString& url);
    Q_INVOKABLE void copyToClipboard(const QString& text);
    Q_INVOKABLE bool showUseGpu() const;
    Q_INVOKABLE bool hasSupportedGpu();
    Q_INVOKABLE void refreshWallet();

private:
#ifdef BEAM_USE_GPU
    std::vector<int32_t> getSelectedDevice() const;
#endif
public slots:
    void applyChanges();
    void undoChanges();
	void reportProblem();
    bool checkWalletPassword(const QString& oldPass) const;
    void changeWalletPassword(const QString& pass);
    void onNodeStarted();
    void onNodeStopped();

signals:
    void nodeAddressChanged();
    void localNodeRunChanged();
    void localNodePortChanged();
    void localNodeMiningThreadsChanged();
    void localNodePeersChanged();
    void propertiesChanged();
    void lockTimeoutChanged();
    void localNodeUseGpuChanged();
    void localNodeRunningChanged();
private:
    WalletSettings& m_settings;

    QString m_nodeAddress;
    bool m_localNodeRun;
    uint m_localNodePort;
    uint m_localNodeMiningThreads;
    QStringList m_localNodePeers;

    QList<DeviceItem*> m_supportedDevices;
    int m_lockTimeout;
#ifdef BEAM_USE_GPU
    bool m_useGpu;
    boost::optional<bool> m_hasSupportedGpu;
#endif
};
