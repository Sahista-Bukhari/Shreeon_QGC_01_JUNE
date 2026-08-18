import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

Item {
    id: root
    width:  parent ? parent.width : implicitWidth
    height: parent ? parent.height : implicitHeight

    property var  _switchNameList:  [ "RC_MAP_ARM_SW", "RC_MAP_GEAR_SW", "RC_MAP_KILL_SW", "RC_MAP_LOITER_SW", "RC_MAP_OFFB_SW", "RC_MAP_RETURN_SW" ]
    property var  _switchTHList:    [ "RC_ARMSWITCH_TH", "RC_GEAR_TH", "RC_KILLSWITCH_TH", "RC_LOITER_TH", "RC_OFFB_TH", "RC_RETURN_TH" ]

    readonly property real  _pageHPad:          ScreenTools.defaultFontPixelWidth * 2.2
    readonly property real  _sectionGap:        ScreenTools.defaultFontPixelHeight * 1.15
    readonly property real  _titlePointSize:    ScreenTools.defaultFontPointSize + 1
    readonly property real  _labelPointSize:    ScreenTools.defaultFontPointSize
    readonly property color _titleColor:        qgcPal.globalTheme === QGCPalette.Dark ? "#AEAEB2" : "#3A3A3C"
    readonly property color _grayCard:          qgcPal.globalTheme === QGCPalette.Dark ? qgcPal.windowShade : "#F2F2F2"
    readonly property real  _cardPad:           ScreenTools.defaultFontPixelHeight * 0.7
    readonly property real  _cardRadius:        ScreenTools.defaultFontPixelWidth * 0.75
    readonly property color _dividerColor:      qgcPal.globalTheme === QGCPalette.Dark ? qgcPal.windowShade : "#EFEFEF"
    readonly property real  _comboWidth:        Math.min(ScreenTools.defaultFontPixelWidth * 15,
                                                         Math.max(ScreenTools.defaultFontPixelWidth * 11, root.width * 0.42))

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

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

    component HeadingLabel: QGCLabel {
        color:          root._titleColor
        font.bold:      true
        font.pointSize: root._titlePointSize
        font.family:    ScreenTools.normalFontFamily
    }

    component SettingLabel: QGCLabel {
        color:          root._titleColor
        font.bold:      false
        font.pointSize: root._labelPointSize
        font.family:    ScreenTools.normalFontFamily
        elide:          Text.ElideRight
    }

    component SectionDivider: Rectangle {
        Layout.fillWidth:   true
        implicitHeight:     1
        color:              root._dividerColor
    }

    QGCFlickable {
        anchors.fill:       parent
        clip:               true
        contentWidth:       width
        contentHeight:      mainColumn.height + ScreenTools.defaultFontPixelHeight
        flickableDirection: Flickable.VerticalFlick

        ColumnLayout {
            id:         mainColumn
            width:      parent.width
            spacing:    root._sectionGap

            Rectangle {
                Layout.fillWidth:       true
                Layout.leftMargin:      root._pageHPad
                Layout.rightMargin:     root._pageHPad
                Layout.topMargin:       ScreenTools.defaultFontPixelHeight * 0.15
                implicitHeight:         modeColumn.height + root._cardPad * 2
                radius:                 root._cardRadius
                color:                  root._grayCard

                ColumnLayout {
                    id:                 modeColumn
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    anchors.top:        parent.top
                    anchors.margins:    root._cardPad
                    spacing:            ScreenTools.defaultFontPixelHeight * 0.55

                    RowLayout {
                        Layout.fillWidth:   true
                        spacing:            ScreenTools.defaultFontPixelWidth * 0.9

                        SettingLabel {
                            Layout.fillWidth:   true
                            text:               qsTr("Mode Channel")
                        }

                        FactComboBox {
                            Layout.preferredWidth:  root._comboWidth
                            Layout.maximumWidth:    root._comboWidth
                            fact:                   controller.getParameterFact(-1, "RC_MAP_FLTMODE")
                            indexModel:             false
                            sizeToContents:         false
                        }
                    }

                    Repeater {
                        model: 6

                        RowLayout {
                            Layout.fillWidth:   true
                            spacing:            ScreenTools.defaultFontPixelWidth * 0.9

                            SettingLabel {
                                Layout.fillWidth:   true
                                text:               qsTr("Flight Mode %1").arg(index + 1)
                                color:              (controller.activeFlightMode - 1) == index ? qgcPal.colorGreen : root._titleColor
                            }

                            FactComboBox {
                                Layout.preferredWidth:  root._comboWidth
                                Layout.maximumWidth:    root._comboWidth
                                fact:                   controller.getParameterFact(-1, "COM_FLTMODE" + (index + 1))
                                indexModel:             false
                                sizeToContents:         false
                            }
                        }
                    }
                }
            }

            SectionDivider { }

            HeadingLabel {
                Layout.leftMargin:  root._pageHPad
                text:               qsTr("Switch Settings")
            }

            Rectangle {
                Layout.fillWidth:       true
                Layout.leftMargin:      root._pageHPad
                Layout.rightMargin:     root._pageHPad
                implicitHeight:         switchColumn.height + root._cardPad * 2
                radius:                 root._cardRadius
                color:                  root._grayCard

                ColumnLayout {
                    id:                 switchColumn
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    anchors.top:        parent.top
                    anchors.margins:    root._cardPad
                    spacing:            ScreenTools.defaultFontPixelHeight * 0.55

                    Repeater {
                        id: switchRepeater

                        RowLayout {
                            Layout.fillWidth:   true
                            spacing:            ScreenTools.defaultFontPixelWidth * 0.9

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

                            SettingLabel {
                                Layout.fillWidth:   true
                                text:               swFact.shortDescription
                                color:              swActive ? qgcPal.colorGreen : root._titleColor
                            }

                            FactComboBox {
                                Layout.preferredWidth:  root._comboWidth
                                Layout.maximumWidth:    root._comboWidth
                                fact:                   swFact
                                indexModel:             false
                                sizeToContents:         false
                            }
                        }
                    }
                }
            }

            SectionDivider { }

            RCChannelMonitor {
                Layout.fillWidth:    true
                Layout.leftMargin:   root._pageHPad
                Layout.rightMargin:  root._pageHPad
                twoColumn:           true
            }
        }
    }
}
