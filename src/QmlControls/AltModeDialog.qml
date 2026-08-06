import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

QGCPopupDialog {
    title:   qsTr("Altitude Mode")
    buttons: Dialog.Close
    minimumContentHeight: ScreenTools.defaultFontPixelHeight * 12

    property var rgRemoveModes
    property var updateAltModeFn
    property var currentAltMode

    Component.onCompleted: {
        // Check for custom build override on AMSL usage
        if (!QGroundControl.corePlugin.options.showMissionAbsoluteAltitude && currentAltMode != QGroundControl.AltitudeModeAbsolute) {
            rgRemoveModes.push(QGroundControl.AltitudeModeAbsolute)
        }

        // Remove modes specified by consumer
        for (var i=0; i<rgRemoveModes.length; i++) {
            for (var j=0; j<buttonModel.count; j++) {
                if (buttonModel.get(j).modeValue == rgRemoveModes[i]) {
                    buttonModel.remove(j)
                    break
                }
            }
        }

        buttonRepeater.model = buttonModel
    }

    ListModel {
        id: buttonModel

        ListElement {
            modeName:   qsTr("Relative")
            help:       qsTr("Altitude above home position")
            modeValue:  QGroundControl.AltitudeModeRelative
        }
        ListElement {
            modeName:   qsTr("Absolute")
            help:       qsTr("Altitude above mean sea level (AMSL)")
            modeValue:  QGroundControl.AltitudeModeAbsolute
        }
        ListElement {
            modeName:   qsTr("Terrain")
            help:       qsTr("Altitude above terrain at waypoint")
            modeValue:  QGroundControl.AltitudeModeTerrainFrame
        }
        ListElement {
            modeName:   qsTr("Terrain Calculated")
            help:       qsTr("Altitudes are terrain-relative; converting to AMSL before upload")
            modeValue:  QGroundControl.AltitudeModeCalcAboveTerrain
        }
        ListElement {
            modeName:   qsTr("Waypoint Defined")
            help:       qsTr("Each waypoint specifies its own altitude mode")
            modeValue:  QGroundControl.AltitudeModeMixed
        }
    }

    Column {
        width:      parent ? parent.width : implicitWidth
        spacing:    ScreenTools.defaultFontPixelHeight * 0.55

        QGCLabel {
            width:               parent.width
            text:                qsTr("Altitude mode for mission items")
            font.pointSize:      ScreenTools.smallFontPointSize
            horizontalAlignment: Text.AlignHCenter
            color:               "#3f3f3f"
        }

        Repeater {
            id: buttonRepeater

            Button {
                hoverEnabled:   true
                checked:        modeValue == currentAltMode
                width:          parent.width
                leftPadding:    ScreenTools.defaultFontPixelWidth
                rightPadding:   ScreenTools.defaultFontPixelWidth
                topPadding:     ScreenTools.defaultFontPixelHeight * 0.35
                bottomPadding:  ScreenTools.defaultFontPixelHeight * 0.35

                background: Rectangle {
                    radius: ScreenTools.defaultFontPixelHeight / 2
                    color:  pressed | hovered | checked ? QGroundControl.globalPalette.buttonHighlight: QGroundControl.globalPalette.button
                }

                contentItem: Column {
                    width:   parent.width
                    spacing: ScreenTools.defaultFontPixelHeight * 0.05

                    QGCLabel {
                        id:                  modeNameLabel
                        width:               parent.width
                        text:                modeName
                        color:               pressed | hovered | checked ? QGroundControl.globalPalette.buttonHighlightText: QGroundControl.globalPalette.buttonText
                        horizontalAlignment: Text.AlignLeft
                    }

                    QGCLabel {
                        width:              parent.width
                        text:               help
                        wrapMode:           Label.WordWrap
                        font.pointSize:     ScreenTools.smallFontPointSize
                        color:              modeNameLabel.color
                    }
                }

                onClicked: {
                    updateAltModeFn(modeValue)
                    close()
                }
            }
        }
    }
}
