import QtQuick

import QGroundControl.Controls

// Vertical battery icon with bottom-up fill and optional charge arrow overlay.
Item {
    id: control

    property real level: -1              // 0..100, -1 = unknown
    property color outlineColor: "#FFFFFF"
    property color fillColor: "#FFFFFF"
    property bool showChargeArrow: true

    readonly property real _fillRatio: level < 0 ? 0 : Math.min(1, Math.max(0, level / 100))
    readonly property real _borderWidth: Math.max(1.5, height * 0.035)
    readonly property real _termH: height * 0.06
    readonly property real _bodyW: width * 0.9
    readonly property real _bodyH: height * 0.8 - _termH
    readonly property real _bodyX: (width - _bodyW) / 2
    readonly property real _bodyY: _termH + height * 0.015
    readonly property real _radius: _bodyW * 0.14
    readonly property real _termW: _bodyW * 0.36

    implicitWidth: height * 0.46

    Rectangle {
        x: control._bodyX + (control._bodyW - control._termW) / 2
        y: 0
        width: control._termW
        height: control._termH
        radius: control._termH * 0.22
        color: control.outlineColor
    }

    Rectangle {
        x: control._bodyX
        y: control._bodyY
        width: control._bodyW
        height: control._bodyH
        radius: control._radius
        color: "transparent"
        border.width: control._borderWidth
        border.color: control.outlineColor
    }

    Item {
        id: fillClip
        x: control._bodyX + control._borderWidth
        y: control._bodyY + control._borderWidth
        width: control._bodyW - control._borderWidth * 2
        height: control._bodyH - control._borderWidth * 2
        clip: true

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: parent.height * control._fillRatio
            radius: control._radius * 0.55
            color: control.fillColor
        }
    }

    Canvas {
        id: chargeArrow
        visible: control.showChargeArrow
        x: control._bodyX + control._bodyW * 0.42
        y: control._bodyY + control._bodyH * 0.38
        width: control._bodyW * 0.62
        height: control._bodyH * 0.58
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = control.fillColor
            ctx.strokeStyle = control.outlineColor
            ctx.lineWidth = control._borderWidth * 0.85
            ctx.lineJoin = "round"

            var w = width
            var h = height
            ctx.beginPath()
            ctx.moveTo(w * 0.52, h * 0.02)
            ctx.lineTo(w * 0.98, h * 0.52)
            ctx.quadraticCurveTo(w * 0.72, h * 0.92, w * 0.5, h * 0.82)
            ctx.quadraticCurveTo(w * 0.28, h * 0.92, w * 0.02, h * 0.52)
            ctx.closePath()
            ctx.fill()
            ctx.stroke()
        }

        Connections {
            target: control
            function onFillColorChanged() { chargeArrow.requestPaint() }
            function onOutlineColorChanged() { chargeArrow.requestPaint() }
            function onLevelChanged() { chargeArrow.requestPaint() }
        }

        Component.onCompleted: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }
}
