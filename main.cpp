#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QFont>
#include <QIcon>
#include <QDir>
#include <QCoreApplication>
#include <cstring>

#include "commons.h"
#include "widgets/itoneAndicw.h"

// Global variables shared with Fortran and C++ backend
int volatile itone[MAX_NUM_SYMBOLS];
int volatile icw[NUM_CW_SYMBOLS];
dec_data_t dec_data;

// Fortran TX encoding functions (extern "C")
// fortran_charlen_t is the hidden string-length argument appended by gfortran
typedef int fortran_charlen_t;
extern "C" {
    void genft8_(char* msg, int* i3, int* n3, char* msgsent,
                 char ft8msgbits[], int itone[],
                 fortran_charlen_t msg_len, fortran_charlen_t msgsent_len);
    void genft2_(char* msg, int* ichk, char* msgsent,
                 char ft2msgbits[], int itone[],
                 fortran_charlen_t msg_len, fortran_charlen_t msgsent_len);
    void genft4_(char* msg, int* ichk, char* msgsent,
                 char ft4msgbits[], int itone[],
                 fortran_charlen_t msg_len, fortran_charlen_t msgsent_len);
}

// Avoid macro clash with AudioController::RX_SAMPLE_RATE
#undef RX_SAMPLE_RATE

#include "controllers/AppController.hpp"
#include "controllers/RadioController.hpp"
#include "controllers/DecoderController.hpp"
#include "controllers/AudioController.hpp"
#include "controllers/TxController.hpp"
#include "controllers/LogController.hpp"
#include "controllers/WaterfallController.hpp"
#include "controllers/DecodeListModel.hpp"
#include "qmlitems/WaterfallItem.hpp"
#include "Audio/NetworkAudioInput.hpp"
#include "Audio/soundout.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setOrganizationName("Decodium");
    app.setOrganizationDomain("decodium.radio");
    app.setApplicationName("Decodium 3 FT2");
    app.setApplicationVersion("3.0.0");

    // Set default font
    QFont defaultFont("Segoe UI", 10);
    app.setFont(defaultFont);

    // Use Qt Quick Controls Material style as base
    QQuickStyle::setStyle("Basic");

    // Create controllers
    AppController appController;
    RadioController radioController;
    DecoderController decoderController;
    AudioController audioController;
    TxController txController;
    LogController logController;
    WaterfallController waterfallController;
    DecodeListModel decodeListModel;
    DecodeListModel decodeModelP1;
    DecodeListModel decodeModelP2;
    DecodeListModel decodeModelRx;

    // Connect controllers: radio mode → audio/decoder
    QObject::connect(&radioController, &RadioController::modeChanged,
                     [&audioController, &radioController]() {
        audioController.onModeChanged(radioController.mode());
    });
    QObject::connect(&radioController, &RadioController::modeChanged,
                     [&decoderController, &radioController]() {
        decoderController.setCurrentMode(radioController.mode());
    });

    // Connect audio → decoder: frames written triggers decode timing + spectrum
    QObject::connect(&audioController, &AudioController::framesWritten,
                     &decoderController, &DecoderController::onFramesWritten);

    // Connect decoder spectrum → waterfall display
    QObject::connect(&decoderController, &DecoderController::spectrumData,
                     &waterfallController, &WaterfallController::onSpectrumData);

    // WiFi CAT: forward radio changes to bridge when in WiFi mode
    QObject::connect(&radioController, &RadioController::dialFrequencyChanged,
                     [&audioController, &radioController]() {
        audioController.sendCatFreqToBridge(
            static_cast<quint64>(radioController.dialFrequency()));
    });
    QObject::connect(&radioController, &RadioController::modeChanged,
                     [&audioController, &radioController]() {
        audioController.sendCatModeToBridge(radioController.mode());
    });

    // ─── TX Encoding: txRequested → genXX_ → Modulator::start ───
    QObject::connect(&txController, &TxController::txRequested,
                     [&radioController, &audioController, &waterfallController,
                      &txController](const QString &message) {
        QString mode = radioController.mode();
        int txFreq = waterfallController.txFreq();

        // Prepare Fortran message buffers (37 chars, space-padded)
        char msg[37], msgsent[37], msgbits[77];
        std::memset(msg, ' ', 37);
        std::memset(msgsent, ' ', 37);
        std::memset(msgbits, 0, 77);
        QByteArray msgBytes = message.toLatin1();
        std::memcpy(msg, msgBytes.constData(), qMin(msgBytes.size(), 37));

        unsigned nsym = 79;
        double framesPerSymbol = 1920.0;
        double toneSpacing = 6.25;
        double trPeriod = 15.0;

        if (mode == QLatin1String("FT8")) {
            int i3 = 0, n3 = 0;
            genft8_(msg, &i3, &n3, msgsent, msgbits,
                    const_cast<int*>(itone), 37, 37);
            nsym = 79;
            framesPerSymbol = 1920.0;  // nsps at 12kHz base
            toneSpacing = 6.25;        // 12000/1920
            trPeriod = 15.0;
        } else if (mode == QLatin1String("FT2")) {
            int ichk = 0;
            genft2_(msg, &ichk, msgsent, msgbits,
                    const_cast<int*>(itone), 37, 37);
            nsym = 103;
            framesPerSymbol = 288.0;
            toneSpacing = 0.0;  // GFSK — Modulator uses baud = 12000/nsps
            trPeriod = 3.75;
        } else if (mode == QLatin1String("FT4")) {
            int ichk = 0;
            genft4_(msg, &ichk, msgsent, msgbits,
                    const_cast<int*>(itone), 37, 37);
            nsym = 103;
            framesPerSymbol = 576.0;
            toneSpacing = 0.0;  // GFSK
            trPeriod = 7.5;
        } else {
            qWarning() << "TX: unsupported mode" << mode;
            return;
        }

        qDebug() << "TX: encoded" << message << "for" << mode
                 << "nsym=" << nsym << "freq=" << txFreq;

        // Start Modulator (pulls from itone[] via readData)
        Modulator *mod = audioController.modulator();
        SoundOutput *sout = audioController.wifiMode()
                                ? nullptr : audioController.soundOutput();
        if (mod) {
            mod->start(mode, nsym, framesPerSymbol,
                       static_cast<double>(txFreq), toneSpacing,
                       sout, AudioDevice::Mono,
                       true, false, 99.0, trPeriod);
        }

        // In WiFi mode, also send PTT to bridge
        if (audioController.wifiMode()) {
            audioController.sendCatPttToBridge(true);
        }
    });

    // TX halt: stop Modulator
    QObject::connect(&txController, &TxController::haltRequested,
                     [&audioController]() {
        Modulator *mod = audioController.modulator();
        if (mod) mod->stop(true);
        if (audioController.wifiMode()) {
            audioController.sendCatPttToBridge(false);
        }
    });

    // Connect decoder → decode list models (all + per-period + rx-freq)
    QObject::connect(&decoderController, &DecoderController::newDecode,
                     [&decodeListModel, &decodeModelP1, &decodeModelP2,
                      &decodeModelRx, &waterfallController](
                         const QString &utc, int snr, double dt,
                         int freq, const QString &message) {
        bool isCQ = message.startsWith(QStringLiteral("CQ "));
        QColor color = isCQ ? QColor(QStringLiteral("#4CAF50"))    // verde — CQ
                            : QColor(QStringLiteral("#B0BEC5"));   // grigio — normale

        // Add to the combined model
        decodeListModel.addDecode(utc, snr, dt, freq, message, isCQ, false, color);

        // Determine period from UTC seconds: 00/30 = even (P1), 15/45 = odd (P2)
        int secs = utc.right(2).toInt();
        bool isEven = (secs == 0 || secs == 30);
        if (isEven)
            decodeModelP1.addDecode(utc, snr, dt, freq, message, isCQ, false, color);
        else
            decodeModelP2.addDecode(utc, snr, dt, freq, message, isCQ, false, color);

        // Add to RX freq model if within ±100 Hz of current rxFreq
        int rxFreq = waterfallController.rxFreq();
        if (qAbs(freq - rxFreq) <= 100)
            decodeModelRx.addDecode(utc, snr, dt, freq, message, isCQ, false, color);
    });

    // Clear all decode models at the start of each decoding period
    QObject::connect(&decoderController, &DecoderController::decodingStarted,
                     [&decodeListModel, &decodeModelP1, &decodeModelP2, &decodeModelRx]() {
        decodeListModel.clear();
        decodeModelP1.clear();
        decodeModelP2.clear();
        decodeModelRx.clear();
    });

    // Pass callsign/grid to decoder when they change
    QObject::connect(&appController, &AppController::callsignChanged,
                     [&decoderController, &appController]() {
        decoderController.setMyCall(appController.callsign());
    });
    QObject::connect(&appController, &AppController::gridChanged,
                     [&decoderController, &appController]() {
        decoderController.setMyGrid(appController.grid());
    });
    // Pass RX frequency to decoder
    QObject::connect(&waterfallController, &WaterfallController::rxFreqChanged,
                     [&decoderController, &waterfallController]() {
        decoderController.setNfqso(waterfallController.rxFreq());
    });

    // WiFi CAT: when bridge connects, wire CAT status feedback to RadioController
    QObject::connect(&audioController, &AudioController::bridgeConnectedChanged,
                     [&audioController, &radioController]() {
        auto *netInput = audioController.networkInput();
        if (netInput && audioController.bridgeConnected()) {
            // Disconnect any previous connections to avoid duplicates
            QObject::disconnect(netInput, &NetworkAudioInput::catStatusReceived,
                                nullptr, nullptr);
            QObject::connect(netInput, &NetworkAudioInput::catStatusReceived,
                             [&radioController](quint64 freq, quint8 /*mode*/,
                                                bool /*ptt*/, qint16 /*sMeter*/) {
                radioController.setDialFrequency(static_cast<double>(freq));
            });
        }
    });

    // Initialize decoder with current settings
    decoderController.setMyCall(appController.callsign());
    decoderController.setMyGrid(appController.grid());
    decoderController.setNfqso(waterfallController.rxFreq());

    // Initialize audio subsystem
    audioController.initialize();

    // Register QML types
    qmlRegisterType<WaterfallItem>("Decodium", 1, 0, "WaterfallItem");

    // Create QML engine
    QQmlApplicationEngine engine;

    // Import path for Decodium QML module (qrc resources)
    engine.addImportPath("qrc:/");

    // Import path for Qt QML modules next to the executable
    QString appDir = QCoreApplication::applicationDirPath();
    engine.addImportPath(appDir + "/qml");

    // Expose controllers to QML
    QQmlContext *ctx = engine.rootContext();
    ctx->setContextProperty("app", &appController);
    ctx->setContextProperty("radio", &radioController);
    ctx->setContextProperty("decoder", &decoderController);
    ctx->setContextProperty("audio", &audioController);
    ctx->setContextProperty("tx", &txController);
    ctx->setContextProperty("log", &logController);
    ctx->setContextProperty("waterfall", &waterfallController);
    ctx->setContextProperty("decodeModel", &decodeListModel);
    ctx->setContextProperty("decodeModelP1", &decodeModelP1);
    ctx->setContextProperty("decodeModelP2", &decodeModelP2);
    ctx->setContextProperty("decodeModelRx", &decodeModelRx);

    // Load main QML
    const QUrl url(QStringLiteral("qrc:/qml/main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);

    engine.load(url);

    return app.exec();
}
