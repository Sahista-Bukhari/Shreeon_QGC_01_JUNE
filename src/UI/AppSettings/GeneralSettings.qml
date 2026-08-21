import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

SettingsPage {
    property var    _settingsManager:           QGroundControl.settingsManager
    property var    _appSettings:               _settingsManager.appSettings
    property Fact   _appFontPointSize:          _appSettings.appFontPointSize

    SettingsGroupLayout {
        Layout.fillWidth:   true
        heading:            qsTr("General")

        LabelledFactComboBox {
            label:      qsTr("Language")
            fact:       _appSettings.qLocaleLanguage
            indexModel: false
            visible:    _appSettings.qLocaleLanguage.visible
        }

        LabelledFactComboBox {
            label:      qsTr("Color Scheme")
            fact:       _appSettings.indoorPalette
            indexModel: false
            visible:    _appSettings.indoorPalette.visible
        }

        LabelledFactComboBox {
            label:       qsTr("Stream GCS Position")
            fact:       _appSettings.followTarget
            indexModel: false
            visible:    _appSettings.followTarget.visible
        }

        FactCheckBoxSlider {
            Layout.fillWidth: true
            text:           qsTr("Mute all audio output")
            fact:       _audioMuted
            visible:    _audioMuted.visible
            property Fact _audioMuted: _appSettings.audioMuted
        }

        FactCheckBoxSlider {
            Layout.fillWidth: true
            text:       fact.shortDescription
            fact:       _appSettings.androidDontSaveToSDCard
            visible:    fact.visible
        }

        QGCCheckBoxSlider {
            Layout.fillWidth: true
            text:       qsTr("Clear all settings on next start")
            checked:    false
            onClicked: {
                if (checked) {
                    QGroundControl.deleteAllSettingsNextBoot()
                } else {
                    QGroundControl.clearDeleteAllSettingsNextBoot()
                }
            }
        }

        RowLayout {
            Layout.fillWidth:   true
            spacing:            ScreenTools.defaultFontPixelWidth * 2
            visible:            _appFontPointSize.visible

            QGCLabel {
                Layout.fillWidth:   true
                text:               qsTr("UI Scaling")
            }

            RowLayout {
                spacing: ScreenTools.defaultFontPixelWidth * 2

                Rectangle {
                    id:                     minusBtn
                    Layout.preferredWidth:  height
                    height:                 baseFontEdit.height * 1.5
                    radius:                 height / 2
                    color:                  minusMouse.containsMouse ? "#00a04c" : "#ffffff"
                    border.width:           1
                    border.color:           minusMouse.containsMouse ? "#00a04c" : "#E5E5E5"

                    Behavior on color { ColorAnimation { duration: 120 } }

                    QGCLabel {
                        anchors.centerIn:   parent
                        text:               "-"
                        color:              minusMouse.containsMouse ? "#ffffff" : "#1C1C1E"
                        font.pointSize:     ScreenTools.largeFontPointSize
                        font.weight:        Font.DemiBold
                    }

                    MouseArea {
                        id:             minusMouse
                        anchors.fill:   parent
                        hoverEnabled:   true
                        cursorShape:    Qt.PointingHandCursor
                        onClicked: {
                            if (_appFontPointSize.value > _appFontPointSize.min) {
                                _appFontPointSize.value = _appFontPointSize.value - 1
                            }
                        }
                    }
                }

                QGCLabel {
                    id:                     baseFontEdit
                    width:                  ScreenTools.defaultFontPixelWidth * 6
                    horizontalAlignment:    Text.AlignHCenter
                    text:                   (QGroundControl.settingsManager.appSettings.appFontPointSize.value / ScreenTools.platformFontPointSize * 100).toFixed(0) + "%"
                }

                Rectangle {
                    id:                     plusBtn
                    Layout.preferredWidth:  height
                    height:                 baseFontEdit.height * 1.5
                    radius:                 height / 2
                    color:                  plusMouse.containsMouse ? "#00a04c" : "#ffffff"
                    border.width:           1
                    border.color:           plusMouse.containsMouse ? "#00a04c" : "#E5E5E5"

                    Behavior on color { ColorAnimation { duration: 120 } }

                    QGCLabel {
                        anchors.centerIn:   parent
                        text:               "+"
                        color:              plusMouse.containsMouse ? "#ffffff" : "#1C1C1E"
                        font.pointSize:     ScreenTools.largeFontPointSize
                        font.weight:        Font.DemiBold
                    }

                    MouseArea {
                        id:             plusMouse
                        anchors.fill:   parent
                        hoverEnabled:   true
                        cursorShape:    Qt.PointingHandCursor
                        onClicked: {
                            if (_appFontPointSize.value < _appFontPointSize.max) {
                                _appFontPointSize.value = _appFontPointSize.value + 1
                            }
                        }
                    }
                }
            }
        }
    }

    SettingsGroupLayout {
        Layout.fillWidth:   true
        heading:            qsTr("Units")
        visible:            QGroundControl.settingsManager.unitsSettings.visible

        Repeater {
            model: [ QGroundControl.settingsManager.unitsSettings.horizontalDistanceUnits, QGroundControl.settingsManager.unitsSettings.verticalDistanceUnits, QGroundControl.settingsManager.unitsSettings.areaUnits, QGroundControl.settingsManager.unitsSettings.speedUnits, QGroundControl.settingsManager.unitsSettings.temperatureUnits ]

            LabelledFactComboBox {
                label:                  modelData.shortDescription
                fact:                   modelData
                indexModel:             false
            }
        }
    }
}
