import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

Button {
    id:             control
    width:          contentLayoutItem.contentWidth + (contentMargins * 2)
    height:         width
    hoverEnabled:   !ScreenTools.isMobile
    flat:           true
    enabled:        toolStripAction ? toolStripAction.enabled : false
    visible:        toolStripAction ? toolStripAction.visible : false
    imageSource:    toolStripAction
                    ? (toolStripAction.showAlternateIcon ? toolStripAction.alternateIconSource : toolStripAction.iconSource)
                    : ""
    text:           toolStripAction ? toolStripAction.text : ""
    checked:        toolStripAction ? toolStripAction.checked : false
    checkable:      toolStripAction ? (toolStripAction.dropPanelComponent || toolStripAction.checkable) : false

    property var    toolStripAction:    undefined
    property var    dropPanel:          undefined
    property int    buttonIndex:        -1
    property var    glassBackgroundSource: null
    property alias  radius:             buttonBkRect.radius
    property alias  fontPointSize:      innerText.font.pointSize
    property alias  imageSource:        innerImage.source
    property alias  contentWidth:       innerText.contentWidth

    property bool forceImageScale11: false
    readonly property bool _customMission: typeof mainWindow !== "undefined"
                                           && mainWindow
                                           && mainWindow.customMissionStyleActive
    property real imageScale:        forceImageScale11 && (text == "") ? 0.8 : 0.6
    property real contentMargins:    _customMission ? (innerText.height * 0.18) : (innerText.height * 0.1)

    // Custom Mission: Route Mapping white/green. Other pages keep map-glass look.
    property color _currentContentColor: {
        if (_customMission) {
            if (checked || pressed)
                return "#ffffff"
            return enabled ? "#3f3f3f" : Qt.rgba(0.25, 0.25, 0.25, 0.40)
        }
        return (checked || pressed) ? qgcPal.buttonHighlightText : qgcPal.windowTransparentText
    }
    property color _currentContentColorSecondary:  (checked || pressed) ? qgcPal.windowTransparentText : qgcPal.buttonHighlight

    signal dropped(int index)

    onCheckedChanged: {
        if (toolStripAction)
            toolStripAction.checked = checked
    }

    Connections {
        target: toolStripAction
        function onCheckedChanged(newChecked) {
            if (control.checked !== newChecked) {
                control.checked = newChecked
            }
        }
    }

    onClicked: {
        if (mainWindow.allowViewSwitch()) {
            dropPanel.hide()
            if (!toolStripAction.dropPanelComponent) {
                toolStripAction.triggered(this)
            } else if (checked) {
                var stripItem = (dropPanel && dropPanel.toolStrip) ? dropPanel.toolStrip : parent
                // Prefer full-strip right edge so Custom Mission's 2-column Pattern
                // button does not open the panel over Waypoint/Return.
                var edgeWidth = (typeof stripItem.dropPanelEdgeX === "number" && stripItem.dropPanelEdgeX > 0)
                                ? stripItem.dropPanelEdgeX
                                : stripItem.width
                var buttonTopInStrip = mapToItem(stripItem, 0, 0)
                // dropPanel may be a child of the strip (stock ToolStrip) or a sibling
                // (Custom Mission). Always map into dropPanel.parent coordinates.
                var stripOrigin = stripItem.mapToItem(dropPanel.parent, 0, 0)
                var panelEdgeTopPoint = Qt.point(
                    stripOrigin.x + (dropPanel.dropToLeft ? 0 : edgeWidth),
                    stripOrigin.y + buttonTopInStrip.y
                )
                dropPanel.show(panelEdgeTopPoint, toolStripAction.dropPanelComponent, this)
                checked = true
                control.dropped(buttonIndex >= 0 ? buttonIndex : 0)
            }
        } else if (checkable) {
            checked = !checked
        }
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: control.enabled }

    contentItem: Item {
        id:                 contentLayoutItem
        anchors.fill:       parent
        anchors.margins:    contentMargins

        Column {
            anchors.centerIn:   parent
            spacing:            0

            Image {
                id:                         innerImageColorful
                height:                     contentLayoutItem.height * imageScale
                width:                      contentLayoutItem.width  * imageScale
                smooth:                     true
                mipmap:                     true
                fillMode:                   Image.PreserveAspectFit
                antialiasing:               true
                sourceSize.height:          height
                sourceSize.width:           width
                anchors.horizontalCenter:   parent.horizontalCenter
                source:                     control.imageSource
                visible:                    source != "" && toolStripAction && toolStripAction.fullColorIcon
            }

            QGCColoredImage {
                id:                         innerImage
                height:                     contentLayoutItem.height * imageScale
                width:                      contentLayoutItem.width  * imageScale
                smooth:                     true
                mipmap:                     true
                color:                      _currentContentColor
                fillMode:                   Image.PreserveAspectFit
                antialiasing:               true
                sourceSize.height:          height
                sourceSize.width:           width
                anchors.horizontalCenter:   parent.horizontalCenter
                visible:                    source != "" && !(toolStripAction && toolStripAction.fullColorIcon)

                QGCColoredImage {
                    id:                         innerImageSecondColor
                    source:                     toolStripAction ? toolStripAction.alternateIconSource : ""
                    height:                     contentLayoutItem.height * imageScale
                    width:                      contentLayoutItem.width  * imageScale
                    smooth:                     true
                    mipmap:                     true
                    color:                      _currentContentColorSecondary
                    fillMode:                   Image.PreserveAspectFit
                    antialiasing:               true
                    sourceSize.height:          height
                    sourceSize.width:           width
                    anchors.horizontalCenter:   parent.horizontalCenter
                    visible:                    source != "" && toolStripAction && toolStripAction.biColorIcon
                }
            }

            QGCLabel {
                id:                         innerText
                text:                       control.text
                color:                      _currentContentColor
                anchors.horizontalCenter:   parent.horizontalCenter
                font.bold:                  !innerImage.visible && !innerImageColorful.visible
                opacity:                    !innerImage.visible ? 0.8 : 1.0
            }
        }
    }

    background: Item {
        id: buttonBkRect
        property real radius: ScreenTools.defaultFontPixelWidth / 2

        // Custom Mission — white idle, gray hover, green selected
        Rectangle {
            anchors.fill: parent
            visible: control._customMission
            radius: buttonBkRect.radius
            color: {
                if (control.checked || control.pressed)
                    return "#00a651"
                if (control.enabled && control.hovered)
                    return "#e8e8e8"
                return "#ffffff"
            }
            border.width: 1
            border.color: {
                if (control.checked || control.pressed)
                    return "#00a651"
                return "#e2e2e2"
            }

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }
        }

        // Other pages — map glass
        LiquidGlassSurface {
            anchors.fill: parent
            visible: !control._customMission
            backgroundSource: control.glassBackgroundSource
            cornerRadius: buttonBkRect.radius
            blurAmount: 12
            tintColor: {
                if (control.checked || control.pressed)
                    return Qt.rgba(0.14, 0.69, 0.36, 0.42)
                if (control.enabled && control.hovered)
                    return Qt.rgba(1, 1, 1, 0.18)
                return Qt.rgba(1, 1, 1, 0.10)
            }
            rimColor: (control.checked || control.pressed || control.hovered)
                      ? Qt.rgba(1, 1, 1, 0.40) : Qt.rgba(1, 1, 1, 0.22)
            accentColor: Qt.rgba(0.14, 0.69, 0.36, 0.08)
            showGlint: false
            pressed: control.pressed
        }

        RippleEffect {
            id: stripRipple
            rippleColor: control._customMission
                         ? ((control.checked || control.pressed)
                            ? Qt.rgba(1, 1, 1, 0.40)
                            : Qt.rgba(0, 0, 0, 0.14))
                         : Qt.rgba(1, 1, 1, 0.40)
            clipRadius: buttonBkRect.radius
        }

        Connections {
            target: control
            function onPressedChanged() {
                if (control.pressed)
                    stripRipple.tap(control.pressX, control.pressY)
            }
        }
    }
}
