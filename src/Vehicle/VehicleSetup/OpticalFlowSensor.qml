import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls

Item {
    readonly property real  _pageHPad:          ScreenTools.defaultFontPixelWidth * 2.2
    readonly property real  _titlePointSize:    ScreenTools.defaultFontPointSize + 1
    readonly property color _titleColor:        qgcPal.globalTheme === QGCPalette.Dark ? "#AEAEB2" : "#3A3A3C"

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    QGCLabel {
        x:              _pageHPad
        y:              ScreenTools.defaultFontPixelHeight * 0.15
        text:           qsTr("Optical Flow Camera")
        color:          _titleColor
        font.bold:      true
        font.pointSize: _titlePointSize
        font.family:    ScreenTools.normalFontFamily
    }

    Image {
        source:     globals.activeVehicle ? "image://QGCImages/" + globals.activeVehicle.id + "/" + globals.activeVehicle.flowImageIndex : ""
        width:      parent.width * 0.5
        height:     width * 0.75
        cache:      false
        fillMode:   Image.PreserveAspectFit
        anchors.centerIn: parent
    }
}
