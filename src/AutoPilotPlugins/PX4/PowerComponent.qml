import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls
import QGroundControl.AutoPilotPlugins.PX4

SetupPage {
    id:              powerPage
    pageComponent:   pageComponent
    pageDescription: ""

    Component {
        id: pageComponent

        Item {
            width:  availableWidth
            height: innerColumn.height + _pageHPad

            readonly property string _highlightPrefix: "<font color=\"" + qgcPal.warningText + "\">"
            readonly property string _highlightSuffix: "</font>"
            readonly property color  _titleColor:      qgcPal.globalTheme === QGCPalette.Dark ? "#AEAEB2" : "#3A3A3C"
            readonly property color  _bodyColor:       qgcPal.globalTheme === QGCPalette.Dark ? "#8E8E93" : "#3A3A3C"
            readonly property real   _titlePointSize:  ScreenTools.defaultFontPointSize + 1
            readonly property real   _labelPointSize:  ScreenTools.defaultFontPointSize
            readonly property real   _bodyPointSize:   ScreenTools.smallFontPointSize
            readonly property real   _pageHPad:        ScreenTools.defaultFontPixelWidth * 2.2
            readonly property real   _cardPad:         ScreenTools.defaultFontPixelWidth * 1.6
            readonly property real   _cardRadius:      ScreenTools.defaultFontPixelWidth * 0.75
            readonly property real   _innerRadius:     ScreenTools.defaultFontPixelWidth * 0.55
            readonly property real   _comboRadius:     ScreenTools.defaultFontPixelHeight * 0.35
            readonly property real   _comboHeight:     ScreenTools.defaultFontPixelHeight * 1.85
            readonly property color  _greenPill:       "#00a04c"
            readonly property color  _greenPillText:   "#FFFFFF"
            readonly property color  _cardFill:        qgcPal.globalTheme === QGCPalette.Dark ? qgcPal.windowShade : "#FFFFFF"
            readonly property color  _cardBorder:      qgcPal.globalTheme === QGCPalette.Dark ? qgcPal.windowShade : "#E6E6E6"
            readonly property color  _innerFill:       qgcPal.globalTheme === QGCPalette.Dark ? qgcPal.window : "#FFFFFF"
            readonly property color  _graySoft:        qgcPal.globalTheme === QGCPalette.Dark ? qgcPal.windowShade : "#F2F2F2"
            readonly property color  _dividerColor:    qgcPal.globalTheme === QGCPalette.Dark ? qgcPal.windowShade : "#EFEFEF"
            readonly property color  _warningRed:      "#E53935"
            readonly property bool   _narrow:          availableWidth < ScreenTools.defaultFontPixelWidth * 48
            readonly property string _powerDescription: qsTr("Power Setup is used to setup battery parameters as well as advanced settings for propellers.")

            property Fact _uavcanEnable:             controller.getParameterFact(-1, "UAVCAN_ENABLE", false)
            property int  _indexedBatteryParamCount: getIndexedBatteryParamCount()

            function getIndexedBatteryParamCount() {
                var batteryIndex = 1
                do {
                    if (!controller.parameterExists(-1, "BAT#_SOURCE".replace("#", batteryIndex)))
                        return batteryIndex - 1
                    batteryIndex++
                } while (true)
            }

            PowerComponentController {
                id:                  controller
                onOldFirmware:       mainWindow.showMessageDialog(qsTr("ESC Calibration"), qsTr("%1 cannot perform ESC Calibration with this version of firmware. You will need to upgrade to a newer firmware.").arg(QGroundControl.appName))
                onNewerFirmware:     mainWindow.showMessageDialog(qsTr("ESC Calibration"), qsTr("%1 cannot perform ESC Calibration with this version of firmware. You will need to upgrade %1.").arg(QGroundControl.appName))
                onDisconnectBattery: mainWindow.showMessageDialog(qsTr("ESC Calibration failed"), qsTr("You must disconnect the battery prior to performing ESC Calibration. Disconnect your battery and try again."))
                onConnectBattery:    escCalibrationDlgComponent.createObject(mainWindow).open()
            }

            component HeadingLabel: QGCLabel {
                color:          _titleColor
                font.bold:      true
                font.pointSize: _titlePointSize
                font.family:    ScreenTools.normalFontFamily
                wrapMode:       Text.WordWrap
            }

            component SettingLabel: QGCLabel {
                color:          _titleColor
                font.pointSize: _labelPointSize
                font.family:    ScreenTools.normalFontFamily
                wrapMode:       Text.NoWrap
                elide:          Text.ElideNone
            }

            component BodyLabel: QGCLabel {
                color:          _bodyColor
                font.pointSize: _bodyPointSize
                font.family:    ScreenTools.normalFontFamily
                wrapMode:       Text.WordWrap
            }

            component GreenFactCombo: FactComboBox {
                id:                     greenCombo
                indexModel:             false
                sizeToContents:         false
                Layout.preferredHeight: _comboHeight
                Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 16
                Layout.minimumWidth:    ScreenTools.defaultFontPixelWidth * 14
                Layout.fillWidth:       true
                leftPadding:            ScreenTools.defaultFontPixelWidth * 1.1
                rightPadding:           ScreenTools.defaultFontPixelWidth * 2.4

                contentItem: Text {
                    text:              greenCombo.currentText
                    color:             _greenPillText
                    font.family:       ScreenTools.normalFontFamily
                    font.pointSize:    ScreenTools.defaultFontPointSize
                    verticalAlignment: Text.AlignVCenter
                    elide:             Text.ElideRight
                }

                background: Item {
                    implicitHeight: _comboHeight
                    Rectangle {
                        anchors.fill: parent
                        color:        greenCombo.enabled ? _greenPill : qgcPal.windowShade
                        radius:       _comboRadius
                    }
                }

                indicator: QGCColoredImage {
                    anchors.right:          parent.right
                    anchors.rightMargin:    ScreenTools.defaultFontPixelWidth * 0.7
                    anchors.verticalCenter: parent.verticalCenter
                    height:                 ScreenTools.defaultFontPixelWidth * 1.1
                    width:                  height
                    source:                 "/qmlimages/arrow-down.png"
                    color:                  _greenPillText
                }
            }

            component PowerFactField: FactTextField {
                id:                     powerField
                showHelp:               false
                showUnits:              true
                Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 11
                Layout.maximumWidth:    ScreenTools.defaultFontPixelWidth * 11
                Layout.preferredHeight: _comboHeight
                Layout.alignment:       Qt.AlignVCenter | Qt.AlignRight
                horizontalAlignment:    Text.AlignRight
                fieldTextColor:         _titleColor
                fieldBackgroundColor:   _graySoft
                activeFocusBorderColor: _greenPill
            }

            component PowerCard: Rectangle {
                Layout.fillWidth: true
                radius:           _cardRadius
                color:            _cardFill
                border.width:     1
                border.color:     _cardBorder
                implicitHeight:   cardCol.implicitHeight + _cardPad * 2

                default property alias contentData: cardCol.data

                ColumnLayout {
                    id:              cardCol
                    anchors.left:    parent.left
                    anchors.right:   parent.right
                    anchors.top:     parent.top
                    anchors.margins: _cardPad
                    spacing:         ScreenTools.defaultFontPixelHeight * 0.65
                }
            }

            component AccentButton: Item {
                id:               accentBtn
                property string   text: qsTr("Calibrate")
                signal            clicked()

                implicitWidth:  Math.max(ScreenTools.defaultFontPixelWidth * 14, btnLabel.implicitWidth + ScreenTools.defaultFontPixelWidth * 4)
                implicitHeight: ScreenTools.defaultFontPixelHeight * 2.15

                Rectangle {
                    anchors.fill: parent
                    radius:       ScreenTools.defaultFontPixelWidth * 0.35
                    color:        accentMouse.pressed ? Qt.darker(_graySoft, 1.04) : _graySoft
                    border.width: 1
                    border.color: _cardBorder

                    Rectangle {
                        anchors.left:   parent.left
                        anchors.top:    parent.top
                        anchors.bottom: parent.bottom
                        width:          3
                        radius:         1
                        color:          _greenPill
                    }
                }

                QGCLabel {
                    id:              btnLabel
                    anchors.centerIn: parent
                    text:            accentBtn.text
                    color:           _titleColor
                    font.pointSize:  _labelPointSize
                    font.family:     ScreenTools.normalFontFamily
                }

                MouseArea {
                    id:           accentMouse
                    anchors.fill: parent
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    accentBtn.clicked()
                }
            }

            ColumnLayout {
                id:                 innerColumn
                anchors.left:       parent.left
                anchors.right:      parent.right
                anchors.top:        parent.top
                anchors.leftMargin: _pageHPad
                anchors.rightMargin:_pageHPad
                anchors.topMargin:  ScreenTools.defaultFontPixelHeight * 0.2
                spacing:            ScreenTools.defaultFontPixelHeight * 1.05

                Repeater {
                    id:    batterySetupRepeater
                    model: _indexedBatteryParamCount

                    Loader {
                        Layout.fillWidth: true
                        sourceComponent:  batterySetupComponent
                        property int  batteryIndex:     index + 1
                        property bool showBatteryIndex: batterySetupRepeater.count > 1
                        onLoaded: {
                            if (item)
                                item.width = Qt.binding(function() { return width })
                        }
                    }
                }

                PowerCard {
                    HeadingLabel {
                        Layout.fillWidth: true
                        text:             qsTr("ESC PWM Minimum and Maximum Calibration")
                    }

                    Rectangle {
                        Layout.fillWidth:   true
                        implicitHeight:     warnRow.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.9
                        radius:             _innerRadius
                        color:              _graySoft
                        border.width:       1
                        border.color:       _cardBorder

                        RowLayout {
                            id:              warnRow
                            anchors.left:    parent.left
                            anchors.right:   parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: ScreenTools.defaultFontPixelWidth * 0.9
                            spacing:         ScreenTools.defaultFontPixelWidth * 0.8

                            Item {
                                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.45
                                Layout.preferredHeight: Layout.preferredWidth

                                Canvas {
                                    id:            warnCanvas
                                    anchors.fill:  parent
                                    antialiasing:  true
                                    Component.onCompleted: requestPaint()
                                    onWidthChanged:        requestPaint()
                                    onHeightChanged:       requestPaint()
                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.clearRect(0, 0, width, height)
                                        ctx.beginPath()
                                        ctx.moveTo(width * 0.5, height * 0.08)
                                        ctx.lineTo(width * 0.92, height * 0.90)
                                        ctx.lineTo(width * 0.08, height * 0.90)
                                        ctx.closePath()
                                        ctx.fillStyle = _greenPill
                                        ctx.fill()
                                    }
                                }

                                QGCLabel {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom:           parent.bottom
                                    anchors.bottomMargin:     parent.height * 0.10
                                    text:                     "!"
                                    color:                    "#FFFFFF"
                                    font.bold:                true
                                    font.pointSize:           ScreenTools.defaultFontPointSize
                                }
                            }

                            QGCLabel {
                                Layout.fillWidth: true
                                wrapMode:         Text.WordWrap
                                color:            _warningRed
                                font.pointSize:   _bodyPointSize
                                font.family:      ScreenTools.normalFontFamily
                                text:             qsTr("WARNING: Propellers must be removed from vehicle prior to performing ESC calibration.")
                            }
                        }
                    }

                    BodyLabel {
                        Layout.fillWidth: true
                        text:             qsTr("You must use USB connection for this operation.")
                    }

                    AccentButton {
                        text:      qsTr("Calibrate")
                        onClicked: controller.calibrateEsc()
                    }
                }

                QGCCheckBox {
                    id:        showUAVCAN
                    text:      qsTr("Show UAVCAN Settings")
                    textColor: _titleColor
                    checked:   _uavcanEnable ? _uavcanEnable.rawValue !== 0 : false
                }

                PowerCard {
                    visible: showUAVCAN.checked

                    HeadingLabel {
                        Layout.fillWidth: true
                        text:             qsTr("UAVCAN Bus Configuration")
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing:          ScreenTools.defaultFontPixelWidth

                        FactComboBox {
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 20
                            fact:                  _uavcanEnable
                            indexModel:            false
                        }

                        SettingLabel {
                            Layout.fillWidth: true
                            text:             qsTr("Change required restart")
                        }
                    }
                }

                PowerCard {
                    visible: showUAVCAN.checked

                    HeadingLabel {
                        Layout.fillWidth: true
                        text:             qsTr("UAVCAN Motor Index and Direction Assignment")
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        wrapMode:         Text.WordWrap
                        color:            _warningRed
                        font.pointSize:   _bodyPointSize
                        text:             qsTr("WARNING: Propellers must be removed from vehicle prior to performing UAVCAN ESC configuration.")
                    }

                    BodyLabel {
                        Layout.fillWidth: true
                        text:             qsTr("ESC parameters will only be accessible in the editor after assignment.")
                    }

                    BodyLabel {
                        Layout.fillWidth: true
                        text:             qsTr("Start the process, then turn each motor into its turn direction, in the order of their motor indices.")
                    }

                    RowLayout {
                        spacing: ScreenTools.defaultFontPixelWidth

                        AccentButton {
                            text:      qsTr("Start Assignment")
                            onClicked: controller.startBusConfigureActuators()
                        }

                        AccentButton {
                            text:      qsTr("Stop Assignment")
                            onClicked: controller.stopBusConfigureActuators()
                        }
                    }
                }
            }

            Component {
                id: batterySetupComponent

                ColumnLayout {
                    property var _controller:   controller
                    property int _batteryIndex: batteryIndex
                    spacing: ScreenTools.defaultFontPixelHeight * 0.7

                    BatteryParams {
                        id:           batParams
                        controller:   _controller
                        batteryIndex: _batteryIndex
                    }

                    property Fact battSource:        batParams.battSource
                    property Fact battNumCells:      batParams.battNumCells
                    property Fact battHighVolt:      batParams.battHighVolt
                    property Fact battLowVolt:       batParams.battLowVolt
                    property Fact battVoltLoadDrop:  batParams.battVoltLoadDrop
                    property Fact battVoltageDivider: batParams.battVoltageDivider
                    property Fact battAmpsPerVolt:   batParams.battAmpsPerVolt

                    readonly property bool battReady: battSource && battSource.rawValue != -1
                    readonly property real packMaxV:  (batParams.battNumCellsAvailable && batParams.battHighVoltAvailable)
                                                      ? battNumCells.value * battHighVolt.value : 0
                    readonly property real packMinV:  (batParams.battNumCellsAvailable && batParams.battLowVoltAvailable)
                                                      ? battNumCells.value * battLowVolt.value : 0
                    readonly property var  battGroup: _controller.vehicle ? _controller.vehicle.getFactGroup("battery" + (_batteryIndex - 1)) : null
                    readonly property real liveVolts: {
                        if (!battGroup || !battGroup.voltage)
                            return NaN
                        var v = Number(battGroup.voltage.value)
                        return isFinite(v) ? v : NaN
                    }
                    readonly property real fillRatio: {
                        if (packMaxV <= packMinV)
                            return 0
                        var v = isFinite(liveVolts) ? liveVolts : ((packMinV + packMaxV) * 0.45)
                        return Math.max(0, Math.min(1, (v - packMinV) / (packMaxV - packMinV)))
                    }

                    function getBatteryImage() {
                        switch (battNumCells ? battNumCells.value : 1) {
                        case 1:  return "/qmlimages/PowerComponentBattery_01cell.svg"
                        case 2:  return "/qmlimages/PowerComponentBattery_02cell.svg"
                        case 3:  return "/qmlimages/PowerComponentBattery_03cell.svg"
                        case 4:  return "/qmlimages/PowerComponentBattery_04cell.svg"
                        case 5:  return "/qmlimages/PowerComponentBattery_05cell.svg"
                        case 6:  return "/qmlimages/PowerComponentBattery_06cell.svg"
                        default: return "/qmlimages/PowerComponentBattery_01cell.svg"
                        }
                    }

                    HeadingLabel {
                        Layout.fillWidth: true
                        text:             qsTr("Power Config") + (showBatteryIndex ? (" " + _batteryIndex) : "")
                    }

                    BodyLabel {
                        Layout.fillWidth: true
                        Layout.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.15
                        text:             _powerDescription
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight:   cardBody.implicitHeight + ScreenTools.defaultFontPixelHeight * 2.0
                        radius:           _innerRadius
                        color:            _innerFill
                        border.width:     1
                        border.color:     _cardBorder

                        ColumnLayout {
                            id:              cardBody
                            anchors.left:    parent.left
                            anchors.right:   parent.right
                            anchors.top:     parent.top
                            anchors.margins: ScreenTools.defaultFontPixelWidth * 1.6
                            spacing:         ScreenTools.defaultFontPixelHeight * 1.1

                            GridLayout {
                                Layout.fillWidth:  true
                                columns:           2
                                columnSpacing:     ScreenTools.defaultFontPixelWidth * 1.4
                                rowSpacing:        ScreenTools.defaultFontPixelHeight * 0.85

                                SettingLabel {
                                    text:             qsTr("Source")
                                    Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                                }

                                GreenFactCombo {
                                    fact:             battSource
                                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                                }

                                SettingLabel {
                                    visible:          battReady && batParams.battNumCellsAvailable
                                    text:             qsTr("Number of Cells (in Series)")
                                    Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                                }

                                PowerFactField {
                                    visible: battReady && batParams.battNumCellsAvailable
                                    fact:    battNumCells
                                }

                                SettingLabel {
                                    visible:          battReady && batParams.battLowVoltAvailable
                                    text:             qsTr("Empty Voltage (per cell)")
                                    Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                                }

                                PowerFactField {
                                    visible: battReady && batParams.battLowVoltAvailable
                                    fact:    battLowVolt
                                }

                                SettingLabel {
                                    visible:          battReady && batParams.battHighVoltAvailable
                                    text:             qsTr("Full Voltage (per cell)")
                                    Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                                }

                                PowerFactField {
                                    visible: battReady && batParams.battHighVoltAvailable
                                    fact:    battHighVolt
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.15
                                visible:          battReady && batParams.battNumCellsAvailable && batParams.battLowVoltAvailable && batParams.battHighVoltAvailable
                                implicitHeight:   batteryVisual.implicitHeight + ScreenTools.defaultFontPixelHeight * 1.4
                                radius:           ScreenTools.defaultFontPixelWidth * 0.75
                                color:            qgcPal.globalTheme === QGCPalette.Dark ? qgcPal.windowShade : "#E8E8E8"
                                border.width:     1
                                border.color:     _dividerColor

                                ColumnLayout {
                                    id:              batteryVisual
                                    anchors.left:    parent.left
                                    anchors.right:   parent.right
                                    anchors.top:     parent.top
                                    anchors.margins: ScreenTools.defaultFontPixelWidth * 1.1
                                    spacing:         ScreenTools.defaultFontPixelHeight * 0.55

                                    QGCColoredImage {
                                        Layout.alignment:       Qt.AlignHCenter
                                        Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 2.8
                                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 5.0
                                        sourceSize.height:      height
                                        fillMode:               Image.PreserveAspectFit
                                        smooth:                 true
                                        color:                  _titleColor
                                        source:                 getBatteryImage()
                                    }

                                    Row {
                                        Layout.alignment: Qt.AlignHCenter
                                        spacing:          ScreenTools.defaultFontPixelWidth * 0.5

                                        Rectangle {
                                            width:  maxLbl.implicitWidth + ScreenTools.defaultFontPixelWidth * 1.8
                                            height: ScreenTools.defaultFontPixelHeight * 1.5
                                            radius: ScreenTools.defaultFontPixelWidth * 0.35
                                            color:  _cardFill

                                            QGCLabel {
                                                id:               maxLbl
                                                anchors.centerIn: parent
                                                text:             qsTr("Max %1 V").arg(packMaxV.toFixed(1))
                                                color:            _titleColor
                                                font.pointSize:   _bodyPointSize
                                            }
                                        }

                                        Rectangle {
                                            width:  minLbl.implicitWidth + ScreenTools.defaultFontPixelWidth * 1.8
                                            height: ScreenTools.defaultFontPixelHeight * 1.5
                                            radius: ScreenTools.defaultFontPixelWidth * 0.35
                                            color:  _cardFill

                                            QGCLabel {
                                                id:               minLbl
                                                anchors.centerIn: parent
                                                text:             qsTr("Min %1 V").arg(packMinV.toFixed(1))
                                                color:            _titleColor
                                                font.pointSize:   _bodyPointSize
                                            }
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth:       true
                                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.7

                                        Rectangle {
                                            anchors.left:           parent.left
                                            anchors.right:          parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            height:                 ScreenTools.defaultFontPixelHeight * 0.5
                                            radius:                 height / 2
                                            color:                  _cardFill

                                            Rectangle {
                                                width:  Math.max(height, parent.width * fillRatio)
                                                height: parent.height
                                                radius: parent.radius
                                                color:  _greenPill
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true

                                        BodyLabel { text: packMinV.toFixed(1) + " V" }
                                        Item { Layout.fillWidth: true }
                                        BodyLabel { text: packMaxV.toFixed(1) + " V" }
                                    }
                                }
                            }
                        }
                    }

                    QGCCheckBox {
                        id:        showAdvanced
                        text:      qsTr("Show Advanced Settings")
                        textColor: _titleColor
                        visible:   battReady && (batParams.battVoltageDividerAvailable || batParams.battAmpsPerVoltAvailable || batParams.battVoltLoadDropAvailable)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing:          ScreenTools.defaultFontPixelHeight * 0.45
                        visible:          showAdvanced.checked

                        RowLayout {
                            Layout.fillWidth: true
                            visible:          batParams.battVoltageDividerAvailable
                            spacing:          ScreenTools.defaultFontPixelWidth

                            SettingLabel {
                                Layout.fillWidth: true
                                text:             qsTr("Voltage divider")
                            }

                            PowerFactField { fact: battVoltageDivider; showUnits: false }

                            QGCButton {
                                text:      qsTr("Calculate")
                                onClicked: calcVoltageDividerDlgComponent.createObject(mainWindow, { batteryIndex: _batteryIndex }).open()
                            }
                        }

                        BodyLabel {
                            Layout.fillWidth: true
                            visible:          batParams.battVoltageDividerAvailable
                            text:             qsTr("If the battery voltage reported by the vehicle is largely different than the voltage read externally using a voltmeter you can adjust the voltage multiplier value to correct this. Click the Calculate button for help with calculating a new value.")
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible:          batParams.battAmpsPerVoltAvailable
                            spacing:          ScreenTools.defaultFontPixelWidth

                            SettingLabel {
                                Layout.fillWidth: true
                                text:             qsTr("Amps per volt")
                            }

                            PowerFactField { fact: battAmpsPerVolt; showUnits: false }

                            QGCButton {
                                text:      qsTr("Calculate")
                                onClicked: calcAmpsPerVoltDlgComponent.createObject(mainWindow, { batteryIndex: _batteryIndex }).open()
                            }
                        }

                        BodyLabel {
                            Layout.fillWidth: true
                            visible:          batParams.battAmpsPerVoltAvailable
                            text:             qsTr("If the current draw reported by the vehicle is largely different than the current read externally using a current meter you can adjust the amps per volt value to correct this. Click the Calculate button for help with calculating a new value.")
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible:          batParams.battVoltLoadDropAvailable
                            spacing:          ScreenTools.defaultFontPixelWidth

                            SettingLabel {
                                Layout.fillWidth: true
                                text:             qsTr("Voltage Drop on Full Load (per cell)")
                            }

                            PowerFactField { fact: battVoltLoadDrop }
                        }

                        BodyLabel {
                            Layout.fillWidth: true
                            visible:          batParams.battVoltLoadDropAvailable
                            text:             qsTr("Batteries show less voltage at high throttle. Enter the difference in Volts between idle throttle and full throttle, divided by the number of battery cells. Leave at the default if unsure. ") +
                                              _highlightPrefix + qsTr("If this value is set too high, the battery might be deep discharged and damaged.") + _highlightSuffix
                        }
                    }
                }
            }

            Component {
                id: calcVoltageDividerDlgComponent

                QGCPopupDialog {
                    title:   qsTr("Calculate Voltage Divider")
                    buttons: Dialog.Close

                    property alias batteryIndex: batParams.batteryIndex
                    property var   _controller:  controller
                    property var   _batteryFactGroup: controller.vehicle.getFactGroup("battery" + (batteryIndex - 1))

                    BatteryParams {
                        id:           batParams
                        controller:   _controller
                    }

                    ColumnLayout {
                        spacing: ScreenTools.defaultFontPixelHeight

                        QGCLabel {
                            Layout.preferredWidth: gridLayout.width
                            wrapMode:              Text.WordWrap
                            text:                  qsTr("Measure battery voltage using an external voltmeter and enter the value below. Click Calculate to set the new voltage multiplier.")
                        }

                        GridLayout {
                            id:      gridLayout
                            columns: 2

                            QGCLabel { text: qsTr("Measured voltage:") }
                            QGCTextField { id: measuredVoltage; numericValuesOnly: true }

                            QGCLabel { text: qsTr("Vehicle voltage:") }
                            QGCLabel { text: _batteryFactGroup.voltage.valueString }

                            QGCLabel { text: qsTr("Voltage divider:") }
                            FactLabel { fact: batParams.battVoltageDivider }
                        }

                        QGCButton {
                            text: qsTr("Calculate")
                            onClicked: {
                                var measuredVoltageValue = parseFloat(measuredVoltage.text)
                                if (measuredVoltageValue === 0 || isNaN(measuredVoltageValue))
                                    return
                                var newVoltageDivider = (measuredVoltageValue * batParams.battVoltageDivider.value) / _batteryFactGroup.voltage.value
                                if (newVoltageDivider > 0)
                                    batParams.battVoltageDivider.value = newVoltageDivider
                            }
                        }
                    }
                }
            }

            Component {
                id: calcAmpsPerVoltDlgComponent

                QGCPopupDialog {
                    title:   qsTr("Calculate Amps per Volt")
                    buttons: Dialog.Close

                    property alias batteryIndex: batParams.batteryIndex
                    property var   _controller:  controller
                    property var   _batteryFactGroup: controller.vehicle.getFactGroup("battery" + (batteryIndex - 1))

                    BatteryParams {
                        id:           batParams
                        controller:   _controller
                    }

                    ColumnLayout {
                        spacing: ScreenTools.defaultFontPixelHeight

                        QGCLabel {
                            Layout.preferredWidth: gridLayout.width
                            wrapMode:              Text.WordWrap
                            text:                  qsTr("Measure current draw using an external current meter and enter the value below. Click Calculate to set the new amps per volt value.")
                        }

                        GridLayout {
                            id:      gridLayout
                            columns: 2

                            QGCLabel { text: qsTr("Measured current:") }
                            QGCTextField { id: measuredCurrent; numericValuesOnly: true }

                            QGCLabel { text: qsTr("Vehicle current:") }
                            QGCLabel { text: _batteryFactGroup.current.valueString }

                            QGCLabel { text: qsTr("Amps per volt:") }
                            FactLabel { fact: batParams.battAmpsPerVolt }
                        }

                        QGCButton {
                            text: qsTr("Calculate")
                            onClicked: {
                                var measuredCurrentValue = parseFloat(measuredCurrent.text)
                                if (measuredCurrentValue === 0 || isNaN(measuredCurrentValue))
                                    return
                                var newAmpsPerVolt = (measuredCurrentValue * batParams.battAmpsPerVolt.value) / _batteryFactGroup.current.value
                                if (newAmpsPerVolt != 0)
                                    batParams.battAmpsPerVolt.value = newAmpsPerVolt
                            }
                        }
                    }
                }
            }

            Component {
                id: escCalibrationDlgComponent

                QGCPopupDialog {
                    id:                  escCalibrationDlg
                    title:               qsTr("ESC Calibration")
                    buttons:             Dialog.Ok
                    acceptButtonEnabled: false

                    Connections {
                        target: controller
                        function onBatteryConnected() { textLabel.text = qsTr("Performing calibration. This will take a few seconds..") }
                        function onCalibrationFailed(errorMessage) {
                            escCalibrationDlg.acceptButtonEnabled = true
                            textLabel.text = _highlightPrefix + qsTr("ESC Calibration failed. ") + _highlightSuffix + errorMessage
                        }
                        function onCalibrationSuccess() {
                            escCalibrationDlg.acceptButtonEnabled = true
                            textLabel.text = qsTr("Calibration complete. You can disconnect your battery now if you like.")
                        }
                    }

                    ColumnLayout {
                        QGCLabel {
                            id:                  textLabel
                            wrapMode:            Text.WordWrap
                            text:                _highlightPrefix + qsTr("WARNING: Props must be removed from vehicle prior to performing ESC calibration.") + _highlightSuffix + qsTr(" Connect the battery now and calibration will begin.")
                            Layout.fillWidth:    true
                            Layout.maximumWidth: mainWindow.width / 2
                        }
                    }
                }
            }
        }
    }
}
