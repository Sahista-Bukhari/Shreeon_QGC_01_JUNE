import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

ColumnLayout {
    id:                 control
    spacing:            _headingGap
    implicitWidth:      Math.max(headingRow.implicitWidth, outerRect.implicitWidth)
    implicitHeight:     (heading !== "" ? headingRow.implicitHeight + spacing : 0) + outerRect.implicitHeight

    default property alias contentItem: _contentLayout.data

    property alias contentSpacing: _contentLayout.spacing

    property string defaultBorderColor  : control._dividerColor
    property string outerBorderColor    : defaultBorderColor

    property string defaultHeadingPointSize:    ScreenTools.defaultFontPointSize + 1
    property string headingPointSize:           defaultHeadingPointSize

    property string heading
    property string headingDescription
    property bool   showDividers:       true
    property bool   showBorder:         true
    property bool   lightStyle:         false

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    readonly property bool  _darkTheme:  !lightStyle && qgcPal.globalTheme === QGCPalette.Dark
    readonly property color _titleColor: _darkTheme ? "#AEAEB2" : "#3A3A3C"
    readonly property color _bodyColor:  _darkTheme ? "#8E8E93" : "#5A5A5E"
    readonly property color _accentGreen: "#00a04c"
    readonly property color _cardFill:    _darkTheme ? qgcPal.windowShade : "#F7F7F7"
    readonly property color _innerFill:   _darkTheme ? qgcPal.window : "#FFFFFF"
    readonly property color _dividerColor: _darkTheme ? qgcPal.windowShade : "#E5E5E5"

    // Shared inset so headings ("General", "Units") line up with option labels
    property real _contentPad:  ScreenTools.defaultFontPixelWidth * 1.25
    property real _headingGap:  ScreenTools.defaultFontPixelHeight * 0.45
    property real _margins:     ScreenTools.defaultFontPixelHeight * 0.72

    RowLayout {
        id:                 headingRow
        Layout.fillWidth:   true
        Layout.leftMargin:  _contentPad
        Layout.rightMargin: _contentPad
        spacing:            ScreenTools.defaultFontPixelWidth * 0.8
        visible:            heading !== ""

        Rectangle {
            Layout.preferredWidth:  Math.max(3, ScreenTools.defaultFontPixelWidth * 0.38)
            Layout.preferredHeight: headingText.implicitHeight * 0.9
            Layout.alignment:       Qt.AlignTop
            radius:                 width / 2
            color:                  control._accentGreen
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing:          ScreenTools.defaultFontPixelHeight * 0.15

            QGCLabel {
                id:             headingText
                Layout.fillWidth: true
                text:           heading
                color:          control._titleColor
                font.pointSize: headingPointSize
                font.weight:    Font.DemiBold
                font.family:    ScreenTools.normalFontFamily
                elide:          Text.ElideRight
            }

            QGCLabel {
                Layout.fillWidth: true
                text:             headingDescription
                wrapMode:         Text.WordWrap
                font.pointSize:   ScreenTools.smallFontPointSize
                font.family:      ScreenTools.normalFontFamily
                color:            control._bodyColor
                visible:          headingDescription !== ""
            }
        }
    }

    Rectangle {
        id:                 outerRect
        Layout.fillWidth:   true
        implicitWidth:      _contentLayout.implicitWidth + _contentPad * 2 + _margins * 2
        implicitHeight:     _contentLayout.implicitHeight + _margins * 2
        color:              control._cardFill
        border.color:       outerBorderColor
        border.width:       showBorder ? 1 : 0
        radius:             ScreenTools.defaultFontPixelWidth * 1.0

        Repeater {
            model: showDividers ? Math.max(0, _contentLayout.visibleChildren.length - 1) : 0

            Rectangle {
                x:                  _contentPad + _margins
                y:                  _contentLayout.y + _contentItem.y + _contentItem.height
                                    + _contentLayout.spacing * 0.5
                width:              parent.width - _contentPad * 2 - _margins * 2
                height:             1
                color:              control._dividerColor

                property var _contentItem: _contentLayout.visibleChildren[index]
            }
        }

        ColumnLayout {
            id:                 _contentLayout
            x:                  _contentPad + _margins
            y:                  _margins
            width:              parent.width - _contentPad * 2 - _margins * 2
            spacing:            _margins * (showDividers ? 1.45 : 0.95)
        }
    }
}
