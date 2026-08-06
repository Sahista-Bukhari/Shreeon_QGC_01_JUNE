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

    // Liquid glass only on Custom Mission — Application Settings / Fly View stay solid
    readonly property bool _customMission: typeof mainWindow !== "undefined"
                                           && mainWindow
                                           && mainWindow.activeMissionEditor === "customMission"
    readonly property color _cmGlassTint: Qt.rgba(0.06, 0.10, 0.09, 0.40)
    readonly property color _cmGlassTintHover: Qt.rgba(0.137, 0.659, 0.0, 0.30)
    readonly property color _cmGlassTintPressed: Qt.rgba(0.137, 0.659, 0.0, 0.42)
    readonly property color _primaryTint: Qt.rgba(0.137, 0.659, 0.0, 0.42)
    readonly property color _primaryTintPressed: Qt.rgba(0.137, 0.659, 0.0, 0.58)

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

        // Custom Mission liquid glass only
        LiquidGlassSurface {
            anchors.fill: parent
            visible: control._customMission
            cornerRadius: control.backRadius
            blurAmount: 14
            tintColor: {
                if (control.primary)
                    return control.pressed || control.checked ? control._primaryTintPressed : control._primaryTint
                if (control.pressed || control.checked)
                    return control._cmGlassTintPressed
                if (control.enabled && control.hovered)
                    return control._cmGlassTintHover
                return control._cmGlassTint
            }
            rimColor: control.primary || control.pressed || control.checked || control.hovered
                      ? Qt.rgba(0.45, 0.90, 0.15, 0.75)
                      : Qt.rgba(1, 1, 1, control.showBorder ? 0.32 : 0)
            innerGlow: "transparent"
            accentColor: Qt.rgba(0.137, 0.659, 0.0, 0.14)
            showGlint: false
            pressed: control.pressed
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
            color: control._customMission
                   ? (control.enabled ? "#ffffff" : Qt.rgba(1, 1, 1, 0.45))
                   : (_showHighlight ? qgcPal.buttonHighlightText
                                     : (primary ? qgcPal.primaryButtonText : qgcPal.buttonText))
            visible: control.text !== ""
        }
    }
}
