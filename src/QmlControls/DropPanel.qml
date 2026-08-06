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
        if (dropBelow) {
            let xPos = clickRect.x + clickRect.width - _root.width
            xPos = Math.max(dropViewPort.x + _innerMargin, Math.min(xPos, dropViewPort.x + dropViewPort.width - _root.width - _innerMargin))
            let yPos = clickRect.y + clickRect.height + ScreenTools.defaultFontPixelHeight * 0.35
            yPos = Math.min(yPos, dropViewPort.y + dropViewPort.height - _root.height - _innerMargin)
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
        let originalYPos = yPos
        yPos = Math.max(yPos, dropViewPort.y)
        yPos = Math.min(yPos, dropViewPort.y + dropViewPort.height - _root.height)

        _root.x = xPos
        _root.y = yPos

        // Adjust arrow position back to point at click position
        _arrowPointPositionY += originalYPos - yPos
    }

    background: Item {
        implicitWidth:  contentItem.implicitWidth + _innerMargin * 2 + (_root.dropBelow ? 0 : _arrowPointWidth)
        implicitHeight: contentItem.implicitHeight + _innerMargin * 2

        readonly property bool _customMission: typeof mainWindow !== "undefined"
                                               && mainWindow
                                               && mainWindow.activeMissionEditor === "customMission"
        readonly property color _panelColor: _customMission
                                             ? Qt.rgba(0.10, 0.12, 0.12, 0.72)
                                             : Qt.rgba(0.28, 0.30, 0.30, 0.78)
        readonly property real _panelRadius: ScreenTools.defaultFontPixelHeight / 2

        Item {
            id: panelBody
            x:      _root.dropBelow ? 0 : (_dropRight ? _arrowPointWidth : 0)
            width:  parent.implicitWidth - (_root.dropBelow ? 0 : _arrowPointWidth)
            height: parent.implicitHeight

            Rectangle {
                anchors.fill: parent
                visible: !parent.parent._customMission
                radius: parent.parent._panelRadius
                color: parent.parent._panelColor
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.28)
            }

            LiquidGlassSurface {
                anchors.fill: parent
                visible: parent.parent._customMission
                enableBlur: false
                cornerRadius: parent.parent._panelRadius
                tintColor: Qt.rgba(0.10, 0.12, 0.12, 0.68)
                rimColor: Qt.rgba(1, 1, 1, 0.38)
                innerGlow: Qt.rgba(1, 1, 1, 0.12)
                accentColor: Qt.rgba(0.14, 0.69, 0.36, 0.08)
                showGlint: true
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

    contentItem: SettingsGroupLayout {
        showBorder: false
        showDividers: false

        Loader {
            sourceComponent: _root.sourceComponent
        }
    }
}
