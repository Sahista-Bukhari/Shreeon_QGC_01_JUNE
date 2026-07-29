import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Item {
    id:             control
    implicitWidth:  400
    implicitHeight: 70

    property string text:           "Slide to Confirm"
    property real   progress:       0
    property bool   isCompleted:    false
    property color  accentColor:    "#7CFF00"

    signal accepted()

    function reset() {
        handle.x = handle._minX
        control.progress = 0
        control.isCompleted = false
        snapBackAnimation.stop()
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    // Match FlyViewBottomBar telemetry glass colors
    readonly property color _glassFill:   Qt.rgba(0.12, 0.12, 0.14, 0.15)
    readonly property color _glassBorder: Qt.rgba(1.00, 1.00, 1.00, 0.28)

    Rectangle {
        id:             background
        anchors.fill:   parent
        radius:         height / 2
        color:          control._glassFill
        border.color:   control._glassBorder
        border.width:   1
        clip:           true

        // Progress fill — arrow green as the handle slides
        Rectangle {
            id:         progressFill
            height:     parent.height
            width:      control.isCompleted ? parent.width : Math.max(0, handle.x + handle.width / 2)
            radius:     parent.radius
            visible:    progress > 0.01 || control.isCompleted
            z:          1
            color:      Qt.rgba(control.accentColor.r, control.accentColor.g, control.accentColor.b, 0.45)
        }

        QGCLabel {
            anchors.centerIn: parent
            z:              2
            text:           control.text
            color:          "white"
            font.weight:    Font.Black
            font.family:    "Noto Sans"
            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.72
            opacity:        Math.max(0.35, 1.0 - control.progress * 0.65)
            style:          Text.Outline
            styleColor:     Qt.rgba(0, 0, 0, 0.55)
        }

        Rectangle {
            id:         handle
            x:          _minX
            anchors.verticalCenter: parent.verticalCenter
            height:     parent.height - ScreenTools.defaultFontPixelHeight * 0.35
            width:      height * 1.35
            radius:     height / 2
            z:          3
            color:      "white"
            border.color: "#e0e0e0"
            border.width: 1

            property real _minX: ScreenTools.defaultFontPixelWidth * 0.35
            property real _maxX: parent.width - width - ScreenTools.defaultFontPixelWidth * 0.35

            onXChanged: {
                if (handle._maxX > handle._minX) {
                    control.progress = Math.max(0, Math.min(1,
                        (handle.x - handle._minX) / (handle._maxX - handle._minX)))
                }
            }

            // Soft drop shadow under the handle
            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 2
                z: -1
                radius: parent.radius
                color: Qt.rgba(0, 0, 0, 0.22)
            }

            QGCLabel {
                anchors.centerIn: parent
                text: ">>"
                color: control.accentColor
                font.bold: true
                font.pointSize: ScreenTools.defaultFontPointSize * 1.15
            }

            MouseArea {
                id:             dragArea
                anchors.fill:   parent
                drag.target:    handle
                drag.axis:      Drag.XAxis
                drag.minimumX:  handle._minX
                drag.maximumX:  handle._maxX
                cursorShape:    Qt.PointingHandCursor

                onReleased: {
                    if (handle.x >= handle._maxX - 10) {
                        control.isCompleted = true
                        control.accepted()
                        snapBackAnimation.stop()
                    } else {
                        snapBackAnimation.start()
                    }
                }

                onPositionChanged: {
                    control.progress = (handle.x - handle._minX) / (handle._maxX - handle._minX)
                }
            }

            NumberAnimation on x {
                id:             snapBackAnimation
                to:             handle._minX
                duration:       280
                easing.type:    Easing.OutQuad
                onFinished:     control.progress = 0
            }
        }
    }
}
