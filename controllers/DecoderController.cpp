#include "DecoderController.hpp"
#include "commons.h"
#include <QDebug>
#include <QFile>
#include <QTextStream>
#include <QStandardPaths>
#include <QDir>
#include <QDateTime>
#include <QThread>
#include <cstring>

// Shared data — defined in main.cpp
extern dec_data_t dec_data;

// Fortran decoder and spectrum functions
typedef int fortran_charlen_t;
extern "C" {
    // Main decoder dispatch (decoder.f90)
    void multimode_decoder_(float ss[], short id2[], void *params, int *nfsample);

    // Spectrum computation (symspec.f90)
    void symspec_(void *dd, int *k, double *trperiod, int *nsps, int *ingain,
                  bool *bLowSidelobes, int *minw, float *px, float s[], float *df3,
                  int *nhsym, int *npts8, float *pxmax, int *npct);

    // Fortran prog_args initialization
    // prog_args module variables: temp_dir, data_dir, exe_dir
    // These are set via a bridge subroutine or by writing to the module directly.
    // For simplicity, we create decoded.txt in the app's data directory.
}

DecoderController::DecoderController(QObject *parent)
    : QObject(parent)
{
    // Ensure temp directory exists for decoded.txt
    QString dataDir = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
    QDir().mkpath(dataDir);
}

DecoderController::~DecoderController()
{
    // Wait for decoder thread to finish
    while (m_decoderRunning.load()) {
        QThread::msleep(10);
    }
}

double DecoderController::period() const
{
    return m_period;
}

void DecoderController::setPeriod(double p)
{
    if (!qFuzzyCompare(m_period, p) && p > 0.0) {
        m_period = p;
        emit periodChanged();
    }
}

bool DecoderController::decoding() const
{
    return m_decoding;
}

int DecoderController::nDecodes() const
{
    return m_nDecodes;
}

int DecoderController::deepSearch() const
{
    return m_deepSearch;
}

void DecoderController::setDeepSearch(int level)
{
    if (m_deepSearch != level && level >= 0 && level <= 3) {
        m_deepSearch = level;
        emit deepSearchChanged();
    }
}

QString DecoderController::currentMode() const
{
    return m_currentMode;
}

void DecoderController::setCurrentMode(const QString &mode)
{
    if (m_currentMode != mode) {
        m_currentMode = mode;
        emit currentModeChanged();
        updatePeriodForMode();
    }
}

void DecoderController::setMyCall(const QString &call)
{
    m_myCall = call.toUpper().trimmed();
}

void DecoderController::setMyGrid(const QString &grid)
{
    m_myGrid = grid.toUpper().trimmed();
}

void DecoderController::setNfqso(int freq)
{
    m_nfqso = freq;
}

void DecoderController::clearDecodes()
{
    m_nDecodes = 0;
    emit nDecodesChanged();
}

void DecoderController::decode()
{
    if (m_decoding || m_decoderRunning.load())
        return;

    m_decoding = true;
    emit decodingChanged();
    emit decodingStarted();

    // Run decoder in background thread
    m_decoderRunning.store(true);
    std::thread(&DecoderController::runDecoder, this).detach();
}

void DecoderController::runDecoder()
{
    qDebug() << "DecoderController: starting decode for" << m_currentMode
             << "kin=" << m_lastKin << "nfqso=" << m_nfqso;

    // Prepare decoder params
    // Make a local copy of params to avoid race with audio thread
    auto params = dec_data.params;

    // Set mode
    if (m_currentMode == QLatin1String("FT8"))      params.nmode = 8;
    else if (m_currentMode == QLatin1String("FT2"))  params.nmode = 2;
    else if (m_currentMode == QLatin1String("FT4"))  params.nmode = 5;
    else                                              params.nmode = 8;

    // Set TR period
    params.ntrperiod = static_cast<int>(m_period);

    // Sample position (use last known kin before reset)
    params.kin = static_cast<int>(m_lastKin);
    if (params.kin <= 0) params.kin = static_cast<int>(m_period * 12000);

    // Decode timing
    int utcNow = QDateTime::currentDateTimeUtc().time().hour() * 10000
               + QDateTime::currentDateTimeUtc().time().minute() * 100
               + QDateTime::currentDateTimeUtc().time().second();
    params.nutc = utcNow;

    // Decode parameters
    params.newdat = true;
    params.nagain = false;
    params.ndepth = m_deepSearch;
    params.nfqso = m_nfqso;
    params.nftx = m_nfqso;  // TX freq = RX freq unless split
    params.nfa = 200;       // low decode limit (Hz)
    params.nfb = 5000;      // high decode limit (Hz)
    params.ntol = 20;       // frequency tolerance

    // FT8-specific symbol count for decode timing
    if (params.nmode == 8) {
        params.nzhsym = 41;  // full FT8 decode (50 half-symbols → 41 for legacy)
    } else {
        params.nzhsym = 41;
    }

    // Callsigns (Fortran expects space-padded char arrays)
    std::memset(params.mycall, ' ', 12);
    std::memset(params.hiscall, ' ', 12);
    std::memset(params.mygrid, ' ', 6);
    std::memset(params.hisgrid, ' ', 6);
    if (!m_myCall.isEmpty()) {
        QByteArray mc = m_myCall.toLatin1();
        std::memcpy(params.mycall, mc.constData(), qMin(mc.size(), 12));
    }
    if (!m_myGrid.isEmpty()) {
        QByteArray mg = m_myGrid.toLatin1();
        std::memcpy(params.mygrid, mg.constData(), qMin(mg.size(), 6));
    }

    // AP decoding flags
    params.lft8apon = true;
    params.lapcqonly = false;
    params.napwid = 50;
    params.n2pass = 2;
    params.nranera = 6;
    params.naggressive = 0;
    params.nrobust = false;
    params.nexp_decode = 0;

    // FT8 multi-thread decoder settings
    params.lmultift8 = false;
    params.nft8cycles = 3;
    params.nmt = 0;
    params.nft8rxfsens = 3;
    params.lft8lowth = true;
    params.lft8subpass = true;
    params.lhideft8dupes = false;
    params.lhound = false;
    params.lcommonft8b = false;
    params.lmycallstd = true;
    params.lhiscallstd = true;
    params.lapmyc = false;
    params.lmodechanged = false;
    params.lbandchanged = false;
    params.lenabledxcsearch = false;
    params.lwidedxcsearch = false;
    params.lmultinst = false;
    params.lskiptx1 = false;
    params.ltxing = false;
    params.ncandthin = 2;
    params.ndtcenter = 0;
    params.ntrials10 = 3;
    params.ntrialsrxf10 = 3;
    params.nharmonicsdepth = 0;
    params.ntopfreq65 = 0;
    params.nprepass = 1;
    params.nsdecatt = 0;
    params.nlasttx = 0;
    params.ndelay = 0;
    params.nft4depth = 3;
    params.nsecbandchanged = 0;
    params.nagainfil = false;
    params.nstophint = true;
    params.nhint = false;
    params.fmaskact = false;
    params.ndecoderstart = 3;

    // DateTime string for decoder
    QByteArray dt = QDateTime::currentDateTimeUtc().toString("yyyyMMdd_HHmmss").toLatin1();
    std::memset(params.datetime, ' ', 20);
    std::memcpy(params.datetime, dt.constData(), qMin(dt.size(), 20));

    // Date for superfox
    params.yymmdd = QDateTime::currentDateTimeUtc().toString("yyMMdd").toInt();
    params.b_even_seq = false;
    params.b_superfox = false;

    // Clear mybcall / hisbcall
    std::memset(params.mybcall, ' ', 12);
    std::memset(params.hisbcall, ' ', 12);

    // Call the Fortran decoder
    int nfsample = 12000;
    multimode_decoder_(dec_data.ss, dec_data.d2, &params, &nfsample);

    // Parse results from decoded.txt
    parseDecodedResults();

    qDebug() << "DecoderController: decode complete, found" << m_nDecodes << "decodes";

    m_decoderRunning.store(false);
    QMetaObject::invokeMethod(this, "onDecodingComplete", Qt::QueuedConnection);
}

void DecoderController::parseDecodedResults()
{
    // decoded.txt is written by decoder.f90 in the current working directory
    // Format: HHMMSS sync  SNR   DT     Freq  flag   message              mode
    //         i6.6   i4    i5    f6.1   f8.0  i4 3x  a37                  ' FT8'
    // Positions: 0-5  6-9  10-14 15-20  21-28 29-32  36-72

    QFile file(QStringLiteral("decoded.txt"));
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qDebug() << "DecoderController: could not open decoded.txt";
        return;
    }

    QTextStream in(&file);
    while (!in.atEnd()) {
        QString line = in.readLine();
        if (line.length() < 40)
            continue;

        // Parse fixed-position fields
        QString utc = line.mid(0, 6).trimmed();
        int snr = line.mid(10, 5).trimmed().toInt();
        double dt = line.mid(15, 6).trimmed().toDouble();
        int freq = qRound(line.mid(21, 8).trimmed().toDouble());
        QString message = line.mid(36, 37).trimmed();

        if (utc.isEmpty() || message.isEmpty())
            continue;

        // Post result to GUI thread
        QMetaObject::invokeMethod(this, "onDecodeResult",
            Qt::QueuedConnection,
            Q_ARG(QString, utc), Q_ARG(int, snr),
            Q_ARG(double, dt), Q_ARG(int, freq),
            Q_ARG(QString, message));
    }
    file.close();
}

double DecoderController::periodForMode(const QString &mode) const
{
    if (mode == QLatin1String("FT8"))
        return 15.0;
    if (mode == QLatin1String("FT4"))
        return 7.5;
    if (mode == QLatin1String("FT2"))
        return 3.75;
    if (mode == QLatin1String("JT65"))
        return 60.0;
    if (mode == QLatin1String("JT9"))
        return 60.0;
    if (mode == QLatin1String("WSPR"))
        return 120.0;
    return 15.0;
}

void DecoderController::onDecodeResult(const QString &utc, int snr, double dt, int freq, const QString &message)
{
    m_nDecodes++;
    emit nDecodesChanged();
    emit newDecode(utc, snr, dt, freq, message);
}

void DecoderController::onDecodingComplete()
{
    m_decoding = false;
    emit decodingChanged();
    emit decodingFinished();
}

void DecoderController::onFramesWritten(qint64 nFrames)
{
    // nFrames is dec_data.params.kin (cumulative samples in current period)

    // Detect TR period boundary: kin drops below previous value → period reset
    if (nFrames < m_lastKin && m_lastKin > 0 && !m_decoding) {
        qDebug() << "DecoderController: TR period complete, kin was"
                 << m_lastKin << "starting decode for" << m_currentMode;
        decode();
    }

    m_lastKin = nFrames;

    // Compute spectrum for waterfall display
    computeSpectrum(nFrames);
}

void DecoderController::computeSpectrum(qint64 k)
{
    if (k <= 0)
        return;

    // Determine nsps for current mode
    int nsps = 1920; // FT8 default
    if (m_currentMode == QLatin1String("FT2"))      nsps = 288;
    else if (m_currentMode == QLatin1String("FT4"))  nsps = 576;

    double trperiod = m_period;
    int ingain = 0;
    bool bLowSidelobes = false;
    int minw = 2;
    int npct = 0;
    int kk = static_cast<int>(k);

    float s[NSMAX];
    std::memset(s, 0, sizeof(s));

    symspec_(&dec_data, &kk, &trperiod, &nsps, &ingain,
             &bLowSidelobes, &minw, &m_px, s, &m_df3,
             &m_ihsym, &m_npts8, &m_pxmax, &npct);

    // Only emit if we got valid spectrum data
    if (m_df3 > 0.0f && m_ihsym > 0) {
        // Number of bins to cover 0–5000 Hz
        int nbins = qMin(static_cast<int>(5000.0 / m_df3), static_cast<int>(NSMAX));

        QList<float> bins;
        bins.reserve(nbins);
        for (int i = 0; i < nbins; i++) {
            bins.append(s[i]);
        }
        emit spectrumData(bins);
    }
}

void DecoderController::updatePeriodForMode()
{
    double newPeriod = periodForMode(m_currentMode);
    if (!qFuzzyCompare(m_period, newPeriod)) {
        m_period = newPeriod;
        emit periodChanged();
    }
    // Reset spectrum tracking on mode change
    m_ihsym = 0;
    m_pxmax = 0.0f;
}
