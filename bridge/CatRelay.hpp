#ifndef CAT_RELAY_HPP
#define CAT_RELAY_HPP

#include <QObject>
#include <QTimer>
#include <QString>

#ifdef HAVE_HAMLIB
#include <hamlib/rig.h>
#endif

// Relays CAT commands from Android client to radio via Hamlib.
class CatRelay : public QObject
{
    Q_OBJECT

public:
    explicit CatRelay(QObject *parent = nullptr);
    ~CatRelay() override;

    bool open(int rigModel, const QString &port, int baudRate);
    void close();
    bool isOpen() const;

public slots:
    void setFrequency(quint64 freqHz);
    void setMode(const QString &mode);
    void setPtt(bool on);
    void poll();

signals:
    void statusUpdate(quint64 freq, quint8 mode, bool ptt, qint16 sMeter);
    void error(const QString &message);

private:
#ifdef HAVE_HAMLIB
    RIG *m_rig = nullptr;
#endif
    QTimer m_pollTimer;
    bool m_open = false;
};

#endif // CAT_RELAY_HPP
