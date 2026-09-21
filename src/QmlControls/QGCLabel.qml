import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

Text {
    font.pointSize: ScreenTools.defaultFontPointSize
    font.family:    ScreenTools.normalFontFamily
    antialiasing:   true

    // Custom Mission plan panel is a white card; default palette text is light and vanishes.
    readonly property bool _customMissionLightPanel: typeof mainWindow !== "undefined"
                                                     && mainWindow.customMissionStyleActive

    color: _customMissionLightPanel ? "#3f3f3f" : qgcPal.text

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }
}
