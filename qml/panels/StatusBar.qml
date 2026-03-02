import QtQuick
import QtQuick.Layouts
import Decodium
import "../components" as Components

Rectangle {
    id: statusBar
    color: Theme.surface

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.margin
        anchors.rightMargin: Theme.margin
        spacing: Theme.spacingLarge

        // ── DX Callsign ──
        Row {
            spacing: Theme.spacingSmall
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: "DX:"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTiny
                color: Theme.textDim
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: typeof tx !== "undefined" && tx.hisCall ? tx.hisCall : "------"
                font.family: Theme.digitalFont
                font.pixelSize: Theme.fontSmall
                font.bold: true
                color: (typeof tx !== "undefined" && tx.hisCall) ? Theme.accent : Theme.textDim
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Separator
        Rectangle { width: 1; height: 16; color: Theme.border; Layout.alignment: Qt.AlignVCenter }

        // ── Grid ──
        Row {
            spacing: Theme.spacingSmall
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: "Grid:"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTiny
                color: Theme.textDim
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: typeof app !== "undefined" && app.grid ? app.grid : "----"
                font.family: Theme.digitalFont
                font.pixelSize: Theme.fontSmall
                color: Theme.textSecondary
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Separator
        Rectangle { width: 1; height: 16; color: Theme.border; Layout.alignment: Qt.AlignVCenter }

        // ── Report Sent / Rcvd ──
        Row {
            spacing: Theme.spacingSmall
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: "Rpt:"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTiny
                color: Theme.textDim
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "--/--"
                font.family: Theme.digitalFont
                font.pixelSize: Theme.fontSmall
                color: Theme.textSecondary
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Separator
        Rectangle { width: 1; height: 16; color: Theme.border; Layout.alignment: Qt.AlignVCenter }

        // ── Active TX message ──
        Row {
            spacing: Theme.spacingSmall
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: "TX:"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTiny
                color: Theme.textDim
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: typeof tx !== "undefined" && tx.activeTxMessage ? tx.activeTxMessage : "---"
                font.family: Theme.digitalFont
                font.pixelSize: Theme.fontSmall
                color: (typeof tx !== "undefined" && tx.transmitting) ? Theme.alertRed : Theme.textSecondary
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                Layout.maximumWidth: 300
            }
        }

        // Spacer
        Item { Layout.fillWidth: true }

        // ── Decoding indicator ──
        Components.StatusBadge {
            text: (typeof decoder !== "undefined" && decoder.decoding) ? "DECODING" : "IDLE"
            badgeColor: (typeof decoder !== "undefined" && decoder.decoding) ? Theme.activeGreen : Theme.textDim
            Layout.alignment: Qt.AlignVCenter
        }

        // Separator
        Rectangle { width: 1; height: 16; color: Theme.border; Layout.alignment: Qt.AlignVCenter }

        // ── QSO counter ──
        Row {
            spacing: Theme.spacingSmall
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: "QSOs:"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTiny
                color: Theme.textDim
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: typeof log !== "undefined" ? String(log.qsoCount) : "0"
                font.family: Theme.digitalFont
                font.pixelSize: Theme.fontSmall
                font.bold: true
                color: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Separator
        Rectangle { width: 1; height: 16; color: Theme.border; Layout.alignment: Qt.AlignVCenter }

        // ── Callsign ──
        Text {
            text: typeof app !== "undefined" && app.callsign ? app.callsign : "N0CALL"
            font.family: Theme.digitalFont
            font.pixelSize: Theme.fontSmall
            font.bold: true
            color: Theme.accent
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
