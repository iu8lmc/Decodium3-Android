#ifndef WATERFALLITEM_HPP
#define WATERFALLITEM_HPP

#include <QQuickPaintedItem>
#include <QImage>
#include <QColor>
#include <QVector>
#include <QMutex>

class WaterfallItem : public QQuickPaintedItem
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(int rxFreq READ rxFreq WRITE setRxFreq NOTIFY rxFreqChanged)
    Q_PROPERTY(int txFreq READ txFreq WRITE setTxFreq NOTIFY txFreqChanged)
    Q_PROPERTY(int startFreq READ startFreq WRITE setStartFreq NOTIFY startFreqChanged)
    Q_PROPERTY(int bandwidth READ bandwidth WRITE setBandwidth NOTIFY bandwidthChanged)
    Q_PROPERTY(int gain READ gain WRITE setGain NOTIFY gainChanged)
    Q_PROPERTY(int zero READ zero WRITE setZero NOTIFY zeroChanged)
    Q_PROPERTY(bool running READ running WRITE setRunning NOTIFY runningChanged)

public:
    explicit WaterfallItem(QQuickItem *parent = nullptr);

    void paint(QPainter *painter) override;

    int rxFreq() const { return m_rxFreq; }
    void setRxFreq(int f);
    int txFreq() const { return m_txFreq; }
    void setTxFreq(int f);
    int startFreq() const { return m_startFreq; }
    void setStartFreq(int f);
    int bandwidth() const { return m_bandwidth; }
    void setBandwidth(int bw);
    int gain() const { return m_gain; }
    void setGain(int g);
    int zero() const { return m_zero; }
    void setZero(int z);
    bool running() const { return m_running; }
    void setRunning(bool r);

    Q_INVOKABLE void addSpectrumData(const QVector<float> &data);

signals:
    void rxFreqChanged();
    void txFreqChanged();
    void startFreqChanged();
    void bandwidthChanged();
    void gainChanged();
    void zeroChanged();
    void runningChanged();
    void frequencySelected(int freq);

protected:
    void mousePressEvent(QMouseEvent *event) override;
    void mouseMoveEvent(QMouseEvent *event) override;

private:
    void drawSpectrum(QPainter *painter, int y, int h);
    void drawWaterfall(QPainter *painter, int y, int h);
    void drawMarkers(QPainter *painter, int y, int h);
    void scrollWaterfall();
    QColor spectrumColor(float value) const;
    int freqToX(int freq) const;
    int xToFreq(int x) const;

    int m_rxFreq = 1500;
    int m_txFreq = 1500;
    int m_startFreq = 200;
    int m_bandwidth = 4000;
    int m_gain = 50;
    int m_zero = 50;
    bool m_running = false;

    QImage m_waterfallImage;
    QVector<float> m_currentSpectrum;
    QMutex m_mutex;
    int m_spectrumHeight = 80;

    // Color palette
    QVector<QColor> m_palette;
    void initPalette();
};

#endif // WATERFALLITEM_HPP
