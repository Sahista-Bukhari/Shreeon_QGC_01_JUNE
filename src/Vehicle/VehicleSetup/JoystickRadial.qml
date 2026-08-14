import QtQuick

import QGroundControl
import QGroundControl.Controls

Item {
    id: radial

    property string joystickTitle: qsTr("Joystick 1")
    property real   stickX: 0
    property real   stickY: 0
    property bool   darkTheme: false
    property color  accentGreen: "#00a04c"
    property color  titleColor: "#3A3A3C"

    readonly property color _white:      "#FFFFFF"
    readonly property color _grayLight:  darkTheme ? "#5C5C5E" : "#E8E8E8"
    readonly property color _grayMid:    darkTheme ? "#3A3A3C" : "#D0D0D0"
    readonly property color _grayDark:   darkTheme ? "#2C2C2E" : "#8E8E93"
    readonly property color _grayText:   darkTheme ? "#C7C7CC" : "#6A6A6A"
    readonly property color _wellOuter:  darkTheme ? "#3A3A3C" : "#C8C8C8"
    readonly property color _wellInner:  darkTheme ? "#1C1C1E" : "#F7F7F7"

    readonly property real _magnitude: Math.sqrt(stickX * stickX + stickY * stickY)
    readonly property bool _moved: _magnitude >= 0.18
    readonly property int directionIndex: {
        if (!_moved)
            return -1
        var deg = Math.atan2(stickX, stickY) * 180 / Math.PI
        if (deg < 0)
            deg += 360
        return Math.round(deg / 45) % 8
    }
    readonly property var _directionNames: [
        qsTr("North"), qsTr("Northeast"), qsTr("East"), qsTr("Southeast"),
        qsTr("South"), qsTr("Southwest"), qsTr("West"), qsTr("Northwest")
    ]
    readonly property string directionName: directionIndex < 0 ? "" : _directionNames[directionIndex]
    readonly property var _cardinals: [
        { t: qsTr("N"), deg: -90, idx: 0 },
        { t: qsTr("E"), deg: 0,   idx: 2 },
        { t: qsTr("S"), deg: 90,  idx: 4 },
        { t: qsTr("W"), deg: 180, idx: 6 }
    ]

    width: ScreenTools.defaultFontPixelHeight * 9.2
    height: width

    onDirectionIndexChanged: faceCanvas.requestPaint()
    onDarkThemeChanged: faceCanvas.requestPaint()
    onWidthChanged: faceCanvas.requestPaint()
    Component.onCompleted: faceCanvas.requestPaint()

    Canvas {
        id: faceCanvas
        anchors.fill: parent
        antialiasing: true
        contextType: "2d"

        onPaint: {
            var ctx = getContext("2d")
            if (!ctx)
                return
            ctx.clearRect(0, 0, width, height)

            var cx = width / 2
            var cy = height / 2
            var outerR = width / 2 - 1
            var ringInner = outerR * 0.62
            var wellR = outerR * 0.56

            // Direction ring
            ctx.beginPath()
            ctx.arc(cx, cy, outerR, 0, Math.PI * 2)
            ctx.fillStyle = radial._grayLight
            ctx.fill()

            ctx.beginPath()
            ctx.arc(cx, cy, ringInner, 0, Math.PI * 2)
            ctx.fillStyle = radial._grayMid
            ctx.fill()

            // Active cardinal highlight
            if (radial.directionIndex >= 0 && radial.directionIndex % 2 === 0) {
                var slice = Math.PI / 4
                var start0 = -Math.PI / 2 - slice / 2
                var a0 = start0 + radial.directionIndex * slice
                var a1 = a0 + slice
                ctx.beginPath()
                ctx.arc(cx, cy, outerR - 1, a0, a1, false)
                ctx.arc(cx, cy, ringInner + 1, a1, a0, true)
                ctx.closePath()
                ctx.fillStyle = "#D8F3E3"
                ctx.fill()
            }

            // Radial ticks toward N/E/S/W and diagonals
            for (var i = 0; i < 8; i++) {
                var ang = -Math.PI / 2 + i * Math.PI / 4
                var isCardinal = (i % 2 === 0)
                var r0 = wellR + 2
                var r1 = isCardinal ? outerR * 0.78 : outerR * 0.70
                ctx.beginPath()
                ctx.moveTo(cx + Math.cos(ang) * r0, cy + Math.sin(ang) * r0)
                ctx.lineTo(cx + Math.cos(ang) * r1, cy + Math.sin(ang) * r1)
                ctx.strokeStyle = isCardinal ? radial.accentGreen : radial._grayDark
                ctx.lineWidth = isCardinal ? 1.6 : 1
                ctx.stroke()
            }

            // Recessed well — concentric gray rings
            var rings = [1.00, 0.88, 0.76, 0.64]
            var ringColors = [radial._wellOuter, radial._grayDark, radial._grayMid, radial._wellInner]
            for (var r = 0; r < rings.length; r++) {
                ctx.beginPath()
                ctx.arc(cx, cy, wellR * rings[r], 0, Math.PI * 2)
                ctx.fillStyle = ringColors[r]
                ctx.fill()
            }

            ctx.beginPath()
            ctx.arc(cx, cy, wellR * 0.52, 0, Math.PI * 2)
            ctx.fillStyle = radial._white
            ctx.fill()
            ctx.strokeStyle = radial._grayMid
            ctx.lineWidth = 1
            ctx.stroke()
        }
    }

    Repeater {
        model: radial._cardinals

        Item {
            width: 1
            height: 1
            property real _ang: modelData.deg * Math.PI / 180
            property real _labelR: radial.width * 0.42
            property real _dotR: radial.width * 0.355
            x: radial.width / 2
            y: radial.height / 2

            Rectangle {
                width:  ScreenTools.defaultFontPixelHeight * 0.28
                height: width
                radius: width / 2
                color:  radial.directionIndex === modelData.idx ? radial.accentGreen : radial._white
                border.width: 1
                border.color: radial.directionIndex === modelData.idx ? radial.accentGreen : radial._grayDark
                x: Math.cos(_ang) * _dotR - width / 2
                y: Math.sin(_ang) * _dotR - height / 2
            }

            QGCLabel {
                text: modelData.t
                font.pointSize: ScreenTools.smallFontPointSize
                font.bold: true
                font.family: ScreenTools.normalFontFamily
                color: radial.directionIndex === modelData.idx ? radial.accentGreen : radial._grayText
                x: Math.cos(_ang) * _labelR - width / 2
                y: Math.sin(_ang) * _labelR - height / 2
            }
        }
    }

    // Physical-style stick: boot rings + green cap, moves like native QGC
    Item {
        id: stick
        width:  radial.width * 0.34
        height: width
        z:      2
        property real _travel: radial.width * 0.16
        property real _clampedX: Math.max(-1, Math.min(1, radial.stickX))
        property real _clampedY: Math.max(-1, Math.min(1, radial.stickY))
        x: radial.width  / 2 + _travel * _clampedX - width  / 2
        y: radial.height / 2 - _travel * _clampedY - height / 2

        Rectangle {
            anchors.centerIn: parent
            width:  parent.width
            height: width
            radius: width / 2
            color:  radial._grayMid
        }
        Rectangle {
            anchors.centerIn: parent
            width:  parent.width * 0.78
            height: width
            radius: width / 2
            color:  radial._grayLight
        }
        Rectangle {
            anchors.centerIn: parent
            width:  parent.width * 0.58
            height: width
            radius: width / 2
            color:  radial._grayDark
        }
        Rectangle {
            anchors.centerIn: parent
            width:  parent.width * 0.42
            height: width
            radius: width / 2
            color:  radial._white
            border.width: 1
            border.color: radial._grayMid
        }
        Rectangle {
            anchors.centerIn: parent
            width:  parent.width * 0.28
            height: width
            radius: width / 2
            color:  radial.accentGreen
        }
    }
}
