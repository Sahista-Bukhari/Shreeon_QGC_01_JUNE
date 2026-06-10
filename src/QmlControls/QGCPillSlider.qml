import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import QGroundControl
import QGroundControl.Controls

Item {
    id:             control
    implicitWidth:  400
    implicitHeight: 70

    property string text:           "Slide to Confirm"
    property real   progress:       0
    property bool   isCompleted:    false
    property color  accentColor:    "#26ad5f"

    signal accepted()

    function reset() {
        handle.x = handle._minX
        control.progress = 0
        control.isCompleted = false
        snapBackAnimation.stop()
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    Rectangle {
        id:             background
        anchors.fill:   parent
        radius:         height / 2
        color:          qgcPal.globalTheme === QGCPalette.Light ? Qt.rgba(0.15, 0.15, 0.15, 0.75) : Qt.rgba(0, 0, 0, 0.7)
        border.color:   Qt.rgba(1, 1, 1, 0.15)
        border.width:   1
        clip:           true

        // Progress Fill (Professional Gradient)
        Rectangle {
            id:         progressFill
            height:     parent.height
            width:      control.isCompleted ? parent.width : (handle.x + handle.width / 2)
            radius:     parent.radius
            visible:    progress > 0
            z:          1

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(0.15, 0.68, 0.37, 0.9) } // Richer success green
                GradientStop { position: 1.0; color: control.accentColor }
            }

            // Glass/Shine Effect on fill
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.1) }
                    GradientStop { position: 0.5; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.1) }
                }
            }
        }

        // Animated Arrows (Increased density for better guidance)
        Row {
            anchors.centerIn: parent
            spacing: 12
            opacity: 1.0 - control.progress * 1.5
            visible: opacity > 0
            z:       2

            Repeater {
                model: 10
                QGCColoredImage {
                    source:     "/res/chevron-double-right.svg"
                    height:     background.height * 0.4
                    width:      height
                    color:      "white"
                    opacity:    Math.max(0.05, (index / 10) * 0.5)

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.1; to: 0.4; duration: 1500; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.4; to: 0.1; duration: 1500; easing.type: Easing.InOutSine }
                    }
                }
            }
        }

        // Text with High Impact Visibility
        Item {
            anchors.centerIn: parent
            width:          labelText.width
            height:         labelText.height
            z:              10 // Ensure it's above the handle if they overlap, or at least above fill

            DropShadow {
                anchors.fill: labelText
                horizontalOffset: 0
                verticalOffset: 2
                radius: 6.0
                samples: 12
                color: "#ff000000" // Solid black shadow
                source: labelText
            }

            QGCLabel {
                id:             labelText
                text:           control.text
                font.bold:      true
                font.pointSize: ScreenTools.largeFontPointSize // Slightly larger
                color:          "white"
                opacity:        1.0
            }
        }

        // Handle (Premium Glossy Design)
        Rectangle {
            id:         handle
            x:          _minX
            anchors.verticalCenter: parent.verticalCenter
            height:     parent.height - 10
            width:      height
            radius:     height / 2
            color:      "white"
            z:          15

            property real _minX: 5
            property real _maxX: parent.width - width - 5

            // Elevation Glow
            RectangularGlow {
                anchors.fill: parent
                glowRadius: 10
                spread: 0.2
                color: Qt.rgba(1, 1, 1, 0.4)
                cornerRadius: parent.radius
            }

            // Pulse Animation
            SequentialAnimation on scale {
                running: control.progress < 0.05 && !dragArea.pressed
                loops:   Animation.Infinite
                NumberAnimation { from: 1.0; to: 1.05; duration: 1000; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 1.05; to: 1.0; duration: 1000; easing.type: Easing.InOutQuad }
            }

            QGCColoredImage {
                anchors.centerIn: parent
                source: "/res/chevron-double-right.svg"
                height: parent.height * 0.5
                width:  height
                color:  control.accentColor
            }

            MouseArea {
                id:             dragArea
                anchors.fill:   parent
                drag.target:    handle
                drag.axis:      Drag.XAxis
                drag.minimumX:  handle._minX
                drag.maximumX:  handle._maxX

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
                duration:       500
                easing.type:    Easing.OutElastic
                onFinished:     control.progress = 0
            }
        }
    }
}
