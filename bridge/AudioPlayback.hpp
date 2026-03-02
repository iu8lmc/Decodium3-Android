#ifndef AUDIO_PLAYBACK_HPP
#define AUDIO_PLAYBACK_HPP

#include <QObject>
#include <QAudioSink>
#include <QAudioDevice>
#include <QIODevice>
#include <QBuffer>

// Receives PCM Int16 mono 48kHz from Android client and plays
// through local soundcard (to radio TX input).
class AudioPlayback : public QObject
{
    Q_OBJECT

public:
    explicit AudioPlayback(QObject *parent = nullptr);
    ~AudioPlayback() override;

    bool start(const QAudioDevice &device);
    void stop();
    bool isActive() const;

    void setOutputDevice(const QAudioDevice &device);

public slots:
    void writePcm(const QByteArray &pcm48kHz);

signals:
    void error(const QString &message);
    void playbackStarted();
    void playbackStopped();

private:
    QAudioSink *m_audioSink = nullptr;
    QIODevice *m_ioDevice = nullptr;
    QAudioDevice m_device;

    static constexpr int SAMPLE_RATE = 48000;
};

#endif // AUDIO_PLAYBACK_HPP
