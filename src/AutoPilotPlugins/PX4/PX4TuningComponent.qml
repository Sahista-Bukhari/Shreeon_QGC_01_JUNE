import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

ColumnLayout {
    id:         root
    spacing:    ScreenTools.defaultFontPixelWidth / 4

    property var model

    property real _availableHeight: availableHeight
    property real _availableWidth:  availableWidth

    readonly property real _contentInset: ScreenTools.defaultFontPixelWidth * 2.2
    readonly property color _dividerColor: qgcPal.globalTheme === QGCPalette.Dark
                                              ? qgcPal.windowShade
                                              : "#E5E5E5"

    QGCPalette {
        id: qgcPal
    }

    FactPanelController {
        id:         controller
    }

    QGCComboBox {
        id:                    controllerSelector
        Layout.leftMargin:     root._contentInset
        Layout.preferredWidth: Math.min(Math.max(0, root._availableWidth - (root._contentInset * 2)),
                                        ScreenTools.defaultFontPixelWidth * 32)
        model:                 root.model
        textRole:              "buttonText"
    }

    Rectangle {
        Layout.fillWidth:       true
        Layout.preferredHeight: 1
        Layout.leftMargin:      root._contentInset
        Layout.rightMargin:     root._contentInset
        Layout.topMargin:       ScreenTools.defaultFontPixelHeight * 0.5
        Layout.bottomMargin:    ScreenTools.defaultFontPixelHeight * 0.5
        color:                  root._dividerColor
    }

    Loader {
        id:     loader
        source: model.get(controllerSelector.currentIndex).tuningPage

        property bool useAutoTuning:    true
        property real availableWidth:   _availableWidth
        property real availableHeight:  _availableHeight - loader.y
    }
}
