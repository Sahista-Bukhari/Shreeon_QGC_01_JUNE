import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

Item {
    id:         _root
    visible:    false

    signal          clicked()
    property real   radius:             ScreenTools.isMobile ? ScreenTools.defaultFontPixelHeight * 1.75 : ScreenTools.defaultFontPixelHeight * 1.25
    property real   viewportMargins:    0
    property var    toolStrip
    property bool   dropToLeft:         !!(toolStrip && toolStrip.dropLeft)

    // Should be an enum but that get's into the whole problem of creating a singleton which isn't worth the effort
    readonly property int dropLeft:     1
    readonly property int dropRight:    2
    readonly property int dropUp:       3
    readonly property int dropDown:     4

    readonly property real _arrowBaseHeight:    radius             // Height of vertical side of arrow
    readonly property real _arrowPointWidth:    radius * 0.666     // Distance from vertical side to point
    readonly property real _dropMargin:         ScreenTools.defaultFontPixelWidth * 1.6

    property var    _dropEdgeTopPoint
    property alias  _dropDownComponent: panelLoader.sourceComponent
    property real   _viewportMaxTop:    0
    property real   _viewportMaxBottom: parent.parent.height - parent.y
    property real   _viewportMaxHeight: _viewportMaxBottom - _viewportMaxTop
    property real   _viewportMaxLeft:   viewportMargins
    property real   _viewportMaxRight:  parent.parent.width - parent.x - viewportMargins
    property real   _viewportMaxWidth:  Math.max(1, _viewportMaxRight - _viewportMaxLeft)
    property var    _dropPanelCancel
    property var    _parentButton

    function show(panelEdgeTopPoint, panelComponent, parentButton) {
        _parentButton = parentButton
        _dropEdgeTopPoint = panelEdgeTopPoint
        _dropDownComponent = panelComponent
        _calcPositions()
        visible = true
        _dropPanelCancel = dropPanelCancelComponent.createObject(toolStrip.parent)
    }

    function hide() {
        if (_dropPanelCancel) {
            _dropPanelCancel.destroy()
            _parentButton.checked = false
            visible = false
            _dropDownComponent = undefined
        }
    }

    function _calcPositions() {
        var panelComponentWidth  = panelLoader.item.width
        var panelComponentHeight = panelLoader.item.height

        dropDownItem.width  = Math.min(panelComponentWidth + (_dropMargin * 2) + _arrowPointWidth,
                                       _viewportMaxWidth)
        dropDownItem.height = panelComponentHeight + (_dropMargin * 2)

        if (dropToLeft) {
            // Position dropdown to the left of the toolbar
            dropDownItem.x = _dropEdgeTopPoint.x - dropDownItem.width - _dropMargin
        } else {
            // Position dropdown to the right of the toolbar (default)
            dropDownItem.x = _dropEdgeTopPoint.x + _dropMargin
        }
        dropDownItem.x = Math.max(_viewportMaxLeft,
                                  Math.min(dropDownItem.x,
                                           _viewportMaxRight - dropDownItem.width))
        dropDownItem.y = _dropEdgeTopPoint.y -(dropDownItem.height / 2) + radius

        // Validate that dropdown is within viewport
        dropDownItem.y = Math.min(dropDownItem.y + dropDownItem.height, _viewportMaxBottom) - dropDownItem.height
        dropDownItem.y = Math.max(dropDownItem.y, _viewportMaxTop)

        // Adjust height to not exceed viewport bounds
        dropDownItem.height = Math.min(dropDownItem.height, _viewportMaxHeight - dropDownItem.y)

        // Arrow points
        arrowCanvas.arrowPoint.y = (_dropEdgeTopPoint.y + radius) - dropDownItem.y
        if (dropToLeft) {
            // Arrow points right (to toolbar)
            arrowCanvas.arrowPoint.x = dropDownItem.width
            arrowCanvas.arrowBase1.x = dropDownItem.width - _arrowPointWidth
            arrowCanvas.arrowBase1.y = arrowCanvas.arrowPoint.y - (_arrowBaseHeight / 2)
            arrowCanvas.arrowBase2.x = arrowCanvas.arrowBase1.x
            arrowCanvas.arrowBase2.y = arrowCanvas.arrowBase1.y + _arrowBaseHeight
        } else {
            // Arrow points left (default)
            arrowCanvas.arrowPoint.x = 0
            arrowCanvas.arrowBase1.x = _arrowPointWidth
            arrowCanvas.arrowBase1.y = arrowCanvas.arrowPoint.y - (_arrowBaseHeight / 2)
            arrowCanvas.arrowBase2.x = arrowCanvas.arrowBase1.x
            arrowCanvas.arrowBase2.y = arrowCanvas.arrowBase1.y + _arrowBaseHeight
        }
        arrowCanvas.requestPaint()
    } // function - _calcPositions

    QGCPalette { id: qgcPal }

    Component {
        // Overlay which is used to cancel the panel when the user clicks away
        id: dropPanelCancelComponent

        MouseArea {
            anchors.fill:   parent
            // Keep under the tool strip so Takeoff / Waypoint / Open / Save stay
            // clickable while the Pattern panel is open.
            z:              toolStrip.z - 1
            onClicked:      dropPanel.hide()
        }
    }

    // This item is sized to hold the entirety of the drop panel including the arrow point
    Item {
        id: dropDownItem

        DeadMouseArea {
            anchors.fill: parent
        }

        readonly property bool _customMission: typeof mainWindow !== "undefined"
                                               && mainWindow
                                               && mainWindow.customMissionStyleActive
        readonly property real _panelRadius: ScreenTools.defaultFontPixelHeight * 0.55
        readonly property color _panelColor: _customMission
                                             ? "#fbfbfb"
                                             : Qt.rgba(0.30, 0.32, 0.32, 0.78)
        readonly property color _panelBorder: _customMission
                                              ? "#e2e2e2"
                                              : Qt.rgba(1, 1, 1, 0.32)

        Item {
            id: panelBody
            x: dropToLeft ? 0 : _arrowPointWidth
            width: parent.width - _arrowPointWidth
            height: parent.height

            Rectangle {
                anchors.fill: parent
                radius: dropDownItem._panelRadius
                color: dropDownItem._panelColor
                border.width: 1
                border.color: dropDownItem._panelBorder
            }
        }

        Canvas {
            id:             arrowCanvas
            anchors.fill:   parent

            property point arrowPoint: Qt.point(0, 0)
            property point arrowBase1: Qt.point(0, 0)
            property point arrowBase2: Qt.point(0, 0)

            onPaint: {
                var context = getContext("2d")
                context.reset()
                context.beginPath()
                context.moveTo(arrowBase1.x, arrowBase1.y)
                context.lineTo(arrowPoint.x, arrowPoint.y)
                context.lineTo(arrowBase2.x, arrowBase2.y)
                context.closePath()
                context.fillStyle = dropDownItem._panelColor
                context.fill()
            }
        }

        Flickable {
            id:                 panelItemFlickable
            anchors.margins:    _dropMargin
            anchors.leftMargin: dropToLeft ? _dropMargin : (_dropMargin + _arrowPointWidth)
            anchors.rightMargin: dropToLeft ? (_dropMargin + _arrowPointWidth) : _dropMargin
            anchors.fill:       parent
            clip:               true
            boundsBehavior:     Flickable.StopAtBounds
            flickableDirection: Flickable.AutoFlickDirection
            interactive:        contentHeight > height + 1 || contentWidth > width + 1
            contentWidth:       Math.max(width, panelLoader.width)
            contentHeight:      panelLoader.height

            Loader {
                id: panelLoader

                onHeightChanged:    _calcPositions()
                onWidthChanged:     _calcPositions()

                property var dropPanel: _root
            }

            ScrollBar.vertical: ScrollBar {
                policy: panelItemFlickable.contentHeight > panelItemFlickable.height
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
                policy: panelItemFlickable.contentWidth > panelItemFlickable.width
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
    } // Item - dropDownItem
}
