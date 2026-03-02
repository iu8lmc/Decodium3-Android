#include <QCoreApplication>
#include <QCommandLineParser>
#include <QMediaDevices>
#include <QAudioDevice>
#include <QDebug>

#include "BridgeServer.hpp"
#include "AudioCapture.hpp"
#include "AudioPlayback.hpp"
#include "CatRelay.hpp"
#include "DiscoveryService.hpp"

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("DecodiumBridge"));
    app.setApplicationVersion(QStringLiteral("1.0.0"));

    QCommandLineParser parser;
    parser.setApplicationDescription(
        QStringLiteral("Decodium WiFi Audio Bridge - connects Android Decodium3 to PC radio"));
    parser.addHelpOption();
    parser.addVersionOption();

    QCommandLineOption portOption(
        QStringList() << "p" << "port",
        QStringLiteral("WebSocket port (default: 52178)"),
        QStringLiteral("port"),
        QString::number(BridgeProtocol::WEBSOCKET_PORT));
    parser.addOption(portOption);

    QCommandLineOption inputOption(
        QStringList() << "i" << "input",
        QStringLiteral("Audio input device name"),
        QStringLiteral("device"));
    parser.addOption(inputOption);

    QCommandLineOption outputOption(
        QStringList() << "o" << "output",
        QStringLiteral("Audio output device name"),
        QStringLiteral("device"));
    parser.addOption(outputOption);

    QCommandLineOption listDevicesOption(
        QStringList() << "l" << "list-devices",
        QStringLiteral("List available audio devices and exit"));
    parser.addOption(listDevicesOption);

    QCommandLineOption rigOption(
        "rig",
        QStringLiteral("Hamlib rig model number"),
        QStringLiteral("model"));
    parser.addOption(rigOption);

    QCommandLineOption rigPortOption(
        "rig-port",
        QStringLiteral("Hamlib serial port (e.g. COM3 or /dev/ttyUSB0)"),
        QStringLiteral("port"));
    parser.addOption(rigPortOption);

    QCommandLineOption baudOption(
        "baud",
        QStringLiteral("Hamlib baud rate (default: 9600)"),
        QStringLiteral("rate"),
        QStringLiteral("9600"));
    parser.addOption(baudOption);

    parser.process(app);

    // List devices mode
    if (parser.isSet(listDevicesOption)) {
        qDebug() << "=== Audio Input Devices ===";
        for (const auto &dev : QMediaDevices::audioInputs()) {
            qDebug() << "  " << dev.description();
        }
        qDebug() << "\n=== Audio Output Devices ===";
        for (const auto &dev : QMediaDevices::audioOutputs()) {
            qDebug() << "  " << dev.description();
        }
        return 0;
    }

    quint16 wsPort = parser.value(portOption).toUShort();

    // --- Bridge Server ---
    BridgeServer server(wsPort);

    // --- Audio Capture (RX: soundcard → Android) ---
    AudioCapture capture;
    QAudioDevice inputDev;
    if (parser.isSet(inputOption)) {
        QString name = parser.value(inputOption);
        for (const auto &dev : QMediaDevices::audioInputs()) {
            if (dev.description() == name) {
                inputDev = dev;
                break;
            }
        }
        if (inputDev.isNull()) {
            qWarning() << "Input device not found:" << name;
        }
    }
    if (inputDev.isNull()) {
        inputDev = QMediaDevices::defaultAudioInput();
    }

    // --- Audio Playback (TX: Android → soundcard) ---
    AudioPlayback playback;
    QAudioDevice outputDev;
    if (parser.isSet(outputOption)) {
        QString name = parser.value(outputOption);
        for (const auto &dev : QMediaDevices::audioOutputs()) {
            if (dev.description() == name) {
                outputDev = dev;
                break;
            }
        }
        if (outputDev.isNull()) {
            qWarning() << "Output device not found:" << name;
        }
    }
    if (outputDev.isNull()) {
        outputDev = QMediaDevices::defaultAudioOutput();
    }

    // --- CAT Relay ---
    CatRelay catRelay;

    // --- Discovery ---
    DiscoveryService discovery;

    // === Wire everything together ===

    // Audio RX: capture chunk → send to client
    QObject::connect(&capture, &AudioCapture::pcmChunkReady,
                     &server, &BridgeServer::sendAudioRx);

    // Audio TX: received from client → play on soundcard
    QObject::connect(&server, &BridgeServer::audioTxReceived,
                     &playback, &AudioPlayback::writePcm);

    // CAT: client commands → Hamlib
    QObject::connect(&server, &BridgeServer::catFreqReceived,
                     &catRelay, &CatRelay::setFrequency);
    QObject::connect(&server, &BridgeServer::catModeReceived,
                     &catRelay, &CatRelay::setMode);
    QObject::connect(&server, &BridgeServer::catPttReceived,
                     &catRelay, &CatRelay::setPtt);

    // CAT: status poll → send to client
    QObject::connect(&catRelay, &CatRelay::statusUpdate,
                     &server, &BridgeServer::sendCatStatus);

    // Start/stop audio when client connects/disconnects
    QObject::connect(&server, &BridgeServer::clientConnected, [&]() {
        qDebug() << "Client connected - starting audio";
        capture.start(inputDev);
        playback.start(outputDev);
    });

    QObject::connect(&server, &BridgeServer::clientDisconnected, [&]() {
        qDebug() << "Client disconnected - stopping audio";
        capture.stop();
        playback.stop();
    });

    // Status messages
    QObject::connect(&server, &BridgeServer::statusMessage, [](const QString &msg) {
        qDebug() << "[Bridge]" << msg;
    });
    QObject::connect(&server, &BridgeServer::serverError, [](const QString &msg) {
        qCritical() << "[Bridge ERROR]" << msg;
    });

    // Open Hamlib if configured
    if (parser.isSet(rigOption) && parser.isSet(rigPortOption)) {
        int model = parser.value(rigOption).toInt();
        QString port = parser.value(rigPortOption);
        int baud = parser.value(baudOption).toInt();
        if (!catRelay.open(model, port, baud)) {
            qWarning() << "Failed to open Hamlib rig - CAT relay disabled";
        }
    }

    // Start bridge
    if (!server.start()) {
        qCritical() << "Failed to start bridge server";
        return 1;
    }

    // Start discovery broadcast
    discovery.startBroadcast(wsPort);

    qDebug() << "\n========================================";
    qDebug() << " DecodiumBridge v1.0.0";
    qDebug() << " WebSocket port:" << wsPort;
    qDebug() << " RX input:" << inputDev.description();
    qDebug() << " TX output:" << outputDev.description();
    qDebug() << " Waiting for connection...";
    qDebug() << "========================================\n";

    return app.exec();
}
