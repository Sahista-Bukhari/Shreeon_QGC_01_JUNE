import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

/// Base class for Remote Control Calibration (supports both RC and Joystick)
RowLayout {
    property Component additionalSetupComponent

    id: root
    spacing: ScreenTools.defaultFontPixelWidth

    property var _controller: controller

    ListModel {
        id: attitudeControlsModel

        Component.onCompleted: {
            attitudeControlsModel.append(
                {
                    name: qsTr("Roll"),
                    mapped: controller.rollChannelMapped,
                    reversed: controller.rollChannelReversed,
                    value: controller.rollChannelValue
                })
            attitudeControlsModel.append(
                {
                    name: qsTr("Pitch"),
                    mapped: controller.pitchChannelMapped,
                    reversed: controller.pitchChannelReversed,
                    value: controller.pitchChannelValue
                })
            attitudeControlsModel.append(
                {
                    name: qsTr("Yaw"),
                    mapped: controller.yawChannelMapped,
                    reversed: controller.yawChannelReversed,
                    value: controller.yawChannelValue
                })
            attitudeControlsModel.append(
                {
                    name: qsTr("Throttle"),
                    mapped: controller.throttleChannelMapped,
                    reversed: controller.throttleChannelReversed,
                    value: controller.throttleChannelValue
                })
        }
    }

    function setupPageCompleted() {
        controller.start()
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: root.enabled }

    readonly property bool _darkTheme: qgcPal.globalTheme === QGCPalette.Dark
    readonly property color _titleColor: _darkTheme ? "#AEAEB2" : "#3A3A3C"
    readonly property color _bodyColor:  _darkTheme ? "#8E8E93" : "#3A3A3C"
    readonly property color _accentGreen: qgcPal.colorGreen
    readonly property real  _sectionHPad: ScreenTools.defaultFontPixelWidth * 2.2

    function _pwmAxis(value, reversed) {
        var n = (value - 1500) / 500
        if (n > 1)
            n = 1
        else if (n < -1)
            n = -1
        if (Math.abs(n) < 0.08)
            n = 0
        return reversed ? -n : n
    }

    function _diagramOrLive(diagram, live) {
        return Math.abs(diagram) > 0 ? diagram : live
    }

    function _stickPos(index) {
        return (controller.stickDisplayPositions && controller.stickDisplayPositions.length > index)
               ? controller.stickDisplayPositions[index] : 0
    }

    readonly property real _leftStickX: {
        var live = (controller.transmitterMode === 3 || controller.transmitterMode === 4)
                   ? _pwmAxis(controller.rollChannelValue, controller.rollChannelReversed)
                   : _pwmAxis(controller.yawChannelValue, controller.yawChannelReversed)
        return _diagramOrLive(_stickPos(0), live)
    }
    readonly property real _leftStickY: {
        var live = (controller.transmitterMode === 1 || controller.transmitterMode === 3)
                   ? _pwmAxis(controller.pitchChannelValue, controller.pitchChannelReversed)
                   : _pwmAxis(controller.throttleChannelValue, controller.throttleChannelReversed)
        return _diagramOrLive(_stickPos(1), live)
    }
    readonly property real _rightStickX: {
        var live = (controller.transmitterMode === 3 || controller.transmitterMode === 4)
                   ? _pwmAxis(controller.yawChannelValue, controller.yawChannelReversed)
                   : _pwmAxis(controller.rollChannelValue, controller.rollChannelReversed)
        return _diagramOrLive(_stickPos(2), live)
    }
    readonly property real _rightStickY: {
        var live = (controller.transmitterMode === 1 || controller.transmitterMode === 3)
                   ? _pwmAxis(controller.throttleChannelValue, controller.throttleChannelReversed)
                   : _pwmAxis(controller.pitchChannelValue, controller.pitchChannelReversed)
        return _diagramOrLive(_stickPos(3), live)
    }

    RadioComponentController {
        id: controller
        statusText: statusText
        cancelButton: cancelButton
        nextButton: nextButton
        skipButton: skipButton
        onThrottleReversedCalFailure: mainWindow.showMessageDialog(qsTr("Throttle channel reversed"), qsTr("Calibration failed. The throttle channel on your transmitter is reversed. You must correct this on your transmitter in order to complete calibration."))
    }

    ColumnLayout {
        id: leftColumnLayout
        Layout.alignment: Qt.AlignTop
        spacing: 10

        ColumnLayout {
            Layout.fillWidth:   true
            Layout.leftMargin:  root._sectionHPad
            Layout.rightMargin: root._sectionHPad
            spacing: ScreenTools.defaultFontPixelHeight * 0.9

            QGCLabel {
                text:           qsTr("Mode Selection")
                color:          root._titleColor
                font.bold:      true
                font.pointSize: ScreenTools.defaultFontPointSize + 1
                font.family:    ScreenTools.normalFontFamily
            }

            Rectangle {
                id: stickDisplayContainer
                Layout.fillWidth: true
                implicitHeight: modeColumn.implicitHeight + _outerPad * 2
                radius: ScreenTools.defaultFontPixelWidth * 0.75
                color: qgcPal.window
                border.width: 1
                border.color: qgcPal.globalTheme === QGCPalette.Dark ? qgcPal.windowShade : "#E6E6E6"

                readonly property bool _darkTheme: qgcPal.globalTheme === QGCPalette.Dark
                readonly property color _innerFill: _darkTheme ? qgcPal.windowShade : "#E8E8E8"
                readonly property color _lineColor: _darkTheme ? qgcPal.windowShade : "#E5E5E5"
                property real _outerPad: ScreenTools.defaultFontPixelWidth * 1.05
                property real _innerPad: ScreenTools.defaultFontPixelWidth * 1.35

                Column {
                    id: modeColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: stickDisplayContainer._outerPad
                    spacing: ScreenTools.defaultFontPixelHeight * 0.45

                    RowLayout {
                        width: parent.width
                        spacing: ScreenTools.defaultFontPixelWidth * 2

                        QGCComboBox {
                            id: transmitterModeComboBox
                            model: [ qsTr("Mode 1"), qsTr("Mode 2"), qsTr("Mode 3"), qsTr("Mode 4") ]
                            onActivated: (index) => controller.transmitterMode = index + 1

                            Component.onCompleted: currentIndex = controller.transmitterMode - 1
                        }

                        Item { Layout.fillWidth: true }

                        QGCCheckBox {
                            id: centeredThrottleCheckBox
                            text: qsTr("Centered Throttle")
                            textColor: root._titleColor
                            rounded: true
                            checked: controller.centeredThrottle
                            onClicked: controller.centeredThrottle = checked
                        }

                        Item { Layout.fillWidth: true }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: stickDisplayContainer._lineColor
                    }

                    Rectangle {
                        width: parent.width
                        implicitHeight: sticksRow.height + stickDisplayContainer._innerPad * 2.4
                        radius: ScreenTools.defaultFontPixelWidth * 0.75
                        color: stickDisplayContainer._innerFill
                        border.width: 1
                        border.color: stickDisplayContainer._lineColor

                      Row {
                            id: sticksRow
                            anchors.centerIn: parent
                            spacing: ScreenTools.defaultFontPixelWidth * 1.6

                            JoystickRadial {
                                joystickTitle: qsTr("Joystick 1")
                                stickX: root._leftStickX
                                stickY: root._leftStickY
                                darkTheme: root._darkTheme
                                accentGreen: root._accentGreen
                                titleColor: root._titleColor
                            }

                            JoystickRadial {
                                joystickTitle: qsTr("Joystick 2")
                                stickX: root._rightStickX
                                stickY: root._rightStickY
                                darkTheme: root._darkTheme
                                accentGreen: root._accentGreen
                                titleColor: root._titleColor
                            }
                        }
                    }
                }
            }
        }

        ColumnLayout {
            id: attitudeControlsLayout
            Layout.fillWidth: true
            Layout.leftMargin:  root._sectionHPad
            Layout.rightMargin: root._sectionHPad
            spacing: ScreenTools.defaultFontPixelHeight

            QGCLabel {
                text:           qsTr("Attitude Controls")
                color:          root._titleColor
                font.bold:      true
                font.pointSize: ScreenTools.defaultFontPointSize + 1
                font.family:    ScreenTools.normalFontFamily
            }

            Repeater {
                model: attitudeControlsModel

                RowLayout {
                    Layout.fillWidth: true
                    spacing:          ScreenTools.defaultFontPixelWidth * 1.2

                    QGCLabel {
                        Layout.fillWidth: true
                        text:             name
                        color:            root._titleColor
                        font.family:      ScreenTools.normalFontFamily
                        font.pointSize:   ScreenTools.defaultFontPointSize
                    }

                    Loader {
                        id: channelMonitorLoader
                        width: ScreenTools.defaultFontPixelWidth * 28
                        height: ScreenTools.defaultFontPixelHeight * 1.6
                        sourceComponent: attitudeChannelDisplayComponent
                        property var channelMapped: mapped
                        property var channelReversed: reversed
                        property var channelValue: value
                    }
                }
            }
        }

        // Command Buttons
        RowLayout {
            Layout.fillWidth:   true
            Layout.leftMargin:  root._sectionHPad
            Layout.rightMargin: root._sectionHPad
            spacing: ScreenTools.defaultFontPixelWidth

            QGCButton {
                id: skipButton
                text: qsTr("Skip")
                onClicked: controller.skipButtonClicked()
            }

            QGCButton {
                id: cancelButton
                text: qsTr("Cancel")
                onClicked: controller.cancelButtonClicked()
            }

            QGCButton {
                id: nextButton
                primary: true
                text: qsTr("Calibrate")

                onClicked: {
                    if (text === qsTr("Calibrate")) {
                        if (controller.channelCount < controller.minChannelCount) {
                            mainWindow.showMessageDialog(qsTr("Radio Not Ready"),
                                                            controller.channelCount == 0 ? qsTr("Please turn on transmitter.") :
                                                                                        (controller.channelCount < controller.minChannelCount ?
                                                                                                qsTr("%1 channels or more are needed to fly.").arg(controller.minChannelCount) :
                                                                                                qsTr("Ready to calibrate.")))
                        } else {
                            mainWindow.showMessageDialog(qsTr("Zero Trims"),
                                                            qsTr("Before calibrating you should zero all your trims and subtrims. Click Ok to start Calibration.\n\n%1").arg(
                                                                (QGroundControl.multiVehicleManager.activeVehicle.px4Firmware ? "" : qsTr("Please ensure all motor power is disconnected AND all props are removed from the vehicle."))),
                                                            Dialog.Ok,
                                                            function() { controller.nextButtonClicked() })
                        }
                    } else {
                        controller.nextButtonClicked()
                    }
                }
            }
        }

        // Status Text
        QGCLabel {
            id: statusText
            Layout.fillWidth: true
            Layout.maximumWidth: parent.width
            Layout.leftMargin:  root._sectionHPad
            Layout.rightMargin: root._sectionHPad
            wrapMode: Text.WordWrap
            font.pointSize: ScreenTools.smallFontPointSize
            font.family: ScreenTools.normalFontFamily
            color: root._bodyColor
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            // hide the some calibration parts which no londer needed
            visible: additionalSetupComponent !== null
            color: qgcPal.globalTheme === QGCPalette.Dark ? qgcPal.windowShade : "#EFEFEF"
        }

        Loader {
            id: additionalSetupLoader
            Layout.fillWidth: true
            visible: additionalSetupComponent !== null
            active: additionalSetupComponent !== null
            sourceComponent: additionalSetupComponent
        }
    }

    ColumnLayout {
        id: rightColumnLayout
        Layout.alignment: Qt.AlignTop
        spacing: ScreenTools.defaultFontPixelHeight / 2

        RCChannelMonitor {
            Layout.fillWidth: true
            twoColumn: true
        }
    }

    Component {
        id: attitudeChannelDisplayComponent

        Item {
            implicitHeight: ScreenTools.defaultFontPixelHeight * 1.6
            implicitWidth: ScreenTools.defaultFontPixelWidth * 28

            readonly property int _channelMin: 800
            readonly property int _channelMax: 2200
            readonly property int _channelRange: _channelMax - _channelMin

            property int _lastChannelValue: (_channelMax - _channelMin) / 2 + _channelMin
            property color _barColor: qgcPal.windowShade

            // Bar
            Rectangle {
                id: bar
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: ScreenTools.defaultFontPixelHeight * 1.15
                radius: ScreenTools.defaultFontPixelWidth * 0.35
                color: _barColor
            }

            // Center point
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: globals.defaultTextWidth / 2
                height: bar.height
                color: qgcPal.window
            }

            // Indicator
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.height
                height: width
                radius: width / 2
                color: qgcPal.text
                visible: channelMapped
                x: (((channelReversed ? _channelMax - channelValue : channelValue - _channelMin) / _channelRange) * parent.width) - (width / 2)
            }

            QGCLabel {
                id: notMappedLabel
                anchors.left:           parent.left
                anchors.right:          parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin:     ScreenTools.defaultFontPixelWidth * 1.1
                anchors.rightMargin:    ScreenTools.defaultFontPixelWidth * 1.1
                horizontalAlignment:    Text.AlignHCenter
                elide:                  Text.ElideRight
                text:                   qsTr("Not Mapped")
                visible:                !channelMapped
                color:                  root._bodyColor
                font.family:            ScreenTools.normalFontFamily
            }

            ColorAnimation {
                id: barAnimation
                target: bar
                property: "color"
                from: "yellow"
                to: _barColor
                duration: 1500
            }
        }
    }
}
