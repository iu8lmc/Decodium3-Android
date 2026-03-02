import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Decodium

import "components" as Components
import "panels"     as Panels
import "dialogs"    as Dialogs

ApplicationWindow {
    id: root

    visible: true
    title: "Decodium 3 FT2"
    width: Theme.isMobile ? Screen.width : 1400
    height: Theme.isMobile ? Screen.height : 900
    minimumWidth: Theme.isMobile ? 320 : 1200
    minimumHeight: Theme.isMobile ? 480 : 800
    color: Theme.background

    // ── Desktop menu bar (hidden on mobile) ──
    menuBar: Theme.isMobile ? null : desktopMenuBar

    MenuBar {
        id: desktopMenuBar
        visible: !Theme.isMobile
        background: Rectangle { color: Theme.surface }

        Menu {
            title: qsTr("&File")
            Action { text: qsTr("&Settings...");  onTriggered: settingsDialog.open() }
            MenuSeparator {}
            Action { text: qsTr("E&xit");         onTriggered: Qt.quit() }
        }
        Menu {
            title: qsTr("&View")
            Action { text: qsTr("&Waterfall");     checkable: true; checked: true }
        }
        Menu {
            title: qsTr("&Help")
            Action { text: qsTr("&About...");      onTriggered: aboutDialog.open() }
        }

        delegate: MenuBarItem {
            id: menuBarItem
            contentItem: Text {
                text: menuBarItem.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontNormal
                color: menuBarItem.highlighted ? Theme.accent : Theme.textPrimary
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: menuBarItem.highlighted ? Theme.surfaceLight : Theme.surface
            }
        }
    }

    // ── Mobile hamburger drawer ──
    Drawer {
        id: mobileDrawer
        visible: false
        width: Math.min(root.width * 0.75, 280)
        height: root.height
        edge: Qt.LeftEdge

        background: Rectangle {
            color: Theme.surface
            border.color: Theme.border
            border.width: 1
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Drawer header
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                color: Theme.background

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.margin
                    anchors.rightMargin: Theme.margin

                    Text {
                        text: "DECODIUM 3"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontMedium
                        font.bold: true
                        font.letterSpacing: 2
                        color: Theme.accent
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

            // Menu items
            Repeater {
                model: [
                    { text: "Settings", icon: "\u2699", action: function() { settingsDialog.open(); mobileDrawer.close() } },
                    { text: "WiFi Bridge", icon: "\u21C4", action: function() { settingsDialog.open(); mobileDrawer.close() } },
                    { text: "About", icon: "\u2139", action: function() { aboutDialog.open(); mobileDrawer.close() } }
                ]

                delegate: AbstractButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    onClicked: modelData.action()

                    background: Rectangle {
                        color: parent.pressed ? Theme.surfaceLight : "transparent"
                    }

                    contentItem: RowLayout {
                        spacing: Theme.spacing

                        Text {
                            text: modelData.icon
                            font.pixelSize: Theme.fontLarge
                            color: Theme.accent
                            Layout.preferredWidth: 40
                            horizontalAlignment: Text.AlignHCenter
                            Layout.leftMargin: Theme.margin
                        }
                        Text {
                            text: modelData.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontNormal
                            color: Theme.textPrimary
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            // WiFi status in drawer
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: Theme.background

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.margin
                    anchors.rightMargin: Theme.margin

                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: (typeof audio !== "undefined" && audio.bridgeConnected)
                               ? Theme.activeGreen : Theme.textDim
                    }
                    Text {
                        text: (typeof audio !== "undefined" && audio.bridgeConnected)
                              ? "Bridge connected" : "Bridge offline"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                        color: Theme.textSecondary
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }

    // ── Main layout ──
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Mobile: hamburger button row
        Rectangle {
            visible: Theme.isMobile
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.isMobile ? 44 : 0
            color: Theme.surface

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingSmall
                anchors.rightMargin: Theme.margin

                // Hamburger button
                AbstractButton {
                    implicitWidth: 40; implicitHeight: 40
                    onClicked: mobileDrawer.open()
                    contentItem: Text {
                        text: "\u2630"
                        font.pixelSize: Theme.fontLarge
                        color: Theme.textPrimary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: Theme.radius
                        color: parent.pressed ? Theme.surfaceLight : "transparent"
                    }
                }

                Text {
                    text: "DECODIUM 3"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    font.bold: true
                    font.letterSpacing: 2
                    color: Theme.accent
                    Layout.fillWidth: true
                }

                // WiFi indicator
                Rectangle {
                    visible: typeof audio !== "undefined" && audio.wifiMode
                    width: 10; height: 10; radius: 5
                    color: (typeof audio !== "undefined" && audio.bridgeConnected)
                           ? Theme.activeGreen : Theme.alertRed
                }
            }
        }

        // Row 1 - Header
        Components.HeaderBar {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.headerHeight
        }

        // Separator
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }

        // Row 2 - Waterfall
        Panels.WaterfallPanel {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: Theme.isMobile ? 150 : 200
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }

        // Row 3 - Decode panels
        Panels.DecodePanelRow {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: Theme.isMobile ? 200 : 300
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }

        // Row 4 - Bottom toolbar (bands + modes)
        Panels.BottomToolbar {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.toolbarHeight
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }

        // Row 5 - TX button row
        Panels.TxButtonRow {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.txRowHeight
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }

        // Row 6 - Status bar
        Panels.StatusBar {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.statusBarHeight
        }
    }

    // ── Dialogs ──
    Dialogs.SettingsDialog { id: settingsDialog }
    Dialogs.LogQSODialog   { id: logQSODialog   }
    Dialogs.AboutDialog    { id: aboutDialog     }
}
