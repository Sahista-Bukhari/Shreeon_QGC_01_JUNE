import QtQuick
import Qt5Compat.GraphicalEffects

import QGroundControl
import QGroundControl.Controls

/*!
    Approximate Apple Liquid Glass:
    optional backdrop blur + translucent tint + specular rim + soft highlight.
    All fills are masked to the rounded outline so hover never becomes a rectangle.
 */
Item {
    id: root

    property Item backgroundSource
    property real blurAmount: 18
    property real cornerRadius: ScreenTools.defaultFontPixelHeight * 0.75
    property color tintColor: Qt.rgba(1, 1, 1, 0.18)
    property color rimColor: Qt.rgba(1, 1, 1, 0.48)
    property color innerGlow: Qt.rgba(1, 1, 1, 0.16)
    property color accentColor: Qt.rgba(0.12, 0.69, 0.36, 0.22)
    property bool round: false
    property bool pressed: false
    property bool showGlint: !round
    property bool enableBlur: backgroundSource != null

    readonly property real _radius: round ? width / 2 : cornerRadius

    function _syncBlurOffset() {
        if (!enableBlur || !backgroundSource || !blurLayer)
            return
        var p = mapToItem(backgroundSource, 0, 0)
        blurLayer.x = -p.x
        blurLayer.y = -p.y
    }

    onXChanged: _syncBlurOffset()
    onYChanged: _syncBlurOffset()
    onWidthChanged: _syncBlurOffset()
    onHeightChanged: _syncBlurOffset()
    Component.onCompleted: Qt.callLater(_syncBlurOffset)

    Timer {
        interval: 80
        running: root.enableBlur
        repeat: false
        onTriggered: root._syncBlurOffset()
    }

    Connections {
        target: backgroundSource
        enabled: root.enableBlur
        ignoreUnknownSignals: true
        function onWidthChanged() { root._syncBlurOffset() }
        function onHeightChanged() { root._syncBlurOffset() }
    }

    Rectangle {
        id: maskRect
        anchors.fill: parent
        radius: root._radius
        visible: false
    }

    Item {
        id: blurClip
        anchors.fill: parent
        visible: false
        enabled: root.enableBlur

        FastBlur {
            id: blurLayer
            width: root.backgroundSource ? root.backgroundSource.width : root.width
            height: root.backgroundSource ? root.backgroundSource.height : root.height
            source: root.enableBlur ? root.backgroundSource : null
            radius: root.blurAmount
            transparentBorder: true
        }
    }

    OpacityMask {
        anchors.fill: parent
        visible: root.enableBlur
        source: blurClip
        maskSource: maskRect
    }

    Item {
        id: fillLayer
        anchors.fill: parent
        visible: false

        Rectangle {
            anchors.fill: parent
            color: root.pressed ? Qt.rgba(1, 1, 1, 0.30) : root.tintColor

            Behavior on color { ColorAnimation { duration: 140 } }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.12) }
                GradientStop { position: 0.42; color: Qt.rgba(1, 1, 1, 0.02) }
                GradientStop { position: 1.0; color: root.accentColor }
            }
        }

        Rectangle {
            id: glint
            width: parent.width * 0.42
            height: parent.height * 0.55
            radius: width
            rotation: -28
            opacity: 0.16
            anchors.verticalCenter: parent.verticalCenter
            x: parent.width * 0.06
            visible: root.showGlint && !root.round

            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0) }
                GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.55) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
            }

            SequentialAnimation on opacity {
                running: glint.visible
                loops: Animation.Infinite
                NumberAnimation { to: 0.08; duration: 2400; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.20; duration: 2400; easing.type: Easing.InOutSine }
            }
        }
    }

    OpacityMask {
        anchors.fill: parent
        source: fillLayer
        maskSource: maskRect
    }

    Rectangle {
        anchors.fill: parent
        radius: root._radius
        color: "transparent"
        border.width: 1.2
        border.color: root.rimColor
        antialiasing: true
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, root._radius - 1)
        color: "transparent"
        border.width: 1
        border.color: root.innerGlow
        visible: root.innerGlow.a > 0.01
        antialiasing: true
    }
}
