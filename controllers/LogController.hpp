#ifndef LOGCONTROLLER_HPP
#define LOGCONTROLLER_HPP

#include <QObject>
#include <QQmlEngine>
#include <QString>
#include <QDateTime>

class LogController : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int qsoCount READ qsoCount NOTIFY qsoCountChanged)
    Q_PROPERTY(QString lastLoggedCall READ lastLoggedCall NOTIFY lastLoggedCallChanged)
    Q_PROPERTY(QString lastLoggedGrid READ lastLoggedGrid NOTIFY lastLoggedGridChanged)
    Q_PROPERTY(QString lastLoggedTime READ lastLoggedTime NOTIFY lastLoggedTimeChanged)

public:
    explicit LogController(QObject *parent = nullptr);
    ~LogController() override = default;

    int qsoCount() const;
    QString lastLoggedCall() const;
    QString lastLoggedGrid() const;
    QString lastLoggedTime() const;

    Q_INVOKABLE void logQSO(const QString &call, const QString &grid,
                             const QString &mode, const QString &rstSent,
                             const QString &rstRcvd, double freq);

    Q_INVOKABLE void logQSOFull(const QString &call, const QString &grid,
                                const QString &mode, const QString &rstSent,
                                const QString &rstRcvd, double freq,
                                const QString &comment, const QString &name);

    Q_INVOKABLE bool isCallWorked(const QString &call, const QString &band) const;
    Q_INVOKABLE bool isGridWorked(const QString &grid, const QString &band) const;

signals:
    void qsoCountChanged();
    void lastLoggedCallChanged();
    void lastLoggedGridChanged();
    void lastLoggedTimeChanged();
    void qsoLogged(const QString &call, const QString &grid, const QString &mode, double freq);

private:
    struct QSORecord {
        QDateTime dateTimeOn;
        QDateTime dateTimeOff;
        QString call;
        QString grid;
        QString mode;
        QString rstSent;
        QString rstRcvd;
        double frequency = 0.0;
        QString comment;
        QString name;
    };

    void writeAdifRecord(const QSORecord &qso);
    QString bandFromFrequency(double freqHz) const;

    int m_qsoCount = 0;
    QString m_lastLoggedCall;
    QString m_lastLoggedGrid;
    QString m_lastLoggedTime;

    // In-memory log of worked calls/grids per band for quick lookups
    QMultiHash<QString, QString> m_workedCallsByBand;  // band -> call
    QMultiHash<QString, QString> m_workedGridsByBand;  // band -> grid
};

#endif // LOGCONTROLLER_HPP
