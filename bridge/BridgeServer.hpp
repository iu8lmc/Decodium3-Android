#ifndef BRIDGE_SERVER_HPP
#define BRIDGE_SERVER_HPP

#include <QObject>
#include <QWebSocketServer>
#include <QWebSocket>
#include <QTimer>
#include <QByteArray>
#include "BridgeProtocol.hpp"

class BridgeServer : public QObject
{
    Q_OBJECT

public:
    explicit BridgeServer(quint16 port = BridgeProtocol::WEBSOCKET_PORT,
                          QObject *parent = nullptr);
    ~BridgeServer() override;

    bool start();
    void stop();
    bool isClientConnected() const;

    // Send data to connected client
    void sendAudioRx(const QByteArray &pcmData);
    void sendCatStatus(quint64 freq, quint8 mode, bool ptt, qint16 sMeter);
    void sendSpectrum(const QByteArray &fftBins);
    void sendHeartbeat();

signals:
    void clientConnected();
    void clientDisconnected();
    void audioTxReceived(const QByteArray &pcmData);
    void catFreqReceived(quint64 freqHz);
    void catModeReceived(const QString &mode);
    void catPttReceived(bool on);
    void heartbeatReceived(quint32 timestamp);
    void serverError(const QString &message);
    void statusMessage(const QString &message);

private slots:
    void onNewConnection();
    void onClientDisconnected();
    void onBinaryMessageReceived(const QByteArray &message);
    void onHeartbeatTimeout();

private:
    void sendPacket(BridgeProtocol::MessageType type,
                    const QByteArray &payload);
    void processPacket(const QByteArray &data);

    QWebSocketServer *m_server = nullptr;
    QWebSocket *m_client = nullptr;
    QTimer m_heartbeatTimer;
    quint16 m_port;
};

#endif // BRIDGE_SERVER_HPP
