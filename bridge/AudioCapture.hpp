#ifndef AUDIO_CAPTURE_HPP
#define AUDIO_CAPTURE_HPP

#include <QObject>
#include <QAudioSource>
#include <QAudioDevice>
#include <QIODevice>
#include <QByteArray>
#include <QBuffer>
#include <QVector>

// Captures audio from local soundcard at 48kHz, downsamples to 12kHz,
// and emits PCM Int16 chunks for transmission to Android client.
class AudioCapture : public QObject
{
    Q_OBJECT

public:
    explicit AudioCapture(QObject *parent = nullptr);
    ~AudioCapture() override;

    bool start(const QAudioDevice &device);
    void stop();
    bool isActive() const;

    void setInputDevice(const QAudioDevice &device);

signals:
    void pcmChunkReady(const QByteArray &pcm12kHz);
    void error(const QString &message);
    void levelChanged(float peak);

private slots:
    void onReadyRead();

private:
    void downsample48to12(const qint16 *in, int inCount,
                          QVector<qint16> &out);

    QAudioSource *m_audioSource = nullptr;
    QIODevice *m_ioDevice = nullptr;
    QAudioDevice m_device;

    // Downsample state
    QByteArray m_accumulator;

    static constexpr int INPUT_RATE  = 48000;
    static constexpr int OUTPUT_RATE = 12000;
    static constexpr int DS_FACTOR   = INPUT_RATE / OUTPUT_RATE; // 4
    static constexpr int CHUNK_SAMPLES_OUT = 480; // 40ms at 12kHz
    static constexpr int CHUNK_SAMPLES_IN  = CHUNK_SAMPLES_OUT * DS_FACTOR; // 1920
};

#endif // AUDIO_CAPTURE_HPP
