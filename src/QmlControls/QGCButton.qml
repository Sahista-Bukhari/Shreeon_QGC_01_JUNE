import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

/// Standard push button control:
///     If there is both an icon and text the icon will be to the left of the text
///     If icon only, icon will be centered
Button {
    property bool primary: false
    property bool showBorder: false
    property bool compact: false
    property real backRadius: height / 2
    property real heightFactor: 0.5
    property string iconSource: ""
    property real fontWeight: Font.Normal
    property real pointSize: ScreenTools.defaultFontPointSize

    property alias wrapMode: text.wrapMode
    property alias horizontalAlignment: text.horizontalAlignment
    property color backgroundColor: primary ? qgcPal.primaryButton : qgcPal.button
    property alias textColor: text.color

    id: control
    hoverEnabled: !ScreenTools.isMobile
    topPadding: _verticalPadding
    bottomPadding: _verticalPadding
    leftPadding: _horizontalPadding
    rightPadding: _horizontalPadding
    focusPolicy: Qt.ClickFocus
    font.family: ScreenTools.normalFontFamily
    text: ""

    property bool _showHighlight: enabled && (pressed | checked)
    property int _horizontalPadding: ScreenTools.defaultFontPixelWidth * (compact ? 1.55 : 2)
    property int _verticalPadding: Math.round(ScreenTools.defaultFontPixelHeight * heightFactor) - (iconSource === "" ? 0 : Math.max(0, (_iconHeight - ScreenTools.defaultFontPixelHeight) / 2))
    property real _iconHeight: text.height * (compact ? 1.35 : 1.5)

    // Custom Mission uses Route Mapping white/green cards
    readonly property bool _customMission: typeof mainWindow !== "undefined"
                                           && mainWindow
                                           && mainWindow.activeMissionEditor === "customMission"
    readonly property color _cmAccent: "#00a651"
    readonly property color _cmHoverGray: "#e8e8e8"
    readonly property color _cmBorder: "#e2e2e2"
    readonly property color _cmTitle: "#3f3f3f"

    QGCPalette { id: qgcPal; colorGroupEnabled: control.enabled }

    background: Item {
        id: backRect
        implicitWidth: ScreenTools.implicitButtonWidth
        implicitHeight: ScreenTools.implicitButtonHeight

        // Default solid style (Application Settings, Fly View, etc.)
        Rectangle {
            anchors.fill: parent
            visible: !control._customMission
            radius: control.backRadius
            border.width: control.showBorder ? 1 : 0
            border.color: qgcPal.buttonBorder
            color: control.primary
                   ? qgcPal.primaryButton
                   : (control.pressed ? qgcPal.buttonHighlight : control.backgroundColor)

            Rectangle {
                anchors.fill: parent
                color: qgcPal.buttonHighlight
                opacity: control._showHighlight ? 1 : (control.enabled && control.hovered ? 0.1 : 0)
                radius: parent.radius
                visible: !control.primary
            }
        }

        // Custom Mission — green idle, gray hover (Application Settings style)
        Rectangle {
            anchors.fill: parent
            visible: control._customMission
            radius: control.backRadius
            color: {
                if (control.pressed || control.checked)
                    return Qt.darker(control._cmAccent, 1.12)
                if (control.enabled && control.hovered)
                    return control._cmHoverGray
                return control._cmAccent
            }
            border.width: 0

            Behavior on color { ColorAnimation { duration: 120 } }
        }

        RippleEffect {
            id: buttonRipple
            rippleColor: {
                if (!control._customMission)
                    return Qt.rgba(0, 0, 0, 0.18)
                if (control.enabled && control.hovered && !(control.pressed || control.checked))
                    return Qt.rgba(0, 0, 0, 0.12)
                return Qt.rgba(1, 1, 1, 0.40)
            }
            clipRadius: control.backRadius
        }

        Connections {
            target: control
            function onPressedChanged() {
                if (control.pressed)
                    buttonRipple.tap(control.pressX, control.pressY)
            }
        }
    }

    contentItem: RowLayout {
        spacing: ScreenTools.defaultFontPixelWidth

        QGCColoredImage {
            id: icon
            Layout.alignment: Qt.AlignHCenter
            source: control.iconSource
            height: _iconHeight
            width: height
            color: text.color
            fillMode: Image.PreserveAspectFit
            sourceSize.height: height
            visible: control.iconSource !== ""
        }

        QGCLabel {
            id: text
            Layout.alignment: Qt.AlignHCenter
            text: control.text
            font.pointSize: control.pointSize
            font.family: control.font.family
            font.weight: fontWeight
            color: {
                if (control._customMission) {
                    if (!control.enabled)
                        return Qt.rgba(0.25, 0.25, 0.25, 0.40)
                    if (control.hovered && !(control.pressed || control.checked))
                        return control._cmTitle
                    return "#ffffff"
                }
                return _showHighlight ? qgcPal.buttonHighlightText
                                      : (primary ? qgcPal.primaryButtonText : qgcPal.buttonText)
            }
            visible: control.text !== ""
        }
    }
}
