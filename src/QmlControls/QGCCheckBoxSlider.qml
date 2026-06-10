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
            visible:        control.text !== ""
        }

        Rectangle {
            id:                     indicator
            anchors.right:          parent.right
            anchors.verticalCenter: parent.verticalCenter
            height:                 ScreenTools.defaultFontPixelHeight * 1.2
            width:                  height * 1.8
            radius:                 height / 2
            color:                  checked ? qgcPal.colorGreen : qgcPal.windowShadeDark
            border.width:           0
            
            // Track background behavior
            Behavior on color { ColorAnimation { duration: 150 } }

            Rectangle {
                id:                     knob
                anchors.verticalCenter: parent.verticalCenter
                x:                      checked ? parent.width - width - 2 : 2
                height:                 parent.height - 4
                width:                  height
                radius:                 height / 2
                color:                  qgcPal.text
                
                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
            }
        }
    }
}
