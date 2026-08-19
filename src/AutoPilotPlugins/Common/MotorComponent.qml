import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

SetupPage {
    id:             motorPage
    pageComponent:  pageComponent

    property bool userLetterMotorIndices: false

    readonly property int _barHeight:           10
    readonly property int _barWidth:            5
    readonly property int _sliderWidth:         15
    readonly property int _motorTimeoutSecs:    3
    readonly property real _labelPointSize:     ScreenTools.defaultFontPointSize
    readonly property real _pagePad:            ScreenTools.defaultFontPixelWidth * 2.2
    readonly property real _sectionGap:         ScreenTools.defaultFontPixelHeight * 1.15
    readonly property real _controlsMaxWidth:   ScreenTools.defaultFontPixelWidth * 48
    readonly property color _accentGreen:       "#00A651"
    readonly property color _dividerColor:      qgcPal.globalTheme === QGCPalette.Dark
                                                ? qgcPal.windowShade
                                                : "#E5E5E5"

    function motorIndexToString(motorIndex) {
        let asciiA = 65;
        if (userLetterMotorIndices) {
            return String.fromCharCode(asciiA + motorIndex);
        } else {
            return motorIndex + 1;
        }
    }

    FactPanelController {
        id: controller
    }

    component MotorSettingLabel: QGCLabel {
        color:          motorPage._titleColor
        font.bold:      false
        font.pointSize: motorPage._labelPointSize
        font.family:    ScreenTools.normalFontFamily
    }

    component MotorBodyLabel: QGCLabel {
        color:          motorPage._bodyColor
        font.bold:      false
        font.pointSize: motorPage._bodyPointSize
        font.family:    ScreenTools.normalFontFamily
        wrapMode:       Text.WordWrap
    }

    component SectionDivider: Rectangle {
        width:  parent ? parent.width : 0
        height: 1
        color:  motorPage._dividerColor
    }

    Component {
        id: pageComponent

        Column {
            id:      mainColumn
            x:       motorPage._pagePad
            width:   Math.max(0, motorPage.availableWidth - (motorPage._pagePad * 2))
            spacing: motorPage._sectionGap

            readonly property real controlsWidth: Math.min(width, motorPage._controlsMaxWidth)

            MotorSettingLabel {
                width:      parent.width
                text:       qsTr("Warning: Unable to determine motor count")
                color:      qgcPal.warningText
                visible:    controller.vehicle.motorCount == -1
                wrapMode:   Text.WordWrap
            }

            Row {
                id:         motorSlider
                width:      mainColumn.controlsWidth
                enabled:    safetySwitch.checked
                spacing:    ScreenTools.defaultFontPixelWidth * 4

                ValueSlider {
                    id:                 sliderThrottle
                    width:              parent.width
                    label:              qsTr("Throttle")
                    from:               0
                    to:                 100
                    majorTickStepSize:  5
                    decimalPlaces: 0
                    unitsString: qsTr("%")
                    rulerColor: motorPage._accentGreen
                }
            } // Row

            SectionDivider { }

            MotorSettingLabel {
                width:    parent.width
                wrapMode: Text.WordWrap
                text:     qsTr("Make sure you remove all props.")
            }

            Flow {
                id:         motorButtons
                width:      mainColumn.controlsWidth
                height:     childrenRect.height
                enabled:    safetySwitch.checked
                spacing:    ScreenTools.defaultFontPixelWidth * 2

                Repeater {
                    id:         buttonRepeater
                    model:      controller.vehicle.motorCount === -1 ? 8 : controller.vehicle.motorCount

                    QGCButton {
                        id:         button
                        text:       motorIndexToString(index)
                        onClicked:  {
                            controller.vehicle.motorTest(index + 1, sliderThrottle.value, sliderThrottle.value === 0 ? 0 : _motorTimeoutSecs, true)
                        }
                    }
                } // Repeater

                QGCButton {
                    id:         allButton
                    text:       qsTr("All")
                    onClicked:  {
                        for (var motorIndex=0; motorIndex<buttonRepeater.count; motorIndex++) {
                            controller.vehicle.motorTest(motorIndex + 1, sliderThrottle.value, sliderThrottle.value === 0 ? 0 : _motorTimeoutSecs, true)
                        }
                    }
                }

                QGCButton {
                    id:         allStopButton
                    text:       qsTr("Stop")
                    onClicked:  {
                        for (var motorIndex=0; motorIndex<buttonRepeater.count; motorIndex++) {
                            controller.vehicle.motorTest(motorIndex + 1, 0, 0, true)
                        }
                    }
                }
            } // Flow

            SectionDivider { }

            RowLayout {
                width:   mainColumn.controlsWidth
                spacing: ScreenTools.defaultFontPixelWidth

                MotorSettingLabel {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text:             safetySwitch.checked
                                      ? qsTr("Careful: Motors are enabled")
                                      : qsTr("Propellers are removed - Enable slider and motors")
                    color:            qgcPal.warningText
                    wrapMode:         Text.WordWrap
                }

                QGCCheckBoxSlider {
                    id:               safetySwitch
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                    onClicked: {
                        if (!checked) {
                            sliderThrottle.setValue(0);
                        }
                    }
                }

            } // RowLayout

            SectionDivider { }
        } // Column
    } // Component
} // SetupPage
