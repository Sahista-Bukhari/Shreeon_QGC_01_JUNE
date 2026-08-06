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
                                           && mainWindow.activeMissionEditor === "customMission"
    property real imageScale:        forceImageScale11 && (text == "") ? 0.8 : 0.6
    property real contentMargins:    _customMission ? (innerText.height * 0.18) : (innerText.height * 0.1)
    property color _currentContentColor:  _customMission
                                          ? ((checked || pressed) ? "#ffffff" : Qt.rgba(1, 1, 1, enabled ? 0.92 : 0.45))
                                          : ((checked || pressed) ? qgcPal.buttonHighlightText : qgcPal.windowTransparentText)
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
                // Anchor to the full strip's right edge (not this button's right edge).
                // In Custom Mission's 2-column grid, Pattern is left-column — using
                // button.width would place the panel over Waypoint/Return.
                var buttonTopInStrip = mapToItem(stripItem, 0, 0)
                var panelEdgeTopPoint = Qt.point(stripItem.width, buttonTopInStrip.y)
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

        LiquidGlassSurface {
            anchors.fill: parent
            backgroundSource: control.glassBackgroundSource
            cornerRadius: buttonBkRect.radius
            blurAmount: control._customMission ? 18 : 12
            // Custom Mission: match Mission Settings panel glass
            tintColor: {
                if (control._customMission) {
                    if (control.checked || control.pressed)
                        return Qt.rgba(0.14, 0.66, 0.00, 0.38)
                    if (control.enabled && control.hovered)
                        return Qt.rgba(0.14, 0.66, 0.00, 0.28)
                    return Qt.rgba(0.06, 0.10, 0.09, 0.40)
                }
                if (control.checked || control.pressed)
                    return Qt.rgba(0.14, 0.69, 0.36, 0.42)
                if (control.enabled && control.hovered)
                    return Qt.rgba(1, 1, 1, 0.18)
                return Qt.rgba(1, 1, 1, 0.10)
            }
            rimColor: {
                if (control._customMission) {
                    if (control.checked || control.pressed || control.hovered)
                        return Qt.rgba(0.55, 1.0, 0.72, 0.55)
                    return Qt.rgba(1, 1, 1, 0.32)
                }
                return (control.checked || control.pressed || control.hovered)
                       ? Qt.rgba(1, 1, 1, 0.40) : Qt.rgba(1, 1, 1, 0.22)
            }
            accentColor: Qt.rgba(0.14, 0.69, 0.36, 0.08)
            showGlint: false
            pressed: control.pressed
        }

        RippleEffect {
            id: stripRipple
            rippleColor: Qt.rgba(1, 1, 1, 0.40)
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
