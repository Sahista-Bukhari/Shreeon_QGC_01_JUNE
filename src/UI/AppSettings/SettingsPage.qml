import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

Item {
    id: root

    default property alias contentItem: mainLayout.data

    readonly property bool  _darkTheme:       settingsPagePalette.globalTheme === QGCPalette.Dark
    readonly property color _pageBackground: _darkTheme ? settingsPagePalette.window : "#FFFFFF"
    readonly property color _accentGreen:    "#00a04c"
    readonly property color _scrollTrack:    _darkTheme ? settingsPagePalette.windowShade : "#F1F1F1"
    readonly property real  _pagePad:        ScreenTools.defaultFontPixelWidth * 2.2
    readonly property real  _maxContentWidth: ScreenTools.defaultFontPixelWidth * 92

    QGCPalette {
        id:                settingsPagePalette
        colorGroupEnabled: root.enabled
    }

    Rectangle {
        anchors.fill: parent
        color:        root._pageBackground
    }

    QGCFlickable {
        id:                 settingsFlickable
        anchors.fill:       parent
        contentWidth:       width
        contentHeight:      mainLayout.implicitHeight + root._pagePad * 2
        flickableDirection: Flickable.VerticalFlick
        clip:               true

        ScrollBar.vertical: ScrollBar {
            policy:        settingsFlickable.contentHeight > settingsFlickable.height
                           ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
            width:         Math.max(7, ScreenTools.defaultFontPixelWidth * 0.7)
            topPadding:    root._pagePad * 0.5
            bottomPadding: topPadding
            leftPadding:   2
            rightPadding:  2

            background: Rectangle {
                radius: parent.width / 2
                color:  root._scrollTrack
            }

            contentItem: Rectangle {
                radius: width / 2
                color:  root._accentGreen
            }
        }

        ColumnLayout {
            id:      mainLayout
            x:       Math.round((settingsFlickable.width - width) / 2)
            y:       root._pagePad
            width:   Math.max(0, Math.min(root._maxContentWidth,
                                          settingsFlickable.width - root._pagePad * 2))
            spacing: ScreenTools.defaultFontPixelHeight * 1.2
        }
    }
}
