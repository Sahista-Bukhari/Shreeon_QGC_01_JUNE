import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

ColumnLayout {
    id:                 control
    spacing:            _rowGap
    implicitWidth:      Math.max(headingColumn.implicitWidth, outerRect.implicitWidth)
    implicitHeight:     (heading !== "" ? headingColumn.implicitHeight + spacing : 0) + outerRect.implicitHeight

    default property alias contentItem: _contentLayout.data

    property alias contentSpacing: _contentLayout.spacing

    property string defaultBorderColor  : QGroundControl.globalPalette.groupBorder
    property string outerBorderColor    : defaultBorderColor

    property string defaultHeadingPointSize:    ScreenTools.defaultFontPointSize + 1
    property string headingPointSize:           defaultHeadingPointSize

    property string heading
    property string headingDescription
    property bool   showDividers:       true
    property bool   showBorder:         false

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    readonly property color _titleColor: qgcPal.globalTheme === QGCPalette.Dark ? "#AEAEB2" : "#3A3A3C"
    readonly property color _bodyColor:  qgcPal.globalTheme === QGCPalette.Dark ? "#8E8E93" : "#3A3A3C"

    // Shared inset so headings ("General", "Units") line up with option labels
    property real _contentPad:  ScreenTools.defaultFontPixelWidth * 1.25
    property real _rowGap:      ScreenTools.defaultFontPixelHeight * 0.35
    property real _margins:     ScreenTools.defaultFontPixelHeight / 2.4

    ColumnLayout {
        id:                 headingColumn
        Layout.fillWidth:   true
        Layout.leftMargin:  _contentPad
        Layout.rightMargin: _contentPad
        spacing:            ScreenTools.defaultFontPixelHeight * 0.15
        visible:            heading !== ""

        QGCLabel {
            text:           heading
            color:          control._titleColor
            font.pointSize: headingPointSize
            font.bold:      true
            font.family:    ScreenTools.normalFontFamily
        }

        QGCLabel {
            Layout.fillWidth:   true
            text:               headingDescription
            wrapMode:           Text.WordWrap
            font.pointSize:     ScreenTools.smallFontPointSize
            font.family:        ScreenTools.normalFontFamily
            color:              control._bodyColor
            visible:            headingDescription !== ""
        }
    }

    Rectangle {
        id:                 outerRect
        Layout.fillWidth:   true
        implicitWidth:      _contentLayout.implicitWidth + _contentPad * 2 + (showBorder ? _margins * 2 : 0)
        implicitHeight:     _contentLayout.implicitHeight + (showBorder ? _margins * 2 : 0)
        color:              "transparent"
        border.color:       outerBorderColor
        border.width:       showBorder ? 1 : 0
        radius:             ScreenTools.defaultFontPixelHeight / 2

        Repeater {
            model: showDividers ? Math.max(0, _contentLayout.visibleChildren.length - 1) : 0

            Rectangle {
                x:                  _contentPad + (showBorder ? _margins : 0)
                y:                  _contentItem.y + _contentItem.height + _margins + (showBorder ? _margins : 0)
                width:              parent.width - _contentPad * 2 - (showBorder ? _margins * 2 : 0)
                height:             1
                color:              qgcPal.globalTheme === QGCPalette.Dark ? qgcPal.windowShade : "#EFEFEF"

                property var _contentItem: _contentLayout.visibleChildren[index]
            }
        }

        ColumnLayout {
            id:                 _contentLayout
            x:                  _contentPad + (showBorder ? _margins : 0)
            y:                  showBorder ? _margins : 0
            width:              parent.width - _contentPad * 2 - (showBorder ? _margins * 2 : 0)
            spacing:            _margins * (showDividers ? 1.35 : 0.85)
        }
    }
}
