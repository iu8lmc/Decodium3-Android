#include "AudioCapture.hpp"
#include <QAudioFormat>
#include <QMediaDevices>
#include <QDebug>
#include <cmath>

AudioCapture::AudioCapture(QObject *parent)
    : QObject(parent)
{
}

AudioCapture::~AudioCapture()
{
    stop();
}

bool AudioCapture::start(const QAudioDevice &device)
{
    stop();

    m_device = device;
    if (m_device.isNull()) {
        m_device = QMediaDevices::defaultAudioInput();
    }

    QAudioFormat fmt;
    fmt.setSampleRate(INPUT_RATE);
    fmt.setChannelCount(1);
    fmt.setSampleFormat(QAudioFormat::Int16);

    if (!m_device.isFormatSupported(fmt)) {
        emit error(tr("Audio format not supported by device: %1")
                   .arg(m_device.description()));
        return false;
    }

    m_audioSource = new QAudioSource(m_device, fmt, this);
    m_audioSource->setBufferSize(CHUNK_SAMPLES_IN * sizeof(qint16) * 4);

    m_ioDevice = m_audioSource->start();
    if (!m_ioDevice) {
        emit error(tr("Failed to start audio capture on: %1")
                   .arg(m_device.description()));
        delete m_audioSource;
        m_audioSource = nullptr;
        return false;
    }

    connect(m_ioDevice, &QIODevice::readyRead,
            this, &AudioCapture::onReadyRead);

    m_accumulator.clear();
    qDebug() << "AudioCapture: started on" << m_device.description();
    return true;
}

void AudioCapture::stop()
{
    if (m_audioSource) {
        m_audioSource->stop();
        delete m_audioSource;
        m_audioSource = nullptr;
        m_ioDevice = nullptr;
    }
    m_accumulator.clear();
}

bool AudioCapture::isActive() const
{
    return m_audioSource &&
           m_audioSource->state() == QAudio::ActiveState;
}

void AudioCapture::setInputDevice(const QAudioDevice &device)
{
    bool wasActive = isActive();
    if (wasActive) stop();
    m_device = device;
    if (wasActive) start(m_device);
}

void AudioCapture::onReadyRead()
{
    if (!m_ioDevice) return;

    QByteArray raw = m_ioDevice->readAll();
    m_accumulator.append(raw);

    const int bytesPerChunk48 = CHUNK_SAMPLES_IN * sizeof(qint16);

    while (m_accumulator.size() >= bytesPerChunk48) {
        const qint16 *samples48 = reinterpret_cast<const qint16*>(
            m_accumulator.constData());

        // Compute peak level
        float peak = 0.0f;
        for (int i = 0; i < CHUNK_SAMPLES_IN; ++i) {
            float v = std::abs(samples48[i]) / 32768.0f;
            if (v > peak) peak = v;
        }
        emit levelChanged(peak);

        // Downsample 48kHz → 12kHz
        QVector<qint16> out12;
        downsample48to12(samples48, CHUNK_SAMPLES_IN, out12);

        QByteArray pcm(reinterpret_cast<const char*>(out12.constData()),
                       out12.size() * sizeof(qint16));
        emit pcmChunkReady(pcm);

        m_accumulator.remove(0, bytesPerChunk48);
    }
}

void AudioCapture::downsample48to12(const qint16 *in, int inCount,
                                    QVector<qint16> &out)
{
    // Simple averaging decimation by factor 4
    int outCount = inCount / DS_FACTOR;
    out.resize(outCount);
    for (int i = 0; i < outCount; ++i) {
        int32_t sum = 0;
        for (int j = 0; j < DS_FACTOR; ++j) {
            sum += in[i * DS_FACTOR + j];
        }
        out[i] = static_cast<qint16>(sum / DS_FACTOR);
    }
}
