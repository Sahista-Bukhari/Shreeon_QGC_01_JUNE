import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Rectangle {
    id: root

    property bool thinFieldBorders: false

    readonly property color _accentGreen:     "#00a04c"
    readonly property color _accentSoftGreen: "#efffee"
    readonly property color _titleColor:      "#3f3f3f"
    readonly property color _bodyColor:       "#6a6a6a"
    readonly property color _hintColor:       "#8a8a8a"
    readonly property color _cardBorderIdle:  "#e2e2e2"
    readonly property real  _pad:             ScreenTools.defaultFontPixelWidth * 1.05
    readonly property real  _radius:          ScreenTools.defaultFontPixelWidth * 0.75

    property int routeMode:   0   // 0 = Area Route, 1 = Boundary Route
    property int resolution: 0   // 0 = Medium, 1 = High
    property var surveyItem:  null
    property var takeoffItem: null
    property bool sprayPatternExpanded: false
    property bool missionExpanded: false
    property bool boundaryRouteEnabled: false
    // Temporary feature gate. Keep the Boundary Route UI and implementation
    // in place so it can be re-enabled without restoring removed code.

    property string patternSectionTitle: qsTr("Spray Pattern")
    // Live photo / resolution UI is Route Mapping only.
    property bool showPhotoSettings: true
    // Vehicle SPRAY_* / nozzle controls are Agriculture Spraying only.
    property bool showSpraySettings: false
    property bool spraySettingsExpanded: true

    readonly property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    readonly property bool _paramsReady: _activeVehicle
                                         && _activeVehicle.parameterManager
                                         && _activeVehicle.parameterManager.parametersReady

    property Fact _sprayEnFact: null
    property Fact _sprayNozRateFact: null
    property Fact _sprayPumpRateFact: null
    property Fact _misResumeExactFact: null

    readonly property bool _sprayParamsAvailable: _sprayEnFact !== null
                                                  || _sprayNozRateFact !== null
                                                  || _sprayPumpRateFact !== null
                                                  || _misResumeExactFact !== null
    readonly property bool _sprayEnabled: _sprayEnFact !== null && Number(_sprayEnFact.value) !== 0
    readonly property bool _misResumeExactEnabled: _misResumeExactFact !== null && Number(_misResumeExactFact.value) !== 0

    // Recreate with the current active vehicle (controller captures vehicle at construct time).
    Loader {
        id: paramControllerLoader
        active: root.showSpraySettings
        sourceComponent: FactPanelController { }
        onLoaded: root._refreshSprayFacts()
    }

    readonly property bool _showGridAngle: routeMode === 0 && surveyItem && surveyItem.gridAngle
    readonly property bool _surveyPolygonValid: _showGridAngle
                                                && surveyItem.surveyAreaPolygon
                                                && surveyItem.surveyAreaPolygon.isValid
    readonly property var  _cameraCalc: surveyItem && surveyItem.cameraCalc
                                        ? surveyItem.cameraCalc
                                        : null

    // These two Facts belong to the SurveyComplexItem. Updating them changes
    // only the generated survey waypoints and never the takeoff item.
    property Fact _patternAltitudeFact: _cameraCalc && _cameraCalc.distanceToSurface
                                        ? _cameraCalc.distanceToSurface
                                        : null
    property Fact _patternSpeedFact: surveyItem && surveyItem.patternFlightSpeed
                                     ? surveyItem.patternFlightSpeed
                                     : null
    readonly property bool _patternAltitudeAvailable: _patternAltitudeFact !== null
    readonly property bool _patternSpeedAvailable: _patternSpeedFact !== null

    // Mission altitude is bound directly to the takeoff item so it remains
    // independent from the survey pattern altitude.
    property Fact _missionAltitudeFact: takeoffItem && takeoffItem.altitude
                                        ? takeoffItem.altitude
                                        : null
    readonly property bool _missionAltitudeAvailable: _missionAltitudeFact !== null

    signal areaRouteSelected()

    color:  "#ffffff"
    radius: Math.max(4, root._radius * 0.75)
    clip:   true

    // Slider writes are debounced while dragging so survey rebuilds are not
    // hammered every pixel. Always flush before Upload/Save (see flushPendingWrites).
    Timer {
        id: patternAltitudeWriteTimer
        interval: 300
        repeat: false
        onTriggered: root._commitPatternAltitude(patternAltitudeSlider.value)
    }

    Timer {
        id: patternSpeedWriteTimer
        interval: 300
        repeat: false
        onTriggered: root._commitPatternSpeed(patternSpeedSlider.value)
    }

    Timer {
        id: missionAltitudeWriteTimer
        interval: 300
        repeat: false
        onTriggered: root._commitMissionAltitude(missionAltitudeSlider.value)
    }

    // Consume pointer and wheel events which are not handled by a control in
    // this panel. This prevents them from reaching and zooming/panning the map
    // underneath while the task settings are being scrolled.
    DeadMouseArea {
        anchors.fill: parent
    }

    // Matches TransectStyleComplexItem::applyNewAltitude so camera-calc
    // does not overwrite DistanceToSurface from GSD for known cameras.
    function _commitPatternAltitude(altitudeValue) {
        if (!root._patternAltitudeFact || !root._cameraCalc) {
            return
        }
        var alt = Number(altitudeValue)
        if (isNaN(alt)) {
            return
        }
        if (root._cameraCalc.valueSetIsDistance) {
            root._cameraCalc.valueSetIsDistance.value = true
        }
        root._patternAltitudeFact.value = alt
    }

    function _commitPatternSpeed(speedValue) {
        if (!root._patternSpeedFact || !root.surveyItem) {
            return
        }
        var speed = Number(speedValue)
        if (isNaN(speed)) {
            return
        }
        root._patternSpeedFact.value = speed
        // Enabling the override causes QGC to insert a speed command
        // before the pattern and restore the previous speed afterward.
        root.surveyItem.specifyPatternFlightSpeed = true
    }

    function _commitMissionAltitude(altitudeValue) {
        if (!root._missionAltitudeFact) {
            return
        }
        var alt = Number(altitudeValue)
        if (isNaN(alt)) {
            return
        }
        root._missionAltitudeFact.value = alt
    }

    Timer {
        id: nozzleRateWriteTimer
        interval: 250
        repeat: false
        property real pendingValue: 0
        onTriggered: root._commitRateFactFromSlider(root._sprayNozRateFact, pendingValue)
    }

    Timer {
        id: pumpRateWriteTimer
        interval: 250
        repeat: false
        property real pendingValue: 0
        onTriggered: root._commitRateFactFromSlider(root._sprayPumpRateFact, pendingValue)
    }

    Timer {
        id: sprayFactRefreshTimer
        interval: 800
        repeat: false
        onTriggered: root._refreshSprayFacts()
    }

    function _lookupSprayFact(name) {
        var controller = paramControllerLoader.item
        if (!controller || !root._paramsReady || !controller.parameterExists(-1, name)) {
            return null
        }
        return controller.getParameterFact(-1, name, false)
    }

    function _refreshSprayFacts() {
        if (!root.showSpraySettings || !root._paramsReady || !paramControllerLoader.item) {
            root._sprayEnFact = null
            root._sprayNozRateFact = null
            root._sprayPumpRateFact = null
            root._misResumeExactFact = null
            return
        }
        root._sprayEnFact = root._lookupSprayFact("SPRAY_EN")
        root._sprayNozRateFact = root._lookupSprayFact("SPRAY_NOZ_RATE")
        root._sprayPumpRateFact = root._lookupSprayFact("SPRAY_PUMP_RATE")
        root._misResumeExactFact = root._lookupSprayFact("MIS_RESUME_EXACT")
    }

    function _reloadSprayParamController() {
        paramControllerLoader.active = false
        paramControllerLoader.active = root.showSpraySettings
    }

    function _setEnableDisableFact(fact, enabled) {
        if (!fact) {
            return
        }
        var strings = fact.enumStrings
        if (strings && strings.length > 0) {
            var want = enabled ? "enabled" : "disabled"
            for (var i = 0; i < strings.length; i++) {
                if (String(strings[i]).toLowerCase().indexOf(want) >= 0) {
                    fact.value = fact.enumValues[i]
                    return
                }
            }
        }
        fact.value = enabled ? 1 : 0
    }

    function _setSprayEnabled(enabled) {
        root._setEnableDisableFact(root._sprayEnFact, enabled)
        // After enable, firmware may expose dependent spray params — request/refresh them.
        if (enabled && paramControllerLoader.item) {
            paramControllerLoader.item.getMissingParameters([
                "SPRAY_NOZ_RATE",
                "SPRAY_PUMP_RATE",
                "MIS_RESUME_EXACT"
            ])
            sprayFactRefreshTimer.restart()
        }
    }

    function _rateFactMin(fact) {
        if (!fact || fact.minIsDefaultForType) {
            return 0
        }
        var v = Number(fact.min)
        return isNaN(v) ? 0 : v
    }

    function _rateFactMax(fact) {
        if (!fact || fact.maxIsDefaultForType) {
            return 1
        }
        var v = Number(fact.max)
        return isNaN(v) ? 1 : v
    }

    function _rateFactStep(fact) {
        return 0.01
    }

    function _nudgeRateFact(fact, direction) {
        // Rates only go to the vehicle while the sprayer is enabled.
        if (!fact || !root._sprayEnabled) {
            return
        }
        var step = root._rateFactStep(fact)
        var next = Number(fact.value) + (direction * step)
        var minV = root._rateFactMin(fact)
        var maxV = root._rateFactMax(fact)
        next = Math.max(minV, Math.min(maxV, next))
        fact.value = Math.round(next * 1000) / 1000
    }

    function _commitRateFactFromSlider(fact, value) {
        // Rates only go to the vehicle while the sprayer is enabled.
        if (!fact || !root._sprayEnabled) {
            return
        }
        var next = Number(value)
        if (isNaN(next)) {
            return
        }
        var minV = root._rateFactMin(fact)
        var maxV = root._rateFactMax(fact)
        next = Math.max(minV, Math.min(maxV, next))
        var rounded = Math.round(next * 1000) / 1000
        if (Math.abs(Number(fact.value) - rounded) < 0.0005) {
            return
        }
        fact.value = rounded
    }

    function _queueNozzleRateWrite(value) {
        nozzleRateWriteTimer.pendingValue = value
        nozzleRateWriteTimer.restart()
    }

    function _queuePumpRateWrite(value) {
        pumpRateWriteTimer.pendingValue = value
        pumpRateWriteTimer.restart()
    }

    // Medium keeps default density; High shortens trigger spacing / raises overlap
    // so Est. Photo Count and mission triggers both increase.
    function applyResolutionPreset() {
        if (!root._cameraCalc) {
            return
        }

        var high = root.resolution === 1
        if (root._cameraCalc.isManualCamera) {
            var altitude = root._patternAltitudeFact
                           ? Number(root._patternAltitudeFact.value)
                           : 50
            if (isNaN(altitude) || altitude <= 0) {
                altitude = 50
            }
            // Manual grids drive shot count from adjusted footprints directly.
            var spacingFactor = high ? 0.35 : 0.50
            var spacing = Math.max(2.0, altitude * spacingFactor)
            if (root._cameraCalc.adjustedFootprintFrontal) {
                root._cameraCalc.adjustedFootprintFrontal.value = spacing
            }
            if (root._cameraCalc.adjustedFootprintSide) {
                root._cameraCalc.adjustedFootprintSide.value = spacing
            }
        } else {
            if (root._cameraCalc.frontalOverlap) {
                root._cameraCalc.frontalOverlap.value = high ? 80 : 70
            }
            if (root._cameraCalc.sideOverlap) {
                root._cameraCalc.sideOverlap.value = high ? 80 : 70
            }
        }
    }

    function syncResolutionFromSurvey() {
        if (!root._cameraCalc) {
            root.resolution = 0
            return
        }

        if (root._cameraCalc.isManualCamera) {
            var altitude = root._patternAltitudeFact
                           ? Number(root._patternAltitudeFact.value)
                           : 0
            var frontalSpacing = root._cameraCalc.adjustedFootprintFrontal
                                 ? Number(root._cameraCalc.adjustedFootprintFrontal.value)
                                 : 0
            root.resolution = altitude > 0 && frontalSpacing > 0
                    && frontalSpacing <= altitude * 0.425 ? 1 : 0
        } else {
            var frontalOverlap = root._cameraCalc.frontalOverlap
                    ? Number(root._cameraCalc.frontalOverlap.value) : 0
            var sideOverlap = root._cameraCalc.sideOverlap
                    ? Number(root._cameraCalc.sideOverlap.value) : 0
            root.resolution = frontalOverlap >= 75 || sideOverlap >= 75 ? 1 : 0
        }
    }

    Component.onCompleted: {
        syncResolutionFromSurvey()
        root._refreshSprayFacts()
    }

    // Call from Upload/Save so pending slider drags are not lost.
    // Only commits when a write is pending or the slider differs from the Fact,
    // so an uninitialized slider cannot clobber the real altitude.
    function flushPendingWrites() {
        if (patternAltitudeWriteTimer.running) {
            patternAltitudeWriteTimer.stop()
            root._commitPatternAltitude(patternAltitudeSlider.value)
        } else if (root._patternAltitudeAvailable && root._patternAltitudeFact) {
            var patternAlt = Number(root._patternAltitudeFact.value)
            if (!isNaN(patternAlt)
                    && Math.abs(patternAltitudeSlider.value - patternAlt) > 0.01) {
                root._commitPatternAltitude(patternAltitudeSlider.value)
            }
        }

        if (patternSpeedWriteTimer.running) {
            patternSpeedWriteTimer.stop()
            root._commitPatternSpeed(patternSpeedSlider.value)
        } else if (root._patternSpeedAvailable && root._patternSpeedFact) {
            var patternSpeed = Number(root._patternSpeedFact.value)
            if (!isNaN(patternSpeed)
                    && Math.abs(patternSpeedSlider.value - patternSpeed) > 0.01) {
                root._commitPatternSpeed(patternSpeedSlider.value)
            }
        }

        if (missionAltitudeWriteTimer.running) {
            missionAltitudeWriteTimer.stop()
            root._commitMissionAltitude(missionAltitudeSlider.value)
        } else if (root._missionAltitudeAvailable && root._missionAltitudeFact) {
            var missionAlt = Number(root._missionAltitudeFact.value)
            if (!isNaN(missionAlt)
                    && Math.abs(missionAltitudeSlider.value - missionAlt) > 0.01) {
                root._commitMissionAltitude(missionAltitudeSlider.value)
            }
        }
    }

    function _syncPatternAltitudeSlider() {
        // Keep external Fact changes visible without fighting an active drag.
        if (!root._patternAltitudeFact || patternAltitudeSlider.pressed) {
            return
        }
        var alt = Number(root._patternAltitudeFact.value)
        if (!isNaN(alt) && Math.abs(patternAltitudeSlider.value - alt) > 0.01) {
            patternAltitudeSlider.value = alt
        }
    }

    function _syncPatternSpeedSlider() {
        // Keep loaded/edited plan values synchronized with the slider.
        if (!root._patternSpeedFact || patternSpeedSlider.pressed) {
            return
        }
        var speed = Number(root._patternSpeedFact.value)
        if (!isNaN(speed) && Math.abs(patternSpeedSlider.value - speed) > 0.01) {
            patternSpeedSlider.value = speed
        }
    }

    function _syncMissionAltitudeSlider() {
        // Takeoff altitude is synchronized separately from pattern altitude.
        if (!root._missionAltitudeFact || missionAltitudeSlider.pressed) {
            return
        }
        var alt = Number(root._missionAltitudeFact.value)
        if (!isNaN(alt) && Math.abs(missionAltitudeSlider.value - alt) > 0.01) {
            missionAltitudeSlider.value = alt
        }
    }

    QGCFlickable {
        id: taskSettingsFlickable
        anchors.fill:         parent
        anchors.topMargin:    root._pad * 1.55
        anchors.bottomMargin: root._pad
        anchors.leftMargin:   root._pad * 1.55
        anchors.rightMargin:  root._pad * 1.55
        contentWidth:         width
        contentHeight:        taskSettingsColumn.implicitHeight
        clip:               true

        ColumnLayout {
            id: taskSettingsColumn
            width:              taskSettingsFlickable.width
            spacing:            ScreenTools.defaultFontPixelHeight * 0.55

            QGCLabel {
                Layout.fillWidth:   true
                text:               qsTr("Task Settings")
                color:              root._titleColor
                font.weight:        Font.Medium
                font.pointSize:     ScreenTools.mediumFontPointSize
                horizontalAlignment: Text.AlignHCenter
            }

            QGCLabel {
                Layout.fillWidth:   true
                Layout.topMargin:   ScreenTools.defaultFontPixelHeight * 0.6
                text:               qsTr("Route Mode")
                color:              root._titleColor
                font.pointSize:     ScreenTools.defaultFontPointSize
            }

            Repeater {
                id: boundarrate
                model: [
                    {
                        title: qsTr("Area Route"),
                        description: qsTr("Maps entire area. Mapping this route type is time consuming and of high accuracy.")
                    },
                    {
                        title: qsTr("Boundary Route"),
                        description: qsTr("Maps a boundary of the area with a width of 20m. Mapping this route type is time efficient and of moderate accuracy.")
                    }
                ]

                Rectangle {
                    Layout.fillWidth:   true
                    Layout.preferredHeight: routeModeCardLayout.implicitHeight + root._pad * 2.4
                    enabled:            index === 0 || root.boundaryRouteEnabled
                    opacity:            enabled ? 1.0 : 0.45
                    radius:             root._radius
                    color:              root.routeMode === index ? root._accentSoftGreen : "#ffffff"
                    border.width:       root.routeMode === index ? 2 : 1
                    border.color:       root.routeMode === index ? root._accentGreen : root._cardBorderIdle

                    RowLayout {
                        id: routeModeCardLayout
                        anchors.fill:   parent
                        anchors.margins: root._pad * 1.35
                        spacing:        root._pad

                        Rectangle {
                            Layout.alignment:       Qt.AlignTop
                            Layout.topMargin:       ScreenTools.defaultFontPixelHeight * 0.12
                            Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.05
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.05
                            radius:                 width / 2
                            color:                  "white"
                            border.width:           root.routeMode === index ? 0 : 1
                            border.color:           root._cardBorderIdle

                            Rectangle {
                                anchors.centerIn:   parent
                                width:              parent.width * (root.routeMode === index ? 0.72 : 0)
                                height:             width
                                radius:             width / 2
                                color:              root._accentGreen
                                visible:            root.routeMode === index
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth:   true
                            spacing:            ScreenTools.defaultFontPixelHeight * 0.2

                            QGCLabel {
                                Layout.fillWidth:   true
                                text:               modelData.title
                                color:              root.routeMode === index ? root._accentGreen : root._titleColor
                                font.weight:        Font.Medium
                                font.pointSize:     ScreenTools.defaultFontPointSize
                                wrapMode:           Text.WordWrap
                            }

                            QGCLabel {
                                Layout.fillWidth:   true
                                text:               modelData.description
                                color:              root._bodyColor
                                font.pointSize:     ScreenTools.defaultFontPointSize
                                wrapMode:           Text.WordWrap
                            }
                        }

                        QGCLabel {
                            Layout.alignment:   Qt.AlignTop
                            Layout.topMargin:   ScreenTools.defaultFontPixelHeight * 0.1
                            text:               index === 0 ? "\u2261" : "\u2317"
                            color:              root.routeMode === index ? root._accentGreen : root._hintColor
                            font.weight:        Font.Medium
                            font.pointSize:     ScreenTools.defaultFontPointSize
                        }
                    }

                    RippleEffect {
                        id: routeModeRipple
                        rippleColor: root.routeMode === index
                                     ? Qt.rgba(0.0, 0.63, 0.30, 0.28)
                                     : Qt.rgba(0, 0, 0, 0.14)
                        clipRadius: root._radius
                    }

                    QGCMouseArea {
                        anchors.fill:   parent
                        enabled:        index === 0 || root.boundaryRouteEnabled
                        cursorShape:    enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: function(mouse) {
                            routeModeRipple.tap(mouse.x, mouse.y)
                            root.routeMode = index
                            if (index === 0) {
                                root.areaRouteSelected()
                            }
                        }
                    }
                }
            }

            // Agriculture spraying nozzle / pump parameters (vehicle Facts).
            Rectangle {
                id:                     nozzleSprayHeader
                Layout.fillWidth:       true
                Layout.topMargin:       ScreenTools.defaultFontPixelHeight * 0.55
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.15
                visible:                root.showSpraySettings
                radius:                 root._radius
                readonly property bool highlighted: root.spraySettingsExpanded
                                                    || spraySettingsHeaderMouseArea.containsMouse
                                                    || spraySettingsHeaderMouseArea.pressed
                color:                  highlighted ? root._accentGreen : "#ffffff"
                border.width:           1
                border.color:           highlighted ? root._accentGreen : root._cardBorderIdle

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                RowLayout {
                    anchors.fill:        parent
                    anchors.leftMargin:  root._pad * 0.75
                    anchors.rightMargin: root._pad * 0.75
                    spacing:             root._pad * 1.2

                    QGCColoredImage {
                        Layout.alignment:       Qt.AlignVCenter
                        Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.15
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.15
                        source:                 "/res/Nozel.png"
                        color:                  nozzleSprayHeader.highlighted ? "#ffffff" : root._titleColor
                        fillMode:               Image.PreserveAspectFit
                    }

                    QGCLabel {
                        Layout.fillWidth:   true
                        Layout.leftMargin:  root._pad * 0.35
                        text:               qsTr("Nozzle Spraying")
                        color:              nozzleSprayHeader.highlighted ? "#ffffff" : root._titleColor
                        font.weight:        Font.Medium
                        font.pointSize:     ScreenTools.defaultFontPointSize
                    }

                    QGCColoredImage {
                        Layout.alignment:       Qt.AlignVCenter
                        Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 0.65
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.65
                        source:                 "/res/DropArrow.svg"
                        color:                  nozzleSprayHeader.highlighted ? "#ffffff" : root._bodyColor
                        rotation:               root.spraySettingsExpanded ? 180 : 0

                        Behavior on rotation {
                            NumberAnimation { duration: 160 }
                        }
                    }
                }

                RippleEffect {
                    id: spraySettingsRipple
                    rippleColor: nozzleSprayHeader.highlighted
                                 ? Qt.rgba(1, 1, 1, 0.40)
                                 : Qt.rgba(0, 0, 0, 0.14)
                    clipRadius: root._radius
                }

                QGCMouseArea {
                    id:           spraySettingsHeaderMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        spraySettingsRipple.tap(mouse.x, mouse.y)
                        root.spraySettingsExpanded = !root.spraySettingsExpanded
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing:          ScreenTools.defaultFontPixelHeight * 0.55
                visible:          root.showSpraySettings && root.spraySettingsExpanded

                QGCLabel {
                    Layout.fillWidth: true
                    text:             !root._activeVehicle
                                      ? qsTr("Connect a vehicle to edit spray parameters.")
                                      : (!root._paramsReady
                                         ? qsTr("Waiting for vehicle parameters…")
                                         : (!root._sprayParamsAvailable
                                            ? qsTr("Spray parameters are not available on this vehicle.")
                                            : qsTr("Control sprayer enable and nozzle / pump output rates.")))
                    color:            root._hintColor
                    wrapMode:         Text.WordWrap
                    font.pointSize:   ScreenTools.smallFontPointSize
                }

                RowLayout {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.15
                    spacing:                root._pad * 0.6
                    visible:                root._sprayEnFact !== null

                    QGCLabel {
                        Layout.fillWidth: true
                        text:             qsTr("Sprayer")
                        color:            root._titleColor
                        font.weight:      Font.Medium
                    }

                    QGCLabel {
                        text:        root._sprayEnabled ? qsTr("Enabled") : qsTr("Disabled")
                        color:       root._sprayEnabled ? root._accentGreen : root._bodyColor
                        font.weight: Font.Medium
                    }

                    QGCCheckBoxSlider {
                        Layout.alignment: Qt.AlignVCenter
                        checked:          root._sprayEnabled
                        onClicked:        root._setSprayEnabled(checked)
                    }
                }

                QGCLabel {
                    Layout.fillWidth: true
                    text:             qsTr("Nozzle rate")
                    color:            root._sprayEnabled ? root._bodyColor : root._hintColor
                    visible:          root._sprayNozRateFact !== null
                }

                RowLayout {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.15
                    spacing:                root._pad * 0.55
                    visible:                root._sprayNozRateFact !== null
                    enabled:                root._sprayEnabled
                    opacity:                root._sprayEnabled ? 1.0 : 0.45

                    QGCSlider {
                        id:                     nozzleRateSlider
                        Layout.fillWidth:       true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.5
                        from:                   root._rateFactMin(root._sprayNozRateFact)
                        to:                     root._rateFactMax(root._sprayNozRateFact)
                        stepSize:               root._rateFactStep(root._sprayNozRateFact)
                        enabled:                root._sprayEnabled && root._sprayNozRateFact !== null
                        activeColor:            root._accentGreen
                        barHeight:              Math.max(1, ScreenTools.defaultFontPixelHeight * 0.12)
                        live:                   true
                        Binding {
                            target:   nozzleRateSlider
                            property: "value"
                            value:    root._sprayNozRateFact ? Number(root._sprayNozRateFact.value) : nozzleRateSlider.from
                            when:     !nozzleRateSlider.pressed
                        }
                        onMoved: root._queueNozzleRateWrite(value)
                        onPressedChanged: {
                            if (!pressed) {
                                nozzleRateWriteTimer.stop()
                                root._commitRateFactFromSlider(root._sprayNozRateFact, value)
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 14
                        Layout.fillHeight:      true
                        radius:                 root._radius
                        color:                  "white"
                        border.width:           1
                        border.color:           root._cardBorderIdle

                        RowLayout {
                            anchors.fill:        parent
                            anchors.leftMargin:  ScreenTools.defaultFontPixelWidth * 0.35
                            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.35
                            spacing:             0

                            Rectangle {
                                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.35
                                Layout.fillHeight:      true
                                Layout.topMargin:       2
                                Layout.bottomMargin:    2
                                radius:                 root._radius * 0.7
                                color:                  nozzleMinusMouse.pressed ? "#ffe8e8" : "transparent"

                                QGCLabel {
                                    anchors.centerIn: parent
                                    text:             "−"
                                    color:            nozzleMinusMouse.pressed ? "#e53935" : root._titleColor
                                    font.weight:      Font.DemiBold
                                    font.pointSize:   ScreenTools.mediumFontPointSize
                                }

                                RippleEffect {
                                    id: nozzleMinusRipple
                                    rippleColor: Qt.rgba(0.90, 0.22, 0.21, 0.28)
                                    clipRadius: root._radius * 0.7
                                }

                                QGCMouseArea {
                                    id:           nozzleMinusMouse
                                    anchors.fill: parent
                                    cursorShape:  Qt.PointingHandCursor
                                    onClicked: function(mouse) {
                                        nozzleMinusRipple.tap(mouse.x, mouse.y)
                                        root._nudgeRateFact(root._sprayNozRateFact, -1)
                                    }
                                }
                            }

                            QGCLabel {
                                Layout.fillWidth:       true
                                horizontalAlignment:    Text.AlignHCenter
                                text:                   root._sprayNozRateFact
                                                        ? Number(root._sprayNozRateFact.value).toFixed(3)
                                                        : "0.000"
                                color:                  root._titleColor
                                font.weight:            Font.Medium
                            }

                            Rectangle {
                                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.35
                                Layout.fillHeight:      true
                                Layout.topMargin:       2
                                Layout.bottomMargin:    2
                                radius:                 root._radius * 0.7
                                color:                  nozzlePlusMouse.pressed ? root._accentSoftGreen : "transparent"

                                QGCLabel {
                                    anchors.centerIn: parent
                                    text:             "+"
                                    color:            root._titleColor
                                    font.weight:      Font.DemiBold
                                    font.pointSize:   ScreenTools.mediumFontPointSize
                                }

                                RippleEffect {
                                    id: nozzlePlusRipple
                                    rippleColor: Qt.rgba(0.0, 0.63, 0.30, 0.28)
                                    clipRadius: root._radius * 0.7
                                }

                                QGCMouseArea {
                                    id:           nozzlePlusMouse
                                    anchors.fill: parent
                                    cursorShape:  Qt.PointingHandCursor
                                    onClicked: function(mouse) {
                                        nozzlePlusRipple.tap(mouse.x, mouse.y)
                                        root._nudgeRateFact(root._sprayNozRateFact, 1)
                                    }
                                }
                            }
                        }
                    }
                }

                QGCLabel {
                    Layout.fillWidth: true
                    text:             qsTr("Pump rate")
                    color:            root._sprayEnabled ? root._bodyColor : root._hintColor
                    visible:          root._sprayPumpRateFact !== null
                }

                RowLayout {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.15
                    spacing:                root._pad * 0.55
                    visible:                root._sprayPumpRateFact !== null
                    enabled:                root._sprayEnabled
                    opacity:                root._sprayEnabled ? 1.0 : 0.45

                    QGCSlider {
                        id:                     pumpRateSlider
                        Layout.fillWidth:       true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.5
                        from:                   root._rateFactMin(root._sprayPumpRateFact)
                        to:                     root._rateFactMax(root._sprayPumpRateFact)
                        stepSize:               root._rateFactStep(root._sprayPumpRateFact)
                        enabled:                root._sprayEnabled && root._sprayPumpRateFact !== null
                        activeColor:            root._accentGreen
                        barHeight:              Math.max(1, ScreenTools.defaultFontPixelHeight * 0.12)
                        live:                   true
                        Binding {
                            target:   pumpRateSlider
                            property: "value"
                            value:    root._sprayPumpRateFact ? Number(root._sprayPumpRateFact.value) : pumpRateSlider.from
                            when:     !pumpRateSlider.pressed
                        }
                        onMoved: root._queuePumpRateWrite(value)
                        onPressedChanged: {
                            if (!pressed) {
                                pumpRateWriteTimer.stop()
                                root._commitRateFactFromSlider(root._sprayPumpRateFact, value)
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 14
                        Layout.fillHeight:      true
                        radius:                 root._radius
                        color:                  "white"
                        border.width:           1
                        border.color:           root._cardBorderIdle

                        RowLayout {
                            anchors.fill:        parent
                            anchors.leftMargin:  ScreenTools.defaultFontPixelWidth * 0.35
                            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.35
                            spacing:             0

                            Rectangle {
                                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.35
                                Layout.fillHeight:      true
                                Layout.topMargin:       2
                                Layout.bottomMargin:    2
                                radius:                 root._radius * 0.7
                                color:                  pumpMinusMouse.pressed ? "#ffe8e8" : "transparent"

                                QGCLabel {
                                    anchors.centerIn: parent
                                    text:             "−"
                                    color:            pumpMinusMouse.pressed ? "#e53935" : root._titleColor
                                    font.weight:      Font.DemiBold
                                    font.pointSize:   ScreenTools.mediumFontPointSize
                                }

                                RippleEffect {
                                    id: pumpMinusRipple
                                    rippleColor: Qt.rgba(0.90, 0.22, 0.21, 0.28)
                                    clipRadius: root._radius * 0.7
                                }

                                QGCMouseArea {
                                    id:           pumpMinusMouse
                                    anchors.fill: parent
                                    cursorShape:  Qt.PointingHandCursor
                                    onClicked: function(mouse) {
                                        pumpMinusRipple.tap(mouse.x, mouse.y)
                                        root._nudgeRateFact(root._sprayPumpRateFact, -1)
                                    }
                                }
                            }

                            QGCLabel {
                                Layout.fillWidth:       true
                                horizontalAlignment:    Text.AlignHCenter
                                text:                   root._sprayPumpRateFact
                                                        ? Number(root._sprayPumpRateFact.value).toFixed(3)
                                                        : "0.000"
                                color:                  root._titleColor
                                font.weight:            Font.Medium
                            }

                            Rectangle {
                                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.35
                                Layout.fillHeight:      true
                                Layout.topMargin:       2
                                Layout.bottomMargin:    2
                                radius:                 root._radius * 0.7
                                color:                  pumpPlusMouse.pressed ? root._accentSoftGreen : "transparent"

                                QGCLabel {
                                    anchors.centerIn: parent
                                    text:             "+"
                                    color:            root._titleColor
                                    font.weight:      Font.DemiBold
                                    font.pointSize:   ScreenTools.mediumFontPointSize
                                }

                                RippleEffect {
                                    id: pumpPlusRipple
                                    rippleColor: Qt.rgba(0.0, 0.63, 0.30, 0.28)
                                    clipRadius: root._radius * 0.7
                                }

                                QGCMouseArea {
                                    id:           pumpPlusMouse
                                    anchors.fill: parent
                                    cursorShape:  Qt.PointingHandCursor
                                    onClicked: function(mouse) {
                                        pumpPlusRipple.tap(mouse.x, mouse.y)
                                        root._nudgeRateFact(root._sprayPumpRateFact, 1)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            QGCLabel {
                Layout.fillWidth:   true
                Layout.topMargin:   ScreenTools.defaultFontPixelHeight * 0.8
                text:               qsTr("Resolution")
                color:              root._titleColor
                font.pointSize:     ScreenTools.defaultFontPointSize
                visible:            root.showPhotoSettings
            }

            RowLayout {
                Layout.fillWidth:   true
                spacing:            0
                clip:               true
                visible:            root.showPhotoSettings

                Repeater {
                    model: [qsTr("Medium"), qsTr("High")]

                    Rectangle {
                        Layout.fillWidth:       true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.15
                        color:                  root.resolution === index ? root._accentGreen : "#ffffff"
                        border.width:           1
                        border.color:           root.resolution === index ? root._accentGreen : root._cardBorderIdle
                        radius:                 root._radius

                        QGCLabel {
                            anchors.centerIn:   parent
                            text:               modelData
                            color:              root.resolution === index ? "#ffffff" : root._bodyColor
                            font.weight:        Font.Medium
                        }

                        RippleEffect {
                            id: resolutionRipple
                            rippleColor: root.resolution === index
                                         ? Qt.rgba(1, 1, 1, 0.40)
                                         : Qt.rgba(0, 0, 0, 0.14)
                            clipRadius: root._radius
                        }

                        QGCMouseArea {
                            anchors.fill: parent
                            cursorShape:  Qt.PointingHandCursor
                            onClicked: function(mouse) {
                                resolutionRipple.tap(mouse.x, mouse.y)
                                root.resolution = index
                                root.applyResolutionPreset()
                            }
                        }
                    }
                }
            }

            QGCLabel {
                Layout.fillWidth:   true
                Layout.topMargin:   ScreenTools.defaultFontPixelHeight * 0.15
                text:               root.resolution === 0
                                    ? qsTr("Medium resolution balances photo count and flight time.")
                                    : qsTr("High resolution increases photo count and flight time.")
                color:              root._hintColor
                font.pointSize:     ScreenTools.defaultFontPointSize
                visible:            root.showPhotoSettings
                wrapMode:           Text.WordWrap
            }

            Rectangle {
                id:                     sprayPatternHeader
                Layout.fillWidth:       true
                Layout.topMargin:       ScreenTools.defaultFontPixelHeight * 0.25
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.15
                visible:                root._showGridAngle
                radius:                 root._radius
                readonly property bool highlighted: root.sprayPatternExpanded
                                                    || sprayPatternHeaderMouseArea.containsMouse
                                                    || sprayPatternHeaderMouseArea.pressed
                color:                  highlighted ? root._accentGreen : "#ffffff"
                border.width:           1
                border.color:           highlighted ? root._accentGreen : root._cardBorderIdle

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: root._pad * 0.75
                    anchors.rightMargin: root._pad * 0.75

                    QGCLabel {
                        Layout.fillWidth: true
                        text:            root.patternSectionTitle
                        color:            sprayPatternHeader.highlighted ? "#ffffff" : root._titleColor
                        font.weight:      Font.Medium
                        font.pointSize:   ScreenTools.defaultFontPointSize
                    }

                    QGCColoredImage {
                        Layout.alignment:       Qt.AlignVCenter
                        Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 0.65
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.65
                        source:                 "/res/DropArrow.svg"
                        color:                  sprayPatternHeader.highlighted ? "#ffffff" : root._bodyColor
                        rotation:               root.sprayPatternExpanded ? 180 : 0

                        Behavior on rotation {
                            NumberAnimation { duration: 160 }
                        }
                    }
                }

                RippleEffect {
                    id: sprayPatternRipple
                    rippleColor: sprayPatternHeader.highlighted
                                 ? Qt.rgba(1, 1, 1, 0.40)
                                 : Qt.rgba(0, 0, 0, 0.14)
                    clipRadius: root._radius
                }

                QGCMouseArea {
                    id:           sprayPatternHeaderMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        sprayPatternRipple.tap(mouse.x, mouse.y)
                        root.sprayPatternExpanded = !root.sprayPatternExpanded
                    }
                }
            }
            // Survey-only parameters. Altitude changes survey waypoint heights;
            // speed controls the temporary speed override around those waypoints.
            GridLayout {
                Layout.fillWidth:    true
                Layout.topMargin:    ScreenTools.defaultFontPixelHeight * 0.25
                Layout.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.35
                columns:             2
                columnSpacing:       root._pad * 0.65
                rowSpacing:          ScreenTools.defaultFontPixelHeight * 0.55
                visible:             root._showGridAngle && root.sprayPatternExpanded

                QGCLabel {
                    text:       qsTr("Angle")
                    color:      root._bodyColor
                }

                FactTextField {
                    id:                 gridAngleField
                    fact:               root.surveyItem ? root.surveyItem.gridAngle : null
                    Layout.fillWidth:   true
                    enabled:            root._showGridAngle
                    activeFocusBorderColor: root._accentGreen
                    persistentBorder:       false
                    fieldBorderWidth:       root.thinFieldBorders ? 1 : 2
                    fieldTextColor:         "#3f3f3f"
                    fieldBackgroundColor:   "white"
                    onUpdated:          gridAngleSlider.value = root.surveyItem.gridAngle.value
                }

                QGCSlider {
                    id:                     gridAngleSlider
                    from:                   0
                    to:                     359
                    stepSize:               1
                    Layout.fillWidth:       true
                    Layout.columnSpan:      2
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.5
                    enabled:                root._showGridAngle
                    activeColor:            "#23a800"
                    barHeight:              Math.max(1, ScreenTools.defaultFontPixelHeight * 0.12)
                    live:                   true
                    onValueChanged: {
                        if (root.surveyItem && root.surveyItem.gridAngle) {
                            root.surveyItem.gridAngle.value = value
                        }
                    }
                }

                QGCLabel {
                    text: root._cameraCalc && root._cameraCalc.isManualCamera
                          ? qsTr("Spacing")
                          : qsTr("Side Lap")
                    color: root._bodyColor
                }

                FactTextField {
                    fact: root._cameraCalc
                          ? (root._cameraCalc.isManualCamera
                             ? root._cameraCalc.adjustedFootprintSide
                             : root._cameraCalc.sideOverlap)
                          : null
                    Layout.fillWidth: true
                    enabled: root._showGridAngle
                    activeFocusBorderColor: root._accentGreen
                    persistentBorder:       false
                    fieldBorderWidth:       root.thinFieldBorders ? 1 : 2
                    fieldTextColor:         "#3f3f3f"
                    fieldBackgroundColor:   "white"
                }

                QGCLabel {
                    text:  qsTr("Turnaround")
                    color: root._bodyColor
                }

                FactTextField {
                    fact: root.surveyItem ? root.surveyItem.turnAroundDistance : null
                    Layout.fillWidth: true
                    enabled: root._showGridAngle
                    activeFocusBorderColor: root._accentGreen
                    persistentBorder:       false
                    fieldBorderWidth:       root.thinFieldBorders ? 1 : 2
                    fieldTextColor:         "#3f3f3f"
                    fieldBackgroundColor:   "white"
                }

                QGCLabel {
                    text:  qsTr("Altitude")
                    color: root._bodyColor
                }

                AltitudeFactTextField {
                    fact:               root._patternAltitudeFact
                    altitudeMode:       root._cameraCalc
                                        ? root._cameraCalc.distanceMode
                                        : QGroundControl.AltitudeModeNone
                    Layout.fillWidth:   true
                    enabled:            root._patternAltitudeAvailable
                    activeFocusBorderColor: root._accentGreen
                    persistentBorder:       false
                    fieldBorderWidth:       root.thinFieldBorders ? 1 : 2
                    fieldTextColor:         "#3f3f3f"
                    fieldBackgroundColor:   "white"
                    onUpdated: {
                        if (root._cameraCalc && root._cameraCalc.valueSetIsDistance) {
                            root._cameraCalc.valueSetIsDistance.value = true
                        }
                        root._syncPatternAltitudeSlider()
                    }
                }

                QGCSlider {
                    id:                     patternAltitudeSlider
                    from:                   1
                    to:                     500
                    stepSize:               1
                    Layout.fillWidth:       true
                    Layout.columnSpan:      2
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.5
                    enabled:                root._patternAltitudeAvailable
                    activeColor:            root._accentGreen
                    barHeight:              Math.max(1, ScreenTools.defaultFontPixelHeight * 0.12)
                    live:                   true
                    // Do not bind value: to the Fact while dragging — that snaps
                    // the handle back and can upload the old/default altitude.
                    Binding {
                        target:   patternAltitudeSlider
                        property: "value"
                        value:    root._patternAltitudeFact
                                  ? Number(root._patternAltitudeFact.value)
                                  : patternAltitudeSlider.from
                        when:     !patternAltitudeSlider.pressed
                    }
                    onMoved:                patternAltitudeWriteTimer.restart()
                    onPressedChanged: {
                        if (!pressed) {
                            patternAltitudeWriteTimer.stop()
                            root._commitPatternAltitude(value)
                        }
                    }
                }

                QGCLabel {
                    text:  qsTr("Speed")
                    color: root._bodyColor
                }

                FactTextField {
                    fact:               root._patternSpeedFact
                    Layout.fillWidth:   true
                    enabled:            root._patternSpeedAvailable
                    activeFocusBorderColor: root._accentGreen
                    persistentBorder:       true
                    fieldBorderWidth:       root.thinFieldBorders ? 1 : 2
                    fieldTextColor:         "#3f3f3f"
                    fieldBackgroundColor:   "white"
                    onUpdated: {
                        if (root.surveyItem) {
                            root.surveyItem.specifyPatternFlightSpeed = true
                        }
                        root._syncPatternSpeedSlider()
                    }
                }

                QGCSlider {
                    id:                     patternSpeedSlider
                    from:                   0.5
                    to:                     30
                    stepSize:               0.5
                    Layout.fillWidth:       true
                    Layout.columnSpan:      2
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.5
                    enabled:                root._patternSpeedAvailable
                    activeColor:            root._accentGreen
                    barHeight:              Math.max(1, ScreenTools.defaultFontPixelHeight * 0.12)
                    live:                   true
                    Binding {
                        target:   patternSpeedSlider
                        property: "value"
                        value:    root._patternSpeedFact
                                  ? Number(root._patternSpeedFact.value)
                                  : patternSpeedSlider.from
                        when:     !patternSpeedSlider.pressed
                    }
                    onMoved:                patternSpeedWriteTimer.restart()
                    onPressedChanged: {
                        if (!pressed) {
                            patternSpeedWriteTimer.stop()
                            root._commitPatternSpeed(value)
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth:       true
                Layout.leftMargin:      root._pad
                Layout.rightMargin:     root._pad
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.15
                visible:                root._showGridAngle && root.sprayPatternExpanded
                enabled:                root._surveyPolygonValid
                opacity:                enabled ? 1.0 : 0.45
                color:                  rotateEntryMouseArea.pressed
                                        ? Qt.darker(root._accentGreen, 1.12)
                                        : root._accentGreen
                border.width:           1
                border.color:           root._accentGreen
                radius:                 root._radius

                QGCLabel {
                    anchors.centerIn: parent
                    text:             qsTr("Rotate Entry Point")
                    color:            "white"
                    font.weight:      Font.Medium
                }

                RippleEffect {
                    id: rotateEntryRipple
                    rippleColor: Qt.rgba(1, 1, 1, 0.42)
                    clipRadius: root._radius
                }

                QGCMouseArea {
                    id:           rotateEntryMouseArea
                    anchors.fill: parent
                    enabled:      parent.enabled
                    cursorShape:  enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: function(mouse) {
                        rotateEntryRipple.tap(mouse.x, mouse.y)
                        if (root.surveyItem) {
                            root.surveyItem.rotateEntryPoint()
                        }
                    }
                }
            }

            QGCLabel {
                Layout.fillWidth:   true
                Layout.topMargin:   ScreenTools.defaultFontPixelHeight * 0.1
                text:               qsTr("Adjust direction, spacing, turnaround, and the survey entry point.")
                color:              root._hintColor
                font.pointSize:     ScreenTools.smallFontPointSize
                wrapMode:           Text.WordWrap
                visible:            root._showGridAngle && root.sprayPatternExpanded
            }

            Rectangle {
                id:                     takeoffHeader
                Layout.fillWidth:       true
                Layout.topMargin:       ScreenTools.defaultFontPixelHeight * 0.25
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.15
                visible:                root.takeoffItem !== null
                radius:                 root._radius
                readonly property bool highlighted: root.missionExpanded
                                                    || missionHeaderMouseArea.containsMouse
                                                    || missionHeaderMouseArea.pressed
                color:                  highlighted ? root._accentGreen : "#ffffff"
                border.width:           1
                border.color:           highlighted ? root._accentGreen : root._cardBorderIdle

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                RowLayout {
                    anchors.fill:        parent
                    anchors.leftMargin:  root._pad * 0.75
                    anchors.rightMargin: root._pad * 0.75

                    QGCLabel {
                        Layout.fillWidth: true
                        text:             qsTr("Take Off")
                        color:            takeoffHeader.highlighted ? "#ffffff" : root._titleColor
                        font.weight:      Font.Medium
                        font.pointSize:   ScreenTools.defaultFontPointSize
                    }

                    QGCColoredImage {
                        Layout.alignment:       Qt.AlignVCenter
                        Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 0.65
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.65
                        source:                 "/res/DropArrow.svg"
                        color:                  takeoffHeader.highlighted ? "#ffffff" : root._bodyColor
                        rotation:               root.missionExpanded ? 180 : 0

                        Behavior on rotation {
                            NumberAnimation { duration: 160 }
                        }
                    }
                }

                RippleEffect {
                    id: missionHeaderRipple
                    rippleColor: takeoffHeader.highlighted
                                 ? Qt.rgba(1, 1, 1, 0.40)
                                 : Qt.rgba(0, 0, 0, 0.14)
                    clipRadius: root._radius
                }

                QGCMouseArea {
                    id:           missionHeaderMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        missionHeaderRipple.tap(mouse.x, mouse.y)
                        root.missionExpanded = !root.missionExpanded
                    }
                }
            }

            // Mission settings operate on the takeoff item, not on the survey.
            GridLayout {
                Layout.fillWidth:   true
                columns:            2
                columnSpacing:      root._pad * 0.5
                rowSpacing:         root._pad * 0.5
                visible:            root.missionExpanded && root._missionAltitudeAvailable

                QGCLabel {
                    text:  qsTr("Altitude")
                    color: root._bodyColor
                }

                AltitudeFactTextField {
                    fact:               root._missionAltitudeFact
                    altitudeMode:       root.takeoffItem
                                        ? root.takeoffItem.altitudeMode
                                        : QGroundControl.AltitudeModeNone
                    Layout.fillWidth:   true
                    enabled:            root._missionAltitudeAvailable
                    activeFocusBorderColor: root._accentGreen
                    persistentBorder:       false
                    fieldBorderWidth:       root.thinFieldBorders ? 1 : 2
                    fieldTextColor:         "#3f3f3f"
                    fieldBackgroundColor:   "white"
                    onUpdated: {
                        if (root._missionAltitudeFact) {
                            var alt = Number(root._missionAltitudeFact.value)
                            if (!isNaN(alt)) {
                                missionAltitudeSlider.value = alt
                            }
                        }
                    }
                }

                QGCSlider {
                    id:                     missionAltitudeSlider
                    from:                   1
                    to:                     500
                    stepSize:               1
                    Layout.fillWidth:       true
                    Layout.columnSpan:      2
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.5
                    enabled:                root._missionAltitudeAvailable
                    activeColor:            root._accentGreen
                    barHeight:              Math.max(1, ScreenTools.defaultFontPixelHeight * 0.12)
                    live:                   true
                    Binding {
                        target:   missionAltitudeSlider
                        property: "value"
                        value:    root._missionAltitudeFact
                                  ? Number(root._missionAltitudeFact.value)
                                  : missionAltitudeSlider.from
                        when:     !missionAltitudeSlider.pressed
                    }
                    onMoved:                missionAltitudeWriteTimer.restart()
                    onPressedChanged: {
                        if (!pressed) {
                            missionAltitudeWriteTimer.stop()
                            root._commitMissionAltitude(value)
                        }
                    }
                }
            }

            QGCLabel {
                Layout.fillWidth:   true
                Layout.topMargin:   ScreenTools.defaultFontPixelHeight * 0.1
                text:               qsTr("Takeoff altitude only. Survey Pattern altitude is separate — if Mission is higher than Survey, the vehicle will descend into the pattern after takeoff.")
                color:              root._hintColor
                font.pointSize:     ScreenTools.smallFontPointSize
                wrapMode:           Text.WordWrap
                visible:            root.missionExpanded && root._missionAltitudeAvailable
            }

            QGCLabel {
                Layout.fillWidth: true
                Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.45
                text:             qsTr("Resume exact")
                color:            root._titleColor
                visible:          root.showSpraySettings && root._misResumeExactFact !== null
            }

            RowLayout {
                Layout.fillWidth: true
                spacing:          0
                visible:          root.showSpraySettings && root._misResumeExactFact !== null

                Repeater {
                    model: [
                        { label: qsTr("Enable"),  enabledValue: true  },
                        { label: qsTr("Disabled"), enabledValue: false }
                    ]

                    Rectangle {
                        Layout.fillWidth:       true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.15
                        color:                  (root._misResumeExactEnabled === modelData.enabledValue)
                                                ? root._accentGreen : "#ffffff"
                        border.width:           1
                        border.color:           (root._misResumeExactEnabled === modelData.enabledValue)
                                                ? root._accentGreen : root._cardBorderIdle
                        radius:                 root._radius

                        QGCLabel {
                            anchors.centerIn: parent
                            text:             modelData.label
                            color:            (root._misResumeExactEnabled === modelData.enabledValue)
                                              ? "#ffffff" : root._bodyColor
                            font.weight:      Font.Medium
                        }

                        RippleEffect {
                            id: resumeExactRipple
                            rippleColor: (root._misResumeExactEnabled === modelData.enabledValue)
                                         ? Qt.rgba(1, 1, 1, 0.40)
                                         : Qt.rgba(0, 0, 0, 0.14)
                            clipRadius: root._radius
                        }

                        QGCMouseArea {
                            anchors.fill: parent
                            cursorShape:  Qt.PointingHandCursor
                            onClicked: function(mouse) {
                                resumeExactRipple.tap(mouse.x, mouse.y)
                                root._setEnableDisableFact(root._misResumeExactFact, modelData.enabledValue)
                            }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: root.surveyItem ? root.surveyItem.gridAngle : null
        ignoreUnknownSignals: true
        function onValueChanged() {
            if (root.surveyItem && root.surveyItem.gridAngle) {
                gridAngleSlider.value = root.surveyItem.gridAngle.value
            }
        }
    }

    Connections {
        target: root._patternAltitudeFact
        ignoreUnknownSignals: true
        function onValueChanged() {
            root._syncPatternAltitudeSlider()
        }
    }

    Connections {
        target: root._patternSpeedFact
        ignoreUnknownSignals: true
        function onValueChanged() {
            root._syncPatternSpeedSlider()
        }
    }

    Connections {
        target: root._missionAltitudeFact
        ignoreUnknownSignals: true
        function onValueChanged() {
            root._syncMissionAltitudeSlider()
        }
    }

    Connections {
        target: root._activeVehicle ? root._activeVehicle.parameterManager : null
        ignoreUnknownSignals: true
        function onParametersReadyChanged(parametersReady) {
            root._refreshSprayFacts()
        }
    }

    Connections {
        target: QGroundControl.multiVehicleManager
        function onActiveVehicleChanged(activeVehicle) {
            root._reloadSprayParamController()
        }
    }

    onShowSpraySettingsChanged: root._reloadSprayParamController()
    on_ParamsReadyChanged: root._refreshSprayFacts()

    onSurveyItemChanged: {
        root.syncResolutionFromSurvey()
        if (root.surveyItem && root.surveyItem.gridAngle) {
            gridAngleSlider.value = root.surveyItem.gridAngle.value
        }
        root._syncPatternAltitudeSlider()
        root._syncPatternSpeedSlider()
    }

    onTakeoffItemChanged: {
        root._syncMissionAltitudeSlider()
    }
}
