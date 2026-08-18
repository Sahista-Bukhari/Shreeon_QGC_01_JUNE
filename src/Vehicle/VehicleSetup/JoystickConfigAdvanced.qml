import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Item {
    width:                  parent ? parent.width : implicitWidth
    height:                 grid.height + (ScreenTools.defaultFontPixelHeight * 2)
    //---------------------------------------------------------------------
    readonly property real  _pageHPad:          ScreenTools.defaultFontPixelWidth * 2.2
    readonly property real  _labelPointSize:    ScreenTools.defaultFontPointSize
    readonly property real  _bodyPointSize:     ScreenTools.smallFontPointSize
    readonly property color _titleColor:        qgcPal.globalTheme === QGCPalette.Dark ? "#AEAEB2" : "#3A3A3C"
    readonly property color _bodyColor:         qgcPal.globalTheme === QGCPalette.Dark ? "#8E8E93" : "#3A3A3C"

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    GridLayout {
        id:                 grid
        columns:            2
        columnSpacing:      ScreenTools.defaultFontPixelWidth
        rowSpacing:         ScreenTools.defaultFontPixelHeight * 0.55
        x:                  _pageHPad
        width:              parent.width - _pageHPad * 2
        //-------------------------------------------------------------
        //-------------------------------------------------------------
        QGCRadioButton {
            text:               qsTr("Full down stick is zero throttle")
            textColor:          _titleColor
            checked:            _activeJoystick ? _activeJoystick.throttleMode === 1 : false
            onClicked:          _activeJoystick.throttleMode = 1
            Layout.columnSpan:  2
        }
        QGCRadioButton {
            text:               qsTr("Center stick is zero throttle")
            textColor:          _titleColor
            checked:            _activeJoystick ? _activeJoystick.throttleMode === 0 : false
            onClicked:          _activeJoystick.throttleMode = 0
            Layout.columnSpan:  2
        }
        //-------------------------------------------------------------
        QGCLabel {
            text:               qsTr("Spring loaded throttle smoothing")
            color:              _titleColor
            font.pointSize:     _labelPointSize
            visible:            _activeJoystick ? _activeJoystick.throttleMode === 0 : false
            Layout.alignment:   Qt.AlignVCenter
            Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 36
        }
        QGCCheckBox {
            checked:            _activeJoystick ? _activeJoystick.accumulator : false
            visible:            _activeJoystick ? _activeJoystick.throttleMode === 0 : false
            onClicked:          _activeJoystick.accumulator = checked
        }
        //-------------------------------------------------------------
        QGCLabel {
            text:               qsTr("Allow negative Thrust")
            color:              _titleColor
            font.pointSize:     _labelPointSize
            visible:            globals.activeVehicle.supportsNegativeThrust
            Layout.alignment:   Qt.AlignVCenter
        }
        QGCCheckBox {
            visible:            globals.activeVehicle.supportsNegativeThrust
            enabled:            globals.activeVehicle.supportsNegativeThrust
            checked:            _activeJoystick ? _activeJoystick.negativeThrust : false
            onClicked:          _activeJoystick.negativeThrust = checked
        }
        //---------------------------------------------------------------------
        QGCLabel {
            text:               qsTr("Exponential:")
            color:              _titleColor
            font.pointSize:     _labelPointSize
        }
        Row {
            spacing:            ScreenTools.defaultFontPixelWidth
            QGCSlider {
                id:             expoSlider
                width:          ScreenTools.defaultFontPixelWidth * 20
                from:   0
                to:   0.75
                Component.onCompleted: value = -_activeJoystick.exponential
                onValueChanged: _activeJoystick.exponential = -value
             }
            QGCLabel {
                id:     expoSliderIndicator
                text:   expoSlider.value.toFixed(2)
                color:  _titleColor
                font.pointSize: _labelPointSize
            }
        }

        QGCCheckBox {
            Layout.columnSpan:  2
            text: qsTr("Allow additional axes to be used for manual control extensions")
            textColor: _titleColor
            checked: _activeJoystick ? _activeJoystick.enableManualControlExtensions : false
            onClicked: _activeJoystick.enableManualControlExtensions = checked
        }

        //-----------------------------------------------------------------
        //-- Enable Advanced Mode
        QGCLabel {
            text:               qsTr("Enable further advanced settings (careful!)")
            color:              _titleColor
            font.pointSize:     _labelPointSize
            Layout.alignment:   Qt.AlignVCenter
            Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 36
        }
        QGCCheckBox {
            id:         advancedSettings
            checked:    globals.activeVehicle.joystickMode !== 0
            onClicked: {
                if (!checked) {
                    globals.activeVehicle.joystickMode = 0
                }
            }
        }
        //-----------------------------------------------------------------
        //-- Axis Message Frequency
        QGCLabel {
            text:               qsTr("Axis frequency (Hz):")
            color:              _titleColor
            font.pointSize:     _labelPointSize
            Layout.alignment:   Qt.AlignVCenter
            visible:            advancedSettings.checked
        }
        QGCTextField {
            text:               _activeJoystick.axisFrequencyHz
            enabled:            advancedSettings.checked
            validator:          DoubleValidator { bottom: _activeJoystick.minAxisFrequencyHz; top: _activeJoystick.maxAxisFrequencyHz; }
            inputMethodHints:   Qt.ImhFormattedNumbersOnly
            Layout.alignment:   Qt.AlignVCenter
            onEditingFinished: {
                _activeJoystick.axisFrequencyHz = parseFloat(text)
            }
            visible:            advancedSettings.checked
        }
        //-----------------------------------------------------------------
        //-- Button Repeat Frequency
        QGCLabel {
            text:               qsTr("Button repeat frequency (Hz):")
            color:              _titleColor
            font.pointSize:     _labelPointSize
            Layout.alignment:   Qt.AlignVCenter
            visible:            advancedSettings.checked
        }
        QGCTextField {
            text:               _activeJoystick.buttonFrequencyHz
            enabled:            advancedSettings.checked
            validator:          DoubleValidator { bottom: _activeJoystick.minButtonFrequencyHz; top: _activeJoystick.maxButtonFrequencyHz; }
            inputMethodHints:   Qt.ImhFormattedNumbersOnly
            Layout.alignment:   Qt.AlignVCenter
            onEditingFinished: {
                _activeJoystick.buttonFrequencyHz = parseFloat(text)
            }
            visible:            advancedSettings.checked
        }
        //-----------------------------------------------------------------
        //-- Enable circle correction
        QGCLabel {
            text:               qsTr("Enable circle correction")
            color:              _titleColor
            font.pointSize:     _labelPointSize
            Layout.alignment:   Qt.AlignVCenter
            visible:            advancedSettings.checked
        }
        QGCCheckBox {
            checked:            globals.activeVehicle.joystickMode !== 0
            enabled:            advancedSettings.checked
            Component.onCompleted: {
                checked = _activeJoystick.circleCorrection
            }
            onClicked: {
                _activeJoystick.circleCorrection = checked
            }
            visible:            advancedSettings.checked
        }
        //-----------------------------------------------------------------
        //-- Deadband
        QGCLabel {
            text:               qsTr("Deadbands")
            color:              _titleColor
            font.pointSize:     _labelPointSize
            Layout.alignment:   Qt.AlignVCenter
            visible:            advancedSettings.checked
        }
        QGCCheckBox {
            enabled:            advancedSettings.checked
            checked:            controller.deadbandToggle
            onClicked:          controller.deadbandToggle = checked
            Layout.alignment:   Qt.AlignVCenter
            visible:            advancedSettings.checked
        }
        QGCLabel{
            Layout.fillWidth:   true
            Layout.columnSpan:  2
            font.pointSize:     _bodyPointSize
            font.family:        ScreenTools.normalFontFamily
            color:              _bodyColor
            wrapMode:           Text.WordWrap
            visible:            advancedSettings.checked
            text:   qsTr("Deadband can be set during the first ") +
                    qsTr("step of calibration by gently wiggling each axis. ") +
                    qsTr("Deadband can also be adjusted by clicking and ") +
                    qsTr("dragging vertically on the corresponding axis monitor.")
        }
    }
}
