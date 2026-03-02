#ifndef TXCONTROLLER_HPP
#define TXCONTROLLER_HPP

#include <QObject>
#include <QQmlEngine>
#include <QString>

class TxController : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool transmitting READ transmitting NOTIFY transmittingChanged)
    Q_PROPERTY(bool autoCQ READ autoCQ WRITE setAutoCQ NOTIFY autoCQChanged)
    Q_PROPERTY(bool autoSequence READ autoSequence WRITE setAutoSequence NOTIFY autoSequenceChanged)
    Q_PROPERTY(int activeTxMessage READ activeTxMessage WRITE setActiveTxMessage NOTIFY activeTxMessageChanged)
    Q_PROPERTY(QString hisCall READ hisCall WRITE setHisCall NOTIFY hisCallChanged)
    Q_PROPERTY(QString hisGrid READ hisGrid WRITE setHisGrid NOTIFY hisGridChanged)
    Q_PROPERTY(QString txReport READ txReport WRITE setTxReport NOTIFY txReportChanged)
    Q_PROPERTY(QString tx1 READ tx1 WRITE setTx1 NOTIFY tx1Changed)
    Q_PROPERTY(QString tx2 READ tx2 WRITE setTx2 NOTIFY tx2Changed)
    Q_PROPERTY(QString tx3 READ tx3 WRITE setTx3 NOTIFY tx3Changed)
    Q_PROPERTY(QString tx4 READ tx4 WRITE setTx4 NOTIFY tx4Changed)
    Q_PROPERTY(QString tx5 READ tx5 WRITE setTx5 NOTIFY tx5Changed)
    Q_PROPERTY(QString tx6 READ tx6 WRITE setTx6 NOTIFY tx6Changed)
    Q_PROPERTY(QString txState READ txState NOTIFY txStateChanged)
    Q_PROPERTY(int txPeriod READ txPeriod WRITE setTxPeriod NOTIFY txPeriodChanged)

public:
    explicit TxController(QObject *parent = nullptr);
    ~TxController() override = default;

    bool transmitting() const;

    bool autoCQ() const;
    void setAutoCQ(bool on);

    bool autoSequence() const;
    void setAutoSequence(bool on);

    int activeTxMessage() const;
    void setActiveTxMessage(int num);

    QString hisCall() const;
    void setHisCall(const QString &call);

    QString hisGrid() const;
    void setHisGrid(const QString &grid);

    QString txReport() const;
    void setTxReport(const QString &report);

    QString tx1() const;
    void setTx1(const QString &msg);
    QString tx2() const;
    void setTx2(const QString &msg);
    QString tx3() const;
    void setTx3(const QString &msg);
    QString tx4() const;
    void setTx4(const QString &msg);
    QString tx5() const;
    void setTx5(const QString &msg);
    QString tx6() const;
    void setTx6(const QString &msg);

    QString txState() const;

    int txPeriod() const;
    void setTxPeriod(int period);

    Q_INVOKABLE void startCQ();
    Q_INVOKABLE void halt();
    Q_INVOKABLE void enableTx();
    Q_INVOKABLE void sendMessage(int num);
    Q_INVOKABLE void genStdMsgs(const QString &myCall, const QString &myGrid,
                                 const QString &hisCall, const QString &hisGrid,
                                 const QString &rptSent, const QString &rptRcvd);

signals:
    void transmittingChanged();
    void autoCQChanged();
    void autoSequenceChanged();
    void activeTxMessageChanged();
    void hisCallChanged();
    void hisGridChanged();
    void txReportChanged();
    void tx1Changed();
    void tx2Changed();
    void tx3Changed();
    void tx4Changed();
    void tx5Changed();
    void tx6Changed();
    void txStateChanged();
    void txPeriodChanged();
    void txRequested(const QString &message);
    void haltRequested();

private:
    void setTransmitting(bool on);
    void setTxState(const QString &state);

    bool m_transmitting = false;
    bool m_autoCQ = false;
    bool m_autoSequence = false;
    int m_activeTxMessage = 1;
    QString m_hisCall;
    QString m_hisGrid;
    QString m_txReport;
    QString m_tx1;
    QString m_tx2;
    QString m_tx3;
    QString m_tx4;
    QString m_tx5;
    QString m_tx6;
    QString m_txState = QStringLiteral("Idle");
    int m_txPeriod = 1;  // 0 = even, 1 = odd (first period)
};

#endif // TXCONTROLLER_HPP
