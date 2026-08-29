import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

AbstractButton   {
    id:         control
    checkable:  true
    padding:    0

    property bool _showBorder:      qgcPal.globalTheme === QGCPalette.Light
    property int  _sliderInset:     2
    property bool _showHighlight:   enabled && (pressed || checked)

    QGCPalette { id: qgcPal; colorGroupEnabled: control.enabled }

    contentItem: Item {
        implicitWidth:  (label.visible ? label.contentWidth + ScreenTools.defaultFontPixelWidth : 0) + indicator.width
        implicitHeight: Math.max(label.contentHeight, indicator.height)

        QGCLabel {
            id:             label
            anchors.left:   parent.left
            anchors.verticalCenter: parent.verticalCenter
            text:           control.text
            color:          (typeof mainWindow !== "undefined" && mainWindow && mainWindow.customMissionStyleActive)
                            ? "#3f3f3f" : qgcPal.text
            visible:        control.text !== ""
        }

        Rectangle {
            id:                     indicator
            anchors.right:          parent.right
            anchors.verticalCenter: parent.verticalCenter
            height:                 ScreenTools.defaultFontPixelHeight * 1.35
            width:                  height * 1.8
            radius:                 height / 2
            color:                  checked ? "#00a651" : "#e8e8e8"
            border.width:           0
            clip:                   true
            
            // Track background behavior
            Behavior on color { ColorAnimation { duration: 150 } }

            Rectangle {
                id:                     knob
                anchors.verticalCenter: parent.verticalCenter
                x:                      checked ? parent.width - width - 2 : 2
                height:                 parent.height - 5
                width:                  height
                radius:                 height / 2
                color:                  "#FFFFFF"
                border.width:           0.5
                border.color:           "#E5E5EA"
                z:                      1
                
                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
            }

            RippleEffect {
                id: sliderRipple
                rippleColor: control.checked
                             ? Qt.rgba(1, 1, 1, 0.45)
                             : Qt.rgba(0, 0, 0, 0.20)
                clipRadius: indicator.radius
                duration:   420
            }

            Connections {
                target: control
                function onPressedChanged() {
                    if (control.pressed) {
                        var px = control.pressX - indicator.x
                        var py = control.pressY - indicator.y
                        if (px < 0 || py < 0 || px > indicator.width || py > indicator.height)
                            sliderRipple.tapCenter()
                        else
                            sliderRipple.tap(px, py)
                    }
                }
            }
        }
    }
}
