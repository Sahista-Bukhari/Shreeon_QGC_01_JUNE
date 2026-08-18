import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

GroupBox {
    id: control

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    readonly property bool  _darkTheme:  qgcPal.globalTheme === QGCPalette.Dark
    readonly property color _titleColor: _darkTheme ? "#AEAEB2" : "#3A3A3C"
    readonly property color _cardFill:   _darkTheme ? qgcPal.windowShade : "#FFFFFF"
    readonly property color _cardBorder: _darkTheme ? qgcPal.windowShade : "#E6E6E6"

    background: Rectangle {
        y:      control.topPadding - control.padding
        width:  parent.width
        height: parent.height - control.topPadding + control.padding
        color:  control._cardFill
        radius: ScreenTools.defaultFontPixelWidth * 0.75
        border.width: 1
        border.color: control._cardBorder
    }

    label: QGCLabel {
        width:          control.availableWidth
        text:           control.title
        font.bold:      true
        font.pointSize: ScreenTools.defaultFontPointSize + 1
        font.family:    ScreenTools.normalFontFamily
        color:          control._titleColor
    }
}
