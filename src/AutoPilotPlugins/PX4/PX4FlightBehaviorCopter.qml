import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

SetupPage {
    id:             flightBehavior
    pageComponent:  pageComponent

    readonly property real  _pagePad:          ScreenTools.defaultFontPixelWidth * 2.2
    readonly property real  _sectionGap:       ScreenTools.defaultFontPixelHeight * 1.15
    readonly property real  _controlsMaxWidth: ScreenTools.defaultFontPixelWidth * 48
    readonly property color _accentGreen:      "#00A651"
    readonly property color _dividerColor:     qgcPal.globalTheme === QGCPalette.Dark
                                                ? qgcPal.windowShade
                                                : "#E5E5E5"

    FactPanelController {
        id: controller
    }

    QGCPalette {
        id: qgcPal
    }

    property Fact _sys_vehicle_resp:  controller.getParameterFact(-1, "SYS_VEHICLE_RESP", false)
    property Fact _mpc_xy_vel_all:    controller.getParameterFact(-1, "MPC_XY_VEL_ALL", false)
    property Fact _mpc_z_vel_all:     controller.getParameterFact(-1, "MPC_Z_VEL_ALL", false)

    component BehaviorBodyLabel: QGCLabel {
        color:          flightBehavior._bodyColor
        font.bold:      false
        font.pointSize: flightBehavior._bodyPointSize
        font.family:    ScreenTools.normalFontFamily
        wrapMode:       Text.WordWrap
    }

    component SectionDivider: Rectangle {
        width:  parent ? parent.width : 0
        height: 1
        color:  flightBehavior._dividerColor
    }

    Component {
        id: pageComponent

        Column {
            id:      mainColumn
            x:       flightBehavior._pagePad
            width:   Math.max(0, flightBehavior.availableWidth - (flightBehavior._pagePad * 2))
            spacing: flightBehavior._sectionGap

            readonly property real controlsWidth: Math.min(width, flightBehavior._controlsMaxWidth)

            ColumnLayout {
                width:   mainColumn.controlsWidth
                spacing: ScreenTools.defaultFontPixelHeight * 0.55
                visible: _sys_vehicle_resp

                SettingsGroupLayout {
                    Layout.fillWidth:   true
                    enabled:            responsivenessCheckbox.checked
                    heading:            qsTr("Responsiveness")
                    headingDescription: qsTr("A higher value makes the vehicle react faster. Be aware that this affects braking as well, and a combination of slow responsiveness with high maximum velocity will lead to long braking distances.")
                    showDividers:       false

                    // It's a bit tricky to handle the fact that the parameter goes negative to signal disabled.
                    // We can't allow the slider to go negative, hence all the hoops to jump through with value and loadComplete.
                    ValueSlider {
                        Layout.fillWidth:   true
                        from:               0.0
                        to:                 1
                        majorTickStepSize:  0.01
                        value:              { value = _sys_vehicle_resp ? Math.abs(_sys_vehicle_resp.value) : (from + to) / 2 }
                        decimalPlaces:      _sys_vehicle_resp ? _sys_vehicle_resp.decimalPlaces : 0
                        rulerColor:         flightBehavior._accentGreen

                        property bool loadComplete: false

                        Component.onCompleted: loadComplete = true

                        onValueChanged: {
                            if (loadComplete && enabled) {
                                _sys_vehicle_resp.value = value
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing:          ScreenTools.defaultFontPixelWidth

                    BehaviorBodyLabel {
                        Layout.fillWidth:    true
                        Layout.minimumWidth: 0
                        text:                qsTr("Enable responsiveness slider (if enabled, acceleration limit parameters and others are automatically set)")
                    }

                    QGCCheckBox {
                        id:               responsivenessCheckbox
                        Layout.alignment: Qt.AlignTop | Qt.AlignRight
                        text:             ""
                        checked:          _sys_vehicle_resp && _sys_vehicle_resp.value >= 0
                        onClicked:        _sys_vehicle_resp.value = checked ? Math.abs(_sys_vehicle_resp.value) : -Math.abs(_sys_vehicle_resp.value)
                    }
                }

                BehaviorBodyLabel {
                    Layout.fillWidth:   true
                    visible:            _sys_vehicle_resp && _sys_vehicle_resp.value > 0.8
                    color:              qgcPal.warningText
                    text:               qsTr("Warning: a high responsiveness requires a vehicle with large thrust-to-weight ratio. The vehicle might lose altitude otherwise.")
                }
            }

            SectionDivider { visible: _sys_vehicle_resp }

            ColumnLayout {
                width:   mainColumn.controlsWidth
                spacing: ScreenTools.defaultFontPixelHeight * 0.55
                visible: _mpc_xy_vel_all

                SettingsGroupLayout {
                    Layout.fillWidth:   true
                    enabled:            xyVelCheckbox.checked
                    heading:            qsTr("Horizontal velocity (m/s)")
                    headingDescription: qsTr("Limit the horizonal velocity (applies to all modes).")
                    showDividers:       false

                    // It's a bit tricky to handle the fact that the parameter goes negative to signal disabled.
                    // We can't allow the slider to go negative, hence all the hoops to jump through with value and loadComplete.
                    ValueSlider {
                        Layout.fillWidth:   true
                        from:               0.5
                        to:                 20
                        majorTickStepSize:  0.6
                        value:              { value = _mpc_xy_vel_all ? Math.abs(_mpc_xy_vel_all.value) : (from + to) / 2 }
                        decimalPlaces:      _mpc_xy_vel_all ? _mpc_xy_vel_all.decimalPlaces : 0
                        rulerColor:         flightBehavior._accentGreen

                        property bool loadComplete: false

                        Component.onCompleted: loadComplete = true

                        onValueChanged: {
                            if (loadComplete && enabled) {
                                _mpc_xy_vel_all.value = value
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing:          ScreenTools.defaultFontPixelWidth

                    BehaviorBodyLabel {
                        Layout.fillWidth:    true
                        Layout.minimumWidth: 0
                        text:                qsTr("Enable horizontal velocity slider (if enabled, individual velocity limit parameters are automatically set)")
                    }

                    QGCCheckBox {
                        id:               xyVelCheckbox
                        Layout.alignment: Qt.AlignTop | Qt.AlignRight
                        text:             ""
                        checked:          _mpc_xy_vel_all ? (_mpc_xy_vel_all.value >= 0) : false
                        onClicked:        _mpc_xy_vel_all.value = checked ? Math.abs(_mpc_xy_vel_all.value) : -Math.abs(_mpc_xy_vel_all.value)
                    }
                }
            }

            SectionDivider { visible: _mpc_xy_vel_all }

            ColumnLayout {
                width:   mainColumn.controlsWidth
                spacing: ScreenTools.defaultFontPixelHeight * 0.55
                visible: _mpc_z_vel_all

                SettingsGroupLayout {
                    Layout.fillWidth:   true
                    enabled:            zVelCheckbox.checked
                    heading:            qsTr("Vertical velocity (m/s)")
                    headingDescription: qsTr("Limit the vertical velocity (applies to all modes).")
                    showDividers:       false

                    // It's a bit tricky to handle the fact that the parameter goes negative to signal disabled.
                    // We can't allow the slider to go negative, hence all the hoops to jump through with value and loadComplete.
                    ValueSlider {
                        Layout.fillWidth:   true
                        from:               0.2
                        to:                 8
                        majorTickStepSize:  0.2
                        value:              { value = _mpc_z_vel_all ? Math.abs(_mpc_z_vel_all.value) : (from + to) / 2 }
                        decimalPlaces:      _mpc_z_vel_all ? _mpc_z_vel_all.decimalPlaces : 0
                        rulerColor:         flightBehavior._accentGreen

                        property bool loadComplete: false

                        Component.onCompleted: loadComplete = true

                        onValueChanged: {
                            if (loadComplete && enabled) {
                                _mpc_z_vel_all.value = value
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing:          ScreenTools.defaultFontPixelWidth

                    BehaviorBodyLabel {
                        Layout.fillWidth:    true
                        Layout.minimumWidth: 0
                        text:                qsTr("Enable vertical velocity slider (if enabled, individual velocity limit parameters are automatically set)")
                    }

                    QGCCheckBox {
                        id:               zVelCheckbox
                        Layout.alignment: Qt.AlignTop | Qt.AlignRight
                        text:             ""
                        checked:          _mpc_z_vel_all && _mpc_z_vel_all.value >= 0
                        onClicked:        _mpc_z_vel_all.value = checked ? Math.abs(_mpc_z_vel_all.value) : -Math.abs(_mpc_z_vel_all.value)
                    }
                }
            }

            SectionDivider { visible: _mpc_z_vel_all }

            SettingsGroupLayout {
                width:              mainColumn.controlsWidth
                heading:            qsTr("Mission Turning Radius")
                headingDescription: qsTr("Increasing this leads to rounder turns in missions (corner cutting). Use the minimum value for accurate corner tracking.")
                showDividers:       false

                FactSlider {
                    Layout.fillWidth:       true
                    from:               QGroundControl.unitsConversion.metersToAppSettingsHorizontalDistanceUnits(2)
                    to:                 QGroundControl.unitsConversion.metersToAppSettingsHorizontalDistanceUnits(16)
                    majorTickStepSize:  0.5
                    fact:               controller.getParameterFact(-1, "NAV_ACC_RAD")
                    rulerColor:         flightBehavior._accentGreen
                }
            }

            SectionDivider { }
        }
    }
}
