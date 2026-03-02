#include "MetaDataRegistry.hpp"

#include <QMetaType>
#include <QItemEditorFactory>
#include <QStandardItemEditorCreator>

#include "Radio.hpp"
#include "models/FrequencyList.hpp"
#include "Audio/AudioDevice.hpp"
#include "Configuration.hpp"
#include "models/StationList.hpp"
#include "Transceiver/Transceiver.hpp"
#include "Transceiver/TransceiverFactory.hpp"
#include "WFPalette.hpp"
#include "models/IARURegions.hpp"
#include "models/DecodeHighlightingModel.hpp"
// #include "widgets/DateTimeEdit.hpp"  // widget-based, not needed in QML app

namespace
{
  class ItemEditorFactory final
    : public QItemEditorFactory
  {
  public:
    ItemEditorFactory ()
      : default_factory_ {QItemEditorFactory::defaultFactory ()}
    {
    }

    QWidget * createEditor (int user_type, QWidget * parent) const override
    {
      auto editor = QItemEditorFactory::createEditor (user_type, parent);
      return editor ? editor : default_factory_->createEditor (user_type, parent);
    }

  private:
    QItemEditorFactory const * default_factory_;
  };
}

void register_types ()
{
  auto item_editor_factory = new ItemEditorFactory;
  QItemEditorFactory::setDefaultFactory (item_editor_factory);

  // Qt6: qRegisterMetaTypeStreamOperators is no longer needed.
  // Types are auto-registered via Q_DECLARE_METATYPE and QDataStream operators.

  // V101 Frequency list model
  QMetaType::registerConverter<FrequencyList_v2_101::Item, QString> (&FrequencyList_v2_101::Item::toString);

  // Audio device
  qRegisterMetaType<AudioDevice::Channel> ("AudioDevice::Channel");

  // Station details
  qRegisterMetaType<StationList::Station> ("Station");
  QMetaType::registerConverter<StationList::Station, QString> (&StationList::Station::toString);
  qRegisterMetaType<StationList::Stations> ("Stations");

  // Transceiver
  qRegisterMetaType<Transceiver::TransceiverState> ("Transceiver::TransceiverState");

  // DecodeHighlightingModel
  QMetaType::registerConverter<DecodeHighlightingModel::HighlightInfo, QString> (&DecodeHighlightingModel::HighlightInfo::toString);
}
