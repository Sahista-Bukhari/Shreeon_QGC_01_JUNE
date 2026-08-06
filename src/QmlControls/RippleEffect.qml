import QtQuick

Item {
    id: root
    anchors.fill: parent
    z: 50

    property color rippleColor: Qt.rgba(1, 1, 1, 0.38)
    property int duration: 460
    property real clipRadius: 0

    function tap(px, py) {
        var cx = (px === undefined || px < 0) ? width / 2 : px
        var cy = (py === undefined || py < 0) ? height / 2 : py
        rippleComp.createObject(root, { startX: cx, startY: cy })
    }

    function tapCenter() {
        tap(width / 2, height / 2)
    }

    Component {
        id: rippleComp

        Rectangle {
            id: wave
            property real startX: 0
            property real startY: 0

            width: 8
            height: 8
            radius: width / 2
            color: root.rippleColor
            opacity: 0.55
            x: startX - width / 2
            y: startY - height / 2

            readonly property real maxSize: Math.max(
                Math.hypot(startX, startY),
                Math.hypot(root.width - startX, startY),
                Math.hypot(startX, root.height - startY),
                Math.hypot(root.width - startX, root.height - startY)
            ) * 2.05

            Component.onCompleted: anim.start()

            ParallelAnimation {
                id: anim
                NumberAnimation {
                    target: wave
                    property: "width"
                    to: wave.maxSize
                    duration: root.duration
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: wave
                    property: "height"
                    to: wave.maxSize
                    duration: root.duration
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: wave
                    property: "x"
                    to: wave.startX - wave.maxSize / 2
                    duration: root.duration
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: wave
                    property: "y"
                    to: wave.startY - wave.maxSize / 2
                    duration: root.duration
                    easing.type: Easing.OutCubic
                }
                SequentialAnimation {
                    PauseAnimation { duration: Math.round(root.duration * 0.2) }
                    NumberAnimation {
                        target: wave
                        property: "opacity"
                        to: 0
                        duration: Math.round(root.duration * 0.8)
                        easing.type: Easing.OutQuad
                    }
                }
                onFinished: wave.destroy()
            }
        }
    }
}
