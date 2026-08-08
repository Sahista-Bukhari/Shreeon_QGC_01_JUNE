import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id:     outerEditorRect
    height: innerEditorRect.y + innerEditorRect.height + (_margin * 2)
    radius: _radius
    color:  _lightTheme ? "#ffffff" : Qt.rgba(0.14, 0.69, 0.36, 0.22)
    border.width: 1
    border.color: _lightTheme ? "#00a651" : Qt.rgba(0.14, 0.69, 0.36, 0.85)

    property var controller ///< RallyPointController

    readonly property bool  _lightTheme: typeof mainWindow !== "undefined"
                                         && mainWindow
                                         && mainWindow.activeMissionEditor === "customMission"
    readonly property real  _margin:     _lightTheme ? ScreenTools.defaultFontPixelWidth * 1.05 : ScreenTools.defaultFontPixelWidth / 2
    readonly property real  _radius:     _lightTheme ? ScreenTools.defaultFontPixelWidth * 0.75 : ScreenTools.defaultFontPixelWidth / 2
    readonly property color _titleColor: _lightTheme ? "#3f3f3f" : "#ffffff"
    readonly property color _bodyColor:  _lightTheme ? "#6a6a6a" : Qt.rgba(1, 1, 1, 0.88)

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    QGCLabel {
        id:                 editorLabel
        anchors.margins:    _margin
        anchors.left:       parent.left
        anchors.top:        parent.top
        text:               qsTr("Rally Points")
        color:              outerEditorRect._titleColor
        font.weight:        Font.DemiBold
    }

    Rectangle {
        id:                 innerEditorRect
        anchors.margins:    _margin
        anchors.left:       parent.left
        anchors.right:      parent.right
        anchors.top:        editorLabel.bottom
        height:             infoLabel.height + (_margin * 2)
        color:              _lightTheme ? "#f5f5f5" : Qt.rgba(1, 1, 1, 0.08)
        radius:             _radius
        border.width:       1
        border.color:       _lightTheme ? "#e2e2e2" : Qt.rgba(1, 1, 1, 0.22)

        QGCLabel {
            id:                 infoLabel
            anchors.margins:    _margin
            anchors.top:        parent.top
            anchors.left:       parent.left
            anchors.right:      parent.right
            wrapMode:           Text.WordWrap
            font.pointSize:     ScreenTools.smallFontPointSize
            color:              outerEditorRect._bodyColor
            text:               qsTr("Rally Points provide alternate landing points when performing a Return to Launch (RTL).\n\nClick on the map to add Rally Points.")
        }
    }
}
