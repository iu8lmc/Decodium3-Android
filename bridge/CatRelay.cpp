#include "CatRelay.hpp"
#include <QDebug>

CatRelay::CatRelay(QObject *parent)
    : QObject(parent)
{
    m_pollTimer.setInterval(500); // poll every 500ms
    connect(&m_pollTimer, &QTimer::timeout, this, &CatRelay::poll);
}

CatRelay::~CatRelay()
{
    close();
}

bool CatRelay::open(int rigModel, const QString &port, int baudRate)
{
#ifdef HAVE_HAMLIB
    close();

    m_rig = rig_init(rigModel);
    if (!m_rig) {
        emit error(tr("Failed to init Hamlib rig model %1").arg(rigModel));
        return false;
    }

    strncpy(m_rig->state.rigport.pathname, port.toLatin1().constData(),
            HAMLIB_FILPATHLEN - 1);
    m_rig->state.rigport.parm.serial.rate = baudRate;

    int ret = rig_open(m_rig);
    if (ret != RIG_OK) {
        emit error(tr("Failed to open rig: %1").arg(rigerror(ret)));
        rig_cleanup(m_rig);
        m_rig = nullptr;
        return false;
    }

    m_open = true;
    m_pollTimer.start();
    qDebug() << "CatRelay: opened rig model" << rigModel << "on" << port;
    return true;
#else
    Q_UNUSED(rigModel);
    Q_UNUSED(port);
    Q_UNUSED(baudRate);
    emit error(tr("Hamlib support not compiled in"));
    return false;
#endif
}

void CatRelay::close()
{
#ifdef HAVE_HAMLIB
    m_pollTimer.stop();
    if (m_rig) {
        rig_close(m_rig);
        rig_cleanup(m_rig);
        m_rig = nullptr;
    }
    m_open = false;
#endif
}

bool CatRelay::isOpen() const
{
    return m_open;
}

void CatRelay::setFrequency(quint64 freqHz)
{
#ifdef HAVE_HAMLIB
    if (!m_rig) return;
    int ret = rig_set_freq(m_rig, RIG_VFO_CURR, static_cast<freq_t>(freqHz));
    if (ret != RIG_OK) {
        qWarning() << "CatRelay: set freq failed:" << rigerror(ret);
    }
#else
    Q_UNUSED(freqHz);
#endif
}

void CatRelay::setMode(const QString &mode)
{
#ifdef HAVE_HAMLIB
    if (!m_rig) return;
    rmode_t rmode = rig_parse_mode(mode.toLatin1().constData());
    pbwidth_t width = rig_passband_normal(m_rig, rmode);
    int ret = rig_set_mode(m_rig, RIG_VFO_CURR, rmode, width);
    if (ret != RIG_OK) {
        qWarning() << "CatRelay: set mode failed:" << rigerror(ret);
    }
#else
    Q_UNUSED(mode);
#endif
}

void CatRelay::setPtt(bool on)
{
#ifdef HAVE_HAMLIB
    if (!m_rig) return;
    int ret = rig_set_ptt(m_rig, RIG_VFO_CURR,
                          on ? RIG_PTT_ON : RIG_PTT_OFF);
    if (ret != RIG_OK) {
        qWarning() << "CatRelay: set PTT failed:" << rigerror(ret);
    }
#else
    Q_UNUSED(on);
#endif
}

void CatRelay::poll()
{
#ifdef HAVE_HAMLIB
    if (!m_rig) return;

    freq_t freq = 0;
    rig_get_freq(m_rig, RIG_VFO_CURR, &freq);

    rmode_t mode = RIG_MODE_NONE;
    pbwidth_t width = 0;
    rig_get_mode(m_rig, RIG_VFO_CURR, &mode, &width);

    ptt_t ptt = RIG_PTT_OFF;
    rig_get_ptt(m_rig, RIG_VFO_CURR, &ptt);

    value_t sMeter;
    sMeter.i = 0;
    rig_get_level(m_rig, RIG_VFO_CURR, RIG_LEVEL_STRENGTH, &sMeter);

    emit statusUpdate(static_cast<quint64>(freq),
                      static_cast<quint8>(mode),
                      ptt != RIG_PTT_OFF,
                      static_cast<qint16>(sMeter.i));
#endif
}
