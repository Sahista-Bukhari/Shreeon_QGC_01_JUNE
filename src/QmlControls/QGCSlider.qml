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
    property real _barHeight: Math.round(ScreenTools.defaultFontPixelHeight / 4) // Slimmer track
    property color activeColor: qgcPal.colorGreen
    property real barHeight: _barHeight

    // Gray rounded knob + soft track on all light / white-theme pages
    readonly property bool _lightTheme: {
        if (typeof mainWindow !== "undefined" && mainWindow)
            return mainWindow.uiThemeMode !== mainWindow.themeBlack
        return qgcPal.globalTheme === QGCPalette.Light
    }
    property real handleRadius: ScreenTools.defaultFontPixelHeight * (_lightTheme ? 0.38 : 0.75)

    QGCPalette { id: qgcPal; colorGroupEnabled: control.enabled }

    background: Rectangle {
        x: control.horizontal ? control.leftPadding : control.leftPadding + control.availableWidth / 2 - width / 2
        y: control.horizontal ? control.topPadding + control.availableHeight / 2 - height / 2 : control.topPadding
        implicitWidth: control.horizontal ? control._implicitBarLength : control.barHeight
        implicitHeight: control.horizontal ? control.barHeight : control._implicitBarLength
        width: control.horizontal ? control.availableWidth : implicitWidth
        height: control.horizontal ? implicitHeight : control.availableHeight
        radius: height / 2
        color: control._lightTheme ? "#e8e8e8" : qgcPal.windowShadeDark

        // Active fill track
        Rectangle {
            width: control.horizontal ? control.visualPosition * parent.width : parent.width
            height: control.horizontal ? parent.height : control.visualPosition * parent.height
            color: control.activeColor
            radius: parent.radius
        }
    }

    handle: Rectangle {
        x: control.horizontal ?
               control.leftPadding + control.visualPosition * (control.availableWidth - width) :
               control.leftPadding + control.availableWidth / 2 - width / 2
        y: control.horizontal ?
               control.topPadding + control.availableHeight / 2 - height / 2 :
               control.topPadding + control.visualPosition * (control.availableHeight - height)
        width: control.handleRadius * 2
        height: control.handleRadius * 2
        implicitWidth: width
        implicitHeight: height
        color: control._lightTheme ? "#f5f5f5" : "white"
        border.width: control._lightTheme ? 1 : 0
        border.color: control._lightTheme ? "#d0d0d0" : "transparent"
        radius: control.handleRadius

        Label {
            text: control.value.toFixed(control.to <= 1 ? 1 : 0)
            visible: control.displayValue
            anchors.centerIn: parent
            font.family: ScreenTools.normalFontFamily
            font.pointSize: ScreenTools.smallFontPointSize
            color: control._lightTheme ? "#3f3f3f" : "black"
        }
    }

    QGCLabel {
        id: minLabel
        anchors.left: parent.left
        anchors.leftMargin: control.leftPadding
        anchors.bottom: parent.bottom
        text: control.from.toFixed(1)
        font.pointSize: ScreenTools.smallFontPointSize
        color: control._lightTheme ? "#6a6a6a" : Qt.rgba(1, 1, 1, 0.78)
        visible: control.showBoundaryValues
    }

    QGCLabel {
        id: maxLabel
        anchors.right: parent.right
        anchors.rightMargin: control.rightPadding
        anchors.bottom: parent.bottom
        text: control.to.toFixed(1)
        font.pointSize: ScreenTools.smallFontPointSize
        color: control._lightTheme ? "#6a6a6a" : Qt.rgba(1, 1, 1, 0.78)
        visible: control.showBoundaryValues
    }
}
