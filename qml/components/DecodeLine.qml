import QtQuick
import Decodium

Rectangle {
    id: decodeLine
    width: ListView.view ? ListView.view.width : 400
    height: 22
    color: {
        if (mouseArea.containsMouse) return Theme.surfaceLight;
        if (model.isCQ) return Qt.rgba(0, 0.83, 1.0, 0.04);
        return "transparent";
    }

    // Highlight new decodes briefly
    property bool flashActive: false

    Rectangle {
        anchors.fill: parent
        color: Theme.accent
        opacity: flashActive ? 0.12 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.animSlow }
        }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: Theme.marginSmall
        anchors.rightMargin: Theme.marginSmall
        spacing: Theme.spacing

        // UTC
        Text {
            width: 52
            text: model.utc || ""
            font.family: Theme.digitalFont
            font.pixelSize: Theme.fontSmall
            color: Theme.textSecondary
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
        }

        // dB
        Text {
            width: 36
            text: model.db !== undefined ? (model.db > 0 ? "+" + model.db : String(model.db)) : ""
            font.family: Theme.digitalFont
            font.pixelSize: Theme.fontSmall
            color: {
                var dbVal = model.db || 0;
                if (dbVal >= 0) return Theme.activeGreen;
                if (dbVal >= -10) return Theme.accent;
                return Theme.textSecondary;
            }
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: parent.verticalCenter
        }

        // DT
        Text {
            width: 40
            text: model.dt !== undefined ? model.dt.toFixed(1) : ""
            font.family: Theme.digitalFont
            font.pixelSize: Theme.fontSmall
            color: Theme.textSecondary
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: parent.verticalCenter
        }

        // Freq
        Text {
            width: 48
            text: model.freq !== undefined ? String(model.freq) : ""
            font.family: Theme.digitalFont
            font.pixelSize: Theme.fontSmall
            color: Theme.accent
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: parent.verticalCenter
        }

        // Separator dot
        Text {
            width: 10
            text: "\u2022"
            font.pixelSize: 8
            color: Theme.border
            horizontalAlignment: Text.AlignHCenter
            anchors.verticalCenter: parent.verticalCenter
        }

        // Message
        Text {
            width: parent.width - 52 - 36 - 40 - 48 - 10 - (5 * Theme.spacing) - Theme.marginSmall * 2
            text: model.message || ""
            font.family: Theme.digitalFont
            font.pixelSize: Theme.fontSmall
            font.bold: model.isCQ || false
            color: model.color || Theme.textPrimary
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // New-entry indicator on the left edge
    Rectangle {
        visible: model.isNew || false
        width: 2
        height: parent.height
        color: Theme.activeGreen
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            // Extract callsign from message and set it as the target
            if (typeof tx !== "undefined" && model.message) {
                // Simple extraction: the message typically has a callsign we can reply to
                tx.hisCall = extractCall(model.message);
            }
        }
        onDoubleClicked: {
            if (typeof tx !== "undefined" && model.isCQ) {
                tx.hisCall = extractCall(model.message);
                // Auto-start reply sequence
            }
        }
    }

    function extractCall(msg) {
        // Naive callsign extraction: take the second word if CQ, or first otherwise
        var parts = msg.trim().split(/\s+/);
        if (parts.length >= 2 && parts[0] === "CQ") {
            // CQ [DX] CALL GRID
            if (parts[1] === "DX" && parts.length >= 3) return parts[2];
            return parts[1];
        }
        if (parts.length >= 2) return parts[1];
        return parts[0] || "";
    }

    // Flash animation on creation
    Component.onCompleted: {
        if (model.isNew) {
            flashActive = true;
            flashTimer.start();
        }
    }

    Timer {
        id: flashTimer
        interval: 600
        onTriggered: flashActive = false
    }
}
