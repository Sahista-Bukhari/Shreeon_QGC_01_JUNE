import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

ColumnLayout {
    id: root

    property real _availableHeight:     availableHeight
    property real _availableWidth:      availableWidth
    property Fact _airmode:             controller.getParameterFact(-1, "MC_AIRMODE", false)
    property Fact _thrustModelFactor:   controller.getParameterFact(-1, "THR_MDL_FAC", false)

    readonly property real _contentInset: ScreenTools.defaultFontPixelWidth * 2.2

    ColumnLayout {
        Layout.fillWidth:    true
        Layout.leftMargin:   root._contentInset
        Layout.rightMargin:  root._contentInset
        Layout.topMargin:    ScreenTools.defaultFontPixelHeight * 0.4
        Layout.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.4
        spacing:             ScreenTools.defaultFontPixelHeight / 2

        RowLayout {
            spacing: ScreenTools.defaultFontPixelWidth / 2

            QGCLabel {
                text:    qsTr("Airmode (disable during tuning)")
                visible: _airmode
            }
            FactComboBox {
                fact:       _airmode
                indexModel: false
                visible:    _airmode
            }
        }

        RowLayout {
            spacing: ScreenTools.defaultFontPixelWidth / 2

            QGCLabel {
                text:    qsTr("Thrust curve")
                visible: _thrustModelFactor
            }
            FactTextField {
                fact:                   _thrustModelFactor
                visible:                _thrustModelFactor
                activeFocusBorderColor: "#00a04c"
            }
        }
    }

    PIDTuning {
        id:                   pidTuning
        Layout.fillWidth:     true
        Layout.leftMargin:    root._contentInset
        Layout.rightMargin:   root._contentInset
        Layout.bottomMargin:  ScreenTools.defaultFontPixelHeight * 0.4
        availableWidth:       Math.max(0, _availableWidth - (root._contentInset * 2))
        availableHeight:      _availableHeight - pidTuning.y
        title:                qsTr("Rate")
        tuningMode:           Vehicle.ModeRateAndAttitude
        unit:                 qsTr("deg/s")
        axis:                 [ roll, pitch, yaw ]
        chartDisplaySec:      3
        showAutoModeChange:   true
        showAutoTuning:       true
        multiAxisPlot:        useAutoTuning
        multiAxisIndices:     [0, 1]
        multiAxisTitle:       qsTr("Multi-Axis PID Response")

        property var roll: QtObject {
            property string name: qsTr("Roll")
            property var plot: [
                { name: "Response", value: globals.activeVehicle.rollRate.value },
                { name: "Setpoint", value: globals.activeVehicle.setpoint.rollRate.value }
            ]
            property var params: ListModel {
                ListElement {
                    title:          qsTr("Overall Multiplier (MC_ROLLRATE_K)")
                    description:    qsTr("Multiplier for P, I and D gains: increase for more responsiveness, reduce if the rates overshoot (and increasing D does not help).")
                    param:          "MC_ROLLRATE_K"
                    min:            0.3
                    max:            3
                    step:           0.05
                }
                ListElement {
                    title:          qsTr("Differential Gain (MC_ROLLRATE_D)")
                    description:    qsTr("Damping: increase to reduce overshoots and oscillations, but not higher than really needed.")
                    param:          "MC_ROLLRATE_D"
                    min:            0.0004
                    max:            0.01
                    step:           0.0002
                }
                ListElement {
                    title:          qsTr("Integral Gain (MC_ROLLRATE_I)")
                    description:    qsTr("Generally does not need much adjustment, reduce this when seeing slow oscillations.")
                    param:          "MC_ROLLRATE_I"
                    min:            0.1
                    max:            0.5
                    step:           0.025
                }
            }
        }
        property var pitch: QtObject {
            property string name: qsTr("Pitch")
            property var plot: [
                { name: "Response", value: globals.activeVehicle.pitchRate.value },
                { name: "Setpoint", value: globals.activeVehicle.setpoint.pitchRate.value }
            ]
            property var params: ListModel {
                ListElement {
                    title:          qsTr("Overall Multiplier (MC_PITCHRATE_K)")
                    description:    qsTr("Multiplier for P, I and D gains: increase for more responsiveness, reduce if the rates overshoot (and increasing D does not help).")
                    param:          "MC_PITCHRATE_K"
                    min:            0.3
                    max:            3
                    step:           0.05
                }
                ListElement {
                    title:          qsTr("Differential Gain (MC_PITCHRATE_D)")
                    description:    qsTr("Damping: increase to reduce overshoots and oscillations, but not higher than really needed.")
                    param:          "MC_PITCHRATE_D"
                    min:            0.0004
                    max:            0.01
                    step:           0.0002
                }
                ListElement {
                    title:          qsTr("Integral Gain (MC_PITCHRATE_I)")
                    description:    qsTr("Generally does not need much adjustment, reduce this when seeing slow oscillations.")
                    param:          "MC_PITCHRATE_I"
                    min:            0.1
                    max:            0.5
                    step:           0.025
                }
            }
        }
        property var yaw: QtObject {
            property string name: qsTr("Yaw")
            property var plot: [
                { name: "Response", value: globals.activeVehicle.yawRate.value },
                { name: "Setpoint", value: globals.activeVehicle.setpoint.yawRate.value }
            ]
            property var params: ListModel {
                ListElement {
                    title:          qsTr("Overall Multiplier (MC_YAWRATE_K)")
                    description:    qsTr("Multiplier for P, I and D gains: increase for more responsiveness, reduce if the rates overshoot (and increasing D does not help).")
                    param:          "MC_YAWRATE_K"
                    min:            0.3
                    max:            3
                    step:           0.05
                }
                ListElement {
                    title:          qsTr("Integral Gain (MC_YAWRATE_I)")
                    description:    qsTr("Generally does not need much adjustment, reduce this when seeing slow oscillations.")
                    param:          "MC_YAWRATE_I"
                    min:            0.04
                    max:            0.4
                    step:           0.02
                }
            }
        }
    }
}
