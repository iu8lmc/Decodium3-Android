#include "soundin.h"

#include <cstdlib>
#include <cmath>
#include <iomanip>
#include <QAudioDevice>
#include <QAudioFormat>
#include <QAudioSource>
#include <QSysInfo>
#include <QDebug>

#include "Logger.hpp"

#include "moc_soundin.cpp"

bool SoundInput::checkStream ()
{
  bool result (false);
  if (m_stream)
    {
      switch (m_stream->error ())
        {
        case QAudio::OpenError:
          Q_EMIT error (tr ("An error opening the audio input device has occurred."));
          break;

        case QAudio::IOError:
          Q_EMIT error (tr ("An error occurred during read from the audio input device."));
          break;

        case QAudio::FatalError:
          Q_EMIT error (tr ("Non-recoverable error, audio input device not usable at this time."));
          break;

        case QAudio::UnderrunError:
        case QAudio::NoError:
          result = true;
          break;
        }
    }
  return result;
}

void SoundInput::start(QAudioDevice const& device, int framesPerBuffer, AudioDevice * sink
                       , unsigned downSampleFactor, AudioDevice::Channel channel)
{
  Q_ASSERT (sink);

  stop ();

  m_sink = sink;

  QAudioFormat format;
  format.setChannelCount (AudioDevice::Mono == channel ? 1 : 2);
  format.setSampleRate (12000 * downSampleFactor);
  format.setSampleFormat (QAudioFormat::Int16);

  if (!device.isFormatSupported (format))
    {
      Q_EMIT error (tr ("Requested input audio format is not supported on device."));
      return;
    }

  m_stream.reset (new QAudioSource {device, format});
  if (!checkStream ())
    {
      return;
    }

  connect (m_stream.data(), &QAudioSource::stateChanged, this, &SoundInput::handleStateChanged);

  if (framesPerBuffer > 0)
    {
      m_stream->setBufferSize (framesPerBuffer * format.bytesPerFrame ());
    }
  if (m_sink->initialize (QIODevice::WriteOnly, channel))
    {
      m_stream->start (sink);
      checkStream ();
      cummulative_lost_usec_ = -1;
    }
  else
    {
      Q_EMIT error (tr ("Failed to initialize audio sink device"));
    }
}

void SoundInput::suspend ()
{
  if (m_stream)
    {
      m_stream->stop();
      checkStream ();
    }
}

void SoundInput::resume ()
{
  if (m_sink)
    {
      m_sink->reset ();
    }

  if (m_stream)
    {
      m_stream->start (m_sink);
      checkStream ();
    }
}

void SoundInput::handleStateChanged (QAudio::State newState)
{
  switch (newState)
    {
    case QAudio::IdleState:
      Q_EMIT status (tr ("Idle"));
      break;

    case QAudio::ActiveState:
      reset (false);
      Q_EMIT status (tr ("Receiving"));
      break;

    case QAudio::SuspendedState:
      Q_EMIT status (tr ("Suspended"));
      break;

    case QAudio::StoppedState:
      if (!checkStream ())
        {
          Q_EMIT status (tr ("Error"));
        }
      else
        {
          Q_EMIT status (tr ("Stopped"));
        }
      break;
    }
}

void SoundInput::reset (bool report_dropped_frames)
{
  if (m_stream)
    {
      auto elapsed_usecs = m_stream->elapsedUSecs ();
      while (std::abs (elapsed_usecs - m_stream->processedUSecs ())
             > 24 * 60 * 60 * 500000ll)
        {
          elapsed_usecs += 24 * 60 * 60 * 1000000ll;
        }
      if (cummulative_lost_usec_ != std::numeric_limits<qint64>::min () && report_dropped_frames)
        {
          auto lost_usec = elapsed_usecs - m_stream->processedUSecs () - cummulative_lost_usec_;
          if (std::abs (lost_usec) > 5 * 48000)
            {
              LOG_ERROR ("Detected excessive dropped audio source samples: "
                        << m_stream->format ().framesForDuration (lost_usec)
                         << " (" << std::setprecision (4) << lost_usec / 1.e6 << " S)");
            }
        }
      cummulative_lost_usec_ = elapsed_usecs - m_stream->processedUSecs ();
    }
}

void SoundInput::stop()
{
  if (m_stream)
    {
      m_stream->stop ();
    }
  m_stream.reset ();
}

SoundInput::~SoundInput ()
{
  stop ();
}
