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

    // Custom Mission uses Route Mapping white/green chrome
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

        Rectangle {
            anchors.fill: parent
            visible: button._customMission
            radius: height / 2
            color: {
                if (button.checked || button.pressed)
                    return "#00a651"
                if (button.hovered)
                    return Qt.rgba(0.18, 0.18, 0.18, 0.72)
                // Match PlanViewToolBar dark translucent chrome
                return Qt.rgba(0.12, 0.12, 0.14, 0.55)
            }
            border.width: 1
            border.color: {
                if (button.checked || button.pressed)
                    return "#00a651"
                return Qt.rgba(1, 1, 1, 0.28)
            }

            Behavior on color { ColorAnimation { duration: 120 } }
        }

        RippleEffect {
            id: toolbarRipple
            rippleColor: button._customMission
                         ? Qt.rgba(1, 1, 1, 0.35)
                         : Qt.rgba(0, 0, 0, 0.16)
            clipRadius: height / 2
        }

        Connections {
            target: button
            function onPressedChanged() {
                if (button.pressed)
                    toolbarRipple.tap(button.pressX, button.pressY)
            }
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
            color: {
                if (logo)
                    return "transparent"
                if (button._customMission) {
                    if (button.checked || button.pressed)
                        return "#ffffff"
                    return "#ffffff"
                }
                return button.checked ? qgcPal.buttonHighlightText : qgcPal.buttonText
            }
            source:                 button.icon.source
            anchors.verticalCenter: parent.verticalCenter
        }
        Label {
            id:                     _label
            visible:                text !== ""
            text:                   button.text
            color: {
                if (button._customMission) {
                    if (button.checked || button.pressed)
                        return "#ffffff"
                    return "#ffffff"
                }
                return button.checked ? qgcPal.buttonHighlightText : qgcPal.buttonText
            }
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
