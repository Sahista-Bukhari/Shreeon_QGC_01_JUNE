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

    ColumnLayout {
        Layout.fillWidth:    true
        Layout.maximumWidth: ScreenTools.defaultFontPixelWidth * 48
        Layout.alignment:    Qt.AlignLeft
        Layout.leftMargin:   root._contentInset
        Layout.rightMargin:  root._contentInset
        Layout.topMargin:    ScreenTools.defaultFontPixelHeight * 0.4
        Layout.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.4
        spacing:             ScreenTools.defaultFontPixelHeight / 2

        QGCLabel {
            Layout.fillWidth: true
            text:             qsTr("Position control mode (set this to 'simple' during tuning):")
            visible:          _mcPosMode
            wrapMode:         Text.WordWrap
        }
        FactComboBox {
            fact:       _mcPosMode
            indexModel: false
            visible:    _mcPosMode
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
                { name: "Response", value: globals.activeVehicle.localPosition.y.value },
                { name: "Setpoint", value: globals.activeVehicle.localPositionSetpoint.y.value }
            ]
            property var params: ListModel {
                ListElement {
                    title:          qsTr("Proportional gain (MPC_XY_P)")
                    description:    qsTr("Increase for more responsiveness, reduce if the position overshoots (there is only a setpoint when hovering, i.e. when centering the stick).")
                    param:          "MPC_XY_P"
                    min:            0
                    max:            2
                    step:           0.05
                }
            }
        }
        property var vertical: QtObject {
            property string name: qsTr("Vertical")
            property var plot: [
                { name: "Response", value: globals.activeVehicle.localPosition.z.value },
                { name: "Setpoint", value: globals.activeVehicle.localPositionSetpoint.z.value }
            ]
            property var params: ListModel {
                ListElement {
                    title:          qsTr("Proportional gain (MPC_Z_P)")
                    description:    qsTr("Increase for more responsiveness, reduce if the position overshoots (there is only a setpoint when hovering, i.e. when centering the stick).")
                    param:          "MPC_Z_P"
                    min:            0
                    max:            2
                    step:           0.05
                }
            }
        }
        title: "Position"
        tuningMode: Vehicle.ModeVelocityAndPosition
        unit: "m"
        axis: [ horizontal, vertical ]
        chartDisplaySec: 50
    }
}
