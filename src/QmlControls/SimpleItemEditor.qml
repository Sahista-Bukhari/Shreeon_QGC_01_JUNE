import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

// Editor for Simple mission items
Rectangle {
    id: root
    width: availableWidth
    height: editorColumn.height + (_margin * 2)
    color: "transparent"
    radius: _radius

    property bool _specifiesAltitude: missionItem.specifiesAltitude
    property real _margin: ScreenTools.defaultFontPixelHeight / 2
    property real _altRectMargin: ScreenTools.defaultFontPixelWidth / 2
    property var _controllerVehicle: missionItem.masterController.controllerVehicle
    property int _globalAltMode: missionItem.masterController.missionController.globalAltitudeMode
    property bool _globalAltModeIsMixed: _globalAltMode == QGroundControl.AltitudeModeMixed
    property real _radius: ScreenTools.defaultFontPixelWidth / 2
    property real _fieldSpacing: ScreenTools.defaultFontPixelHeight / 2
    property real _pad: ScreenTools.defaultFontPixelWidth * 1.05
    readonly property color _accentGreen: "#00a651"
    readonly property color _accentSoftGreen: "#e8e8e8"
    readonly property color _titleColor: "#3f3f3f"
    readonly property color _bodyColor: "#6a6a6a"
    property Fact _altitudeFact: missionItem.altitude
    property Fact _speedFact: missionItem.speedSection.flightSpeed

    QGCPalette { id: qgcPal; colorGroupEnabled: root.enabled }

    function _factMin(fact, fallback) {
        if (!fact)
            return fallback
        if (fact.userMin !== undefined && !isNaN(Number(fact.userMin)))
            return Number(fact.userMin)
        if (!fact.minIsDefaultForType && !isNaN(Number(fact.min)))
            return Number(fact.min)
        return fallback
    }

    function _factMax(fact, fallback) {
        if (!fact)
            return fallback
        if (fact.userMax !== undefined && !isNaN(Number(fact.userMax)))
            return Number(fact.userMax)
        if (!fact.maxIsDefaultForType && !isNaN(Number(fact.max)))
            return Number(fact.max)
        return fallback
    }

    function _factStep(fact, fallback) {
        if (fact && fact.rawIncrement && Number(fact.rawIncrement) > 0)
            return Number(fact.rawIncrement)
        return fallback
    }

    function _nudgeFact(fact, direction, step, minV, maxV) {
        if (!fact)
            return
        var next = Number(fact.value) + (direction * step)
        next = Math.max(minV, Math.min(maxV, next))
        fact.value = Math.round(next * 10) / 10
    }

    // Application Settings–style value stepper: gray circular - / +
    component NozzleValueBox: Item {
        property string valueText
        property bool controlsEnabled: true
        signal minusClicked
        signal plusClicked

        id: stepperRoot
        implicitWidth: stepperRow.implicitWidth
        implicitHeight: stepperRow.implicitHeight
        opacity: controlsEnabled ? 1.0 : 0.45

        RowLayout {
            id: stepperRow
            anchors.centerIn: parent
            spacing: ScreenTools.defaultFontPixelWidth * 1.5

            Rectangle {
                Layout.preferredWidth: height
                Layout.preferredHeight: valueLabel.implicitHeight * 1.55
                radius: height / 2
                color: !controlsEnabled ? "#f0f0f0"
                     : (minusMouse.pressed || minusMouse.containsMouse) ? "#E53935" : "#f5f5f5"
                enabled: controlsEnabled

                Behavior on color { ColorAnimation { duration: 120 } }

                QGCLabel {
                    anchors.centerIn: parent
                    text: "-"
                    color: (minusMouse.pressed || minusMouse.containsMouse) && controlsEnabled
                           ? "#ffffff" : "#1C1C1E"
                    font.pointSize: ScreenTools.largeFontPointSize
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: minusMouse
                    anchors.fill: parent
                    enabled: controlsEnabled
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: stepperRoot.minusClicked()
                }
            }

            QGCLabel {
                id: valueLabel
                Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 8
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: stepperRoot.valueText
                color: "#1C1C1E"
                font.weight: Font.Medium
                font.pointSize: ScreenTools.defaultFontPointSize
            }

            Rectangle {
                Layout.preferredWidth: height
                Layout.preferredHeight: valueLabel.implicitHeight * 1.55
                radius: height / 2
                color: !controlsEnabled ? "#f0f0f0"
                     : (plusMouse.pressed || plusMouse.containsMouse) ? "#00a651" : "#f5f5f5"
                enabled: controlsEnabled

                Behavior on color { ColorAnimation { duration: 120 } }

                QGCLabel {
                    anchors.centerIn: parent
                    text: "+"
                    color: (plusMouse.pressed || plusMouse.containsMouse) && controlsEnabled
                           ? "#ffffff" : "#1C1C1E"
                    font.pointSize: ScreenTools.largeFontPointSize
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: plusMouse
                    anchors.fill: parent
                    enabled: controlsEnabled
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: stepperRoot.plusClicked()
                }
            }
        }
    }

    Column {
        id: editorColumn
        anchors.margins: _margin
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: _margin

        // Takeoff item
        ColumnLayout {
            anchors.margins: _margin
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: _margin
            visible: missionItem.isTakeoffItem && missionItem.wizardMode // Hack special case for takeoff item

            QGCLabel {
                text: qsTr("Move '%1' %2 to the %3 location. %4")
                    .arg(_controllerVehicle.vtol ? qsTr("T") : qsTr("T"))
                    .arg(_controllerVehicle.vtol ? qsTr("Transition Direction") : qsTr("Takeoff"))
                    .arg(_controllerVehicle.vtol ? qsTr("desired") : qsTr("climbout"))
                    .arg(_controllerVehicle.vtol ? (qsTr("Ensure distance from launch to transition direction is far enough to complete transition.")) : "")
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                visible: !initialClickLabel.visible
                color: root._bodyColor
            }

            QGCLabel {
                text: qsTr("Ensure clear of obstacles and into the wind.")
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                visible: !initialClickLabel.visible
                color: root._bodyColor
            }

            QGCButton {
                text: qsTr("Done")
                Layout.fillWidth: true
                visible: !initialClickLabel.visible
                onClicked: {
                    missionItem.wizardMode = false
                }
            }

            QGCLabel {
                id: initialClickLabel
                text: missionItem.launchTakeoffAtSameLocation ?
                                        qsTr("Click in map to set planned Takeoff location.") :
                                        qsTr("Click in map to set planned Launch location.")
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                visible: missionItem.isTakeoffItem && !missionItem.launchCoordinate.isValid
                color: root._bodyColor
            }
        }

        ColumnLayout {
            width: parent.width
            spacing: _fieldSpacing
            visible: !missionItem.wizardMode

            QGCTabBar {
                id: tabBar
                Layout.fillWidth: true
                visible: _multipleTabsVisible()

                property bool _basicItemsAvailable: _specifiesAltitude || missionItem.speedSection.available || missionItem.comboboxFacts.count > 0 || missionItem.textFieldFacts.count > 0 || missionItem.nanFacts.count > 0
                property bool _advancedItemsAvailable: missionItem.comboboxFactsAdvanced.count > 0 || missionItem.textFieldFactsAdvanced.count > 0 || missionItem.nanFactsAdvanced.count > 0
                property bool _cameraAvailable: missionItem.cameraSection.available

                function _multipleTabsVisible() {
                    let visibleCount = 0
                    if (_basicItemsAvailable) visibleCount++
                    if (_cameraAvailable) visibleCount++
                    if (_advancedItemsAvailable) visibleCount++
                    return visibleCount > 1
                }

                Component.onCompleted: {
                    if (_basicItemsAvailable) {
                        tabBar.currentIndex = 0
                    } else if (_cameraAvailable) {
                        tabBar.currentIndex = 1
                    } else if (_advancedItemsAvailable) {
                        tabBar.currentIndex = 2
                    } else {
                        tabBar.currentIndex = -1
                    }
                }

                QGCTabButton {
                    id: basicItemsTab
                    icon.source: "/res/PlanSimpleItemBasic.svg"
                    visible: tabBar._basicItemsAvailable
                }

                QGCTabButton {
                    id: cameraTab
                    icon.source: "/res/PlanSimpleItemCamera.svg"
                    visible: tabBar._cameraAvailable
                }

                QGCTabButton {
                    id: advancedItemsTab
                    icon.source: "/res/PlanSimpleItemAdvanced.svg"
                    visible: tabBar._advancedItemsAvailable
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: _fieldSpacing
                visible: tabBar.currentIndex === 0

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: _fieldSpacing
                    visible: _specifiesAltitude

                    RowLayout {
                        Layout.fillWidth: true
                        visible: _globalAltModeIsMixed

                        QGCLabel {
                            Layout.fillWidth: true
                            text: qsTr("Altitude Mode")
                            color: root._bodyColor
                        }

                        AltModeCombo {
                            altitudeMode: missionItem.altitudeMode
                            vehicle: _controllerVehicle
                            onAltitudeModeChanged: missionItem.altitudeMode = altitudeMode
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelHeight * 0.35

                        QGCLabel {
                            Layout.fillWidth: true
                            text: qsTr("Altitude%1").arg(_extraLabelText())
                            color: root._bodyColor

                            function _extraLabelText() {
                                if (!_globalAltModeIsMixed && missionItem.altitudeMode !== QGroundControl.AltitudeModeRelative) {
                                    return qsTr(" (%1)").arg(QGroundControl.altitudeModeShortDescription(missionItem.altitudeMode))
                                }
                                return ""
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.85
                            spacing: root._pad * 0.45

                            QGCSlider {
                                id: takeoffAltitudeSlider
                                Layout.fillWidth: true
                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.25
                                from: root._factMin(root._altitudeFact, 0)
                                to: root._factMax(root._altitudeFact, 121.9)
                                stepSize: root._factStep(root._altitudeFact, 0.1)
                                activeColor: root._accentGreen
                                barHeight: Math.max(1, ScreenTools.defaultFontPixelHeight * 0.10)
                                live: true
                                Binding {
                                    target: takeoffAltitudeSlider
                                    property: "value"
                                    value: root._altitudeFact ? Number(root._altitudeFact.value) : takeoffAltitudeSlider.from
                                    when: !takeoffAltitudeSlider.pressed
                                }
                                onMoved: {
                                    if (root._altitudeFact)
                                        root._altitudeFact.value = value
                                }
                            }

                            NozzleValueBox {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 16
                                Layout.preferredHeight: implicitHeight
                                valueText: root._altitudeFact
                                           ? (Number(root._altitudeFact.value).toFixed(1)
                                              + (root._altitudeFact.units ? " " + root._altitudeFact.units : ""))
                                           : "0.0"
                                onMinusClicked: root._nudgeFact(root._altitudeFact, -1,
                                                                root._factStep(root._altitudeFact, 0.1),
                                                                takeoffAltitudeSlider.from, takeoffAltitudeSlider.to)
                                onPlusClicked: root._nudgeFact(root._altitudeFact, 1,
                                                               root._factStep(root._altitudeFact, 0.1),
                                                               takeoffAltitudeSlider.from, takeoffAltitudeSlider.to)
                            }
                        }
                    }

                    QGCLabel {
                        font.pointSize: ScreenTools.smallFontPointSize
                        text: qsTr("Actual AMSL alt sent: %1 %2").arg(missionItem.amslAltAboveTerrain.valueString).arg(missionItem.amslAltAboveTerrain.units)
                        visible: missionItem.altitudeMode === QGroundControl.AltitudeModeCalcAboveTerrain
                        color: root._bodyColor
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: _fieldSpacing

                    Repeater {
                        model: missionItem.comboboxFacts

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            QGCLabel {
                                font.pointSize: ScreenTools.smallFontPointSize
                                text: object.name
                                visible: object.name !== ""
                                color: root._bodyColor
                            }

                            FactComboBox {
                                Layout.fillWidth: true
                                indexModel: false
                                model: object.enumStrings
                                fact: object
                            }
                        }
                    }
                }

                Repeater {
                    model: missionItem.textFieldFacts

                    FactTextFieldSlider {
                        Layout.fillWidth: true
                        label: object.name
                        fact: object
                        enabled: !object.readOnly
                        backgroundColor: "transparent"
                    }
                }

                Repeater {
                    model: missionItem.nanFacts

                    FactTextFieldSlider {
                        Layout.fillWidth: true
                        label: object.name
                        fact: object
                        showEnableCheckbox: true
                        enableCheckBoxChecked: !isNaN(object.rawValue)
                        backgroundColor: "transparent"

                        onEnableCheckboxClicked: object.rawValue = enableCheckBoxChecked ? 0 : NaN
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelHeight * 0.35
                    visible: missionItem.speedSection.available
                    opacity: missionItem.speedSection.specifyFlightSpeed ? 1.0 : 0.55

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root._pad * 0.6

                        QGCCheckBox {
                            checked: missionItem.speedSection.specifyFlightSpeed
                            onClicked: missionItem.speedSection.specifyFlightSpeed = checked
                        }

                        QGCLabel {
                            Layout.fillWidth: true
                            text: qsTr("Flight Speed")
                            color: root._bodyColor
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.85
                        spacing: root._pad * 0.45
                        enabled: missionItem.speedSection.specifyFlightSpeed

                        QGCSlider {
                            id: takeoffSpeedSlider
                            Layout.fillWidth: true
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.25
                            from: root._factMin(root._speedFact, 0)
                            to: root._factMax(root._speedFact, 30)
                            stepSize: root._factStep(root._speedFact, 0.5)
                            enabled: missionItem.speedSection.specifyFlightSpeed
                            activeColor: root._accentGreen
                            barHeight: Math.max(1, ScreenTools.defaultFontPixelHeight * 0.10)
                            live: true
                            Binding {
                                target: takeoffSpeedSlider
                                property: "value"
                                value: root._speedFact ? Number(root._speedFact.value) : takeoffSpeedSlider.from
                                when: !takeoffSpeedSlider.pressed
                            }
                            onMoved: {
                                if (root._speedFact && missionItem.speedSection.specifyFlightSpeed)
                                    root._speedFact.value = value
                            }
                        }

                        NozzleValueBox {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 16
                            Layout.preferredHeight: implicitHeight
                            controlsEnabled: missionItem.speedSection.specifyFlightSpeed
                            valueText: root._speedFact
                                       ? (Number(root._speedFact.value).toFixed(1)
                                          + (root._speedFact.units ? " " + root._speedFact.units : ""))
                                       : "0.0"
                            onMinusClicked: root._nudgeFact(root._speedFact, -1,
                                                            root._factStep(root._speedFact, 0.5),
                                                            takeoffSpeedSlider.from, takeoffSpeedSlider.to)
                            onPlusClicked: root._nudgeFact(root._speedFact, 1,
                                                           root._factStep(root._speedFact, 0.5),
                                                           takeoffSpeedSlider.from, takeoffSpeedSlider.to)
                        }
                    }
                }
            }

            CameraSection {
                Layout.fillWidth: true
                showSectionHeader: false
                visible: tabBar.currentIndex === 1

                Component.onCompleted: checked = missionItem.cameraSection.settingsSpecified
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: _fieldSpacing
                visible: tabBar.currentIndex === 2

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: _fieldSpacing

                    Repeater {
                        model: missionItem.comboboxFactsAdvanced

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            QGCLabel {
                                font.pointSize: ScreenTools.smallFontPointSize
                                text: object.name
                                visible: object.name !== ""
                                color: root._bodyColor
                            }

                            FactComboBox {
                                Layout.fillWidth: true
                                indexModel: false
                                model: object.enumStrings
                                fact: object
                            }
                        }
                    }
                }

                Repeater {
                    model: missionItem.textFieldFactsAdvanced

                    FactTextFieldSlider {
                        Layout.fillWidth: true
                        label: object.name
                        fact: object
                        enabled: !object.readOnly
                        backgroundColor: "transparent"
                    }
                }

                Repeater {
                    model: missionItem.nanFactsAdvanced

                    FactTextFieldSlider {
                        Layout.fillWidth: true
                        label: object.name
                        fact: object
                        showEnableCheckbox: true
                        enableCheckBoxChecked: !isNaN(object.rawValue)
                        backgroundColor: "transparent"

                        onEnableCheckboxClicked: object.rawValue = enableCheckBoxChecked ? 0 : NaN
                    }
                }
            }
        }
    }
}
