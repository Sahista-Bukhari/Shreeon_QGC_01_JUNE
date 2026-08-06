import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

// Important Note: Toolbar buttons must manage their checked state manually in order to support
// view switch prevention. This means they can't be checkable or autoExclusive.

Button {
    id:                 button
    height:             ScreenTools.defaultFontPixelHeight * 3
    leftPadding:        _horizontalMargin
    rightPadding:       _horizontalMargin
    checkable:          false
    hoverEnabled:       !ScreenTools.isMobile

    property bool logo: false
    property real iconSize: ScreenTools.defaultFontPixelHeight * 2

    property real _horizontalMargin: ScreenTools.defaultFontPixelWidth

    // Liquid glass only on Custom Mission — Application Settings stays solid
    readonly property bool _customMission: typeof mainWindow !== "undefined"
                                           && mainWindow
                                           && mainWindow.activeMissionEditor === "customMission"

    QGCPalette { id: qgcPal; colorGroupEnabled: button.enabled }

    onCheckedChanged: checkable = false

    background: Item {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            visible: !button._customMission
            color: button.checked ? qgcPal.buttonHighlight : Qt.rgba(0, 0, 0, 0)
            border.color: "red"
            border.width: QGroundControl.corePlugin.showTouchAreas ? 3 : 0
        }

        LiquidGlassSurface {
            anchors.fill: parent
            visible: button._customMission
            cornerRadius: height / 2
            blurAmount: 12
            tintColor: {
                if (button.checked || button.pressed)
                    return Qt.rgba(0.137, 0.659, 0.0, 0.48)
                if (button.hovered)
                    return Qt.rgba(1, 1, 1, 0.18)
                return Qt.rgba(1, 1, 1, 0.08)
            }
            rimColor: Qt.rgba(1, 1, 1, button.checked || button.hovered ? 0.40 : 0.18)
            showGlint: false
            pressed: button.pressed
        }
    }

    contentItem: Row {
        spacing:                ScreenTools.defaultFontPixelWidth
        anchors.verticalCenter: button.verticalCenter
        QGCColoredImage {
            id:                     _icon
            height:                 button.iconSize
            width:                  height
            sourceSize.height:      parent.height
            fillMode:               Image.PreserveAspectFit
            color:                  logo ? "transparent"
                                         : (button.checked ? qgcPal.buttonHighlightText : qgcPal.buttonText)
            source:                 button.icon.source
            anchors.verticalCenter: parent.verticalCenter
        }
        Label {
            id:                     _label
            visible:                text !== ""
            text:                   button.text
            color:                  button.checked ? qgcPal.buttonHighlightText : qgcPal.buttonText
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
