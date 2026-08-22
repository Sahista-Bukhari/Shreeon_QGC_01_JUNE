import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

/// Drop panel that displays positioned next to the specified click position.
/// By default the panel drops to the right of the click position. If there isn't
/// enough room to the right then the panel will drop to the left.
Popup {
    id:             _root
    width:          Math.min(dropPanelBackground.implicitWidth,
                             Math.max(ScreenTools.defaultFontPixelWidth * 8,
                                      dropViewPort.width - _innerMargin * 2))
    height:         Math.min(dropPanelBackground.implicitHeight,
                             Math.max(ScreenTools.defaultFontPixelHeight * 3,
                                      dropViewPort.height - _innerMargin * 2))
    padding:        _innerMargin
    leftPadding:    dropBelow ? _innerMargin : (_dropRight ? _innerMargin + _arrowPointWidth : _innerMargin)
    rightPadding:   dropBelow ? _innerMargin : (_dropRight ? _innerMargin : _innerMargin + _arrowPointWidth)
    modal:          true
    focus:          true
    closePolicy:    Popup.CloseOnEscape | Popup.CloseOnPressOutside
    clip:           false
    dim:            false

    property var  sourceComponent                                               // Component to display within the popup
    property var  clickRect:        Qt.rect(0, 0, 0, 0)                         // Rectangle of clicked item - used to position drop down
    property var  dropViewPort:     Qt.rect(0, 0, parent.width, parent.height)  // Available viewport for dropdown
    property bool dropBelow:        false                                       // true: open under the clicked item (toolbar menus)
    property bool preferLeft:       false                                       // true: always open on the left side of clickRect

    property var  _qgcPal:              QGroundControl.globalPalette
    property real _innerMargin:         ScreenTools.defaultFontPixelWidth * 0.5 // Margin between content and rectanglular portion of background
    property real _arrowPointWidth:     ScreenTools.defaultFontPixelWidth * 2   // Distance from vertical side to point
    property real _arrowPointPositionY: height / 2
    property bool _dropRight:           true

    onAboutToShow: {
        const minX = dropViewPort.x + _innerMargin
        const maxX = Math.max(minX, dropViewPort.x + dropViewPort.width - _root.width - _innerMargin)
        const minY = dropViewPort.y + _innerMargin
        const maxY = Math.max(minY, dropViewPort.y + dropViewPort.height - _root.height - _innerMargin)

        if (dropBelow) {
            let xPos = clickRect.x + clickRect.width - _root.width
            xPos = Math.max(minX, Math.min(xPos, maxX))
            let yPos = clickRect.y + clickRect.height + ScreenTools.defaultFontPixelHeight * 0.35
            yPos = Math.max(minY, Math.min(yPos, maxY))
            _root.x = xPos
            _root.y = yPos
            return
        }

        let xPos
        if (preferLeft) {
            // Open on the map / free side, not over the host panel
            _dropRight = false
            xPos = clickRect.x - _root.width
            if (xPos < dropViewPort.x + _innerMargin) {
                _dropRight = true
                xPos = clickRect.x + Math.max(clickRect.width, 1)
            }
        } else {
            // Panel defaults to dropping to the right of click position
            xPos = clickRect.x + clickRect.width

            // If there isn't room to the right then we switch to drop to the left
            if (xPos + _root.width > dropViewPort.x + dropViewPort.width) {
                _dropRight = false
                xPos = clickRect.x - _root.width
            }
        }

        // Default position of panel is vertically centered on click position
        let yPos = clickRect.y + (clickRect.height / 2)
        yPos -= _root.height / 2

        // Make sure panel is within viewport
        yPos = Math.max(minY, Math.min(yPos, maxY))
        xPos = Math.max(minX, Math.min(xPos, maxX))

        _root.x = xPos
        _root.y = yPos

        // Adjust arrow position back to point at click position
        _arrowPointPositionY = Math.max(_arrowPointWidth,
                                        Math.min(_root.height - _arrowPointWidth,
                                                 (clickRect.y + clickRect.height / 2) - yPos))
    }

    background: Item {
        id: dropPanelBackground
        implicitWidth:  contentItem.implicitWidth + _innerMargin * 2 + (_root.dropBelow ? 0 : _arrowPointWidth)
        implicitHeight: contentItem.implicitHeight + _innerMargin * 2

        readonly property color _panelColor: "#ffffff"
        readonly property real _panelRadius: ScreenTools.defaultFontPixelHeight / 2

        Item {
            id: panelBody
            x:      _root.dropBelow ? 0 : (_dropRight ? _arrowPointWidth : 0)
            width:  parent.width - (_root.dropBelow ? 0 : _arrowPointWidth)
            height: parent.height

            Rectangle {
                anchors.fill: parent
                radius: parent.parent._panelRadius
                color: parent.parent._panelColor
                border.width: 1
                border.color: "#d9d9d9"

                Rectangle {
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    anchors.top:        parent.top
                    anchors.leftMargin: parent.radius
                    anchors.rightMargin: parent.radius
                    height:             3
                    radius:             height / 2
                    color:              "#00a651"
                }
            }
        }

        // Arrowhead
        Canvas {
            x:      _dropRight ? 0 : parent.width - _arrowPointWidth
            y:      _arrowPointPositionY - _arrowPointWidth
            width:  _arrowPointWidth
            height: _arrowPointWidth * 2
            visible: !_root.dropBelow

            onPaint: {
                var context = getContext("2d")
                context.reset()
                context.beginPath()
                context.moveTo(_dropRight ? 0 : _arrowPointWidth, _arrowPointWidth)
                context.lineTo(_dropRight ? _arrowPointWidth : 0, 0)
                context.lineTo(_dropRight ? _arrowPointWidth : 0, _arrowPointWidth * 2)
                context.closePath()
                context.fillStyle = parent._panelColor
                context.fill()
            }
        }
    }

    contentItem: QGCFlickable {
        id: dropPanelFlickable
        implicitWidth:  dropPanelContent.implicitWidth
        implicitHeight: dropPanelContent.implicitHeight
        contentWidth:   dropPanelContent.width
        contentHeight:  dropPanelContent.height
        flickableDirection: Flickable.AutoFlickDirection
        interactive:    contentWidth > width + 1 || contentHeight > height + 1
        clip:            true

        SettingsGroupLayout {
            id:             dropPanelContent
            width:          Math.max(implicitWidth, dropPanelFlickable.width)
            showBorder:     false
            showDividers:   false
            lightStyle:     true

            Loader {
                id: dropPanelSourceLoader
                sourceComponent: _root.sourceComponent
                onLoaded: {
                    if (typeof mainWindow !== "undefined"
                            && mainWindow
                            && mainWindow.applyLightPopupStyle) {
                        Qt.callLater(function() {
                            mainWindow.applyLightPopupStyle(dropPanelSourceLoader.item)
                        })
                    }
                }
            }
        }

        ScrollBar.vertical: ScrollBar {
            policy: dropPanelFlickable.contentHeight > dropPanelFlickable.height
                    ? ScrollBar.AlwaysOn
                    : ScrollBar.AlwaysOff
            width: Math.max(3, ScreenTools.defaultFontPixelWidth * 0.36)

            contentItem: Rectangle {
                implicitWidth: 3
                radius: width / 2
                color: "#00a651"
            }
        }

        ScrollBar.horizontal: ScrollBar {
            policy: dropPanelFlickable.contentWidth > dropPanelFlickable.width
                    ? ScrollBar.AlwaysOn
                    : ScrollBar.AlwaysOff
            height: Math.max(3, ScreenTools.defaultFontPixelWidth * 0.36)

            contentItem: Rectangle {
                implicitHeight: 3
                radius: height / 2
                color: "#00a651"
            }
        }
    }
}
