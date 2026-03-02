#ifndef WATERFALLCONTROLLER_HPP
#define WATERFALLCONTROLLER_HPP

#include <QObject>
#include <QQmlEngine>

class WaterfallController : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int rxFreq READ rxFreq WRITE setRxFreq NOTIFY rxFreqChanged)
    Q_PROPERTY(int txFreq READ txFreq WRITE setTxFreq NOTIFY txFreqChanged)
    Q_PROPERTY(int startFreq READ startFreq WRITE setStartFreq NOTIFY startFreqChanged)
    Q_PROPERTY(int bandwidth READ bandwidth WRITE setBandwidth NOTIFY bandwidthChanged)
    Q_PROPERTY(int gain READ gain WRITE setGain NOTIFY gainChanged)
    Q_PROPERTY(int zero READ zero WRITE setZero NOTIFY zeroChanged)
    Q_PROPERTY(bool splitEnabled READ splitEnabled WRITE setSplitEnabled NOTIFY splitEnabledChanged)
    Q_PROPERTY(int nBins READ nBins NOTIFY nBinsChanged)

public:
    explicit WaterfallController(QObject *parent = nullptr);
    ~WaterfallController() override = default;

    int rxFreq() const;
    void setRxFreq(int freq);

    int txFreq() const;
    void setTxFreq(int freq);

    int startFreq() const;
    void setStartFreq(int freq);

    int bandwidth() const;
    void setBandwidth(int bw);

    int gain() const;
    void setGain(int g);

    int zero() const;
    void setZero(int z);

    bool splitEnabled() const;
    void setSplitEnabled(bool on);

    int nBins() const;

    Q_INVOKABLE void setFrequenciesLocked(bool locked);
    Q_INVOKABLE void centerOnRxFreq();

signals:
    void rxFreqChanged();
    void txFreqChanged();
    void startFreqChanged();
    void bandwidthChanged();
    void gainChanged();
    void zeroChanged();
    void splitEnabledChanged();
    void nBinsChanged();
    void spectrumDataReady(const QList<float> &data);

public slots:
    void onSpectrumData(const QList<float> &bins);

private:
    int clampFreq(int freq) const;

    int m_rxFreq = 1500;
    int m_txFreq = 1500;
    int m_startFreq = 200;
    int m_bandwidth = 5000;
    int m_gain = 50;
    int m_zero = 50;
    bool m_splitEnabled = false;
    bool m_freqsLocked = true;
    int m_nBins = 0;
};

#endif // WATERFALLCONTROLLER_HPP
