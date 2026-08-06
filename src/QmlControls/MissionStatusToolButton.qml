import QtQuick

import QGroundControl
import QGroundControl.Controls

Item {
    id: root
    implicitWidth: ScreenTools.defaultFontPixelHeight * 1.5
    implicitHeight: implicitWidth

    property bool checked: false
    property bool highlightWhenChecked: true
    property url  iconSource
    property real imageMargins: width * 0.15

    signal clicked()

    Rectangle {
        anchors.fill: parent
        radius: ScreenTools.defaultFontPixelWidth * 0.45
        color: (root.checked && root.highlightWhenChecked)
               ? Qt.rgba(0.14, 0.69, 0.36, 0.28)
               : (buttonMouse.containsMouse ? Qt.rgba(0.12, 0.12, 0.14, 0.22) : Qt.rgba(0.12, 0.12, 0.14, 0.15))
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, (root.checked || buttonMouse.containsMouse) ? 0.36 : 0.28)
    }

    QGCColoredImage {
        anchors.margins: root.imageMargins
        anchors.fill: parent
        source: root.iconSource
        color: "#ffffff"
    }

    RippleEffect {
        id: buttonRipple
        rippleColor: Qt.rgba(1, 1, 1, 0.40)
        clipRadius: ScreenTools.defaultFontPixelWidth * 0.45
    }

    MouseArea {
        id: buttonMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
            buttonRipple.tap(mouse.x, mouse.y)
            root.clicked()
        }
    }
}
