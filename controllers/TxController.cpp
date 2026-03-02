#include "TxController.hpp"

TxController::TxController(QObject *parent)
    : QObject(parent)
{
}

bool TxController::transmitting() const
{
    return m_transmitting;
}

void TxController::setTransmitting(bool on)
{
    if (m_transmitting != on) {
        m_transmitting = on;
        emit transmittingChanged();
    }
}

bool TxController::autoCQ() const
{
    return m_autoCQ;
}

void TxController::setAutoCQ(bool on)
{
    if (m_autoCQ != on) {
        m_autoCQ = on;
        emit autoCQChanged();
        if (on) {
            // When enabling Auto CQ, set state and prepare
            setTxState(QStringLiteral("Auto CQ"));
        } else if (!m_transmitting) {
            setTxState(QStringLiteral("Idle"));
        }
    }
}

bool TxController::autoSequence() const
{
    return m_autoSequence;
}

void TxController::setAutoSequence(bool on)
{
    if (m_autoSequence != on) {
        m_autoSequence = on;
        emit autoSequenceChanged();
    }
}

int TxController::activeTxMessage() const
{
    return m_activeTxMessage;
}

void TxController::setActiveTxMessage(int num)
{
    if (num >= 1 && num <= 6 && m_activeTxMessage != num) {
        m_activeTxMessage = num;
        emit activeTxMessageChanged();
    }
}

QString TxController::hisCall() const
{
    return m_hisCall;
}

void TxController::setHisCall(const QString &call)
{
    QString upper = call.toUpper().trimmed();
    if (m_hisCall != upper) {
        m_hisCall = upper;
        emit hisCallChanged();
    }
}

QString TxController::hisGrid() const
{
    return m_hisGrid;
}

void TxController::setHisGrid(const QString &grid)
{
    QString upper = grid.toUpper().trimmed();
    if (m_hisGrid != upper) {
        m_hisGrid = upper;
        emit hisGridChanged();
    }
}

QString TxController::txReport() const
{
    return m_txReport;
}

void TxController::setTxReport(const QString &report)
{
    if (m_txReport != report) {
        m_txReport = report;
        emit txReportChanged();
    }
}

QString TxController::tx1() const { return m_tx1; }
void TxController::setTx1(const QString &msg)
{
    if (m_tx1 != msg) { m_tx1 = msg; emit tx1Changed(); }
}

QString TxController::tx2() const { return m_tx2; }
void TxController::setTx2(const QString &msg)
{
    if (m_tx2 != msg) { m_tx2 = msg; emit tx2Changed(); }
}

QString TxController::tx3() const { return m_tx3; }
void TxController::setTx3(const QString &msg)
{
    if (m_tx3 != msg) { m_tx3 = msg; emit tx3Changed(); }
}

QString TxController::tx4() const { return m_tx4; }
void TxController::setTx4(const QString &msg)
{
    if (m_tx4 != msg) { m_tx4 = msg; emit tx4Changed(); }
}

QString TxController::tx5() const { return m_tx5; }
void TxController::setTx5(const QString &msg)
{
    if (m_tx5 != msg) { m_tx5 = msg; emit tx5Changed(); }
}

QString TxController::tx6() const { return m_tx6; }
void TxController::setTx6(const QString &msg)
{
    if (m_tx6 != msg) { m_tx6 = msg; emit tx6Changed(); }
}

QString TxController::txState() const
{
    return m_txState;
}

void TxController::setTxState(const QString &state)
{
    if (m_txState != state) {
        m_txState = state;
        emit txStateChanged();
    }
}

int TxController::txPeriod() const
{
    return m_txPeriod;
}

void TxController::setTxPeriod(int period)
{
    if (m_txPeriod != period && (period == 0 || period == 1)) {
        m_txPeriod = period;
        emit txPeriodChanged();
    }
}

void TxController::startCQ()
{
    if (m_tx6.isEmpty())
        return;

    setActiveTxMessage(6);
    setTxState(QStringLiteral("Sending CQ"));
    setTransmitting(true);
    emit txRequested(m_tx6);
}

void TxController::halt()
{
    setTransmitting(false);
    m_autoCQ = false;
    emit autoCQChanged();
    setTxState(QStringLiteral("Idle"));
    emit haltRequested();
}

void TxController::enableTx()
{
    if (!m_transmitting) {
        // Prepare for TX on next period
        setTxState(QStringLiteral("Waiting"));
    }
}

void TxController::sendMessage(int num)
{
    if (num < 1 || num > 6)
        return;

    QString msg;
    switch (num) {
    case 1: msg = m_tx1; break;
    case 2: msg = m_tx2; break;
    case 3: msg = m_tx3; break;
    case 4: msg = m_tx4; break;
    case 5: msg = m_tx5; break;
    case 6: msg = m_tx6; break;
    }

    if (msg.isEmpty())
        return;

    setActiveTxMessage(num);
    setTransmitting(true);

    // Update state description
    switch (num) {
    case 1:
        setTxState(QStringLiteral("Sending CQ"));
        break;
    case 2:
        setTxState(QStringLiteral("Sending Grid"));
        break;
    case 3:
        setTxState(QStringLiteral("Sending Report"));
        break;
    case 4:
        setTxState(QStringLiteral("Sending R+Report"));
        break;
    case 5:
        setTxState(QStringLiteral("Sending RR73"));
        break;
    case 6:
        setTxState(QStringLiteral("Sending CQ"));
        break;
    }

    emit txRequested(msg);
}

void TxController::genStdMsgs(const QString &myCall, const QString &myGrid,
                               const QString &hisCall, const QString &hisGrid,
                               const QString &rptSent, const QString &rptRcvd)
{
    Q_UNUSED(rptRcvd)

    if (myCall.isEmpty())
        return;

    // Store the DX station info
    setHisCall(hisCall);
    setHisGrid(hisGrid);
    setTxReport(rptSent);

    // Generate standard FT8/FT4/FT2 messages
    // TX1: CQ myCall myGrid
    QString gridPart = myGrid.left(4);

    // TX6: CQ myCall myGrid  (same as TX1 - the CQ message)
    setTx6(QStringLiteral("CQ %1 %2").arg(myCall, gridPart));

    if (hisCall.isEmpty()) {
        // No DX station selected - clear sequence messages
        setTx1(QString());
        setTx2(QString());
        setTx3(QString());
        setTx4(QString());
        setTx5(QString());
        return;
    }

    // TX1: hisCall myCall myGrid (reply to CQ)
    setTx1(QStringLiteral("%1 %2 %3").arg(hisCall, myCall, gridPart));

    // TX2: hisCall myCall rptSent (send report)
    QString report = rptSent;
    if (report.isEmpty())
        report = QStringLiteral("-10");
    setTx2(QStringLiteral("%1 %2 %3").arg(hisCall, myCall, report));

    // TX3: hisCall myCall R+rptSent (send R+report)
    setTx3(QStringLiteral("%1 %2 R%3").arg(hisCall, myCall, report));

    // TX4: hisCall myCall RR73 (final acknowledgment)
    setTx4(QStringLiteral("%1 %2 RR73").arg(hisCall, myCall));

    // TX5: hisCall myCall 73 (alternate final)
    setTx5(QStringLiteral("%1 %2 73").arg(hisCall, myCall));
}
