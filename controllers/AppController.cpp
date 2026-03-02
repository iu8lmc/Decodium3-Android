#include "AppController.hpp"
#include <QSettings>

AppController::AppController(QObject *parent)
    : QObject(parent)
{
    loadSettings();
}

QString AppController::callsign() const
{
    return m_callsign;
}

void AppController::setCallsign(const QString &call)
{
    QString upper = call.toUpper().trimmed();
    if (m_callsign != upper) {
        m_callsign = upper;
        emit callsignChanged();
        saveSettings();
    }
}

QString AppController::grid() const
{
    return m_grid;
}

void AppController::setGrid(const QString &grid)
{
    QString formatted = grid.toUpper().trimmed();
    if (m_grid != formatted) {
        m_grid = formatted;
        emit gridChanged();
        saveSettings();
    }
}

bool AppController::darkMode() const
{
    return m_darkMode;
}

void AppController::setDarkMode(bool dark)
{
    if (m_darkMode != dark) {
        m_darkMode = dark;
        emit darkModeChanged();
        saveSettings();
    }
}

void AppController::saveSettings()
{
    QSettings settings(QStringLiteral("Decodium3"), QStringLiteral("Decodium3"));
    settings.beginGroup(QStringLiteral("Station"));
    settings.setValue(QStringLiteral("Callsign"), m_callsign);
    settings.setValue(QStringLiteral("Grid"), m_grid);
    settings.endGroup();

    settings.beginGroup(QStringLiteral("Appearance"));
    settings.setValue(QStringLiteral("DarkMode"), m_darkMode);
    settings.endGroup();

    settings.sync();
}

void AppController::loadSettings()
{
    QSettings settings(QStringLiteral("Decodium3"), QStringLiteral("Decodium3"));
    settings.beginGroup(QStringLiteral("Station"));
    m_callsign = settings.value(QStringLiteral("Callsign"), QString()).toString();
    m_grid = settings.value(QStringLiteral("Grid"), QString()).toString();
    settings.endGroup();

    settings.beginGroup(QStringLiteral("Appearance"));
    m_darkMode = settings.value(QStringLiteral("DarkMode"), false).toBool();
    settings.endGroup();
}
