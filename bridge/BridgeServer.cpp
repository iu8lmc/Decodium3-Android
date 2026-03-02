#include "BridgeServer.hpp"
#include <QDebug>
#include <QDateTime>
#include <cstring>

BridgeServer::BridgeServer(quint16 port, QObject *parent)
    : QObject(parent)
    , m_port(port)
{
    m_heartbeatTimer.setInterval(5000); // 5s heartbeat
    connect(&m_heartbeatTimer, &QTimer::timeout,
            this, &BridgeServer::onHeartbeatTimeout);
}

BridgeServer::~BridgeServer()
{
    stop();
}

bool BridgeServer::start()
{
    if (m_server) return true;

    m_server = new QWebSocketServer(
        QStringLiteral("DecodiumBridge"),
        QWebSocketServer::NonSecureMode, this);

    if (!m_server->listen(QHostAddress::Any, m_port)) {
        emit serverError(tr("Cannot listen on port %1: %2")
                         .arg(m_port).arg(m_server->errorString()));
        delete m_server;
        m_server = nullptr;
        return false;
    }

    connect(m_server, &QWebSocketServer::newConnection,
            this, &BridgeServer::onNewConnection);

    emit statusMessage(tr("Bridge listening on port %1").arg(m_port));
    qDebug() << "BridgeServer: listening on port" << m_port;
    return true;
}

void BridgeServer::stop()
{
    m_heartbeatTimer.stop();
    if (m_client) {
        m_client->close();
        m_client = nullptr;
    }
    if (m_server) {
        m_server->close();
        delete m_server;
        m_server = nullptr;
    }
}

bool BridgeServer::isClientConnected() const
{
    return m_client && m_client->isValid();
}

void BridgeServer::sendAudioRx(const QByteArray &pcmData)
{
    sendPacket(BridgeProtocol::AUDIO_RX, pcmData);
}

void BridgeServer::sendCatStatus(quint64 freq, quint8 mode, bool ptt, qint16 sMeter)
{
    BridgeProtocol::CatStatusPayload status;
    status.frequency = freq;
    status.mode = mode;
    status.ptt = ptt ? 1 : 0;
    status.sMeter = sMeter;
    QByteArray payload(reinterpret_cast<const char*>(&status), sizeof(status));
    sendPacket(BridgeProtocol::CAT_STATUS, payload);
}

void BridgeServer::sendSpectrum(const QByteArray &fftBins)
{
    sendPacket(BridgeProtocol::SPECTRUM, fftBins);
}

void BridgeServer::sendHeartbeat()
{
    quint32 ts = static_cast<quint32>(QDateTime::currentMSecsSinceEpoch() & 0xFFFFFFFF);
    QByteArray payload(reinterpret_cast<const char*>(&ts), sizeof(ts));
    sendPacket(BridgeProtocol::HEARTBEAT, payload);
}

void BridgeServer::sendPacket(BridgeProtocol::MessageType type,
                              const QByteArray &payload)
{
    if (!m_client || !m_client->isValid()) return;

    BridgeProtocol::PacketHeader hdr;
    hdr.magic = BridgeProtocol::MAGIC;
    hdr.type = static_cast<uint8_t>(type);
    hdr.reserved = 0;
    hdr.payloadSize = static_cast<uint16_t>(payload.size());

    QByteArray packet;
    packet.reserve(sizeof(hdr) + payload.size());
    packet.append(reinterpret_cast<const char*>(&hdr), sizeof(hdr));
    packet.append(payload);

    m_client->sendBinaryMessage(packet);
}

void BridgeServer::onNewConnection()
{
    QWebSocket *socket = m_server->nextPendingConnection();
    if (!socket) return;

    // Only one client at a time
    if (m_client) {
        qDebug() << "BridgeServer: rejecting second client from"
                 << socket->peerAddress().toString();
        socket->close();
        socket->deleteLater();
        return;
    }

    m_client = socket;
    connect(m_client, &QWebSocket::binaryMessageReceived,
            this, &BridgeServer::onBinaryMessageReceived);
    connect(m_client, &QWebSocket::disconnected,
            this, &BridgeServer::onClientDisconnected);

    m_heartbeatTimer.start();

    qDebug() << "BridgeServer: client connected from"
             << m_client->peerAddress().toString();
    emit statusMessage(tr("Client connected: %1")
                       .arg(m_client->peerAddress().toString()));
    emit clientConnected();
}

void BridgeServer::onClientDisconnected()
{
    m_heartbeatTimer.stop();
    if (m_client) {
        m_client->deleteLater();
        m_client = nullptr;
    }
    qDebug() << "BridgeServer: client disconnected";
    emit statusMessage(tr("Client disconnected"));
    emit clientDisconnected();
}

void BridgeServer::onBinaryMessageReceived(const QByteArray &message)
{
    processPacket(message);
}

void BridgeServer::onHeartbeatTimeout()
{
    sendHeartbeat();
}

void BridgeServer::processPacket(const QByteArray &data)
{
    if (data.size() < static_cast<int>(sizeof(BridgeProtocol::PacketHeader))) {
        qWarning() << "BridgeServer: packet too small:" << data.size();
        return;
    }

    BridgeProtocol::PacketHeader hdr;
    std::memcpy(&hdr, data.constData(), sizeof(hdr));

    if (hdr.magic != BridgeProtocol::MAGIC) {
        qWarning() << "BridgeServer: bad magic:" << Qt::hex << hdr.magic;
        return;
    }

    QByteArray payload = data.mid(sizeof(hdr), hdr.payloadSize);

    switch (static_cast<BridgeProtocol::MessageType>(hdr.type)) {
    case BridgeProtocol::AUDIO_TX:
        emit audioTxReceived(payload);
        break;

    case BridgeProtocol::CAT_FREQ:
        if (payload.size() >= 8) {
            quint64 freq;
            std::memcpy(&freq, payload.constData(), sizeof(freq));
            emit catFreqReceived(freq);
        }
        break;

    case BridgeProtocol::CAT_MODE:
        emit catModeReceived(QString::fromUtf8(payload));
        break;

    case BridgeProtocol::CAT_PTT:
        if (payload.size() >= 1) {
            emit catPttReceived(payload.at(0) != 0);
        }
        break;

    case BridgeProtocol::HEARTBEAT:
        if (payload.size() >= 4) {
            quint32 ts;
            std::memcpy(&ts, payload.constData(), sizeof(ts));
            emit heartbeatReceived(ts);
        }
        break;

    default:
        qDebug() << "BridgeServer: unknown message type:" << hdr.type;
        break;
    }
}
