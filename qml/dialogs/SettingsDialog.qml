import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Decodium

Dialog {
    id: settingsDialog
    title: "Settings"
    modal: true
    width: 560
    height: 480
    anchors.centerIn: parent

    background: Rectangle {
        color: Theme.background
        border.color: Theme.border
        border.width: 1
        radius: Theme.radiusLarge
    }

    header: Rectangle {
        width: parent.width
        height: 48
        color: Theme.surface
        radius: Theme.radiusLarge

        // Flatten bottom corners
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: Theme.radiusLarge
            color: Theme.surface
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.margin
            anchors.rightMargin: Theme.margin

            Text {
                text: "SETTINGS"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontMedium
                font.bold: true
                font.letterSpacing: 2
                color: Theme.accent
            }
            Item { Layout.fillWidth: true }
            AbstractButton {
                implicitWidth: 28; implicitHeight: 28
                onClicked: settingsDialog.close()
                contentItem: Text {
                    text: "\u2715"
                    font.pixelSize: 14
                    color: Theme.textSecondary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 4
                    color: parent.hovered ? Theme.surfaceLight : "transparent"
                }
            }
        }
    }

    contentItem: ColumnLayout {
        spacing: 0

        // Tab bar
        TabBar {
            id: tabBar
            Layout.fillWidth: true

            background: Rectangle { color: Theme.surface }

            Repeater {
                model: ["General", "Audio", "Radio", "WiFi"]
                TabButton {
                    text: modelData
                    width: implicitWidth
                    contentItem: Text {
                        text: parent.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                        font.bold: parent.checked
                        color: parent.checked ? Theme.accent : Theme.textSecondary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.checked ? Theme.surfaceLight : Theme.surface
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 2
                            color: parent.parent.checked ? Theme.accent : "transparent"
                        }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

        // Tab content
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex

            // ── General tab ──
            Flickable {
                contentHeight: generalColumn.height
                clip: true

                ColumnLayout {
                    id: generalColumn
                    width: parent.width
                    spacing: Theme.spacingLarge

                    Item { height: Theme.margin }

                    // Callsign
                    ColumnLayout {
                        Layout.leftMargin: Theme.marginLarge
                        Layout.rightMargin: Theme.marginLarge
                        spacing: Theme.spacingSmall

                        Text {
                            text: "CALLSIGN"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTiny
                            font.letterSpacing: 2
                            color: Theme.textSecondary
                        }
                        TextField {
                            id: callsignField
                            Layout.fillWidth: true
                            text: typeof app !== "undefined" ? app.callsign : ""
                            placeholderText: "Your callsign"
                            font.family: Theme.digitalFont
                            font.pixelSize: Theme.fontNormal
                            color: Theme.textPrimary

                            background: Rectangle {
                                color: Theme.surfaceLight
                                border.color: callsignField.activeFocus ? Theme.accent : Theme.border
                                border.width: 1
                                radius: Theme.radius
                            }
                        }
                    }

                    // Grid locator
                    ColumnLayout {
                        Layout.leftMargin: Theme.marginLarge
                        Layout.rightMargin: Theme.marginLarge
                        spacing: Theme.spacingSmall

                        Text {
                            text: "GRID LOCATOR"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTiny
                            font.letterSpacing: 2
                            color: Theme.textSecondary
                        }
                        TextField {
                            id: gridField
                            Layout.fillWidth: true
                            text: typeof app !== "undefined" ? app.grid : ""
                            placeholderText: "e.g. JN70FU"
                            font.family: Theme.digitalFont
                            font.pixelSize: Theme.fontNormal
                            color: Theme.textPrimary

                            background: Rectangle {
                                color: Theme.surfaceLight
                                border.color: gridField.activeFocus ? Theme.accent : Theme.border
                                border.width: 1
                                radius: Theme.radius
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // ── Audio tab ──
            Flickable {
                contentHeight: audioColumn.height
                clip: true

                ColumnLayout {
                    id: audioColumn
                    width: parent.width
                    spacing: Theme.spacingLarge

                    Item { height: Theme.margin }

                    ColumnLayout {
                        Layout.leftMargin: Theme.marginLarge
                        Layout.rightMargin: Theme.marginLarge
                        spacing: Theme.spacingSmall

                        Text {
                            text: "INPUT DEVICE"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTiny
                            font.letterSpacing: 2
                            color: Theme.textSecondary
                        }
                        ComboBox {
                            id: inputDeviceCombo
                            Layout.fillWidth: true
                            model: ["Default Input"]
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall

                            background: Rectangle {
                                color: Theme.surfaceLight
                                border.color: Theme.border
                                border.width: 1
                                radius: Theme.radius
                            }
                            contentItem: Text {
                                text: inputDeviceCombo.displayText
                                font: inputDeviceCombo.font
                                color: Theme.textPrimary
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: Theme.spacing
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.leftMargin: Theme.marginLarge
                        Layout.rightMargin: Theme.marginLarge
                        spacing: Theme.spacingSmall

                        Text {
                            text: "OUTPUT DEVICE"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTiny
                            font.letterSpacing: 2
                            color: Theme.textSecondary
                        }
                        ComboBox {
                            id: outputDeviceCombo
                            Layout.fillWidth: true
                            model: ["Default Output"]
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall

                            background: Rectangle {
                                color: Theme.surfaceLight
                                border.color: Theme.border
                                border.width: 1
                                radius: Theme.radius
                            }
                            contentItem: Text {
                                text: outputDeviceCombo.displayText
                                font: outputDeviceCombo.font
                                color: Theme.textPrimary
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: Theme.spacing
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // ── Radio tab ──
            Flickable {
                contentHeight: radioColumn.height
                clip: true

                ColumnLayout {
                    id: radioColumn
                    width: parent.width
                    spacing: Theme.spacingLarge

                    Item { height: Theme.margin }

                    ColumnLayout {
                        Layout.leftMargin: Theme.marginLarge
                        Layout.rightMargin: Theme.marginLarge
                        spacing: Theme.spacingSmall

                        Text {
                            text: "CAT CONTROL"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTiny
                            font.letterSpacing: 2
                            color: Theme.textSecondary
                        }
                        ComboBox {
                            id: catCombo
                            Layout.fillWidth: true
                            model: ["None", "Hamlib", "OmniRig", "Flrig"]
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall

                            background: Rectangle {
                                color: Theme.surfaceLight
                                border.color: Theme.border
                                border.width: 1
                                radius: Theme.radius
                            }
                            contentItem: Text {
                                text: catCombo.displayText
                                font: catCombo.font
                                color: Theme.textPrimary
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: Theme.spacing
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.leftMargin: Theme.marginLarge
                        Layout.rightMargin: Theme.marginLarge
                        spacing: Theme.spacingSmall

                        Text {
                            text: "SERIAL PORT"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTiny
                            font.letterSpacing: 2
                            color: Theme.textSecondary
                        }
                        ComboBox {
                            id: portCombo
                            Layout.fillWidth: true
                            model: ["COM1", "COM2", "COM3"]
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall

                            background: Rectangle {
                                color: Theme.surfaceLight
                                border.color: Theme.border
                                border.width: 1
                                radius: Theme.radius
                            }
                            contentItem: Text {
                                text: portCombo.displayText
                                font: portCombo.font
                                color: Theme.textPrimary
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: Theme.spacing
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.leftMargin: Theme.marginLarge
                        Layout.rightMargin: Theme.marginLarge
                        spacing: Theme.spacingSmall

                        Text {
                            text: "BAUD RATE"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTiny
                            font.letterSpacing: 2
                            color: Theme.textSecondary
                        }
                        ComboBox {
                            id: baudCombo
                            Layout.fillWidth: true
                            model: ["4800", "9600", "19200", "38400", "57600", "115200"]
                            currentIndex: 3
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall

                            background: Rectangle {
                                color: Theme.surfaceLight
                                border.color: Theme.border
                                border.width: 1
                                radius: Theme.radius
                            }
                            contentItem: Text {
                                text: baudCombo.displayText
                                font: baudCombo.font
                                color: Theme.textPrimary
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: Theme.spacing
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // ── WiFi Bridge tab ──
            Flickable {
                contentHeight: wifiColumn.height
                clip: true

                ColumnLayout {
                    id: wifiColumn
                    width: parent.width
                    spacing: Theme.spacingLarge

                    Item { height: Theme.margin }

                    // WiFi mode toggle
                    RowLayout {
                        Layout.leftMargin: Theme.marginLarge
                        Layout.rightMargin: Theme.marginLarge
                        spacing: Theme.spacing

                        Text {
                            text: "WIFI BRIDGE MODE"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTiny
                            font.letterSpacing: 2
                            color: Theme.textSecondary
                            Layout.fillWidth: true
                        }
                        Switch {
                            id: wifiModeSwitch
                            checked: typeof audio !== "undefined" ? audio.wifiMode : false
                            onToggled: {
                                if (typeof audio !== "undefined")
                                    audio.wifiMode = checked
                            }
                        }
                    }

                    // Connection status badge
                    Rectangle {
                        Layout.leftMargin: Theme.marginLarge
                        Layout.rightMargin: Theme.marginLarge
                        Layout.fillWidth: true
                        height: 36
                        radius: Theme.radius
                        color: (typeof audio !== "undefined" && audio.bridgeConnected)
                               ? Qt.rgba(0, 1, 0, 0.1) : Qt.rgba(1, 0.2, 0.2, 0.1)
                        border.color: (typeof audio !== "undefined" && audio.bridgeConnected)
                                      ? Theme.activeGreen : Theme.alertRed
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: (typeof audio !== "undefined" && audio.bridgeConnected)
                                  ? "CONNECTED" : "DISCONNECTED"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            font.bold: true
                            font.letterSpacing: 2
                            color: (typeof audio !== "undefined" && audio.bridgeConnected)
                                   ? Theme.activeGreen : Theme.alertRed
                        }
                    }

                    // Bridge IP address
                    ColumnLayout {
                        Layout.leftMargin: Theme.marginLarge
                        Layout.rightMargin: Theme.marginLarge
                        spacing: Theme.spacingSmall

                        Text {
                            text: "BRIDGE ADDRESS"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTiny
                            font.letterSpacing: 2
                            color: Theme.textSecondary
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSmall

                            TextField {
                                id: bridgeAddressField
                                Layout.fillWidth: true
                                text: typeof audio !== "undefined" ? audio.bridgeAddress : ""
                                placeholderText: "192.168.1.100"
                                font.family: Theme.digitalFont
                                font.pixelSize: Theme.fontNormal
                                color: Theme.textPrimary
                                inputMethodHints: Qt.ImhPreferNumbers

                                background: Rectangle {
                                    color: Theme.surfaceLight
                                    border.color: bridgeAddressField.activeFocus ? Theme.accent : Theme.border
                                    border.width: 1
                                    radius: Theme.radius
                                }
                            }

                            // Scan button
                            AbstractButton {
                                implicitWidth: 70; implicitHeight: 34
                                onClicked: {
                                    if (typeof audio !== "undefined")
                                        audio.startBridgeDiscovery()
                                }
                                background: Rectangle {
                                    color: parent.hovered ? Theme.surfaceLight : Theme.surface
                                    border.color: Theme.accent
                                    border.width: 1
                                    radius: Theme.radius
                                }
                                contentItem: Text {
                                    text: "Scan"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSmall
                                    color: Theme.accent
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }

                    // Discovered bridges list
                    ColumnLayout {
                        Layout.leftMargin: Theme.marginLarge
                        Layout.rightMargin: Theme.marginLarge
                        spacing: Theme.spacingSmall

                        Text {
                            text: "DISCOVERED BRIDGES"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTiny
                            font.letterSpacing: 2
                            color: Theme.textSecondary
                        }

                        ListView {
                            id: bridgeList
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.max(60, contentHeight)
                            clip: true
                            model: ListModel { id: bridgeListModel }

                            delegate: AbstractButton {
                                width: bridgeList.width
                                height: 32
                                onClicked: {
                                    bridgeAddressField.text = model.address
                                    if (typeof audio !== "undefined")
                                        audio.bridgeAddress = model.address
                                }
                                background: Rectangle {
                                    color: parent.hovered ? Theme.surfaceLight : Theme.surface
                                    radius: Theme.radius
                                }
                                contentItem: Text {
                                    text: model.address + ":" + model.port
                                    font.family: Theme.digitalFont
                                    font.pixelSize: Theme.fontSmall
                                    color: Theme.textPrimary
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: Theme.spacing
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: Theme.border
                                border.width: 1
                                radius: Theme.radius
                                z: -1
                            }
                        }
                    }

                    // Connect / Disconnect button
                    RowLayout {
                        Layout.leftMargin: Theme.marginLarge
                        Layout.rightMargin: Theme.marginLarge
                        Layout.fillWidth: true

                        Item { Layout.fillWidth: true }

                        AbstractButton {
                            implicitWidth: 140; implicitHeight: 38
                            onClicked: {
                                if (typeof audio !== "undefined") {
                                    audio.bridgeAddress = bridgeAddressField.text
                                    if (audio.bridgeConnected)
                                        audio.disconnectFromBridge()
                                    else
                                        audio.connectToBridge()
                                }
                            }
                            background: Rectangle {
                                color: (typeof audio !== "undefined" && audio.bridgeConnected)
                                       ? Qt.rgba(1, 0.2, 0.2, 0.15)
                                       : Qt.rgba(0, 0.83, 1.0, 0.15)
                                border.color: (typeof audio !== "undefined" && audio.bridgeConnected)
                                              ? Theme.alertRed : Theme.accent
                                border.width: 1
                                radius: Theme.radius
                            }
                            contentItem: Text {
                                text: (typeof audio !== "undefined" && audio.bridgeConnected)
                                      ? "Disconnect" : "Connect"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSmall
                                font.bold: true
                                color: (typeof audio !== "undefined" && audio.bridgeConnected)
                                       ? Theme.alertRed : Theme.accent
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }

                // Handle bridge discovery signal
                Connections {
                    target: typeof audio !== "undefined" ? audio : null
                    function onBridgeDiscovered(address, port) {
                        // Avoid duplicates
                        for (var i = 0; i < bridgeListModel.count; i++) {
                            if (bridgeListModel.get(i).address === address) return
                        }
                        bridgeListModel.append({"address": address, "port": port})
                    }
                }
            }
        }
    }

    footer: Rectangle {
        width: parent.width
        height: 50
        color: Theme.surface
        radius: Theme.radiusLarge

        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: Theme.radiusLarge
            color: Theme.surface
        }

        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: Theme.border
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.marginLarge
            anchors.rightMargin: Theme.marginLarge

            Item { Layout.fillWidth: true }

            AbstractButton {
                implicitWidth: 90; implicitHeight: 34
                onClicked: settingsDialog.close()
                background: Rectangle {
                    color: parent.hovered ? Theme.surfaceLight : Theme.surface
                    border.color: Theme.border
                    border.width: 1
                    radius: Theme.radius
                }
                contentItem: Text {
                    text: "Cancel"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    color: Theme.textSecondary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            AbstractButton {
                implicitWidth: 90; implicitHeight: 34
                onClicked: {
                    if (typeof app !== "undefined") {
                        app.callsign = callsignField.text;
                        app.grid = gridField.text;
                    }
                    settingsDialog.close();
                }
                background: Rectangle {
                    color: parent.hovered ? Qt.rgba(0, 0.83, 1.0, 0.2) : Qt.rgba(0, 0.83, 1.0, 0.1)
                    border.color: Theme.accent
                    border.width: 1
                    radius: Theme.radius
                }
                contentItem: Text {
                    text: "Apply"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    font.bold: true
                    color: Theme.accent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
