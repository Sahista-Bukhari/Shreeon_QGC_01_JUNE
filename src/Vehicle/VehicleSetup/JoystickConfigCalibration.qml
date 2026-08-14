import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Item {
    height:                 calCol.height + ScreenTools.defaultFontPixelHeight * 2
    width:                  calCol.width  + ScreenTools.defaultFontPixelWidth  * 2
    Column {
        id:                 calCol
        spacing:            ScreenTools.defaultFontPixelHeight
        anchors.centerIn:   parent
        Item {
            height:         1
            width:          1
        }
        Row {
            spacing:            ScreenTools.defaultFontPixelWidth * 4
            anchors.horizontalCenter: parent.horizontalCenter
            //-----------------------------------------------------------------
            // Calibration stick guide (native QGC: green marker shows where to move)
            Column {
                id:                 calSticksCol
                spacing:            ScreenTools.defaultFontPixelHeight
                anchors.verticalCenter: parent.verticalCenter

                QGCPalette { id: qgcPal; colorGroupEnabled: true }
                readonly property bool  _darkTheme:   qgcPal.globalTheme === QGCPalette.Dark
                readonly property color _titleColor:  _darkTheme ? "#AEAEB2" : "#3A3A3C"
                readonly property color _accentGreen: qgcPal.colorGreen

                function _calX(pos, center) {
                    return Math.max(-1, Math.min(1, (pos - center) / 0.096))
                }
                function _calY(pos) {
                    return Math.max(-1, Math.min(1, (0.5 - pos) / 0.192))
                }

                Row {
                    spacing: ScreenTools.defaultFontPixelWidth * 1.6
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: controller.stickPositions.length === 4

                    JoystickRadial {
                        joystickTitle: qsTr("Joystick 1")
                        stickX: calSticksCol._calX(controller.stickPositions[0], 0.25)
                        stickY: calSticksCol._calY(controller.stickPositions[1])
                        darkTheme: calSticksCol._darkTheme
                        accentGreen: calSticksCol._accentGreen
                        titleColor: calSticksCol._titleColor
                    }

                    JoystickRadial {
                        joystickTitle: qsTr("Joystick 2")
                        stickX: calSticksCol._calX(controller.stickPositions[2], 0.75)
                        stickY: calSticksCol._calY(controller.stickPositions[3])
                        darkTheme: calSticksCol._darkTheme
                        accentGreen: calSticksCol._accentGreen
                        titleColor: calSticksCol._titleColor
                    }
                }
            }
            //---------------------------------------------------------------------
            // Monitor
            Column {
                spacing:            ScreenTools.defaultFontPixelHeight * 0.5
                anchors.verticalCenter: parent.verticalCenter
                Connections {
                    target: controller
                    onAxisValueChanged: (axis, value) => {
                        if (axisMonitorRepeater.itemAt(axis)) {
                            axisMonitorRepeater.itemAt(axis).axis.axisValue = value
                        }
                    }
                    onAxisDeadbandChanged: (axis, value) => {
                        if (axisMonitorRepeater.itemAt(axis)) {
                            axisMonitorRepeater.itemAt(axis).axis.deadbandValue = value
                        }
                    }
                }
                Repeater {
                    id:             axisMonitorRepeater
                    model:          _activeJoystick ? _activeJoystick.axisCount : 0
                    width:          parent.width
                    Row {
                        spacing:    5
                        anchors.horizontalCenter: parent.horizontalCenter
                        // Need this to get to loader from Connections above
                        property Item axis: theAxis
                        QGCLabel {
                            id:     axisLabel
                            text:   modelData
                        }
                        AxisMonitor {
                            id:                     theAxis
                            anchors.verticalCenter: axisLabel.verticalCenter
                            height:                 ScreenTools.defaultFontPixelHeight
                            width:                  200
                            narrowIndicator:        true
                            mapped:                 true
                            reversed:               false
                            MouseArea {
                                id:                 deadbandMouseArea
                                anchors.fill:       parent.item
                                enabled:            controller.deadbandToggle
                                preventStealing:    true
                                property real startX
                                property real direction
                                onPressed: (mouse) => {
                                    startX = mouseX
                                    direction = startX > width/2 ? 1 : -1
                                    parent.item.deadbandColor = "#3C6315"
                                }
                                onPositionChanged: {
                                    var mouseToDeadband = 32768/(width/2) // Factor to have deadband follow the mouse movement
                                    var newValue = parent.item.deadbandValue + direction*(mouseX - startX)*mouseToDeadband
                                    if ((newValue > 0) && (newValue <32768)){parent.item.deadbandValue=newValue;}
                                    startX = mouseX
                                }
                                onReleased: {
                                    controller.setDeadbandValue(modelData,parent.item.deadbandValue)
                                    parent.item.deadbandColor = "#8c161a"
                                }
                            }
                        }
                    }
                }
            }
        }
        // Command Buttons
        Row {
            spacing:            ScreenTools.defaultFontPixelWidth * 2
            visible:            _activeJoystick && _activeJoystick.requiresCalibration
            anchors.horizontalCenter: parent.horizontalCenter
            QGCButton {
                id:         skipButton
                text:       qsTr("Skip")
                enabled:    controller.calibrating ? controller.skipEnabled : false
                width:      ScreenTools.defaultFontPixelWidth * 10
                onClicked:  controller.skipButtonClicked()
            }
            QGCButton {
                text:       qsTr("Cancel")
                width:      ScreenTools.defaultFontPixelWidth * 10
                enabled:    controller.calibrating
                onClicked: {
                    if(controller.calibrating)
                        controller.cancelButtonClicked()
                }
            }
            QGCButton {
                id:         nextButton
                primary:    true
                enabled:    controller.calibrating ? controller.nextEnabled : true
                text:       controller.calibrating ? qsTr("Next") : qsTr("Start")
                width:      ScreenTools.defaultFontPixelWidth * 10
                onClicked:  controller.nextButtonClicked()
            }
        }
        // Status Text
        QGCLabel {
            text:           controller.statusText
            width:          parent.width * 0.8
            wrapMode:       Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
