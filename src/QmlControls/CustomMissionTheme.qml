import QtQuick

import QGroundControl
import QGroundControl.Controls

// Route Mapping Task Settings tokens, applied to Custom Mission chrome.
// Layout/structure stays the same — only colors and surfaces change.
QtObject {
    id: theme

    readonly property bool active: typeof mainWindow !== "undefined"
                                   && mainWindow
                                   && mainWindow.activeMissionEditor === "customMission"

    readonly property color accentGreen:     "#00a651"
    readonly property color accentSoftGreen: "#e8e8e8"
    readonly property color titleColor:      "#3f3f3f"
    readonly property color bodyColor:       "#6a6a6a"
    readonly property color hintColor:       "#8a8a8a"
    readonly property color cardBorderIdle:  "#e2e2e2"
    readonly property color panelFill:       "#ffffff"
    readonly property color cardFill:        "#ffffff"
    readonly property color textOnAccent:    "#ffffff"

    readonly property real pad:    ScreenTools.defaultFontPixelWidth * 1.05
    readonly property real radius: ScreenTools.defaultFontPixelWidth * 0.75
}
