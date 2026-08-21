import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Button {
    id:                 control
    autoExclusive:      true
    leftPadding:        ScreenTools.defaultFontPixelWidth
    rightPadding:       leftPadding
    implicitHeight:     Math.max(ScreenTools.implicitButtonHeight, ScreenTools.defaultFontPixelHeight * 2.2)
    focusPolicy:        Qt.ClickFocus
    hoverEnabled:       !ScreenTools.isMobile

    property real _compIDWidth: ScreenTools.defaultFontPixelWidth * 3
    property real _hzWidth:     ScreenTools.defaultFontPixelWidth * 6
    property real _nameWidth:   nameLabel.contentWidth

    readonly property bool _darkTheme: {
        if (typeof mainWindow !== "undefined" && mainWindow)
            return mainWindow.uiThemeMode === mainWindow.themeBlack
        return buttonPalette.globalTheme === QGCPalette.Dark
    }
    readonly property color _titleColor:   _darkTheme ? "#AEAEB2" : "#3A3A3C"
    readonly property color _bodyColor:    _darkTheme ? "#8E8E93" : "#3A3A3C"
    readonly property color _idleFill:     _darkTheme ? buttonPalette.window : "#FFFFFF"
    readonly property color _idleBorder:   _darkTheme ? buttonPalette.windowShade : "#E6E6E6"
    readonly property color _selectedFill: Qt.rgba(0, 160 / 255, 76 / 255, _darkTheme ? 0.16 : 0.08)
    readonly property color _accentGreen:  "#00a04c"

    QGCPalette {
        id:                buttonPalette
        colorGroupEnabled: control.enabled
    }

    background: Rectangle {
        anchors.fill: parent
        radius:       ScreenTools.defaultBorderRadius * 2
        border.width: 1
        border.color: control.checked ? control._accentGreen : control._idleBorder
        color: {
            if (control.checked || control.down || control.hovered)
                return control._selectedFill
            return control._idleFill
        }
    }

    property double messageHz:  0
    property int    compID:     0

    contentItem: RowLayout {
        id:         rowLayout
        spacing:    ScreenTools.defaultFontPixelWidth

        QGCLabel {
            text:                   control.compID
            color:                  checked ? control._accentGreen : control._bodyColor
            verticalAlignment:      Text.AlignVCenter
            Layout.minimumHeight:   ScreenTools.isMobile ? (ScreenTools.defaultFontPixelHeight * 2) : (ScreenTools.defaultFontPixelHeight * 1.5)
            Layout.minimumWidth:    _compIDWidth
        }
        QGCLabel {
            id:                     nameLabel
            text:                   control.text
            color:                  checked ? control._accentGreen : control._titleColor
            font.weight:            checked ? Font.DemiBold : Font.Normal
            Layout.fillWidth:       true
            Layout.alignment:       Qt.AlignVCenter
            elide:                  Text.ElideRight
        }
        QGCLabel {
            color:                  checked ? control._accentGreen : control._bodyColor
            text:                   messageHz.toFixed(1) + 'Hz'
            horizontalAlignment:    Text.AlignRight
            Layout.minimumWidth:    _hzWidth
            Layout.alignment:       Qt.AlignVCenter
        }
    }

    Component.onCompleted: maxButtonWidth = Math.max(maxButtonWidth, _compIDWidth + _hzWidth + _nameWidth + (rowLayout.spacing * 2) + (control.leftPadding * 2))
}
