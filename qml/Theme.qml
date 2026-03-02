pragma Singleton
import QtQuick

QtObject {
    // ── Core palette ──
    readonly property color background:   "#0a0e18"
    readonly property color surface:      "#121a2e"
    readonly property color surfaceLight: "#1a2838"
    readonly property color surfaceMid:   "#162030"
    readonly property color accent:       "#00d4ff"
    readonly property color accentDim:    "#007a99"
    readonly property color activeGreen:  "#00ff00"
    readonly property color alertRed:     "#ff3333"
    readonly property color warning:      "#ffaa00"
    readonly property color textPrimary:  "#e0e0e0"
    readonly property color textSecondary:"#808890"
    readonly property color textDim:      "#505860"
    readonly property color border:       "#1a2838"
    readonly property color borderLight:  "#243448"
    readonly property color transparent:  "transparent"

    // ── Platform detection ──
    readonly property bool isMobile: Qt.platform.os === "android" || Qt.platform.os === "ios"

    // ── Typography ──
    readonly property string fontFamily:  isMobile ? "Roboto" : "Segoe UI"
    readonly property string digitalFont: isMobile ? "monospace" : "Consolas"

    // ── Font sizes (responsive) ──
    readonly property int fontTiny:    isMobile ? 8  : 9
    readonly property int fontSmall:   isMobile ? 10 : 11
    readonly property int fontNormal:  isMobile ? 11 : 13
    readonly property int fontMedium:  isMobile ? 13 : 15
    readonly property int fontLarge:   isMobile ? 16 : 18
    readonly property int fontHuge:    isMobile ? 24 : 28
    readonly property int fontGiant:   isMobile ? 30 : 36

    // ── Layout constants (responsive) ──
    readonly property int headerHeight:     isMobile ? 60 : 80
    readonly property int statusBarHeight:  isMobile ? 28 : 30
    readonly property int toolbarHeight:    isMobile ? 44 : 50
    readonly property int txRowHeight:      isMobile ? 36 : 40
    readonly property int radius:            4
    readonly property int radiusLarge:        8
    readonly property int spacing:            8
    readonly property int spacingSmall:       4
    readonly property int spacingLarge:      16
    readonly property int margin:            12
    readonly property int marginSmall:        6
    readonly property int marginLarge:       20

    // ── Opacity values ──
    readonly property real hoverOpacity:   0.08
    readonly property real pressOpacity:   0.15
    readonly property real disabledOpacity:0.4

    // ── Animation durations ──
    readonly property int animFast:   120
    readonly property int animNormal: 200
    readonly property int animSlow:   400
}
