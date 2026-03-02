import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Decodium

Rectangle {
    id: headerBar
    color: Theme.surface

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.margin
        anchors.rightMargin: Theme.margin
        spacing: Theme.spacingLarge

        // ── Logo ──
        Column {
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Text {
                text: "DECODIUM 3"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLarge
                font.bold: true
                font.letterSpacing: 2
                color: Theme.accent
            }
            Text {
                text: "FT2 DIGITAL SUITE"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTiny
                font.letterSpacing: 4
                color: Theme.textSecondary
            }
        }

        // ── Separator ──
        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 50
            Layout.alignment: Qt.AlignVCenter
            color: Theme.border
        }

        // ── Frequency display ──
        FrequencyDisplay {
            Layout.alignment: Qt.AlignVCenter
            frequency: typeof radio !== "undefined" ? radio.dialFrequency : 14075500
        }

        // ── Separator ──
        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 50
            Layout.alignment: Qt.AlignVCenter
            color: Theme.border
        }

        // ── Audio meter ──
        Column {
            Layout.alignment: Qt.AlignVCenter
            spacing: 4

            Text {
                text: "RX"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTiny
                color: Theme.textSecondary
                anchors.horizontalCenter: parent.horizontalCenter
            }
            AudioMeter {
                width: 20
                height: 50
                level: typeof audio !== "undefined" ? audio.rxLevel : 35
            }
        }

        // ── Separator ──
        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 50
            Layout.alignment: Qt.AlignVCenter
            color: Theme.border
        }

        // ── Mode button ──
        ModeButton {
            Layout.alignment: Qt.AlignVCenter
            modeName: typeof radio !== "undefined" ? radio.mode : "FT2"
            active: true
        }

        // ── Spacer ──
        Item { Layout.fillWidth: true }

        // ── Separator ──
        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 50
            Layout.alignment: Qt.AlignVCenter
            color: Theme.border
        }

        // ── Countdown timer ──
        CountdownTimer {
            Layout.alignment: Qt.AlignVCenter
            period: typeof decoder !== "undefined" ? decoder.period : 15.0
            progress: {
                var now = new Date();
                var secs = now.getUTCSeconds() + now.getUTCMilliseconds() / 1000.0;
                var p = typeof decoder !== "undefined" ? decoder.period : 15.0;
                return (secs % p) / p;
            }
        }

        // ── Separator ──
        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 50
            Layout.alignment: Qt.AlignVCenter
            color: Theme.border
        }

        // ── UTC Clock ──
        Column {
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Text {
                text: "UTC"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTiny
                font.letterSpacing: 2
                color: Theme.textSecondary
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                id: utcClock
                font.family: Theme.digitalFont
                font.pixelSize: 22
                color: Theme.accent

                function updateTime() {
                    var now = new Date();
                    var h = String(now.getUTCHours()).padStart(2, '0');
                    var m = String(now.getUTCMinutes()).padStart(2, '0');
                    var s = String(now.getUTCSeconds()).padStart(2, '0');
                    text = h + ":" + m + ":" + s;
                }

                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    triggeredOnStart: true
                    onTriggered: utcClock.updateTime()
                }
            }
        }
    }
}
