import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

ColumnLayout {
    id: root

    property real _availableHeight: availableHeight
    property real _availableWidth:  availableWidth
    property Fact _mcPosMode:       controller.getParameterFact(-1, "MPC_POS_MODE", false)

    readonly property real _contentInset: ScreenTools.defaultFontPixelWidth * 2.2

    GridLayout {
        Layout.fillWidth:    true
        Layout.maximumWidth: ScreenTools.defaultFontPixelWidth * 48
        Layout.alignment:    Qt.AlignLeft
        Layout.leftMargin:   root._contentInset
        Layout.rightMargin:  root._contentInset
        Layout.topMargin:    ScreenTools.defaultFontPixelHeight * 0.4
        Layout.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.4
        rowSpacing:          ScreenTools.defaultFontPixelHeight / 2
        columnSpacing:       ScreenTools.defaultFontPixelWidth
        columns:             2

        QGCLabel {
            text:               qsTr("Position control mode (set this to 'simple' during tuning):")
            visible:            _mcPosMode
        }
        FactComboBox {
            fact:               _mcPosMode
            indexModel:         false
            visible:            _mcPosMode
        }
    }

    PIDTuning {
        id:                  pidTuning
        Layout.fillWidth:    true
        Layout.leftMargin:   root._contentInset
        Layout.rightMargin:  root._contentInset
        Layout.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.4
        availableWidth:      Math.max(0, _availableWidth - (root._contentInset * 2))
        availableHeight:     _availableHeight - pidTuning.y
        cleanManualTuning:   true

        property var horizontal: QtObject {
            property string name: qsTr("Horizontal")
            property string plotTitle: qsTr("Horizontal (Y direction, sidewards)")
            property var plot: [
                { name: "Response", value: globals.activeVehicle.localPosition.vy.value },
                { name: "Setpoint", value: globals.activeVehicle.localPositionSetpoint.vy.value }
            ]
            property var params: ListModel {
                ListElement {
                    title:          qsTr("Proportional gain (MPC_XY_VEL_P_ACC)")
                    description:    qsTr("Increase for more responsiveness, reduce if the velocity overshoots (and increasing D does not help).")
                    param:          "MPC_XY_VEL_P_ACC"
                    min:            1.2
                    max:            5
                    step:           0.05
                }
                ListElement {
                    title:          qsTr("Integral gain (MPC_XY_VEL_I_ACC)")
                    description:    qsTr("Increase to reduce steady-state error (e.g. wind)")
                    param:          "MPC_XY_VEL_I_ACC"
                    min:            0.2
                    max:            10
                    step:           0.2
                }
                ListElement {
                    title:          qsTr("Differential gain (MPC_XY_VEL_D_ACC)")
                    description:    qsTr("Damping: increase to reduce overshoots and oscillations, but not higher than really needed.")
                    param:          "MPC_XY_VEL_D_ACC"
                    min:            0.1
                    max:            2
                    step:           0.05
                }
            }
        }
        property var vertical: QtObject {
            property string name: qsTr("Vertical")
            property var plot: [
                { name: "Response", value: globals.activeVehicle.localPosition.vz.value },
                { name: "Setpoint", value: globals.activeVehicle.localPositionSetpoint.vz.value }
            ]
            property var params: ListModel {
                ListElement {
                    title:          qsTr("Proportional gain (MPC_Z_VEL_P_ACC)")
                    description:    qsTr("Increase for more responsiveness, reduce if the velocity overshoots (and increasing D does not help).")
                    param:          "MPC_Z_VEL_P_ACC"
                    min:            2
                    max:            15
                    step:           0.5
                }
                ListElement {
                    title:          qsTr("Integral gain (MPC_Z_VEL_I_ACC)")
                    description:    qsTr("Increase to reduce steady-state error")
                    param:          "MPC_Z_VEL_I_ACC"
                    min:            0.2
                    max:            3
                    step:           0.05
                }
                ListElement {
                    title:          qsTr("Differential gain (MPC_Z_VEL_D_ACC)")
                    description:    qsTr("Damping: increase to reduce overshoots and oscillations, but not higher than really needed.")
                    param:          "MPC_Z_VEL_D_ACC"
                    min:            0
                    max:            2
                    step:           0.05
                }
            }
        }
        title: "Velocity"
        tuningMode: Vehicle.ModeVelocityAndPosition
        unit: "m/s"
        axis: [ horizontal, vertical ]
    }
}
