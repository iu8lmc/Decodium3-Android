#include "LogController.hpp"
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QTextStream>

LogController::LogController(QObject *parent)
    : QObject(parent)
{
}

int LogController::qsoCount() const
{
    return m_qsoCount;
}

QString LogController::lastLoggedCall() const
{
    return m_lastLoggedCall;
}

QString LogController::lastLoggedGrid() const
{
    return m_lastLoggedGrid;
}

QString LogController::lastLoggedTime() const
{
    return m_lastLoggedTime;
}

void LogController::logQSO(const QString &call, const QString &grid,
                            const QString &mode, const QString &rstSent,
                            const QString &rstRcvd, double freq)
{
    logQSOFull(call, grid, mode, rstSent, rstRcvd, freq, QString(), QString());
}

void LogController::logQSOFull(const QString &call, const QString &grid,
                                const QString &mode, const QString &rstSent,
                                const QString &rstRcvd, double freq,
                                const QString &comment, const QString &name)
{
    if (call.isEmpty())
        return;

    QSORecord qso;
    qso.dateTimeOn = QDateTime::currentDateTimeUtc();
    qso.dateTimeOff = qso.dateTimeOn;
    qso.call = call.toUpper().trimmed();
    qso.grid = grid.toUpper().trimmed();
    qso.mode = mode.toUpper().trimmed();
    qso.rstSent = rstSent;
    qso.rstRcvd = rstRcvd;
    qso.frequency = freq;
    qso.comment = comment;
    qso.name = name;

    // Write to ADIF file
    writeAdifRecord(qso);

    // Update in-memory tracking
    QString band = bandFromFrequency(freq);
    m_workedCallsByBand.insert(band, qso.call);
    if (!qso.grid.isEmpty()) {
        m_workedGridsByBand.insert(band, qso.grid);
    }

    // Update properties
    m_qsoCount++;
    emit qsoCountChanged();

    m_lastLoggedCall = qso.call;
    emit lastLoggedCallChanged();

    m_lastLoggedGrid = qso.grid;
    emit lastLoggedGridChanged();

    m_lastLoggedTime = qso.dateTimeOn.toString(QStringLiteral("yyyy-MM-dd hh:mm:ss"));
    emit lastLoggedTimeChanged();

    emit qsoLogged(qso.call, qso.grid, qso.mode, freq);
}

bool LogController::isCallWorked(const QString &call, const QString &band) const
{
    return m_workedCallsByBand.contains(band, call.toUpper().trimmed());
}

bool LogController::isGridWorked(const QString &grid, const QString &band) const
{
    return m_workedGridsByBand.contains(band, grid.toUpper().trimmed());
}

void LogController::writeAdifRecord(const QSORecord &qso)
{
    // Ensure log directory exists
    QString logDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir dir(logDir);
    if (!dir.exists()) {
        dir.mkpath(logDir);
    }

    QString logPath = logDir + QStringLiteral("/decodium3_log.adi");
    QFile file(logPath);

    bool isNewFile = !file.exists();

    if (!file.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
        return;
    }

    QTextStream out(&file);

    // Write ADIF header if new file
    if (isNewFile) {
        out << QStringLiteral("ADIF Export from Decodium3\n");
        out << QStringLiteral("<adif_ver:5>3.1.4\n");
        out << QStringLiteral("<programid:9>Decodium3\n");
        out << QStringLiteral("<programversion:5>3.0.0\n");
        out << QStringLiteral("<eoh>\n\n");
    }

    // Helper lambda to write an ADIF field
    auto writeField = [&out](const QString &fieldName, const QString &value) {
        if (!value.isEmpty()) {
            out << QStringLiteral("<%1:%2>%3 ")
                       .arg(fieldName)
                       .arg(value.length())
                       .arg(value);
        }
    };

    // Write QSO record
    writeField(QStringLiteral("call"), qso.call);
    writeField(QStringLiteral("gridsquare"), qso.grid);
    writeField(QStringLiteral("mode"), qso.mode);
    writeField(QStringLiteral("rst_sent"), qso.rstSent);
    writeField(QStringLiteral("rst_rcvd"), qso.rstRcvd);

    // Frequency in MHz for ADIF
    double freqMHz = qso.frequency / 1000000.0;
    writeField(QStringLiteral("freq"), QString::number(freqMHz, 'f', 6));

    // Band
    QString band = bandFromFrequency(qso.frequency);
    writeField(QStringLiteral("band"), band);

    // Date/time
    writeField(QStringLiteral("qso_date"),
               qso.dateTimeOn.toString(QStringLiteral("yyyyMMdd")));
    writeField(QStringLiteral("time_on"),
               qso.dateTimeOn.toString(QStringLiteral("hhmmss")));
    writeField(QStringLiteral("qso_date_off"),
               qso.dateTimeOff.toString(QStringLiteral("yyyyMMdd")));
    writeField(QStringLiteral("time_off"),
               qso.dateTimeOff.toString(QStringLiteral("hhmmss")));

    // Optional fields
    writeField(QStringLiteral("comment"), qso.comment);
    writeField(QStringLiteral("name"), qso.name);

    out << QStringLiteral("<eor>\n");

    file.close();
}

QString LogController::bandFromFrequency(double freqHz) const
{
    if (freqHz >= 1800000 && freqHz <= 2000000)
        return QStringLiteral("160m");
    if (freqHz >= 3500000 && freqHz <= 4000000)
        return QStringLiteral("80m");
    if (freqHz >= 5330500 && freqHz <= 5406400)
        return QStringLiteral("60m");
    if (freqHz >= 7000000 && freqHz <= 7300000)
        return QStringLiteral("40m");
    if (freqHz >= 10100000 && freqHz <= 10150000)
        return QStringLiteral("30m");
    if (freqHz >= 14000000 && freqHz <= 14350000)
        return QStringLiteral("20m");
    if (freqHz >= 18068000 && freqHz <= 18168000)
        return QStringLiteral("17m");
    if (freqHz >= 21000000 && freqHz <= 21450000)
        return QStringLiteral("15m");
    if (freqHz >= 24890000 && freqHz <= 24990000)
        return QStringLiteral("12m");
    if (freqHz >= 28000000 && freqHz <= 29700000)
        return QStringLiteral("10m");
    if (freqHz >= 50000000 && freqHz <= 54000000)
        return QStringLiteral("6m");
    if (freqHz >= 144000000 && freqHz <= 148000000)
        return QStringLiteral("2m");
    if (freqHz >= 420000000 && freqHz <= 450000000)
        return QStringLiteral("70cm");

    return QStringLiteral("OOB");
}
