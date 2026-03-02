#include "AudioPlayback.hpp"
#include <QAudioFormat>
#include <QMediaDevices>
#include <QDebug>

AudioPlayback::AudioPlayback(QObject *parent)
    : QObject(parent)
{
}

AudioPlayback::~AudioPlayback()
{
    stop();
}

bool AudioPlayback::start(const QAudioDevice &device)
{
    stop();

    m_device = device;
    if (m_device.isNull()) {
        m_device = QMediaDevices::defaultAudioOutput();
    }

    QAudioFormat fmt;
    fmt.setSampleRate(SAMPLE_RATE);
    fmt.setChannelCount(1);
    fmt.setSampleFormat(QAudioFormat::Int16);

    if (!m_device.isFormatSupported(fmt)) {
        emit error(tr("Audio format not supported by output device: %1")
                   .arg(m_device.description()));
        return false;
    }

    m_audioSink = new QAudioSink(m_device, fmt, this);
    m_audioSink->setBufferSize(SAMPLE_RATE * sizeof(qint16)); // 1s buffer

    m_ioDevice = m_audioSink->start();
    if (!m_ioDevice) {
        emit error(tr("Failed to start audio playback on: %1")
                   .arg(m_device.description()));
        delete m_audioSink;
        m_audioSink = nullptr;
        return false;
    }

    qDebug() << "AudioPlayback: started on" << m_device.description();
    emit playbackStarted();
    return true;
}

void AudioPlayback::stop()
{
    if (m_audioSink) {
        m_audioSink->stop();
        delete m_audioSink;
        m_audioSink = nullptr;
        m_ioDevice = nullptr;
        emit playbackStopped();
    }
}

bool AudioPlayback::isActive() const
{
    return m_audioSink &&
           m_audioSink->state() == QAudio::ActiveState;
}

void AudioPlayback::setOutputDevice(const QAudioDevice &device)
{
    bool wasActive = isActive();
    if (wasActive) stop();
    m_device = device;
    if (wasActive) start(m_device);
}

void AudioPlayback::writePcm(const QByteArray &pcm48kHz)
{
    if (m_ioDevice) {
        m_ioDevice->write(pcm48kHz);
    }
}
