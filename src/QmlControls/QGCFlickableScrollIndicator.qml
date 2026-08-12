import QtQuick

import QGroundControl
import QGroundControl.Controls

Item {
    id:         control
    z:          10
    opacity:    _opacity
    visible:    showIndicator
    state:      orientation == QGCFlickableScrollIndicator.Vertical ? "vertical" : "horizontal"

    property bool showIndicator: false
    property int  orientation:   QGCFlickableScrollIndicator.Vertical

    enum Orientation {
        Vertical,
        Horizontal
    }

    readonly property color _trackColor: Qt.rgba(0, 160 / 255, 76 / 255, 0.14)
    readonly property color _thumbColor: "#00a04c"

    property real _opacity:     0.92
    property var  _flickable:   parent

    Rectangle {
        id: track
        color: control._trackColor
        radius: Math.min(width, height) / 2
        opacity: control.opacity
    }

    Rectangle {
        id: thumb
        color: control._thumbColor
        radius: Math.min(width, height) / 2
        opacity: control.opacity
    }

    states: [
        State {
            name: "vertical"
            AnchorChanges {
                target: track
                anchors.right: _flickable.right
                anchors.top: _flickable.top
                anchors.bottom: _flickable.bottom
            }
            PropertyChanges {
                target: track
                width: ScreenTools.defaultFontPixelWidth * 0.65
            }
            AnchorChanges {
                target: thumb
                anchors.right: _flickable.right
            }
            PropertyChanges {
                target: control
                y: 0
                width: 0
                height: 0
                showIndicator: (_flickable.flickableDirection === Flickable.AutoFlickDirection ||
                                _flickable.flickableDirection === Flickable.VerticalFlick ||
                                _flickable.flickableDirection === Flickable.HorizontalAndVerticalFlick) &&
                               (_flickable.contentHeight > _flickable.height)
            }
            PropertyChanges {
                target: thumb
                y: _flickable.height * (_flickable.contentY / _flickable.contentHeight)
                width: ScreenTools.defaultFontPixelWidth * 0.65
                height: Math.max(ScreenTools.defaultFontPixelHeight * 1.8,
                                 _flickable.height * (_flickable.height / _flickable.contentHeight))
            }
        },

        State {
            name: "horizontal"
            AnchorChanges {
                target: track
                anchors.left: _flickable.left
                anchors.right: _flickable.right
                anchors.bottom: _flickable.bottom
            }
            PropertyChanges {
                target: track
                height: ScreenTools.defaultFontPixelWidth * 0.65
            }
            AnchorChanges {
                target: thumb
                anchors.bottom: _flickable.bottom
            }
            PropertyChanges {
                target: control
                x: 0
                width: 0
                height: 0
                showIndicator: (_flickable.flickableDirection === Flickable.AutoFlickDirection ||
                                _flickable.flickableDirection === Flickable.HorizontalFlick ||
                                _flickable.flickableDirection === Flickable.HorizontalAndVerticalFlick) &&
                               (_flickable.contentWidth > _flickable.width)
            }
            PropertyChanges {
                target: thumb
                x: _flickable.width * (_flickable.contentX / _flickable.contentWidth)
                height: ScreenTools.defaultFontPixelWidth * 0.65
                width: Math.max(ScreenTools.defaultFontPixelHeight * 1.8,
                                _flickable.width * (_flickable.width / _flickable.contentWidth))
            }
        }
    ]

    Component.onCompleted:  { if (animateOpacity) animateOpacity.restart() }
    onVisibleChanged:       { if (animateOpacity) animateOpacity.restart() }
    onHeightChanged:        { if (animateOpacity) animateOpacity.restart() }
    onWidthChanged:         { if (animateOpacity) animateOpacity.restart() }

    Connections {
        target: control._flickable
        function onMovementStarted()        { control.opacity = control._opacity }
        function onMovementEnded()          { animateOpacity.restart() }
        function onContentHeightChanged()   { animateOpacity.restart() }
        function onContentWidthChanged()    { animateOpacity.restart() }
        function onContentYChanged()        { animateOpacity.restart() }
        function onContentXChanged()        { animateOpacity.restart() }
    }

    NumberAnimation {
        id:            animateOpacity
        target:        control
        properties:    "opacity"
        from:          control._opacity
        to:            0.35
        duration:      2000
        easing.type:   Easing.InQuint
    }
}
