import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Decodium
import "../components" as Components

Rectangle {
    id: waterfallPanel
    color: Theme.background

    property double rxFreq: typeof waterfall !== "undefined" ? waterfall.rxFreq : 1500
    property double txFreq: typeof waterfall !== "undefined" ? waterfall.txFreq : 1500
    property double maxFreq: 5000.0  // Maximum audio frequency displayed

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Waterfall display area ──
        Rectangle {
            id: waterfallArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#050810"

            WaterfallItem {
                id: waterfallDisplay
                anchors.fill: parent
                rxFreq: waterfallPanel.rxFreq
                txFreq: waterfallPanel.txFreq
                gain: typeof waterfall !== "undefined" ? waterfall.gain : 50
                zero: typeof waterfall !== "undefined" ? waterfall.zero : 50
                running: typeof audio !== "undefined" ? audio.monitoring : false
                onFrequencySelected: function(freq) {
                    if (typeof waterfall !== "undefined") waterfall.rxFreq = freq;
                    waterfallPanel.rxFreq = freq;
                }
            }
        }

        // ── Waterfall toolbar ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            color: Theme.surface

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.margin
                anchors.rightMargin: Theme.margin
                spacing: Theme.spacingLarge

                // RX Freq readout
                Text {
                    text: "RX: " + Math.round(waterfallPanel.rxFreq) + " Hz"
                    font.family: Theme.digitalFont
                    font.pixelSize: Theme.fontSmall
                    color: Theme.alertRed
                }

                // TX Freq readout
                Text {
                    text: "TX: " + Math.round(waterfallPanel.txFreq) + " Hz"
                    font.family: Theme.digitalFont
                    font.pixelSize: Theme.fontSmall
                    color: Theme.activeGreen
                }

                Item { Layout.fillWidth: true }

                // Gain slider
                Text {
                    text: "Gain"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTiny
                    color: Theme.textSecondary
                }
                Slider {
                    id: gainSlider
                    Layout.preferredWidth: 100
                    from: 0; to: 100
                    value: typeof waterfall !== "undefined" ? waterfall.gain : 50
                    onMoved: {
                        if (typeof waterfall !== "undefined") waterfall.gain = value;
                    }

                    background: Rectangle {
                        x: gainSlider.leftPadding
                        y: gainSlider.topPadding + gainSlider.availableHeight / 2 - height / 2
                        width: gainSlider.availableWidth
                        height: 4
                        radius: 2
                        color: Theme.surfaceLight

                        Rectangle {
                            width: gainSlider.visualPosition * parent.width
                            height: parent.height
                            radius: 2
                            color: Theme.accent
                        }
                    }
                    handle: Rectangle {
                        x: gainSlider.leftPadding + gainSlider.visualPosition * (gainSlider.availableWidth - width)
                        y: gainSlider.topPadding + gainSlider.availableHeight / 2 - height / 2
                        width: 12; height: 12
                        radius: 6
                        color: gainSlider.pressed ? Theme.accent : Theme.textPrimary
                        border.color: Theme.accent
                        border.width: 1
                    }
                }

                // Zero slider
                Text {
                    text: "Zero"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTiny
                    color: Theme.textSecondary
                }
                Slider {
                    id: zeroSlider
                    Layout.preferredWidth: 100
                    from: 0; to: 100
                    value: typeof waterfall !== "undefined" ? waterfall.zero : 50
                    onMoved: {
                        if (typeof waterfall !== "undefined") waterfall.zero = value;
                    }

                    background: Rectangle {
                        x: zeroSlider.leftPadding
                        y: zeroSlider.topPadding + zeroSlider.availableHeight / 2 - height / 2
                        width: zeroSlider.availableWidth
                        height: 4
                        radius: 2
                        color: Theme.surfaceLight

                        Rectangle {
                            width: zeroSlider.visualPosition * parent.width
                            height: parent.height
                            radius: 2
                            color: Theme.accent
                        }
                    }
                    handle: Rectangle {
                        x: zeroSlider.leftPadding + zeroSlider.visualPosition * (zeroSlider.availableWidth - width)
                        y: zeroSlider.topPadding + zeroSlider.availableHeight / 2 - height / 2
                        width: 12; height: 12
                        radius: 6
                        color: zeroSlider.pressed ? Theme.accent : Theme.textPrimary
                        border.color: Theme.accent
                        border.width: 1
                    }
                }
            }
        }
    }
}
