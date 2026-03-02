#ifndef APPCONTROLLER_HPP
#define APPCONTROLLER_HPP

#include <QObject>
#include <QQmlEngine>
#include <QString>

class AppController : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString version READ version CONSTANT)
    Q_PROPERTY(QString callsign READ callsign WRITE setCallsign NOTIFY callsignChanged)
    Q_PROPERTY(QString grid READ grid WRITE setGrid NOTIFY gridChanged)
    Q_PROPERTY(bool darkMode READ darkMode WRITE setDarkMode NOTIFY darkModeChanged)

public:
    explicit AppController(QObject *parent = nullptr);
    ~AppController() override = default;

    QString version() const { return QStringLiteral("3.0.0"); }

    QString callsign() const;
    void setCallsign(const QString &call);

    QString grid() const;
    void setGrid(const QString &grid);

    bool darkMode() const;
    void setDarkMode(bool dark);

    Q_INVOKABLE void saveSettings();
    Q_INVOKABLE void loadSettings();

signals:
    void callsignChanged();
    void gridChanged();
    void darkModeChanged();

private:
    QString m_callsign;
    QString m_grid;
    bool m_darkMode = false;
};

#endif // APPCONTROLLER_HPP
