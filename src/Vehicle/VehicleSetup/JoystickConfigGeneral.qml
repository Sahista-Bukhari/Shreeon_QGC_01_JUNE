import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Item {
    width:  parent ? parent.width : implicitWidth
    height: mainCol.height + ScreenTools.defaultFontPixelHeight * 1.2

    readonly property real axisMonitorWidth: ScreenTools.defaultFontPixelWidth * 32
    readonly property real _pageHPad:        ScreenTools.defaultFontPixelWidth * 2.2
    readonly property real _titlePointSize:  ScreenTools.defaultFontPointSize + 1
    readonly property real _labelPointSize:  ScreenTools.defaultFontPointSize
    readonly property real _bodyPointSize:   ScreenTools.smallFontPointSize

    property var  _activeJoystick:      joystickManager.activeJoystick
    property bool _buttonsOnly:         _activeJoystick ? _activeJoystick.axisCount == 0 : true
    property bool _requiresCalibration: _activeJoystick ? (!_activeJoystick.calibrated && !_buttonsOnly) : false

    QGCPalette { id: qgcPal; colorGroupEnabled: true }
    readonly property bool  _darkTheme:   qgcPal.globalTheme === QGCPalette.Dark
    readonly property color _titleColor:  _darkTheme ? "#AEAEB2" : "#3A3A3C"
    readonly property color _bodyColor:   _darkTheme ? "#8E8E93" : "#3A3A3C"
    readonly property color _accentGreen: qgcPal.colorGreen
    readonly property color _cardBorder:  _darkTheme ? qgcPal.windowShade : "#E6E6E6"
    readonly property color _innerFill:   _darkTheme ? qgcPal.windowShade : "#E8E8E8"

    property real _leftStickX:  0
    property real _leftStickY:  0
    property real _rightStickX: 0
    property real _rightStickY: 0

    function _throttleAsY(value) {
        return Math.max(-1, Math.min(1, (2 * value) - 1))
    }

    function _applyAxisValues(roll, pitch, yaw, throttle) {
        var t = _throttleAsY(throttle)
        var mode = controller ? controller.transmitterMode : 2
        if (mode === 1) {
            _leftStickX = yaw;   _leftStickY = pitch
            _rightStickX = roll; _rightStickY = t
        } else if (mode === 3) {
            _leftStickX = roll;  _leftStickY = pitch
            _rightStickX = yaw;  _rightStickY = t
        } else if (mode === 4) {
            _leftStickX = roll;  _leftStickY = t
            _rightStickX = yaw;  _rightStickY = pitch
        } else {
            _leftStickX = yaw;   _leftStickY = t
            _rightStickX = roll; _rightStickY = pitch
        }
    }

    Column {
        id:                 mainCol
        x:                  _pageHPad
        width:              parent.width - _pageHPad * 2
        spacing:            ScreenTools.defaultFontPixelHeight * 1.15

        QGCLabel {
            text:           qsTr("Joystick Settings")
            color:          _titleColor
            font.bold:      true
            font.pointSize: _titlePointSize
            font.family:    ScreenTools.normalFontFamily
        }

        GridLayout {
            width:              parent.width
            columns:            2
            columnSpacing:      ScreenTools.defaultFontPixelWidth
            rowSpacing:         ScreenTools.defaultFontPixelHeight * 0.55
            //---------------------------------------------------------------------
            //-- Enable Joystick
            QGCLabel {
                text:               _requiresCalibration ? qsTr("Enable not allowed (Calibrate First)") : qsTr("Enable joystick input")
                color:              _titleColor
                font.pointSize:     _labelPointSize
                font.family:        ScreenTools.normalFontFamily
                Layout.alignment:   Qt.AlignVCenter
                Layout.fillWidth:   true
                Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 20
            }
            QGCCheckBox {
                id:             enabledSwitch
                enabled:        !_requiresCalibration
                onClicked:      {
                    if (!globals.activeVehicle)
                        return
                    globals.activeVehicle.joystickEnabled = checked
                    globals.activeVehicle.saveJoystickSettings()
                }
                Component.onCompleted: {
                    if (globals.activeVehicle)
                        checked = globals.activeVehicle.joystickEnabled
                }
                Connections {
                    target:  globals.activeVehicle
                    enabled: globals.activeVehicle !== null
                    function onJoystickEnabledChanged() {
                        enabledSwitch.checked = globals.activeVehicle.joystickEnabled
                    }
                }
                Connections {
                    target: joystickManager
                    function onActiveJoystickChanged() {
                        if (_activeJoystick && globals.activeVehicle) {
                            enabledSwitch.checked = Qt.binding(function() { return _activeJoystick.calibrated && globals.activeVehicle.joystickEnabled })
                        }
                    }
                }
            }
            //---------------------------------------------------------------------
            //-- Joystick Selector
            QGCLabel {
                text:               qsTr("Active joystick:")
                color:              _titleColor
                font.pointSize:     _labelPointSize
                font.family:        ScreenTools.normalFontFamily
                Layout.alignment:   Qt.AlignVCenter
            }
            QGCComboBox {
                id:                 joystickCombo
                width:              ScreenTools.defaultFontPixelWidth * 40
                Layout.alignment:   Qt.AlignVCenter
                model:              joystickManager.joystickNames
                onActivated: (index) => { joystickManager.activeJoystickName = textAt(index) }
                Component.onCompleted: {
                    var index = joystickCombo.find(joystickManager.activeJoystickName)
                    if (index === -1) {
                        console.warn(qsTr("Active joystick name not in combo"), joystickManager.activeJoystickName)
                    } else {
                        joystickCombo.currentIndex = index
                    }
                }
                Connections {
                    target: joystickManager
                    function onAvailableJoysticksChanged() {
                        var index = joystickCombo.find(joystickManager.activeJoystickName)
                        if (index >= 0) {
                            joystickCombo.currentIndex = index
                        }
                    }
                }
            }
            //---------------------------------------------------------------------
            //-- RC Mode
            QGCLabel {
                text:               qsTr("RC Mode:")
                color:              _titleColor
                font.pointSize:     _labelPointSize
                font.family:        ScreenTools.normalFontFamily
                Layout.alignment:   Qt.AlignVCenter
                visible:            !_buttonsOnly
            }
            Row {
                spacing:            ScreenTools.defaultFontPixelWidth
                visible:            !_buttonsOnly
                QGCRadioButton {
                    text:       "1"
                    checked:    controller.transmitterMode === 1
                    enabled:    !controller.calibrating
                    onClicked:  controller.transmitterMode = 1
                    anchors.verticalCenter: parent.verticalCenter
                }
                QGCRadioButton {
                    text:       "2"
                    checked:    controller.transmitterMode === 2
                    enabled:    !controller.calibrating
                    onClicked:  controller.transmitterMode = 2
                    anchors.verticalCenter: parent.verticalCenter
                }
                QGCRadioButton {
                    text:       "3"
                    checked:    controller.transmitterMode === 3
                    enabled:    !controller.calibrating
                    onClicked:  controller.transmitterMode = 3
                    anchors.verticalCenter: parent.verticalCenter
                }
                QGCRadioButton {
                    text:       "4"
                    checked:    controller.transmitterMode === 4
                    enabled:    !controller.calibrating
                    onClicked:  controller.transmitterMode = 4
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            QGCLabel {
                text:               qsTr("Calibration:")
                color:              _titleColor
                font.pointSize:     _labelPointSize
                font.family:        ScreenTools.normalFontFamily
                Layout.alignment:   Qt.AlignVCenter
                visible:            !_buttonsOnly
            }
            QGCButton {
                id:                 calibrateButton
                primary:            true
                visible:            !_buttonsOnly
                text:               qsTr("Calibrate")
                onClicked: {
                    var item = calibrateButton.parent
                    while (item) {
                        if (typeof item.showCalibrationPage === "function") {
                            item.showCalibrationPage()
                            return
                        }
                        item = item.parent
                    }
                }
            }
        }
        Rectangle {
            visible:            !_buttonsOnly
            width:              parent.width
            height:             sticksRow.height + ScreenTools.defaultFontPixelHeight * 1.6
            radius:             ScreenTools.defaultFontPixelWidth * 0.75
            color:              _innerFill
            border.width:       1
            border.color:       _cardBorder

            Row {
                id: sticksRow
                anchors.centerIn: parent
                spacing: ScreenTools.defaultFontPixelWidth * 1.6

                JoystickRadial {
                    joystickTitle: qsTr("Joystick 1")
                    stickX:        _leftStickX
                    stickY:        _leftStickY
                    darkTheme:     _darkTheme
                    accentGreen:   _accentGreen
                    titleColor:    _titleColor
                }

                JoystickRadial {
                    joystickTitle: qsTr("Joystick 2")
                    stickX:        _rightStickX
                    stickY:        _rightStickY
                    darkTheme:     _darkTheme
                    accentGreen:   _accentGreen
                    titleColor:    _titleColor
                }
            }
        }
        Row {
            spacing:                ScreenTools.defaultFontPixelWidth
            //---------------------------------------------------------------------
            //-- Axis Monitors
            Rectangle {
                id:                 axisRect
                color:              "transparent"
                border.color:       _cardBorder
                border.width:       1
                radius:             ScreenTools.defaultFontPixelWidth * 0.75
                width:              axisGrid.width  + (ScreenTools.defaultFontPixelWidth  * 2)
                height:             axisGrid.height + (ScreenTools.defaultFontPixelHeight * 2)
                visible:            !_buttonsOnly

                function joyToAxis(v, reversed) {
                    v = Math.max(-1, Math.min(1, v))
                    if (reversed) v = -v
                    return v * 32768.0
                }

                function joyToThrottleAxis(v, reversed) {
                    v = (2 * v - 1)
                    v = Math.max(-1, Math.min(1, v))
                    if (reversed) v = -v
                    return v * 32768.0
                }

                GridLayout {
                    id:                 axisGrid
                    columns:            2
                    columnSpacing:      ScreenTools.defaultFontPixelWidth
                    rowSpacing:         ScreenTools.defaultFontPixelHeight
                    anchors.centerIn:   parent
                    QGCLabel {
                        text:               globals.activeVehicle && globals.activeVehicle.sub ? qsTr("Lateral") : qsTr("Roll")
                        color:              _titleColor
                        font.pointSize:     _labelPointSize
                        font.family:        ScreenTools.normalFontFamily
                        Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 12
                    }
                    AxisMonitor {
                        id:                 rollAxis
                        height:             ScreenTools.defaultFontPixelHeight
                        width:              axisMonitorWidth
                        mapped:             controller.rollAxisMapped
                        reversed:           controller.rollAxisReversed
                    }

                    QGCLabel {
                        id:                 pitchLabel
                        width:              _attitudeLabelWidth
                        text:               globals.activeVehicle && globals.activeVehicle.sub ? qsTr("Forward") : qsTr("Pitch")
                        color:              _titleColor
                        font.pointSize:     _labelPointSize
                        font.family:        ScreenTools.normalFontFamily
                    }
                    AxisMonitor {
                        id:                 pitchAxis
                        height:             ScreenTools.defaultFontPixelHeight
                        width:              axisMonitorWidth
                        mapped:             controller.pitchAxisMapped
                        reversed:           controller.pitchAxisReversed
                    }

                    QGCLabel {
                        id:                 yawLabel
                        width:              _attitudeLabelWidth
                        text:               qsTr("Yaw")
                        color:              _titleColor
                        font.pointSize:     _labelPointSize
                        font.family:        ScreenTools.normalFontFamily
                    }
                    AxisMonitor {
                        id:                 yawAxis
                        height:             ScreenTools.defaultFontPixelHeight
                        width:              axisMonitorWidth
                        mapped:             controller.yawAxisMapped
                        reversed:           controller.yawAxisReversed
                    }

                    QGCLabel {
                        id:                 throttleLabel
                        width:              _attitudeLabelWidth
                        text:               qsTr("Throttle")
                        color:              _titleColor
                        font.pointSize:     _labelPointSize
                        font.family:        ScreenTools.normalFontFamily
                    }
                    AxisMonitor {
                        id:                 throttleAxis
                        height:             ScreenTools.defaultFontPixelHeight
                        width:              axisMonitorWidth
                        mapped:             controller.throttleAxisMapped
                        reversed:           controller.throttleAxisReversed
                    }

                    Connections {
                        target:  _activeJoystick
                        enabled: _activeJoystick !== null
                        function onAxisValues(roll, pitch, yaw, throttle) {
                            _applyAxisValues(roll, pitch, yaw, throttle)
                            rollAxis.axisValue     = axisRect.joyToAxis(roll,  controller.rollAxisReversed)
                            pitchAxis.axisValue    = axisRect.joyToAxis(pitch, controller.pitchAxisReversed)
                            yawAxis.axisValue      = axisRect.joyToAxis(yaw,   controller.yawAxisReversed)
                            throttleAxis.axisValue = axisRect.joyToThrottleAxis(throttle, controller.throttleAxisReversed)
                        }
                    }
                }
            }
            Rectangle {
                color:              "transparent"
                border.color:       _cardBorder
                border.width:       1
                radius:             ScreenTools.defaultFontPixelWidth * 0.75
                width:              axisRect.width
                height:             axisRect.height
                Flow {
                    width:              ScreenTools.defaultFontPixelWidth * 30
                    spacing:            -1
                    anchors.centerIn:   parent
                    Connections {
                        target:  _activeJoystick
                        enabled: _activeJoystick !== null
                        function onRawButtonPressedChanged(index, pressed) {
                            if (buttonMonitorRepeater.itemAt(index)) {
                                buttonMonitorRepeater.itemAt(index).pressed = pressed
                            }
                        }
                    }
                    Repeater {
                        id:         buttonMonitorRepeater
                        model:      _activeJoystick ? _activeJoystick.totalButtonCount : []
                        Rectangle {
                            width:          ScreenTools.defaultFontPixelHeight * 1.5
                            height:         width
                            border.width:   1
                            border.color:   qgcPal.text
                            color:          pressed ? qgcPal.buttonHighlight : qgcPal.windowShade
                            property bool pressed
                            QGCLabel {
                                anchors.fill:           parent
                                color:                  pressed ? qgcPal.buttonHighlightText : qgcPal.buttonText
                                horizontalAlignment:    Text.AlignHCenter
                                verticalAlignment:      Text.AlignVCenter
                                text:                   modelData
                            }
                        }
                    }
                }
            }
        }
    }
}
