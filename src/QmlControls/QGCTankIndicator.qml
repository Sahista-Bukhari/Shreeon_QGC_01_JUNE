import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import QGroundControl
import QGroundControl.Controls

Item {
    id:         control
    implicitWidth:  ScreenTools.defaultFontPixelWidth * 8
    implicitHeight: ScreenTools.defaultFontPixelHeight * 18

    property real value:        16.0
    property real maxCapacity:   20.0
    property real percentage:    (value / maxCapacity) * 100

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    // External Frame (Glass Background)
    Rectangle {
        id:             tankFrame
        anchors.fill:   parent
        radius:         ScreenTools.defaultBorderRadius
        color:          Qt.rgba(0.1, 0.1, 0.1, 0.6)
        border.color:   Qt.rgba(1, 1, 1, 0.15)
        border.width:   1
        clip:           true

        // Internal Liquid Container
        Rectangle {
            id:             liquidContainer
            anchors.fill:   parent
            anchors.margins: 4
            radius:         parent.radius - 2
            color:          "transparent"
            clip:           true

            // The Liquid Fill
            Rectangle {
                id:             liquidFill
                anchors.left:   parent.left
                anchors.right:  parent.right
                anchors.bottom: parent.bottom
                height:         parent.height * (control.value / control.maxCapacity)
                color:          "#3498db" // Base Water Blue
                z:              1

                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#5dade2" }
                    GradientStop { position: 1.0; color: "#2e86c1" }
                }
            }

            // Animated Wave 1
            Canvas {
                id: wave1
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: liquidFill.top
                anchors.bottomMargin: -5
                height: 20
                z: 2
                property real offset: 0

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = "#5dade2";
                    ctx.beginPath();
                    ctx.moveTo(0, height);
                    for (var x = 0; x <= width; x++) {
                        var y = Math.sin((x / width) * 2 * Math.PI + offset) * 5 + 10;
                        ctx.lineTo(x, y);
                    }
                    ctx.lineTo(width, height);
                    ctx.closePath();
                    ctx.fill();
                }

                NumberAnimation on offset {
                    from: 0; to: 2 * Math.PI
                    duration: 2000
                    loops: Animation.Infinite
                    running: true
                }

                onOffsetChanged: requestPaint()
            }

            // Animated Wave 2 (Slower, different phase)
            Canvas {
                id: wave2
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: liquidFill.top
                anchors.bottomMargin: -3
                height: 15
                z: 1
                opacity: 0.5
                property real offset: Math.PI

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = "#3498db";
                    ctx.beginPath();
                    ctx.moveTo(0, height);
                    for (var x = 0; x <= width; x++) {
                        var y = Math.cos((x / width) * 2 * Math.PI + offset) * 7 + 8;
                        ctx.lineTo(x, y);
                    }
                    ctx.lineTo(width, height);
                    ctx.closePath();
                    ctx.fill();
                }

                NumberAnimation on offset {
                    from: 0; to: 2 * Math.PI
                    duration: 3500
                    loops: Animation.Infinite
                    running: true
                }

                onOffsetChanged: requestPaint()
            }
        }

        // Overlay Gloss/Reflection
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.05) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.0) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.05) }
            }
            z: 10
        }
    }

    // Capacity Text Overlays
    Column {
        anchors.centerIn: parent
        spacing: 2
        z: 20

        QGCLabel {
            text:       "TANK"
            font.pointSize: ScreenTools.smallFontPointSize
            font.bold:  true
            anchors.horizontalCenter: parent.horizontalCenter
            color:      "white"
        }

        QGCLabel {
            text:       Math.round(control.value) + " L"
            font.pointSize: ScreenTools.mediumFontPointSize
            font.bold:  true
            anchors.horizontalCenter: parent.horizontalCenter
            color:      "white"
        }

        QGCLabel {
            text:       Math.round(control.percentage) + "%"
            font.pointSize: ScreenTools.smallFontPointSize
            anchors.horizontalCenter: parent.horizontalCenter
            color:      Qt.rgba(1,1,1,0.8)
        }
    }

    // Top indicator for Max
    QGCLabel {
        text:       control.maxCapacity + "L"
        anchors.top: parent.top
        anchors.topMargin: 5
        anchors.right: parent.right
        anchors.rightMargin: 10
        font.pointSize: ScreenTools.smallFontPointSize * 0.8
        color:      Qt.rgba(1,1,1,0.4)
        z: 20
    }
}
