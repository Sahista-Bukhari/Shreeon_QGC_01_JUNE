import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

RadioButton {
    id:             control
    font.family:    ScreenTools.normalFontFamily
    font.pointSize: ScreenTools.defaultFontPointSize

    readonly property bool _customMissionLightPanel: typeof mainWindow !== "undefined"
                                                     && mainWindow.customMissionStyleActive

    property color  textColor:  _customMissionLightPanel ? "#3f3f3f" : qgcPal.text
    property bool   _noText:    text === ""

    spacing: ScreenTools.defaultFontPixelWidth * 0.25

    QGCPalette { id:qgcPal; colorGroupEnabled: enabled }

    background: Item { implicitWidth: 0; implicitHeight: 0 }

    indicator: Rectangle {
        implicitWidth:          ScreenTools.radioButtonIndicatorSize
        implicitHeight:         width
        color:                  "transparent"
        border.color:           control.checked ? qgcPal.colorGreen
                                : (control._customMissionLightPanel ? "#6a6a6a" : qgcPal.text)
        border.width:           control.checked ? 2 : 1
        radius:                 height / 2
        x:                      control.leftPadding
        y:                      parent.height / 2 - height / 2

        Rectangle {
            anchors.centerIn:   parent
            width:              parent.width * 0.6
            height:             width
            antialiasing:       true
            radius:             height * 0.5
            color:              qgcPal.colorGreen
            visible:            control.checked
        }
    }

    contentItem: Text {
        text:               control.text
        font.family:        control.font.pointSize
        font.pointSize:     control.font.pointSize
        font.bold:          control.font.bold
        color:              control.textColor
        verticalAlignment:  Text.AlignVCenter
        leftPadding:        control.indicator.width + (_noText ? 0 : control.spacing)
    }

}
