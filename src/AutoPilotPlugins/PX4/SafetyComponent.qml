import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

SetupPage {
    id:             safetyPage
    pageComponent:  pageComponent
    pageDescription: ""
    Component {
        id: pageComponent

        Item {
            width:      Math.max(availableWidth, outerColumn.width)
            height:     outerColumn.height + (_pagePad * 2)

            FactPanelController {
                id:         controller
            }

            readonly property string hitlParam: "SYS_HITL"

            property real _margins:         ScreenTools.defaultFontPixelHeight * 0.8
            property real _pagePad:         ScreenTools.defaultFontPixelWidth * 2.2
            property real _labelWidth:      ScreenTools.defaultFontPixelWidth  * 30
            property real _editFieldWidth:  ScreenTools.defaultFontPixelWidth  * 20
            property real _imageHeight:     ScreenTools.defaultFontPixelHeight * 3
            property real _imageWidth:      _imageHeight * 2
            property bool _narrow:          availableWidth < ScreenTools.defaultFontPixelWidth * 42
            readonly property real  _cardPad:        ScreenTools.defaultFontPixelHeight * 0.9
            readonly property real  _sectionGap:     ScreenTools.defaultFontPixelHeight * 0.7
            readonly property real  _cardRadius:     ScreenTools.defaultFontPixelHeight * 0.45
            readonly property color _titleColor:     qgcPal.globalTheme === QGCPalette.Dark ? "#AEAEB2" : "#3A3A3C"
            readonly property color _bodyColor:      qgcPal.globalTheme === QGCPalette.Dark ? "#8E8E93" : "#3A3A3C"
            readonly property real  _titlePointSize: ScreenTools.defaultFontPointSize + 1
            readonly property real  _labelPointSize: ScreenTools.defaultFontPointSize
            readonly property real  _bodyPointSize:  ScreenTools.smallFontPointSize
            readonly property color _grayCard:       qgcPal.globalTheme === QGCPalette.Dark ? qgcPal.windowShade : "#F2F2F2"
            readonly property color _greenPill:      "#00a04c"
            readonly property color _greenPillText:  "#FFFFFF"
            readonly property real  _comboRadius:    ScreenTools.defaultFontPixelHeight * 0.35
            readonly property real  _comboHeight:    ScreenTools.defaultFontPixelHeight * 1.85

            component GreenComboBox: QGCComboBox {
                id:                     greenBox
                sizeToContents:         false
                Layout.fillWidth:       true
                Layout.minimumWidth:    0
                Layout.preferredHeight: _comboHeight
                leftPadding:            ScreenTools.defaultFontPixelWidth * 1.2
                rightPadding:           ScreenTools.defaultFontPixelWidth * 2.6

                contentItem: Text {
                    text:                   greenBox.currentText
                    color:                  _greenPillText
                    font.family:            ScreenTools.normalFontFamily
                    font.pointSize:         ScreenTools.defaultFontPointSize
                    verticalAlignment:      Text.AlignVCenter
                    elide:                  Text.ElideRight
                }

                background: Item {
                    implicitHeight: _comboHeight

                    Rectangle {
                        anchors.fill:   parent
                        color:          greenBox.enabled ? _greenPill : qgcPal.windowShade
                        radius:         _comboRadius
                    }

                    RippleEffect {
                        id:          greenBoxRipple
                        rippleColor: Qt.rgba(1, 1, 1, 0.40)
                        clipRadius:  _comboRadius
                    }

                    Connections {
                        target: greenBox
                        function onPressedChanged() {
                            if (greenBox.pressed)
                                greenBoxRipple.tap(greenBox.pressX, greenBox.pressY)
                        }
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

            component GreenFactCombo: FactComboBox {
                id:                     greenCombo
                indexModel:             false
                sizeToContents:         false
                Layout.fillWidth:       true
                Layout.minimumWidth:    0
                Layout.preferredHeight: _comboHeight
                leftPadding:            ScreenTools.defaultFontPixelWidth * 1.2
                rightPadding:           ScreenTools.defaultFontPixelWidth * 2.6

                contentItem: Text {
                    text:                   greenCombo.currentText
                    color:                  _greenPillText
                    font.family:            ScreenTools.normalFontFamily
                    font.pointSize:         ScreenTools.defaultFontPointSize
                    verticalAlignment:      Text.AlignVCenter
                    elide:                  Text.ElideRight
                }

                background: Item {
                    implicitHeight: _comboHeight

                    Rectangle {
                        anchors.fill:   parent
                        color:          greenCombo.enabled ? _greenPill : qgcPal.windowShade
                        radius:         _comboRadius
                    }

                    RippleEffect {
                        id:          greenComboRipple
                        rippleColor: Qt.rgba(1, 1, 1, 0.40)
                        clipRadius:  _comboRadius
                    }

                    Connections {
                        target: greenCombo
                        function onPressedChanged() {
                            if (greenCombo.pressed)
                                greenComboRipple.tap(greenCombo.pressX, greenCombo.pressY)
                        }
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

            component HeadingLabel: QGCLabel {
                color:          _titleColor
                font.bold:      true
                font.pointSize: _titlePointSize
                font.family:    ScreenTools.normalFontFamily
                wrapMode:       Text.WordWrap
            }

            component SettingLabel: QGCLabel {
                color:          _titleColor
                font.bold:      false
                font.pointSize: _labelPointSize
                font.family:    ScreenTools.normalFontFamily
                wrapMode:       Text.WordWrap
            }

            component BodyLabel: QGCLabel {
                color:          _bodyColor
                font.bold:      false
                font.pointSize: _bodyPointSize
                font.family:    ScreenTools.normalFontFamily
                wrapMode:       Text.WordWrap
            }

            component SafetyFactField: FactTextField {
                id:                     safetyField
                showUnits:              false
                showHelp:               false
                Layout.fillWidth:       _narrow
                Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 14
                Layout.minimumWidth:    0
                Layout.preferredHeight: _comboHeight
                Layout.alignment:       Qt.AlignRight
                leftPadding:            ScreenTools.defaultFontPixelWidth * 1.0
                rightPadding:           ScreenTools.defaultFontPixelWidth * (unitsLabel !== "" ? 4.6 : 1.0)
                fieldTextColor:         "#1C1C1E"
                fieldBackgroundColor:   "#FFFFFF"
                activeFocusBorderColor: _greenPill

                background: Rectangle {
                    implicitHeight: _comboHeight
                    implicitWidth:  ScreenTools.defaultFontPixelWidth * 14
                    radius:         _comboRadius
                    color:          "#FFFFFF"
                    border.width:   safetyField.validationError ? 2 : 1
                    border.color:   safetyField.validationError ? qgcPal.colorRed : _greenPill

                    Text {
                        anchors.right:          parent.right
                        anchors.rightMargin:    ScreenTools.defaultFontPixelWidth * 0.9
                        anchors.verticalCenter: parent.verticalCenter
                        text:                   safetyField.unitsLabel
                        color:                  "#3A3A3C"
                        font.family:            ScreenTools.normalFontFamily
                        font.pointSize:         ScreenTools.defaultFontPointSize
                        visible:                safetyField.unitsLabel !== ""
                    }
                }
            }

            property Fact _enableLogging:       controller.getParameterFact(-1, "SDLOG_MODE")
            property Fact _fenceAction:         controller.getParameterFact(-1, "GF_ACTION")
            property Fact _fenceRadius:         controller.getParameterFact(-1, "GF_MAX_HOR_DIST")
            property Fact _fenceAlt:            controller.getParameterFact(-1, "GF_MAX_VER_DIST")
            property Fact _rtlLandDelay:        controller.getParameterFact(-1, "RTL_LAND_DELAY")
            property Fact _lowBattAction:       controller.getParameterFact(-1, "COM_LOW_BAT_ACT")
            property Fact _battWarnThr:         controller.getParameterFact(-1, "BAT_LOW_THR")
            property Fact _battCritThr:         controller.getParameterFact(-1, "BAT_CRIT_THR")
            property Fact _battEmergThr:        controller.getParameterFact(-1, "BAT_EMERGEN_THR")
            property Fact _rcLossAction:        controller.getParameterFact(-1, "NAV_RCL_ACT")
            property Fact _dlLossAction:        controller.getParameterFact(-1, "NAV_DLL_ACT")
            property Fact _disarmLandDelay:     controller.getParameterFact(-1, "COM_DISARM_LAND")
            property Fact _collisionPrevention: controller.getParameterFact(-1, "CP_DIST")
            property Fact _landSpeedMC:         controller.getParameterFact(-1, "MPC_LAND_SPEED", false)
            property bool _hitlAvailable:       controller.parameterExists(-1, hitlParam)
            property Fact _hitlEnabled:         controller.getParameterFact(-1, hitlParam, false)

            ColumnLayout {
                id:         outerColumn
                spacing:    _margins
                anchors.left:               parent.left
                anchors.right:              parent.right
                anchors.top:                parent.top
                anchors.margins:            _pagePad

                Rectangle {
                    id:                 battFailsafeCard
                    Layout.fillWidth:   true
                    height:             battCardCol.height + _cardPad * 2
                    radius:             _cardRadius
                    color:              _grayCard

                    readonly property real _cardPad: ScreenTools.defaultFontPixelHeight * 0.9
                    readonly property color _titleColor: qgcPal.globalTheme === QGCPalette.Dark ? "#AEAEB2" : "#3A3A3C"
                    readonly property color _pillFill:   qgcPal.globalTheme === QGCPalette.Dark ? "#1E3D2A" : "#D4EDDA"
                    readonly property color _pillText:   qgcPal.globalTheme === QGCPalette.Dark ? "#D4EDDA" : "#1C1C1E"

                    ColumnLayout {
                        id:                 battCardCol
                        anchors.left:       parent.left
                        anchors.right:      parent.right
                        anchors.top:        parent.top
                        anchors.margins:    battFailsafeCard._cardPad
                        spacing:            ScreenTools.defaultFontPixelHeight * 0.6

                        HeadingLabel {
                            text:               qsTr("Low Battery & Power Failsafes")
                        }

                        RowLayout {
                            spacing:            ScreenTools.defaultFontPixelWidth * 0.6
                            Layout.fillWidth:   true

                            Item {
                                id:                 battIcon
                                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 0.72
                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.2

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width:      parent.width * 0.38
                                    height:     parent.height * 0.11
                                    radius:     1
                                    color:      battFailsafeCard._titleColor
                                }

                                Rectangle {
                                    id:                 battBody
                                    anchors.left:       parent.left
                                    anchors.right:      parent.right
                                    anchors.bottom:     parent.bottom
                                    anchors.top:        parent.top
                                    anchors.topMargin:  parent.height * 0.1
                                    radius:             2.5
                                    color:              "transparent"
                                    border.width:       1.5
                                    border.color:       battFailsafeCard._titleColor

                                    Column {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.verticalCenter:   parent.verticalCenter
                                        spacing:                  battBody.height * 0.08

                                        Repeater {
                                            model: 3
                                            Rectangle {
                                                width:  battBody.width * 0.5
                                                height: battBody.height * 0.11
                                                radius: 0.8
                                                color:  battFailsafeCard._titleColor
                                            }
                                        }
                                    }
                                }
                            }

                            SettingLabel {
                                Layout.fillWidth:   true
                                text:               qsTr("Low Battery Failsafe Trigger")
                            }
                        }

                        SettingLabel {
                            text:               qsTr("Multi-Point Battery Range Slider")
                        }

                        BatteryFailsafeRangeSlider {
                            Layout.fillWidth:   true
                            Layout.topMargin:   ScreenTools.defaultFontPixelHeight * 0.15
                            Layout.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.1
                            warnFact:           _battWarnThr
                            critFact:           _battCritThr
                            emergFact:          _battEmergThr
                        }

                        RowLayout {
                            Layout.fillWidth:   true
                            Layout.topMargin:   ScreenTools.defaultFontPixelHeight * 0.15
                            spacing:            ScreenTools.defaultFontPixelWidth

                            SettingLabel {
                                Layout.fillWidth:   true
                                text:               qsTr("Failsafe Action")
                            }

                            GreenFactCombo {
                                fact:                   _lowBattAction
                                Layout.fillWidth:       false
                                Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 20
                                Layout.maximumWidth:   ScreenTools.defaultFontPixelWidth * 24
                            }
                        }
                    }
                }

                Rectangle {
                    id:                 odCard
                    Layout.fillWidth:   true
                    height:             odCol.height + odCard._cardPad * 2
                    radius:             _cardRadius
                    color:              _grayCard

                    readonly property real  _cardPad:    ScreenTools.defaultFontPixelHeight * 0.9
                    readonly property color _titleColor: qgcPal.globalTheme === QGCPalette.Dark ? "#AEAEB2" : "#3A3A3C"

                    ColumnLayout {
                        id:                 odCol
                        anchors.left:       parent.left
                        anchors.right:      parent.right
                        anchors.top:        parent.top
                        anchors.margins:    odCard._cardPad
                        spacing:            ScreenTools.defaultFontPixelHeight * 0.6

                        HeadingLabel {
                            text:               qsTr("Object Detection & Collision Prevention")
                            Layout.fillWidth:   true
                        }

                        RowLayout {
                            Layout.fillWidth:   true
                            spacing:            ScreenTools.defaultFontPixelWidth * 0.7

                            QGCColoredImage {
                                source:                 "/qmlimages/ObjectAvoidance.svg"
                                color:                  odCard._titleColor
                                fillMode:               Image.PreserveAspectFit
                                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 3.6
                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.8
                                Layout.alignment:       Qt.AlignVCenter
                            }

                            SettingLabel {
                                Layout.fillWidth:   true
                                text:               qsTr("Object Detection & Collision")
                            }
                        }

                        GridLayout {
                            Layout.fillWidth:   true
                            columns:            _narrow ? 1 : 2
                            columnSpacing:      ScreenTools.defaultFontPixelWidth
                            rowSpacing:         ScreenTools.defaultFontPixelHeight * 0.5

                            SettingLabel {
                                text:               qsTr("Collision Prevention")
                                Layout.fillWidth:   true
                                Layout.minimumWidth: 0
                                Layout.alignment:   Qt.AlignVCenter
                            }

                            GreenComboBox {
                                model:              [qsTr("Disabled"), qsTr("Enabled")]
                                enabled:            _collisionPrevention
                                currentIndex:       _collisionPrevention ? (_collisionPrevention.rawValue > 0 ? 1 : 0) : 0
                                onActivated: (index) => {
                                    if (_collisionPrevention) {
                                        _collisionPrevention.value = index > 0 ? 5 : -1
                                        showObstacleDistanceOverlayCheckBox.checked = _collisionPrevention.value > 0
                                    }
                                }
                            }

                            SettingLabel {
                                text:               qsTr("Minimum Distance")
                                Layout.fillWidth:   true
                                Layout.minimumWidth: 0
                                Layout.alignment:   Qt.AlignVCenter
                            }

                            ColumnLayout {
                                id:                     odDistCol
                                Layout.fillWidth:       true
                                Layout.minimumWidth:    0
                                spacing:                ScreenTools.defaultFontPixelHeight * 0.05
                                enabled:                _collisionPrevention && _collisionPrevention.rawValue > 0
                                opacity:                enabled ? 1.0 : 0.45

                                readonly property string _distUnits: QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString

                                Item {
                                    Layout.fillWidth:       true
                                    Layout.preferredHeight: setToLabel.implicitHeight

                                    BodyLabel {
                                        id:     setToLabel
                                        text:   qsTr("Set to %1 %2").arg(Math.round(odDistSlider.value)).arg(odDistCol._distUnits)
                                        x: {
                                            var hw = odDistSlider.handle ? odDistSlider.handle.width : 0
                                            var cx = odDistSlider.leftPadding + odDistSlider.visualPosition * (odDistSlider.availableWidth - hw) + hw / 2
                                            return Math.max(0, Math.min(parent.width - width, cx - width / 2))
                                        }
                                    }
                                }

                                QGCSlider {
                                    id:                     odDistSlider
                                    Layout.fillWidth:       true
                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.5
                                    from:                   QGroundControl.unitsConversion.metersToAppSettingsHorizontalDistanceUnits(1)
                                    to:                     QGroundControl.unitsConversion.metersToAppSettingsHorizontalDistanceUnits(15)
                                    stepSize:               1
                                    live:                   true
                                    displayValue:           false
                                    activeColor:            _greenPill
                                    barHeight:              Math.max(1, ScreenTools.defaultFontPixelHeight * 0.12)

                                    function _commitDist(v) {
                                        if (_collisionPrevention && _collisionPrevention.rawValue >= 0) {
                                            _collisionPrevention.rawValue = QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsToMeters(v)
                                        }
                                    }

                                    Binding {
                                        target:     odDistSlider
                                        property:   "value"
                                        value:      _collisionPrevention && _collisionPrevention.rawValue > 0
                                                    ? QGroundControl.unitsConversion.metersToAppSettingsHorizontalDistanceUnits(_collisionPrevention.rawValue)
                                                    : odDistSlider.from
                                        when:       !odDistSlider.pressed
                                    }

                                    onMoved:            _commitDist(value)
                                    onPressedChanged: {
                                        if (!pressed) {
                                            _commitDist(value)
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth:   true
                                    BodyLabel {
                                        text:   Math.round(odDistSlider.from) + " " + odDistCol._distUnits
                                    }
                                    Item { Layout.fillWidth: true }
                                    BodyLabel {
                                        text:   Math.round((odDistSlider.from + odDistSlider.to) / 2) + " " + odDistCol._distUnits
                                    }
                                    Item { Layout.fillWidth: true }
                                    BodyLabel {
                                        text:   Math.round(odDistSlider.to) + " " + odDistCol._distUnits
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth:   true
                            spacing:            ScreenTools.defaultFontPixelWidth
                            visible:            showObstacleDistanceOverlayCheckBox.visible

                            FactCheckBoxSlider {
                                id:                     showObstacleDistanceOverlayCheckBox
                                text:                   ""
                                fact:                   _showObstacleDistanceOverlay
                                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.35 * 1.8
                                visible:                _showObstacleDistanceOverlay.visible
                                property Fact _showObstacleDistanceOverlay: QGroundControl.settingsManager.flyViewSettings.showObstacleDistanceOverlay
                            }

                            SettingLabel {
                                Layout.fillWidth:   true
                                text:               qsTr("Show obstacle distance overlay")
                            }
                        }
                    }
                }

                Rectangle {
                    id:                 linkLossCard
                    Layout.fillWidth:   true
                    Layout.topMargin:   _sectionGap
                    height:             linkLossCol.height + linkLossCard._cardPad * 2
                    radius:             _cardRadius
                    color:              _grayCard

                    readonly property real  _cardPad:    ScreenTools.defaultFontPixelHeight * 0.9
                    readonly property color _titleColor: qgcPal.globalTheme === QGCPalette.Dark ? "#AEAEB2" : "#3A3A3C"

                    ColumnLayout {
                        id:                 linkLossCol
                        anchors.left:       parent.left
                        anchors.right:      parent.right
                        anchors.top:        parent.top
                        anchors.margins:    linkLossCard._cardPad
                        spacing:            ScreenTools.defaultFontPixelHeight * 0.65

                        HeadingLabel {
                            text:               qsTr("RC & Data Link Loss")
                            Layout.fillWidth:   true
                        }

                        RowLayout {
                            Layout.fillWidth:   true
                            spacing:            ScreenTools.defaultFontPixelWidth * 0.7

                            QGCColoredImage {
                                source:                 "/qmlimages/LinkFailsafeTower.svg"
                                color:                  linkLossCard._titleColor
                                fillMode:               Image.PreserveAspectFit
                                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.8
                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.8
                                Layout.alignment:       Qt.AlignVCenter
                            }

                            SettingLabel {
                                Layout.fillWidth:   true
                                text:               qsTr("Link Failsafe Triggers")
                            }
                        }

                        RowLayout {
                            Layout.fillWidth:   true
                            spacing:            ScreenTools.defaultFontPixelWidth * 1.2

                            QGCColoredImage {
                                source:                 "/qmlimages/RCLossGamepad.svg"
                                color:                  linkLossCard._titleColor
                                fillMode:               Image.PreserveAspectFit
                                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.8
                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.8
                                Layout.alignment:       Qt.AlignVCenter
                            }

                            ColumnLayout {
                                Layout.fillWidth:   true
                                spacing:            ScreenTools.defaultFontPixelHeight * 0.4

                                SettingLabel {
                                    text:               qsTr("RC Loss (Control)")
                                    Layout.fillWidth:   true
                                }

                                GridLayout {
                                    Layout.fillWidth:   true
                                    columns:            _narrow ? 1 : 2
                                    columnSpacing:      ScreenTools.defaultFontPixelWidth
                                    rowSpacing:         ScreenTools.defaultFontPixelHeight * 0.45

                                    SettingLabel {
                                        text:               qsTr("Failsafe Action")
                                        Layout.fillWidth:   true
                                        Layout.minimumWidth: 0
                                        Layout.alignment:   Qt.AlignVCenter | Qt.AlignLeft
                                    }
                                    GreenFactCombo {
                                        fact:                   _rcLossAction
                                        Layout.fillWidth:       _narrow
                                        Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 20
                                        Layout.alignment:       Qt.AlignRight
                                    }

                                    SettingLabel {
                                        text:               qsTr("RC Loss Timeout")
                                        Layout.fillWidth:   true
                                        Layout.minimumWidth: 0
                                        Layout.alignment:   Qt.AlignVCenter | Qt.AlignLeft
                                    }
                                    SafetyFactField {
                                        fact:                   controller.getParameterFact(-1, "COM_RC_LOSS_T")
                                        Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 20
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth:   true
                            spacing:            ScreenTools.defaultFontPixelWidth * 1.2

                            QGCColoredImage {
                                source:                 "/qmlimages/DataLinkCloudTower.svg"
                                color:                  linkLossCard._titleColor
                                fillMode:               Image.PreserveAspectFit
                                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.8
                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.8
                                Layout.alignment:       Qt.AlignVCenter
                            }

                            ColumnLayout {
                                Layout.fillWidth:   true
                                spacing:            ScreenTools.defaultFontPixelHeight * 0.4

                                SettingLabel {
                                    text:               qsTr("Data Link Loss (Telemetry)")
                                    Layout.fillWidth:   true
                                }

                                GridLayout {
                                    Layout.fillWidth:   true
                                    columns:            _narrow ? 1 : 2
                                    columnSpacing:      ScreenTools.defaultFontPixelWidth
                                    rowSpacing:         ScreenTools.defaultFontPixelHeight * 0.45

                                    SettingLabel {
                                        text:               qsTr("Failsafe Action")
                                        Layout.fillWidth:   true
                                        Layout.minimumWidth: 0
                                        Layout.alignment:   Qt.AlignVCenter | Qt.AlignLeft
                                    }
                                    GreenFactCombo {
                                        fact:                   _dlLossAction
                                        Layout.fillWidth:       _narrow
                                        Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 20
                                        Layout.alignment:       Qt.AlignRight
                                    }

                                    SettingLabel {
                                        text:               qsTr("Data Link Loss Timeout")
                                        Layout.fillWidth:   true
                                        Layout.minimumWidth: 0
                                        Layout.alignment:   Qt.AlignVCenter | Qt.AlignLeft
                                    }
                                    SafetyFactField {
                                        fact:                   controller.getParameterFact(-1, "COM_DL_LOSS_T")
                                        Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 20
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id:                 geoCard
                    Layout.fillWidth:   true
                    Layout.topMargin:   _sectionGap
                    height:             geoCol.height + geoCard._cardPad * 2
                    radius:             _cardRadius
                    color:              _grayCard

                    readonly property real  _cardPad:    ScreenTools.defaultFontPixelHeight * 0.9
                    readonly property color _titleColor: qgcPal.globalTheme === QGCPalette.Dark ? "#AEAEB2" : "#3A3A3C"

                    ColumnLayout {
                        id:                 geoCol
                        anchors.left:       parent.left
                        anchors.right:      parent.right
                        anchors.top:        parent.top
                        anchors.margins:    geoCard._cardPad
                        spacing:            ScreenTools.defaultFontPixelHeight * 0.6

                        HeadingLabel {
                            text:               qsTr("Geofence Parameters")
                            Layout.fillWidth:   true
                        }

                        RowLayout {
                            Layout.fillWidth:   true
                            spacing:            ScreenTools.defaultFontPixelWidth * 0.7

                            QGCColoredImage {
                                source:                 "/qmlimages/GeoFenceMapPin.svg"
                                color:                  geoCard._titleColor
                                fillMode:               Image.PreserveAspectFit
                                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.8
                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.8
                                Layout.alignment:       Qt.AlignVCenter
                            }

                            SettingLabel {
                                Layout.fillWidth:   true
                                text:               qsTr("Geofence Failsafe Trigger")
                            }
                        }

                        GridLayout {
                            Layout.fillWidth:   true
                            columns:            _narrow ? 1 : 2
                            columnSpacing:      ScreenTools.defaultFontPixelWidth
                            rowSpacing:         ScreenTools.defaultFontPixelHeight * 0.5

                            SettingLabel {
                                text:               qsTr("Action on breach")
                                Layout.fillWidth:   true
                                Layout.minimumWidth: 0
                                Layout.alignment:   Qt.AlignVCenter
                            }
                            GreenFactCombo {
                                fact:               _fenceAction
                            }
                        }

                        RowLayout {
                            Layout.fillWidth:   true
                            spacing:            ScreenTools.defaultFontPixelWidth

                            QGCCheckBoxSlider {
                                id:                     fenceRadiusCheckBox
                                text:                   ""
                                checked:                _fenceRadius.value > 0
                                onClicked:              _fenceRadius.value = checked ? 100 : 0
                                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.35 * 1.8
                            }

                            SettingLabel {
                                Layout.fillWidth:   true
                                text:               qsTr("Enable Max Radius")
                            }

                            SafetyFactField {
                                fact:                   _fenceRadius
                                enabled:                fenceRadiusCheckBox.checked
                            }
                        }

                        RowLayout {
                            Layout.fillWidth:   true
                            spacing:            ScreenTools.defaultFontPixelWidth

                            QGCCheckBoxSlider {
                                id:                     fenceAltMaxCheckBox
                                text:                   ""
                                checked:                _fenceAlt ? _fenceAlt.value > 0 : false
                                onClicked:              _fenceAlt.value = checked ? 100 : 0
                                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.35 * 1.8
                            }

                            SettingLabel {
                                Layout.fillWidth:   true
                                text:               qsTr("Enable Max Altitude")
                            }

                            SafetyFactField {
                                fact:                   _fenceAlt
                                enabled:                fenceAltMaxCheckBox.checked
                            }
                        }
                    }
                }

                HeadingLabel {
                    text:               qsTr("Return To Launch Settings")
                    Layout.topMargin:   _sectionGap
                }

                Rectangle {
                    Layout.fillWidth:   true
                    height:             rtlCol.height + _cardPad * 2
                    radius:             _cardRadius
                    color:              _grayCard

                    ColumnLayout {
                        id:                 rtlCol
                        anchors.left:       parent.left
                        anchors.right:      parent.right
                        anchors.top:        parent.top
                        anchors.margins:    _cardPad
                        spacing:            ScreenTools.defaultFontPixelHeight * 0.6

                        QGCColoredImage {
                            Layout.alignment:       Qt.AlignHCenter
                            source:                 controller.vehicle.fixedWing
                                                    ? "/qmlimages/ReturnToHomeAltitude.svg"
                                                    : "/qmlimages/ReturnToHomeAltitudeCopter.svg"
                            color:                  _titleColor
                            fillMode:               Image.PreserveAspectFit
                            Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 8
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 4
                            Layout.topMargin:       ScreenTools.defaultFontPixelHeight * 0.15
                            Layout.bottomMargin:    ScreenTools.defaultFontPixelHeight * 0.15
                        }

                        GridLayout {
                            Layout.fillWidth:   true
                            columns:            _narrow ? 1 : 2
                            columnSpacing:      ScreenTools.defaultFontPixelWidth
                            rowSpacing:         ScreenTools.defaultFontPixelHeight * 0.45

                                SettingLabel {
                                    text:               qsTr("Climb to altitude of:")
                                    Layout.fillWidth:   true
                                    Layout.minimumWidth: 0
                                    Layout.alignment:   Qt.AlignVCenter
                                }
                                SafetyFactField {
                                    fact:   controller.getParameterFact(-1, "RTL_RETURN_ALT")
                                }

                                SettingLabel {
                                    text:               qsTr("Return to launch, then:")
                                    Layout.fillWidth:   true
                                    Layout.columnSpan:  _narrow ? 1 : 2
                                }

                                ColumnLayout {
                                    Layout.fillWidth:   true
                                    Layout.columnSpan:  _narrow ? 1 : 2
                                    spacing:            ScreenTools.defaultFontPixelHeight * 0.2

                                    QGCRadioButton {
                                        id:                 homeLandRadio
                                        checked:            _rtlLandDelay ? _rtlLandDelay.value === 0 : false
                                        text:               qsTr("Land immediately")
                                        textColor:          _titleColor
                                        font.pointSize:     _labelPointSize
                                        onClicked:          _rtlLandDelay.value = 0
                                    }
                                    QGCRadioButton {
                                        id:                 homeLoiterNoLandRadio
                                        checked:            _rtlLandDelay ? _rtlLandDelay.value < 0 : false
                                        text:               qsTr("Loiter and do not land")
                                        textColor:          _titleColor
                                        font.pointSize:     _labelPointSize
                                        onClicked:          _rtlLandDelay.value = -1
                                    }
                                    QGCRadioButton {
                                        id:                 homeLoiterLandRadio
                                        checked:            _rtlLandDelay ? _rtlLandDelay.value > 0 : false
                                        text:               qsTr("Loiter and land after specified time")
                                        textColor:          _titleColor
                                        font.pointSize:     _labelPointSize
                                        onClicked:          _rtlLandDelay.value = 60
                                    }
                                }

                                SettingLabel {
                                    text:               qsTr("Loiter Time")
                                    Layout.fillWidth:   true
                                    Layout.minimumWidth: 0
                                    Layout.alignment:   Qt.AlignVCenter
                                }
                                SafetyFactField {
                                    fact:       controller.getParameterFact(-1, "RTL_LAND_DELAY")
                                    enabled:    homeLoiterLandRadio.checked === true
                                }

                                SettingLabel {
                                    text:               qsTr("Loiter Altitude")
                                    Layout.fillWidth:   true
                                    Layout.minimumWidth: 0
                                    Layout.alignment:   Qt.AlignVCenter
                                }
                                SafetyFactField {
                                    fact:       controller.getParameterFact(-1, "RTL_DESCEND_ALT")
                                    enabled:    homeLoiterLandRadio.checked === true || homeLoiterNoLandRadio.checked === true
                                }
                            }
                    }
                }

                HeadingLabel {
                    text:               qsTr("Land Mode Settings")
                    Layout.topMargin:   _sectionGap
                }

                Rectangle {
                    Layout.fillWidth:   true
                    height:             landCol.height + _cardPad * 2
                    radius:             _cardRadius
                    color:              _grayCard

                    RowLayout {
                        id:                 landCol
                        anchors.left:       parent.left
                        anchors.right:      parent.right
                        anchors.top:        parent.top
                        anchors.margins:    _cardPad
                        spacing:            ScreenTools.defaultFontPixelWidth * 1.2

                        QGCColoredImage {
                            source:                 controller.vehicle.fixedWing
                                                    ? "/qmlimages/LandMode.svg"
                                                    : "/qmlimages/LandModeCopter.svg"
                            color:                  _titleColor
                            fillMode:               Image.PreserveAspectFit
                            Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.8
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.8
                            Layout.alignment:       Qt.AlignVCenter
                        }

                        ColumnLayout {
                            Layout.fillWidth:   true
                            spacing:            ScreenTools.defaultFontPixelHeight * 0.45

                            GridLayout {
                                Layout.fillWidth:   true
                                columns:            2
                                columnSpacing:      ScreenTools.defaultFontPixelWidth
                                rowSpacing:         ScreenTools.defaultFontPixelHeight * 0.45

                                SettingLabel {
                                    id:                 landVelocityLabel
                                    text:               qsTr("Landing Descent Rate:")
                                    visible:            controller.vehicle && !controller.vehicle.fixedWing
                                    Layout.fillWidth:   true
                                    Layout.minimumWidth: 0
                                    Layout.alignment:   Qt.AlignVCenter
                                }
                                SafetyFactField {
                                    fact:                   _landSpeedMC
                                    visible:                controller.vehicle && !controller.vehicle.fixedWing
                                    Layout.fillWidth:       false
                                    Layout.maximumWidth:    ScreenTools.defaultFontPixelWidth * 14
                                }

                                RowLayout {
                                    Layout.fillWidth:   true
                                    spacing:            ScreenTools.defaultFontPixelWidth

                                    QGCCheckBoxSlider {
                                        id:                     disarmDelayCheckBox
                                        text:                   ""
                                        checked:                _disarmLandDelay.value > 0
                                        onClicked:              _disarmLandDelay.value = checked ? 2 : 0
                                        Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.35 * 1.8
                                    }

                                    SettingLabel {
                                        Layout.fillWidth:   true
                                        text:               qsTr("Disarm After")
                                    }
                                }
                                SafetyFactField {
                                    fact:                   _disarmLandDelay
                                    enabled:                disarmDelayCheckBox.checked
                                    Layout.fillWidth:       false
                                    Layout.maximumWidth:    ScreenTools.defaultFontPixelWidth * 14
                                }
                            }
                        }
                    }
                }

                HeadingLabel {
                    text:               qsTr("Vehicle Telemetry Logging")
                    Layout.topMargin:   _sectionGap
                }

                Rectangle {
                    Layout.fillWidth:   true
                    height:             loggingCol.height + _cardPad * 2
                    radius:             _cardRadius
                    color:              _grayCard

                    RowLayout {
                        id:                 loggingCol
                        anchors.left:       parent.left
                        anchors.right:      parent.right
                        anchors.top:        parent.top
                        anchors.margins:    _cardPad
                        spacing:            ScreenTools.defaultFontPixelWidth * 1.2

                        Image {
                            mipmap:                 true
                            fillMode:               Image.PreserveAspectFit
                            source:                 qgcPal.globalTheme === QGCPalette.Light
                                                    ? "/qmlimages/no-logging-light.svg"
                                                    : "/qmlimages/no-logging.svg"
                            Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.8
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.8
                            Layout.alignment:       Qt.AlignVCenter
                        }

                        GridLayout {
                            Layout.fillWidth:   true
                            Layout.alignment:   Qt.AlignVCenter
                            columns:            _narrow ? 1 : 2
                            columnSpacing:      ScreenTools.defaultFontPixelWidth
                            rowSpacing:         ScreenTools.defaultFontPixelHeight * 0.45

                            SettingLabel {
                                text:               qsTr("Telemetry logging to vehicle storage:")
                                Layout.fillWidth:   true
                                Layout.minimumWidth: 0
                                Layout.alignment:   Qt.AlignVCenter
                            }
                            GreenComboBox {
                                model:              [qsTr("Disabled"), qsTr("Enabled")]
                                enabled:            _enableLogging
                                Layout.fillWidth:   _narrow
                                Component.onCompleted: {
                                    currentIndex = _enableLogging ? (_enableLogging.value >= 0 ? 1 : 0) : 0
                                }
                                onActivated: (index) => {
                                    if (_enableLogging) {
                                        _enableLogging.value = index > 0 ? 0 : -1
                                    }
                                }
                            }
                        }
                    }
                }

                HeadingLabel {
                    text:               qsTr("Hardware in the Loop Simulation")
                    visible:            _hitlAvailable
                    Layout.topMargin:   _sectionGap
                }

                Rectangle {
                    Layout.fillWidth:   true
                    height:             hitlCol.height + _cardPad * 2
                    radius:             _cardRadius
                    color:              _grayCard
                    visible:            _hitlAvailable

                    RowLayout {
                        id:                 hitlCol
                        anchors.left:       parent.left
                        anchors.right:      parent.right
                        anchors.top:        parent.top
                        anchors.margins:    _cardPad
                        spacing:            ScreenTools.defaultFontPixelWidth * 1.2

                        QGCColoredImage {
                            source:                 "/qmlimages/HITL.svg"
                            color:                  _titleColor
                            fillMode:               Image.PreserveAspectFit
                            Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.8
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.8
                            Layout.alignment:       Qt.AlignVCenter
                        }

                        GridLayout {
                            Layout.fillWidth:   true
                            Layout.alignment:   Qt.AlignVCenter
                            columns:            _narrow ? 1 : 2
                            columnSpacing:      ScreenTools.defaultFontPixelWidth
                            rowSpacing:         ScreenTools.defaultFontPixelHeight * 0.45

                            SettingLabel {
                                text:               qsTr("HITL Enabled:")
                                Layout.fillWidth:   true
                                Layout.minimumWidth: 0
                                Layout.alignment:   Qt.AlignVCenter
                            }
                            GreenFactCombo {
                                fact:               _hitlEnabled
                                Layout.fillWidth:   _narrow
                            }
                        }
                    }
                }
            }
        }
    }
}
