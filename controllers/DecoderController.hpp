#ifndef DECODERCONTROLLER_HPP
#define DECODERCONTROLLER_HPP

#include <QObject>
#include <QQmlEngine>
#include <QString>
#include <QList>
#include <thread>
#include <atomic>

class DecoderController : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(double period READ period WRITE setPeriod NOTIFY periodChanged)
    Q_PROPERTY(bool decoding READ decoding NOTIFY decodingChanged)
    Q_PROPERTY(int nDecodes READ nDecodes NOTIFY nDecodesChanged)
    Q_PROPERTY(int deepSearch READ deepSearch WRITE setDeepSearch NOTIFY deepSearchChanged)
    Q_PROPERTY(QString currentMode READ currentMode WRITE setCurrentMode NOTIFY currentModeChanged)

public:
    explicit DecoderController(QObject *parent = nullptr);
    ~DecoderController() override;

    double period() const;
    void setPeriod(double p);

    bool decoding() const;

    int nDecodes() const;

    int deepSearch() const;
    void setDeepSearch(int level);

    QString currentMode() const;
    void setCurrentMode(const QString &mode);

    // Decoder params (set from main.cpp wiring)
    void setMyCall(const QString &call);
    void setMyGrid(const QString &grid);
    void setNfqso(int freq);

    Q_INVOKABLE void clearDecodes();
    Q_INVOKABLE void decode();
    Q_INVOKABLE double periodForMode(const QString &mode) const;

signals:
    void periodChanged();
    void decodingChanged();
    void nDecodesChanged();
    void deepSearchChanged();
    void currentModeChanged();
    void newDecode(const QString &utc, int snr, double dt, int freq, const QString &message);
    void decodingStarted();
    void decodingFinished();
    void spectrumData(const QList<float> &bins);

public slots:
    void onDecodeResult(const QString &utc, int snr, double dt, int freq, const QString &message);
    void onDecodingComplete();
    void onFramesWritten(qint64 nFrames);

private:
    void updatePeriodForMode();
    void computeSpectrum(qint64 k);
    void runDecoder();
    void parseDecodedResults();

    double m_period = 15.0;
    bool m_decoding = false;
    int m_nDecodes = 0;
    int m_deepSearch = 1;
    QString m_currentMode = QStringLiteral("FT8");

    // Frame tracking for period detection
    qint64 m_lastKin = 0;

    // Spectrum state (persistent across symspec_ calls)
    int m_ihsym = 0;
    float m_px = 0.0f;
    float m_pxmax = 0.0f;
    float m_df3 = 0.0f;
    int m_npts8 = 0;

    // Decoder params
    QString m_myCall;
    QString m_myGrid;
    int m_nfqso = 1500;

    // Background decode thread
    std::atomic<bool> m_decoderRunning{false};
};

#endif // DECODERCONTROLLER_HPP
