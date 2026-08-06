import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// We implement our own TabButton to get around the fact that QtQuick.Controls TabBar does not
// support hiding tabs. This version supports hiding tabs by setting the visible property
// on the QGCTabButton instances.
Button {
    id: control
    Layout.fillWidth: true
    topPadding: _verticalPadding
    bottomPadding: _verticalPadding
    leftPadding: _horizontalPadding
    rightPadding: _horizontalPadding
    focusPolicy: Qt.ClickFocus
    checkable: true
    flat: true
    hoverEnabled: !ScreenTools.isMobile

    property bool primary: false ///< primary button for a group of buttons
    property real pointSize: ScreenTools.defaultFontPointSize ///< Point size for button text
    property bool showBorder: qgcPal.globalTheme === QGCPalette.Light
    property real backRadius: ScreenTools.defaultBorderRadius
    property real heightFactor: 0.5

    property bool _showHighlight: enabled && (pressed | checked)
    property int _horizontalPadding: ScreenTools.defaultFontPixelWidth
    property int _verticalPadding: Math.round(ScreenTools.defaultFontPixelHeight * heightFactor)
    property bool _showIcon: control.icon.source != ""

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    background: Rectangle {
        id: backRect
        implicitWidth: ScreenTools.implicitButtonWidth
        implicitHeight: ScreenTools.implicitButtonHeight
        radius: height / 2
        color: checked ? Qt.rgba(0.14, 0.69, 0.36, 0.48) : (control.hovered ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06))
        border.width: checked ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, 0.35)
        antialiasing: true

        Behavior on color { ColorAnimation { duration: 150 } }

        RippleEffect {
            id: tabRipple
            rippleColor: Qt.rgba(1, 1, 1, 0.42)
            clipRadius: backRect.radius
        }

        Connections {
            target: control
            function onPressedChanged() {
                if (control.pressed)
                    tabRipple.tap(control.pressX, control.pressY)
            }
        }
    }

    contentItem: Item {
        implicitWidth: _showIcon ? icon.width : text.implicitWidth
        implicitHeight: _showIcon ? icon.height : text.implicitHeight
        baselineOffset: text.y + text.baselineOffset

        QGCColoredImage {
            id: icon
            anchors.centerIn: parent
            source: control.icon.source
            height: source === "" ? 0 : ScreenTools.defaultFontPixelHeight
            width: height
            color: "#ffffff"
            fillMode: Image.PreserveAspectFit
            sourceSize.height: height
            visible: _showIcon
        }

        Text {
            id: text
            anchors.centerIn: parent
            antialiasing: true
            text: control.text
            font.pointSize: control.pointSize
            font.family: ScreenTools.normalFontFamily
            color: "#ffffff"
            visible: !_showIcon
        }
    }
}
