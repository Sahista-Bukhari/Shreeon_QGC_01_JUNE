import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

Slider {
    property bool zeroCentered: false ///< Value indicator starts display from zero instead of min value
    property bool displayValue: false ///< true: Show value on handle
    property bool showBoundaryValues: false ///< true: Show min/max values at slider ends

    id: control
    implicitHeight: ScreenTools.implicitSliderHeight + bottomPadding
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: showBoundaryValues ? minLabel.contentHeight : 0
    wheelEnabled: false

    property real _implicitBarLength: Math.round(ScreenTools.defaultFontPixelWidth * 20)
    property real _barHeight: Math.round(ScreenTools.defaultFontPixelHeight / 5)
    property color activeColor: "#00a04c"
    property real barHeight: _barHeight

    readonly property color _trackInactive: Qt.rgba(0, 160 / 255, 76 / 255, 0.18)
    readonly property real _thumbDiameter: ScreenTools.defaultFontPixelHeight * 0.72
    property real handleRadius: _thumbDiameter / 2

    QGCPalette { id: qgcPal; colorGroupEnabled: control.enabled }

    background: Item {
        x: control.horizontal ? control.leftPadding : control.leftPadding + control.availableWidth / 2 - _track.width / 2
        y: control.horizontal ? control.topPadding + control.availableHeight / 2 - _track.height / 2 : control.topPadding
        width: control.horizontal ? control.availableWidth : _track.width
        height: control.horizontal ? _track.height : control.availableHeight

        Rectangle {
            id: _track
            anchors.centerIn: parent
            implicitWidth: control.horizontal ? parent.width : control.barHeight
            implicitHeight: control.horizontal ? control.barHeight : parent.height
            width: implicitWidth
            height: implicitHeight
            radius: Math.min(width, height) / 2
            color: control._trackInactive

            Rectangle {
                radius: parent.radius
                color: control.activeColor

                anchors.left: control.horizontal ? parent.left : undefined
                anchors.right: control.horizontal ? undefined : parent.right
                anchors.bottom: parent.bottom
                anchors.top: control.horizontal ? undefined : undefined
                anchors.verticalCenter: control.horizontal ? parent.verticalCenter : undefined

                width: control.horizontal ? control.visualPosition * parent.width : parent.width
                height: control.horizontal ? parent.height : control.visualPosition * parent.height
            }
        }
    }

    handle: Item {
        x: control.horizontal ?
               control.leftPadding + control.visualPosition * (control.availableWidth - width) :
               control.leftPadding + control.availableWidth / 2 - width / 2
        y: control.horizontal ?
               control.topPadding + control.availableHeight / 2 - height / 2 :
               control.topPadding + control.visualPosition * (control.availableHeight - height)
        width: control._thumbDiameter * 1.65
        height: width

        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: width
            radius: width / 2
            color: Qt.rgba(0, 160 / 255, 76 / 255, control.pressed ? 0.32 : (control.hovered ? 0.22 : 0.14))
            visible: control.enabled
        }

        Rectangle {
            id: thumb
            anchors.centerIn: parent
            width: control._thumbDiameter
            height: width
            radius: width / 2
            color: control.activeColor
            border.width: control.pressed ? 2 : 0
            border.color: Qt.rgba(1, 1, 1, 0.55)
        }

        Label {
            text: control.value.toFixed(control.to <= 1 ? 1 : 0)
            visible: control.displayValue
            anchors.centerIn: parent
            font.family: ScreenTools.normalFontFamily
            font.pointSize: ScreenTools.smallFontPointSize
            color: "white"
        }
    }

    QGCLabel {
        id: minLabel
        anchors.left: parent.left
        anchors.leftMargin: control.leftPadding
        anchors.bottom: parent.bottom
        text: control.from.toFixed(1)
        font.pointSize: ScreenTools.smallFontPointSize
        color: "#6a6a6a"
        visible: control.showBoundaryValues
    }

    QGCLabel {
        id: maxLabel
        anchors.right: parent.right
        anchors.rightMargin: control.rightPadding
        anchors.bottom: parent.bottom
        text: control.to.toFixed(1)
        font.pointSize: ScreenTools.smallFontPointSize
        color: "#6a6a6a"
        visible: control.showBoundaryValues
    }
}
