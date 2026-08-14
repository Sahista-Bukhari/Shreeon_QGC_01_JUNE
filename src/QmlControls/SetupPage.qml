import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

/// Base view control for all Setup pages
Item {
    id:             setupView
    enabled:        !_disableDueToArmed && !_disableDueToFlying

    property alias  pageComponent:          pageLoader.sourceComponent
    property string pageName:               vehicleComponent ? vehicleComponent.name : ""
    property string pageDescription:        vehicleComponent ? vehicleComponent.description : ""
    property real   availableWidth:         width - pageLoader.x
    property real   availableHeight:        height - pageLoader.y
    property bool   showAdvanced:           false
    property alias  advanced:               advancedCheckBox.checked

    property bool   _vehicleIsRover:        globals.activeVehicle ? globals.activeVehicle.rover : false
    property bool   _vehicleArmed:          globals.activeVehicle ? globals.activeVehicle.armed : false
    property bool   _vehicleFlying:         globals.activeVehicle ? globals.activeVehicle.flying : false
    property bool   _disableDueToArmed:     vehicleComponent ? (!vehicleComponent.allowSetupWhileArmed && _vehicleArmed) : false
    // FIXME: The _vehicleIsRover checkl is a hack to work around https://github.com/PX4/Firmware/issues/10969
    property bool   _disableDueToFlying:    vehicleComponent ? (!_vehicleIsRover && !vehicleComponent.allowSetupWhileFlying && _vehicleFlying) : false
    property string _disableReason:         _disableDueToArmed ? qsTr("armed") : qsTr("flying")
    property real   _margins:               ScreenTools.defaultFontPixelHeight * 0.3
    property string _pageTitle:             qsTr("%1 Config").arg(pageName)

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }
    readonly property color _titleColor: qgcPal.globalTheme === QGCPalette.Dark ? "#AEAEB2" : "#3A3A3C"
    readonly property color _bodyColor:  qgcPal.globalTheme === QGCPalette.Dark ? "#8E8E93" : "#3A3A3C"

    Component.onCompleted: {
        if(pageLoader.item && pageLoader.item.setupPageCompleted) {
            pageLoader.item.setupPageCompleted()
        }
    }

    QGCFlickable {
        anchors.fill:   parent
        contentWidth:   width
        contentHeight:  Math.max(availableHeight, pageLoader.y + (pageLoader.item ? pageLoader.item.height : 0))
        clip:           true

        ColumnLayout {
            id:                 headingRow
            anchors.top:        parent.top
            anchors.topMargin:  ScreenTools.defaultFontPixelHeight * 0.3
            width:              availableWidth
            spacing:            ScreenTools.defaultFontPixelHeight * 1.15
            visible:            showAdvanced || (pageDescription !== "" && !ScreenTools.isShortScreen)

            RowLayout {
                Layout.fillWidth:   true
                spacing:            _margins
                layoutDirection:    Qt.RightToLeft
                visible:            showAdvanced

                QGCCheckBox {
                    id:         advancedCheckBox
                    text:       qsTr("Advanced")
                    textColor:  setupView._titleColor
                    visible:    showAdvanced
                }

                Item { Layout.fillWidth: true }
            }

            QGCLabel {
                Layout.fillWidth:   true
                font.pointSize:     ScreenTools.mediumFontPointSize
                font.bold:          true
                font.family:        ScreenTools.normalFontFamily
                color:              setupView._titleColor
                text:               !setupView.enabled ? _pageTitle + "<font color=\"red\">" + qsTr(" (Disabled while the vehicle is %1)").arg(_disableReason) + "</font>" : _pageTitle
                visible:            !ScreenTools.isShortScreen
            }

            QGCLabel {
                Layout.fillWidth:   true
                wrapMode:           Text.WordWrap
                font.pointSize:     ScreenTools.smallFontPointSize
                font.family:        ScreenTools.normalFontFamily
                color:              setupView._bodyColor
                text:               pageDescription
                visible:            pageDescription !== "" && !ScreenTools.isShortScreen
            }
        }

        Loader {
            id:                 pageLoader
            anchors.topMargin:  ScreenTools.defaultFontPixelHeight * 1.2
            anchors.top:        headingRow.bottom
            width:              availableWidth
        }

        // Overlay to display when vehicle is armed and this setup page needs
        // to be disabled
        Rectangle {
            visible:            !setupView.enabled
            anchors.fill:       parent
            color:              "black"
            opacity:            0.5
        }
    }
}
