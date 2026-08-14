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

    readonly property bool _customMission: typeof mainWindow !== "undefined"
                                           && mainWindow
                                           && mainWindow.activeMissionEditor === "customMission"
    readonly property color _cmAccent: "#00a651"
    readonly property color _cmHoverGray: "#e8e8e8"
    readonly property color _cmBorder: "#e2e2e2"
    readonly property color _cmBody:   "#6a6a6a"

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    background: Rectangle {
        id: backRect
        implicitWidth: ScreenTools.implicitButtonWidth
        implicitHeight: ScreenTools.implicitButtonHeight
        radius: height / 2
        antialiasing: true

        color: {
            if (control._customMission) {
                if (checked)
                    return control._cmAccent
                if (control.hovered)
                    return control._cmHoverGray
                return "#ffffff"
            }
            if (qgcPal.globalTheme === QGCPalette.Light) {
                if (checked)
                    return qgcPal.colorGreen
                if (control.hovered)
                    return "#F2F2F2"
                return "#FFFFFF"
            }
            return checked ? Qt.rgba(0.14, 0.69, 0.36, 0.48)
                           : (control.hovered ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06))
        }
        border.width: control._customMission || qgcPal.globalTheme === QGCPalette.Light ? 1 : (checked ? 1 : 0)
        border.color: {
            if (control._customMission)
                return checked ? control._cmAccent : control._cmBorder
            if (qgcPal.globalTheme === QGCPalette.Light)
                return checked ? qgcPal.colorGreen : "#E6E6E6"
            return Qt.rgba(1, 1, 1, 0.35)
        }

        Behavior on color { ColorAnimation { duration: 150 } }

        RippleEffect {
            id: tabRipple
            rippleColor: control._customMission
                         ? (checked ? Qt.rgba(1, 1, 1, 0.40) : Qt.rgba(0, 0, 0, 0.12))
                         : Qt.rgba(1, 1, 1, 0.42)
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
            color: text.color
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
            color: {
                if (control._customMission)
                    return checked ? "#ffffff" : control._cmBody
                if (qgcPal.globalTheme === QGCPalette.Light)
                    return checked ? "#ffffff" : "#3A3A3C"
                return "#ffffff"
            }
            visible: !_showIcon
        }
    }
}
