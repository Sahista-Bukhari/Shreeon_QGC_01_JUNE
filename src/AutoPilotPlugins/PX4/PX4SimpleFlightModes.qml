import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

Item {
    id: root
    width:  parent ? parent.width : implicitWidth
    height: flickable.contentHeight

    property real _margins:         ScreenTools.defaultFontPixelHeight * 0.3
    property var  _switchNameList:  [ "RC_MAP_ARM_SW", "RC_MAP_GEAR_SW", "RC_MAP_KILL_SW", "RC_MAP_LOITER_SW", "RC_MAP_OFFB_SW", "RC_MAP_RETURN_SW" ]
    property var  _switchTHList:    [ "RC_ARMSWITCH_TH", "RC_GEAR_TH", "RC_KILLSWITCH_TH", "RC_LOITER_TH", "RC_OFFB_TH", "RC_RETURN_TH" ]

    readonly property real _comboWidth: Math.min(ScreenTools.defaultFontPixelWidth * 12,
                                                 Math.max(ScreenTools.defaultFontPixelWidth * 9, root.width * 0.38))

    Component.onCompleted: {
        if (controller.vehicle.vtol) {
            _switchNameList.push("RC_MAP_TRANS_SW")
            _switchTHList.push("RC_TRANS_TH")
        }
        if (controller.vehicle.fixedWing) {
            _switchNameList.push("RC_MAP_FLAPS")
            _switchTHList.push("")
        }
        switchRepeater.model = _switchNameList
    }

    PX4SimpleFlightModesController {
        id: controller
    }

    QGCFlickable {
        id:                 flickable
        anchors.fill:       parent
        clip:               true
        contentWidth:       width
        contentHeight:      mainColumn.height
        flickableDirection: Flickable.VerticalFlick

        ColumnLayout {
            id:         mainColumn
            width:      flickable.width
            spacing:    _margins

            QGCLabel {
                text:       qsTr("Flight Mode Settings")
                font.bold:  true
                font.pointSize: ScreenTools.smallFontPointSize
            }

            Rectangle {
                Layout.fillWidth:           true
                Layout.preferredHeight:     flightModeColumn.height + _margins * 2
                color:                      qgcPal.windowShade
                radius:                     2

                ColumnLayout {
                    id:                 flightModeColumn
                    anchors.margins:    _margins
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    anchors.top:        parent.top
                    spacing:            ScreenTools.defaultFontPixelHeight * 0.2

                    RowLayout {
                        Layout.fillWidth:   true
                        spacing:            ScreenTools.defaultFontPixelWidth * 0.6

                        QGCLabel {
                            Layout.fillWidth:   true
                            text:               qsTr("Mode Channel")
                            elide:              Text.ElideRight
                            font.pointSize:     ScreenTools.smallFontPointSize
                        }

                        FactComboBox {
                            Layout.preferredWidth:  _comboWidth
                            Layout.maximumWidth:    _comboWidth
                            fact:                   controller.getParameterFact(-1, "RC_MAP_FLTMODE")
                            indexModel:             false
                            sizeToContents:         false
                            compact:                true
                        }
                    }

                    Repeater {
                        model: 6

                        RowLayout {
                            Layout.fillWidth:   true
                            spacing:            ScreenTools.defaultFontPixelWidth * 0.6

                            QGCLabel {
                                Layout.fillWidth:   true
                                text:               qsTr("Flight Mode %1").arg(index + 1)
                                color:              (controller.activeFlightMode - 1) == index ? "yellow" : qgcPal.text
                                elide:              Text.ElideRight
                                font.pointSize:     ScreenTools.smallFontPointSize
                            }

                            FactComboBox {
                                Layout.preferredWidth:  _comboWidth
                                Layout.maximumWidth:    _comboWidth
                                fact:                   controller.getParameterFact(-1, "COM_FLTMODE" + (index + 1))
                                indexModel:             false
                                sizeToContents:         false
                                compact:                true
                            }
                        }
                    }
                }
            }

            QGCLabel {
                Layout.topMargin:   _margins * 0.4
                text:               qsTr("Switch Settings")
                font.bold:          true
                font.pointSize:     ScreenTools.smallFontPointSize
            }

            Rectangle {
                Layout.fillWidth:           true
                Layout.preferredHeight:     switchColumn.height + _margins * 2
                color:                      qgcPal.windowShade
                radius:                     2

                ColumnLayout {
                    id:                 switchColumn
                    anchors.margins:    _margins
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    anchors.top:        parent.top
                    spacing:            ScreenTools.defaultFontPixelHeight * 0.2

                    Repeater {
                        id: switchRepeater

                        RowLayout {
                            Layout.fillWidth:   true
                            spacing:            ScreenTools.defaultFontPixelWidth * 0.6

                            property string thFactName:     _switchTHList[index]
                            property bool   thFactExists:   thFactName !== ""
                            property Fact   swFact:         controller.getParameterFact(-1, modelData)
                            property Fact   thFact:         thFactExists ? controller.getParameterFact(-1, thFactName) : null
                            property real   thValue:        thFactExists ? thFact.rawValue : 0.5
                            property real   thPWM:          1000 + (1000 * thValue)
                            property int    swChannel:      swFact.rawValue - 1
                            property bool   swActive:       swChannel < 0 ?
                                                                false :
                                                                (thValue >= 0 ?
                                                                     (controller.rcChannelValues[swChannel] > thPWM) :
                                                                     (controller.rcChannelValues[swChannel] <= thPWM))

                            QGCLabel {
                                Layout.fillWidth:   true
                                text:               swFact.shortDescription
                                color:              swActive ? "yellow" : qgcPal.text
                                elide:              Text.ElideRight
                                font.pointSize:     ScreenTools.smallFontPointSize
                            }

                            FactComboBox {
                                Layout.preferredWidth:  _comboWidth
                                Layout.maximumWidth:    _comboWidth
                                fact:                   swFact
                                indexModel:             false
                                sizeToContents:         false
                                compact:                true
                            }
                        }
                    }
                }
            }

            RCChannelMonitor {
                Layout.fillWidth:   true
                twoColumn:          true
            }
        }
    }
}
