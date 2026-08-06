import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

// Editor for Mission Settings
Rectangle {
    id: root
    width: availableWidth
    height: valuesColumn.height + (_margin * 2)
    color: "transparent"
    radius: ScreenTools.defaultBorderRadius

    property var _masterController: masterController
    property var _missionController: _masterController.missionController
    property var _controllerVehicle: _masterController.controllerVehicle
    property var _visualItems: _missionController.visualItems
    property bool _vehicleHasHomePosition: _controllerVehicle.homePosition.isValid
    property bool _showCruiseSpeed: !_controllerVehicle.multiRotor
    property bool _showHoverSpeed: _controllerVehicle.multiRotor || _controllerVehicle.vtol
    property bool _multipleFirmware: !QGroundControl.singleFirmwareSupport
    property bool _multipleVehicleTypes: !QGroundControl.singleVehicleSupport
    property real _fieldWidth: ScreenTools.defaultFontPixelWidth * 16
    property bool _mobile: ScreenTools.isMobile
    property var _savePath: QGroundControl.settingsManager.appSettings.missionSavePath
    property var _appSettings: QGroundControl.settingsManager.appSettings
    property bool _waypointsOnlyMode: QGroundControl.corePlugin.options.missionWaypointsOnly
    property bool _showCameraSection: _waypointsOnlyMode || QGroundControl.corePlugin.showAdvancedUI
    property bool _simpleMissionStart: QGroundControl.corePlugin.options.showSimpleMissionStart
    property bool _showFlightSpeed: !_controllerVehicle.vtol && !_simpleMissionStart && !_controllerVehicle.apmFirmware
    property bool _allowFWVehicleTypeSelection: _noMissionItemsAdded && !globals.activeVehicle

    readonly property string _firmwareLabel: qsTr("Firmware")
    readonly property string _vehicleLabel: qsTr("Vehicle")
    readonly property real _margin: ScreenTools.defaultFontPixelWidth / 2

    // Fields-style dark glass + readable light text
    readonly property color _fieldsBg:        Qt.rgba(0.03, 0.03, 0.03, 0.28)
    readonly property color _accentGreen:     "#23a800"
    readonly property color _accentSoftGreen: "#efffee"
    readonly property color _titleColor:      "#ffffff"
    readonly property color _bodyColor:       Qt.rgba(1, 1, 1, 0.88)
    readonly property color _cardBorderIdle:  Qt.rgba(1, 1, 1, 0.28)
    readonly property real  _pad:             ScreenTools.defaultFontPixelWidth * 1.05
    readonly property real  _radius:          ScreenTools.defaultFontPixelWidth * 0.75

    property Fact _altitudeFact: QGroundControl.settingsManager.appSettings.defaultMissionItemAltitude
    property Fact _speedFact: missionItem.speedSection.flightSpeed

    QGCPalette { id: qgcPal }
    Component { id: altModeDialogComponent; AltModeDialog { } }

    function _factMin(fact, fallback) {
        if (!fact) {
            return fallback
        }
        if (fact.userMin !== undefined && !isNaN(Number(fact.userMin))) {
            return Number(fact.userMin)
        }
        if (!fact.minIsDefaultForType && !isNaN(Number(fact.min))) {
            return Number(fact.min)
        }
        return fallback
    }

    function _factMax(fact, fallback) {
        if (!fact) {
            return fallback
        }
        if (fact.userMax !== undefined && !isNaN(Number(fact.userMax))) {
            return Number(fact.userMax)
        }
        if (!fact.maxIsDefaultForType && !isNaN(Number(fact.max))) {
            return Number(fact.max)
        }
        return fallback
    }

    function _factStep(fact, fallback) {
        if (fact && fact.rawIncrement && Number(fact.rawIncrement) > 0) {
            return Number(fact.rawIncrement)
        }
        return fallback
    }

    function _nudgeFact(fact, direction, step, minV, maxV) {
        if (!fact) {
            return
        }
        var next = Number(fact.value) + (direction * step)
        next = Math.max(minV, Math.min(maxV, next))
        fact.value = Math.round(next * 10) / 10
    }

    Connections {
        target: _controllerVehicle
        function onSupportsTerrainFrameChanged() {
            if (!_controllerVehicle.supportsTerrainFrame && _missionController.globalAltitudeMode === QGroundControl.AltitudeModeTerrainFrame) {
                _missionController.globalAltitudeMode = QGroundControl.AltitudeModeCalcAboveTerrain
            }
        }
    }

    // Shared nozzle-style value stepper used by altitude / speed
    component NozzleValueBox: Rectangle {
        property string valueText
        property bool controlsEnabled: true
        signal minusClicked
        signal plusClicked

        radius:                 root._radius
        color:                  Qt.rgba(1, 1, 1, 0.88)
        border.width:           1
        border.color:           Qt.rgba(1, 1, 1, 0.45)
        opacity:                controlsEnabled ? 1.0 : 0.45

        RowLayout {
            anchors.fill:        parent
            anchors.leftMargin:  ScreenTools.defaultFontPixelWidth * 0.35
            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.35
            spacing:             0

            Rectangle {
                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.15
                Layout.fillHeight:      true
                Layout.topMargin:       2
                Layout.bottomMargin:    2
                radius:                 root._radius * 0.6
                color:                  minusMouse.pressed ? "#ffe8e8" : "transparent"
                enabled:                controlsEnabled

                QGCLabel {
                    anchors.centerIn: parent
                    text:             "−"
                    color:            minusMouse.pressed ? "#e53935" : "#3f3f3f"
                    font.weight:      Font.DemiBold
                    font.pointSize:   ScreenTools.defaultFontPointSize
                }

                QGCMouseArea {
                    id:           minusMouse
                    anchors.fill: parent
                    enabled:      controlsEnabled
                    onClicked:    minusClicked()
                }
            }

            QGCLabel {
                Layout.fillWidth:       true
                horizontalAlignment:    Text.AlignHCenter
                text:                   valueText
                color:                  "#3f3f3f"
                font.weight:            Font.Medium
                font.pointSize:         ScreenTools.defaultFontPointSize
            }

            Rectangle {
                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.15
                Layout.fillHeight:      true
                Layout.topMargin:       2
                Layout.bottomMargin:    2
                radius:                 root._radius * 0.6
                color:                  plusMouse.pressed ? root._accentSoftGreen : "transparent"
                enabled:                controlsEnabled

                QGCLabel {
                    anchors.centerIn: parent
                    text:             "+"
                    color:            "#3f3f3f"
                    font.weight:      Font.DemiBold
                    font.pointSize:   ScreenTools.defaultFontPointSize
                }

                QGCMouseArea {
                    id:           plusMouse
                    anchors.fill: parent
                    enabled:      controlsEnabled
                    onClicked:    plusClicked()
                }
            }
        }
    }

    ColumnLayout {
        id: valuesColumn
        anchors.margins: _margin
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: ScreenTools.defaultFontPixelHeight / 2

        RowLayout {
            Layout.fillWidth: true
            spacing:          ScreenTools.defaultFontPixelWidth * 2

            QGCLabel {
                Layout.fillWidth: true
                text:             qsTr("Altitude Mode")
                color:            root._titleColor
            }

            QGCButton {
                text:             QGroundControl.altitudeModeShortDescription(_missionController.globalAltitudeMode)
                textColor:        root._titleColor
                showBorder:       true
                backRadius:       ScreenTools.defaultFontPixelHeight

                onClicked: {
                    var removeModes = []
                    var updateFunction = function(altMode){ _missionController.globalAltitudeMode = altMode }
                    if (!_controllerVehicle.supportsTerrainFrame) {
                        removeModes.push(QGroundControl.AltitudeModeTerrainFrame)
                    }
                    if (!_noMissionItemsAdded) {
                        if (_missionController.globalAltitudeMode !== QGroundControl.AltitudeModeRelative) {
                            removeModes.push(QGroundControl.AltitudeModeRelative)
                        }
                        if (_missionController.globalAltitudeMode !== QGroundControl.AltitudeModeAbsolute) {
                            removeModes.push(QGroundControl.AltitudeModeAbsolute)
                        }
                        if (_missionController.globalAltitudeMode !== QGroundControl.AltitudeModeCalcAboveTerrain) {
                            removeModes.push(QGroundControl.AltitudeModeCalcAboveTerrain)
                        }
                        if (_missionController.globalAltitudeMode !== QGroundControl.AltitudeModeTerrainFrame) {
                            removeModes.push(QGroundControl.AltitudeModeTerrainFrame)
                        }
                    }
                    altModeDialogComponent.createObject(mainWindow, { rgRemoveModes: removeModes, updateAltModeFn: updateFunction }).open()
                }
            }
        }

        // Waypoints Altitude — nozzle spraying style
        ColumnLayout {
            Layout.fillWidth: true
            spacing:          ScreenTools.defaultFontPixelHeight * 0.35

            QGCLabel {
                Layout.fillWidth: true
                text:             qsTr("Waypoints Altitude")
                color:            root._bodyColor
            }

            RowLayout {
                Layout.fillWidth:       true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.85
                spacing:                root._pad * 0.45

                QGCSlider {
                    id:                     altitudeSlider
                    Layout.fillWidth:       true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.25
                    from:                   root._factMin(root._altitudeFact, 0)
                    to:                     root._factMax(root._altitudeFact, 121.9)
                    stepSize:               root._factStep(root._altitudeFact, 0.1)
                    activeColor:            root._accentGreen
                    barHeight:              Math.max(1, ScreenTools.defaultFontPixelHeight * 0.10)
                    live:                   true
                    Binding {
                        target:   altitudeSlider
                        property: "value"
                        value:    root._altitudeFact ? Number(root._altitudeFact.value) : altitudeSlider.from
                        when:     !altitudeSlider.pressed
                    }
                    onMoved: {
                        if (root._altitudeFact) {
                            root._altitudeFact.value = value
                        }
                    }
                }

                NozzleValueBox {
                    Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 13
                    Layout.fillHeight:      true
                    valueText:              root._altitudeFact
                                            ? (Number(root._altitudeFact.value).toFixed(1)
                                               + (root._altitudeFact.units ? " " + root._altitudeFact.units : ""))
                                            : "0.0"
                    onMinusClicked: root._nudgeFact(root._altitudeFact, -1,
                                                    root._factStep(root._altitudeFact, 0.1),
                                                    altitudeSlider.from, altitudeSlider.to)
                    onPlusClicked:  root._nudgeFact(root._altitudeFact, 1,
                                                    root._factStep(root._altitudeFact, 0.1),
                                                    altitudeSlider.from, altitudeSlider.to)
                }
            }
        }

        QGCButton {
            id: applyDefaultAltitudeButton
            Layout.fillWidth: true
            text: qsTr("Apply New Altitude")
            visible: false
            backgroundColor: root._fieldsBg
            textColor: root._titleColor
            showBorder: true

            onClicked: mainWindow.showMessageDialog(qsTr("Apply New Altitude"),
                            qsTr("You have changed the default altitude for mission items. Would you like to apply that altitude to all the items in the current mission?"),
                            Dialog.Yes | Dialog.No,
                            function() { applyDefaultAltitudeButton.visible = false; _missionController.applyDefaultMissionAltitude() })

            Connections {
                target: _appSettings.defaultMissionItemAltitude
                function onRawValueChanged() {
                    if (_visualItems.count > 1) {
                        applyDefaultAltitudeButton.visible = true
                    }
                }
            }

            Connections {
                target: _visualItems
                function onCountChanged() {
                    if (_visualItems.count <= 1) {
                        applyDefaultAltitudeButton.visible = false
                    }
                }
            }
        }

        // Flight Speed — nozzle spraying style
        ColumnLayout {
            Layout.fillWidth: true
            spacing:          ScreenTools.defaultFontPixelHeight * 0.35
            visible:          missionItem.speedSection.available
            opacity:          missionItem.speedSection.specifyFlightSpeed ? 1.0 : 0.55

            RowLayout {
                Layout.fillWidth: true
                spacing:          root._pad * 0.6

                QGCCheckBox {
                    checked: missionItem.speedSection.specifyFlightSpeed
                    onClicked: missionItem.speedSection.specifyFlightSpeed = checked
                }

                QGCLabel {
                    Layout.fillWidth: true
                    text:             qsTr("Flight Speed")
                    color:            root._bodyColor
                }
            }

            RowLayout {
                Layout.fillWidth:       true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.85
                spacing:                root._pad * 0.45
                enabled:                missionItem.speedSection.specifyFlightSpeed

                QGCSlider {
                    id:                     speedSlider
                    Layout.fillWidth:       true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.25
                    from:                   root._factMin(root._speedFact, 0)
                    to:                     root._factMax(root._speedFact, 30)
                    stepSize:               root._factStep(root._speedFact, 0.5)
                    enabled:                missionItem.speedSection.specifyFlightSpeed
                    activeColor:            root._accentGreen
                    barHeight:              Math.max(1, ScreenTools.defaultFontPixelHeight * 0.10)
                    live:                   true
                    Binding {
                        target:   speedSlider
                        property: "value"
                        value:    root._speedFact ? Number(root._speedFact.value) : speedSlider.from
                        when:     !speedSlider.pressed
                    }
                    onMoved: {
                        if (root._speedFact && missionItem.speedSection.specifyFlightSpeed) {
                            root._speedFact.value = value
                        }
                    }
                }

                NozzleValueBox {
                    Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 13
                    Layout.fillHeight:      true
                    controlsEnabled:        missionItem.speedSection.specifyFlightSpeed
                    valueText:              root._speedFact
                                            ? (Number(root._speedFact.value).toFixed(1)
                                               + (root._speedFact.units ? " " + root._speedFact.units : ""))
                                            : "0.0"
                    onMinusClicked: root._nudgeFact(root._speedFact, -1,
                                                    root._factStep(root._speedFact, 0.5),
                                                    speedSlider.from, speedSlider.to)
                    onPlusClicked:  root._nudgeFact(root._speedFact, 1,
                                                    root._factStep(root._speedFact, 0.5),
                                                    speedSlider.from, speedSlider.to)
                }
            }
        }

        Column {
            Layout.fillWidth: true
            spacing: _margin
            visible: !_simpleMissionStart

            CameraSection {
                id: cameraSection
                anchors.left: parent.left
                anchors.right: parent.right
                visible: _showCameraSection
                headerColor: root._titleColor

                Component.onCompleted: checked = !_waypointsOnlyMode && missionItem.cameraSection.settingsSpecified
            }

            QGCLabel {
                anchors.left: parent.left
                anchors.right: parent.right
                text: qsTr("Above camera commands will take affect immediately upon mission start.")
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                font.pointSize: ScreenTools.smallFontPointSize
                visible: _showCameraSection && cameraSection.checked
            }

            SectionHeader {
                id: vehicleInfoSectionHeader
                anchors.left: parent.left
                anchors.right: parent.right
                text: qsTr("Vehicle Info")
                color: root._titleColor
                visible: !_waypointsOnlyMode
                checked: false
            }

            GridLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                columnSpacing: ScreenTools.defaultFontPixelWidth
                rowSpacing: columnSpacing
                columns: 2
                visible: vehicleInfoSectionHeader.visible && vehicleInfoSectionHeader.checked

                QGCLabel {
                    text: _firmwareLabel
                    Layout.fillWidth: true
                    visible: _multipleFirmware
                }
                FactComboBox {
                    fact: QGroundControl.settingsManager.appSettings.offlineEditingFirmwareClass
                    indexModel: false
                    Layout.preferredWidth: _fieldWidth
                    visible: _multipleFirmware && _allowFWVehicleTypeSelection
                }
                QGCLabel {
                    text: _controllerVehicle.firmwareTypeString
                    visible: _multipleFirmware && !_allowFWVehicleTypeSelection
                }

                QGCLabel {
                    text: _vehicleLabel
                    Layout.fillWidth: true
                    visible: _multipleVehicleTypes
                }
                FactComboBox {
                    fact: QGroundControl.settingsManager.appSettings.offlineEditingVehicleClass
                    indexModel: false
                    Layout.preferredWidth: _fieldWidth
                    visible: _multipleVehicleTypes && _allowFWVehicleTypeSelection
                }
                QGCLabel {
                    text: _controllerVehicle.vehicleTypeString
                    visible: _multipleVehicleTypes && !_allowFWVehicleTypeSelection
                }

                QGCLabel {
                    Layout.columnSpan: 2
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pointSize: ScreenTools.smallFontPointSize
                    text: qsTr("The following speed values are used to calculate total mission time. They do not affect the flight speed for the mission.")
                    visible: _showCruiseSpeed || _showHoverSpeed
                }

                QGCLabel {
                    text: qsTr("Cruise speed")
                    visible: _showCruiseSpeed
                    Layout.fillWidth: true
                }
                FactTextField {
                    fact: QGroundControl.settingsManager.appSettings.offlineEditingCruiseSpeed
                    visible: _showCruiseSpeed
                    Layout.preferredWidth: _fieldWidth
                }

                QGCLabel {
                    text: qsTr("Hover speed")
                    visible: _showHoverSpeed
                    Layout.fillWidth: true
                }
                FactTextField {
                    fact: QGroundControl.settingsManager.appSettings.offlineEditingHoverSpeed
                    visible: _showHoverSpeed
                    Layout.preferredWidth: _fieldWidth
                }
            } // GridLayout

            SectionHeader {
                id: plannedHomePositionSection
                anchors.left: parent.left
                anchors.right: parent.right
                text: qsTr("Launch Position")
                color: root._titleColor
                visible: !_vehicleHasHomePosition
                checked: false
            }

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: _margin
                visible: plannedHomePositionSection.checked && !_vehicleHasHomePosition

                GridLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    columnSpacing: ScreenTools.defaultFontPixelWidth
                    rowSpacing: columnSpacing
                    columns: 2

                    QGCLabel {
                        text: qsTr("Altitude")
                    }
                    FactTextField {
                        fact: missionItem.plannedHomePositionAltitude
                        Layout.fillWidth: true
                    }
                }

                QGCLabel {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    font.pointSize: ScreenTools.smallFontPointSize
                    text: qsTr("Actual position set by vehicle at flight time.")
                    horizontalAlignment: Text.AlignHCenter
                }

                QGCButton {
                    text: qsTr("Set To Map Center")
                    onClicked: missionItem.coordinate = map.center
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        } // Column
    } // Column
} // Rectangle
