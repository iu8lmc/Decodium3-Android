#include "Radio.hpp"

#include <QMetaType>
#include <QDebug>
#include <QDataStream>

namespace Radio
{
  void register_types ()
  {
    qRegisterMetaType<Radio::Frequency> ("Frequency");
    qRegisterMetaType<Radio::FrequencyDelta> ("FrequencyDelta");
    qRegisterMetaType<Radio::Frequencies> ("Frequencies");

    // Qt6: qRegisterMetaTypeStreamOperators removed, types auto-registered
  }
}
