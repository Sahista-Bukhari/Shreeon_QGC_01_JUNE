import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

CheckBox {
    id:             control
    spacing:        _noText ? 0 : ScreenTools.defaultFontPixelWidth
    focusPolicy:    Qt.ClickFocus
    leftPadding:    0

    Component.onCompleted: {
        if (_noText) {
            rightPadding = 0
        }
    }

    property color  textColor:              qgcPal.buttonText
    property color  uncheckedBorderColor:   _customMission ? "#00a651" : qgcPal.text
    property bool   textBold:               false
    property real   textFontPointSize:      ScreenTools.defaultFontPointSize
    property ButtonGroup buttonGroup: null

    property bool _noText: text === ""
    readonly property bool _customMission: typeof mainWindow !== "undefined"
                                           && mainWindow
                                           && mainWindow.activeMissionEditor === "customMission"
    readonly property color _accentGreen: "#00a651"

    QGCPalette { id: qgcPal; colorGroupEnabled: control.enabled }

    background: Item { implicitWidth: 0; implicitHeight: 0 }

    onButtonGroupChanged: {
        if (buttonGroup) {
            buttonGroup.addButton(control)
        }
    }

    contentItem: Text {
        leftPadding:        control.indicator.width + control.spacing
        verticalAlignment:  Text.AlignVCenter
        text:               control.text
        font.pointSize:     textFontPointSize
        font.bold:          control.textBold
        font.family:        ScreenTools.normalFontFamily
        color:              control._customMission ? "#3f3f3f" : control.textColor
    }

    indicator:  Rectangle {
        implicitWidth:  ScreenTools.implicitCheckBoxHeight
        implicitHeight: implicitWidth
        x:              control.leftPadding
        y:              parent.height / 2 - height / 2
        color:          control.checked ? control._accentGreen : "transparent"
        border.color:   control.checked ? control._accentGreen : control.uncheckedBorderColor
        border.width:   control.checked ? 0 : 2
        radius:         ScreenTools.defaultBorderRadius / 2
        opacity:        control.checkedState === Qt.PartiallyChecked ? 0.5 : 1

        QGCColoredImage {
            source:             "/qmlimages/checkbox-check.svg"
            color:              "white"
            mipmap:             true
            fillMode:           Image.PreserveAspectFit
            width:              parent.implicitWidth * 0.8
            height:             width
            sourceSize.height:  height
            visible:            control.checked
            anchors.centerIn:   parent
        }
    }
}
