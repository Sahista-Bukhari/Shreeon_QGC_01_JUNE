import QtQuick

import QGroundControl
import QGroundControl.Controls

/// Stick graphic (white / gray / green).
/// stickX, stickY in [-1, 1]: X right positive, Y up positive.
Item {
    id: radial

    property string joystickTitle: qsTr("Joystick 1")
    property real   stickX: 0
    property real   stickY: 0
    property bool   darkTheme: false
    property color  accentGreen: "#00a04c"
    property color  titleColor: "#3A3A3C"

    readonly property color _white:     "#FFFFFF"
    readonly property color _graySoft:  darkTheme ? "#4A4A4C" : "#E8E8E8"
    readonly property color _grayLight: darkTheme ? "#5C5C5E" : "#D8D8D8"
    readonly property color _grayMid:   darkTheme ? "#3A3A3C" : "#C4C4C4"
    readonly property color _grayDark:  darkTheme ? "#2C2C2E" : "#8E8E93"
    readonly property color _grayText:  darkTheme ? "#C7C7CC" : "#6A6A6A"
    readonly property color _panel:     darkTheme ? "#2C2C2E" : "#F0F0F0"
    readonly property color _well:      darkTheme ? "#1C1C1E" : "#BDBDBD"

    readonly property real _clampedX: Math.max(-1, Math.min(1, stickX))
    readonly property real _clampedY: Math.max(-1, Math.min(1, stickY))
    readonly property real _magnitude: Math.sqrt(_clampedX * _clampedX + _clampedY * _clampedY)
    readonly property bool _moved: _magnitude >= 0.18
    readonly property int directionIndex: {
        if (!_moved)
            return -1
        var deg = Math.atan2(_clampedX, _clampedY) * 180 / Math.PI
        if (deg < 0)
            deg += 360
        return Math.round(deg / 45) % 8
    }
    readonly property var _cardinals: [
        { t: qsTr("N"), deg: -90, idx: 0 },
        { t: qsTr("E"), deg: 0,   idx: 2 },
        { t: qsTr("S"), deg: 90,  idx: 4 },
        { t: qsTr("W"), deg: 180, idx: 6 }
    ]

    // Tip travel inside the well
    readonly property real _travel: width * 0.22
    readonly property real _tipX: width / 2 + _travel * _clampedX
    readonly property real _tipY: height / 2 - _travel * _clampedY

    width:  ScreenTools.defaultFontPixelHeight * 9.2
    height: width

    onDirectionIndexChanged: faceCanvas.requestPaint()
    onDarkThemeChanged: faceCanvas.requestPaint()
    onWidthChanged: faceCanvas.requestPaint()
    on_TipXChanged: stemCanvas.requestPaint()
    on_TipYChanged: stemCanvas.requestPaint()
    Component.onCompleted: {
        faceCanvas.requestPaint()
        stemCanvas.requestPaint()
    }

    // Concentric base + well
    Canvas {
        id: faceCanvas
        anchors.fill: parent
        antialiasing: true
        contextType: "2d"
        z: 0

        onPaint: {
            var ctx = getContext("2d")
            if (!ctx)
                return
            ctx.clearRect(0, 0, width, height)

            var cx = width / 2
            var cy = height / 2
            var outerR = width / 2 - 1
            var wellR = outerR * 0.55

            // Outer plate
            ctx.beginPath()
            ctx.arc(cx, cy, outerR, 0, Math.PI * 2)
            ctx.fillStyle = radial._panel
            ctx.fill()
            ctx.strokeStyle = radial._grayMid
            ctx.lineWidth = 1.5
            ctx.stroke()

            // Direction ring
            ctx.beginPath()
            ctx.arc(cx, cy, outerR * 0.92, 0, Math.PI * 2)
            ctx.arc(cx, cy, wellR + 6, 0, Math.PI * 2, true)
            ctx.closePath()
            ctx.fillStyle = radial._graySoft
            ctx.fill()

            // Active direction highlight
            if (radial.directionIndex >= 0) {
                var slice = Math.PI / 4
                var start0 = -Math.PI / 2 - slice / 2
                var a0 = start0 + radial.directionIndex * slice
                var a1 = a0 + slice
                ctx.beginPath()
                ctx.arc(cx, cy, outerR * 0.92, a0, a1, false)
                ctx.arc(cx, cy, wellR + 6, a1, a0, true)
                ctx.closePath()
                ctx.fillStyle = "#D6F0E0"
                ctx.fill()
            }

            // Tick marks
            for (var i = 0; i < 8; i++) {
                var ang = -Math.PI / 2 + i * Math.PI / 4
                var isCardinal = (i % 2 === 0)
                var r0 = wellR + 8
                var r1 = isCardinal ? outerR * 0.82 : outerR * 0.76
                ctx.beginPath()
                ctx.moveTo(cx + Math.cos(ang) * r0, cy + Math.sin(ang) * r0)
                ctx.lineTo(cx + Math.cos(ang) * r1, cy + Math.sin(ang) * r1)
                ctx.strokeStyle = isCardinal ? radial.accentGreen : radial._grayDark
                ctx.lineWidth = isCardinal ? 1.8 : 1.0
                ctx.stroke()
            }

            // Recessed well rings
            var rings = [
                { s: 1.00, c: radial._grayMid },
                { s: 0.88, c: radial._grayDark },
                { s: 0.74, c: radial._well },
                { s: 0.58, c: radial._graySoft }
            ]
            for (var r = 0; r < rings.length; r++) {
                ctx.beginPath()
                ctx.arc(cx, cy, wellR * rings[r].s, 0, Math.PI * 2)
                ctx.fillStyle = rings[r].c
                ctx.fill()
            }

            // White center floor (under the stick stem)
            ctx.beginPath()
            ctx.arc(cx, cy, wellR * 0.42, 0, Math.PI * 2)
            ctx.fillStyle = radial._white
            ctx.fill()
        }
    }

    // Cardinal dots + labels
    Repeater {
        model: radial._cardinals

        Item {
            width: 1
            height: 1
            z: 1
            property real _ang: modelData.deg * Math.PI / 180
            property real _labelR: radial.width * 0.435
            property real _dotR: radial.width * 0.372
            x: radial.width / 2
            y: radial.height / 2

            Rectangle {
                width:  ScreenTools.defaultFontPixelHeight * 0.26
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

    // Fixed center pivot + connecting stem to the moving knob
    Canvas {
        id: stemCanvas
        anchors.fill: parent
        antialiasing: true
        contextType: "2d"
        z: 2

        onPaint: {
            var ctx = getContext("2d")
            if (!ctx)
                return
            ctx.clearRect(0, 0, width, height)

            var cx = width / 2
            var cy = height / 2
            var tipX = radial._tipX
            var tipY = radial._tipY
            var mag = radial._magnitude

            // Soft contact shadow under tip
            ctx.beginPath()
            ctx.arc(tipX, tipY + height * 0.03, width * 0.09, 0, Math.PI * 2)
            ctx.fillStyle = "#33000000"
            ctx.fill()

            // Rubber boot rings around the fixed center (stretch toward tip)
            for (var i = 0; i < 4; i++) {
                var t = (i + 1) / 5.0
                var bx = cx + (tipX - cx) * t * 0.22
                var by = cy + (tipY - cy) * t * 0.22
                var br = width * (0.14 - i * 0.016)
                ctx.beginPath()
                ctx.arc(bx, by, br, 0, Math.PI * 2)
                ctx.fillStyle = (i % 2 === 0) ? radial._grayDark : radial._grayMid
                ctx.fill()
                ctx.strokeStyle = radial._graySoft
                ctx.lineWidth = 1
                ctx.stroke()
            }

            // Stem shaft from center toward tip (tapers)
            var dx = tipX - cx
            var dy = tipY - cy
            var len = Math.sqrt(dx * dx + dy * dy)
            if (len < 1)
                len = 1
            var nx = -dy / len
            var ny = dx / len
            var baseW = width * 0.12
            var tipW = width * 0.08
            // Shorten stem so it ends under the knob
            var endX = cx + dx * 0.72
            var endY = cy + dy * 0.72

            ctx.beginPath()
            ctx.moveTo(cx + nx * baseW, cy + ny * baseW)
            ctx.lineTo(endX + nx * tipW, endY + ny * tipW)
            ctx.lineTo(endX - nx * tipW, endY - ny * tipW)
            ctx.lineTo(cx - nx * baseW, cy - ny * baseW)
            ctx.closePath()
            ctx.fillStyle = radial._white
            ctx.fill()
            ctx.strokeStyle = radial._grayMid
            ctx.lineWidth = 1.5
            ctx.stroke()

            // Soft gray sides for thickness / roundness
            ctx.beginPath()
            ctx.moveTo(cx + nx * baseW, cy + ny * baseW)
            ctx.lineTo(endX + nx * tipW, endY + ny * tipW)
            ctx.lineTo(endX + nx * tipW * 0.45, endY + ny * tipW * 0.45)
            ctx.lineTo(cx + nx * baseW * 0.45, cy + ny * baseW * 0.45)
            ctx.closePath()
            ctx.fillStyle = radial._graySoft
            ctx.fill()

            // Fixed center pivot disc (always visible)
            ctx.beginPath()
            ctx.arc(cx, cy, width * 0.09, 0, Math.PI * 2)
            ctx.fillStyle = radial._grayDark
            ctx.fill()
            ctx.beginPath()
            ctx.arc(cx, cy, width * 0.06, 0, Math.PI * 2)
            ctx.fillStyle = radial._white
            ctx.fill()
            ctx.beginPath()
            ctx.arc(cx, cy, width * 0.028, 0, Math.PI * 2)
            ctx.fillStyle = radial.accentGreen
            ctx.fill()
        }
    }

    // Moving knob (green / white / gray) — sits on the stem tip
    Item {
        id: knob
        z: 3
        width:  radial.width * 0.28
        height: width
        x: radial._tipX - width / 2
        y: radial._tipY - height / 2

        Behavior on x { NumberAnimation { duration: 70; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 70; easing.type: Easing.OutCubic } }

        onXChanged: stemCanvas.requestPaint()
        onYChanged: stemCanvas.requestPaint()

        Rectangle {
            anchors.centerIn: parent
            width:  parent.width
            height: width
            radius: width / 2
            color:  radial._grayMid
            border.width: 1
            border.color: radial._grayDark
        }
        Rectangle {
            anchors.centerIn: parent
            width:  parent.width * 0.72
            height: width
            radius: width / 2
            color:  radial._white
        }
        Rectangle {
            anchors.centerIn: parent
            width:  parent.width * 0.38
            height: width
            radius: width / 2
            color:  radial.accentGreen
        }
    }
}
