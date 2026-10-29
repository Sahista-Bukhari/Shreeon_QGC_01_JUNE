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
    property int resolution: -1   // -1 = Custom/unselected, 0 = Low, 1 = High
    readonly property bool _resolutionPresetSelected: resolution === 0 || resolution === 1
    // High Resolution flies lower for denser GSD; Low Resolution flies higher.
    // Both presets share the same pattern flight speed.
    readonly property real _highResolutionAltitudeMeters: 30
    readonly property real _lowResolutionAltitudeMeters: 60
    readonly property real _highResolutionTriggerDistanceMeters: 6
    readonly property real _lowResolutionTriggerDistanceMeters: 9
    readonly property real _resolutionPresetSpeedMetersPerSecond: 5
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
    // Fly View reuses this panel for the agriculture parameters only. The
    // route-mode chooser remains owned by the mission editor.
    property bool showRouteModeSettings: true
    // Mission geometry cannot safely be changed while a mission is running.
    // Vehicle sprayer and resume parameters remain available independently.
    property bool missionSettingsEnabled: true
    // Vehicle SPRAY_* / nozzle controls are Agriculture Spraying only.
    property bool showSpraySettings: false
    property bool spraySettingsExpanded: true
    property string cameraTriggerConfigurationError: ""
    // Route Mapping must finish its vertical takeoff before starting the
    // horizontal transit. Matching the takeoff and survey heights prevents the
    // first transit leg from becoming a gradual climb or descent.
    property bool synchronizeTakeoffAltitudeWithPattern: false
    // When set (e.g. "AgricultureSpraying"), altitude/speed commits log to the console.
    property string consoleLogTag: ""

    function _logPlanTelemetry(label, value, unit) {
        if (root.consoleLogTag === "")
            return
        console.info("[" + root.consoleLogTag + "] Plan " + label + " (" + unit + "):", value)
    }

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
    // Agriculture Spraying plans start with their payload enabled. The Fly View
    // confirmation popup can turn it off before the route is flown.
    property bool _planSprayEnabledDraft: true
    property real _planSprayNozzleRateDraft: NaN
    property real _planSprayPumpRateDraft: NaN
    readonly property bool planSprayEnabled: _planSprayEnabledDraft
    readonly property real planSprayNozzleRate: _planSprayNozzleRateDraft
    readonly property real planSprayPumpRate: _planSprayPumpRateDraft
    readonly property bool _sprayEnabled: root.showSpraySettings
                                          ? root._planSprayEnabledDraft
                                          : (_sprayEnFact !== null && Number(_sprayEnFact.value) !== 0)
    readonly property bool _misResumeExactEnabled: _misResumeExactFact !== null && Number(_misResumeExactFact.value) !== 0

    // Recreate with the current active vehicle (controller captures vehicle at construct time).
    Loader {
        id: paramControllerLoader
        active: root.showSpraySettings || root.showPhotoSettings
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

    // A Route Mapping preset is an AGL/relative-height contract only while the
    // survey uses the normal relative-altitude frame. Terrain-following and
    // absolute-altitude surveys own a different vertical profile and must not
    // have their takeoff item rewritten from DistanceToSurface.
    readonly property bool _takeoffFollowsPattern: synchronizeTakeoffAltitudeWithPattern
                                                   && _cameraCalc
                                                   && _cameraCalc.distanceMode === QGroundControl.AltitudeModeRelative

    // Mission altitude is bound directly to the takeoff item. Route Mapping can
    // opt into synchronizing it with the survey altitude.
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
        // A selected resolution preset owns the survey altitude. This guard
        // also prevents a delayed slider/Save flush from overwriting it.
        if (root._resolutionPresetSelected || !root._patternAltitudeFact || !root._cameraCalc) {
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
        root._syncTakeoffAltitudeToPattern()
        root._logPlanTelemetry("pattern altitude", alt, "m")
    }

    function _commitPatternSpeed(speedValue) {
        // A selected resolution preset owns the pattern speed (5 m/s).
        if (root._resolutionPresetSelected || !root._patternSpeedFact || !root.surveyItem) {
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
        root._logPlanTelemetry("pattern speed", speed, "m/s")
    }

    function _commitMissionAltitude(altitudeValue) {
        if (!root._missionAltitudeFact) {
            return
        }
        var alt = Number(altitudeValue)
        if (isNaN(alt)) {
            return
        }
        if (root._takeoffFollowsPattern && root._patternAltitudeFact) {
            alt = Number(root._patternAltitudeFact.rawValue)
            root._missionAltitudeFact.rawValue = alt
        } else {
            root._missionAltitudeFact.value = alt
        }
        root._logPlanTelemetry("mission/takeoff altitude", alt, "m")
    }

    function _syncTakeoffAltitudeToPattern() {
        if (!root._takeoffFollowsPattern
                || !root._missionAltitudeFact || !root._patternAltitudeFact) {
            return
        }

        var patternAltitudeMeters = Number(root._patternAltitudeFact.rawValue)
        if (!isFinite(patternAltitudeMeters)) {
            return
        }
        var takeoffAltitudeMeters = Number(root._missionAltitudeFact.rawValue)
        if (!isFinite(takeoffAltitudeMeters)
                || Math.abs(takeoffAltitudeMeters - patternAltitudeMeters) > 0.01) {
            root._missionAltitudeFact.rawValue = patternAltitudeMeters
            root._logPlanTelemetry("synchronized takeoff altitude", patternAltitudeMeters, "m")
        }
        root._syncMissionAltitudeSlider()
    }

    // Upload-time invariant for ordinary (non-terrain) Route Mapping: the
    // NAV_TAKEOFF target and every generated survey coordinate must use the
    // same relative altitude. This catches a missing/stale Fact binding before
    // a mismatched mission can reach the flight controller.
    function altitudeProfileReadyForUpload() {
        if (!root._takeoffFollowsPattern) {
            return true
        }
        if (!root._missionAltitudeFact || !root._patternAltitudeFact) {
            return false
        }

        root._syncTakeoffAltitudeToPattern()
        var takeoffAltitudeMeters = Number(root._missionAltitudeFact.rawValue)
        var patternAltitudeMeters = Number(root._patternAltitudeFact.rawValue)
        return isFinite(takeoffAltitudeMeters)
                && isFinite(patternAltitudeMeters)
                && Math.abs(takeoffAltitudeMeters - patternAltitudeMeters) <= 0.01
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
        if (root.showSpraySettings) {
            if (!isFinite(root._planSprayNozzleRateDraft)) {
                root._initializeSprayerPlanDraftFromFacts()
            }
        }
    }

    function _reloadParamController() {
        paramControllerLoader.active = false
        paramControllerLoader.active = root.showSpraySettings || root.showPhotoSettings
    }

    // Route Mapping depends on PX4's distance-trigger survey mode to emit the
    // native CAMERA_TRIGGER events consumed by Fly View. Configure only the
    // PX4 parameters which select that mode and MAVLink interface; the mission
    // itself supplies the selected 6 m / 9 m trigger distance.
    function configureRouteMappingCameraTriggerParameters() {
        root.cameraTriggerConfigurationError = ""
        if (!root.showPhotoSettings) {
            return true
        }
        if (!root._activeVehicle) {
            root.cameraTriggerConfigurationError = qsTr("Connect the vehicle before uploading the Route Mapping mission.")
            return false
        }
        if (!root._activeVehicle.px4Firmware) {
            // TRIG_MODE and TRIG_INTERFACE are PX4-specific. Other firmware
            // families continue to use their normal mission-command handling.
            return true
        }
        if (!root._paramsReady || !paramControllerLoader.item) {
            root.cameraTriggerConfigurationError = qsTr("Vehicle parameters are still loading. Wait for parameter download to finish, then upload again.")
            return false
        }

        var controller = paramControllerLoader.item
        if (!controller.parameterExists(-1, "TRIG_MODE")
                || !controller.parameterExists(-1, "TRIG_INTERFACE")) {
            root.cameraTriggerConfigurationError = qsTr("This PX4 vehicle does not provide the required TRIG_MODE and TRIG_INTERFACE camera-trigger parameters.")
            return false
        }

        var triggerModeFact = controller.getParameterFact(-1, "TRIG_MODE", false)
        var triggerInterfaceFact = controller.getParameterFact(-1, "TRIG_INTERFACE", false)
        if (!triggerModeFact || !triggerInterfaceFact) {
            root.cameraTriggerConfigurationError = qsTr("QGC could not access the PX4 camera-trigger parameters. Refresh vehicle parameters and try again.")
            return false
        }

        // Select the output interface before enabling the trigger mode so a
        // previously configured PWM/GPIO interface is never activated first.
        if (Number(triggerInterfaceFact.rawValue) !== 3) {
            triggerInterfaceFact.rawValue = 3
        }
        if (Number(triggerModeFact.rawValue) !== 4) {
            triggerModeFact.rawValue = 4
        }
        console.info("[RouteMapping] Camera trigger parameters enabled: TRIG_MODE=4, TRIG_INTERFACE=3")
        return true
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
        if (root.showSpraySettings) {
            root._planSprayEnabledDraft = enabled
            if (enabled && paramControllerLoader.item) {
                paramControllerLoader.item.getMissingParameters([
                                                                    "SPRAY_NOZ_RATE",
                                                                    "SPRAY_PUMP_RATE",
                                                                    "MIS_RESUME_EXACT"
                                                                ])
                sprayFactRefreshTimer.restart()
            }
            return
        }

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

    function loadSprayerPlanDraft(enabled, nozzleRate, pumpRate) {
        root._planSprayEnabledDraft = enabled
        var nozzle = Number(nozzleRate)
        var pump = Number(pumpRate)
        root._planSprayNozzleRateDraft = isFinite(nozzle) ? nozzle : NaN
        root._planSprayPumpRateDraft = isFinite(pump) ? pump : NaN
    }

    function resetSprayerPlanDraft() {
        root._planSprayEnabledDraft = root.showSpraySettings
        root._initializeSprayerPlanDraftFromFacts()
    }

    function _initializeSprayerPlanDraftFromFacts() {
        var nozzle = root._sprayNozRateFact ? Number(root._sprayNozRateFact.value) : NaN
        var pump = root._sprayPumpRateFact ? Number(root._sprayPumpRateFact.value) : NaN
        root._planSprayNozzleRateDraft = isFinite(nozzle) ? nozzle : NaN
        root._planSprayPumpRateDraft = isFinite(pump) ? pump : NaN
    }

    function _isNozzleRateFact(fact) {
        return fact && root._sprayNozRateFact && fact === root._sprayNozRateFact
    }

    function _isPumpRateFact(fact) {
        return fact && root._sprayPumpRateFact && fact === root._sprayPumpRateFact
    }

    function _planRateDraftValue(fact) {
        if (root._isNozzleRateFact(fact)) {
            return root._planSprayNozzleRateDraft
        }
        if (root._isPumpRateFact(fact)) {
            return root._planSprayPumpRateDraft
        }
        return NaN
    }

    function _setPlanRateDraftValue(fact, value) {
        var rounded = Math.round(Number(value) * 1000) / 1000
        if (root._isNozzleRateFact(fact)) {
            root._planSprayNozzleRateDraft = rounded
        } else if (root._isPumpRateFact(fact)) {
            root._planSprayPumpRateDraft = rounded
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
        if (!fact || !root._sprayEnabled) {
            return
        }
        var step = root._rateFactStep(fact)
        var minV = root._rateFactMin(fact)
        var maxV = root._rateFactMax(fact)
        var current = root.showSpraySettings
                ? root._planRateDraftValue(fact)
                : Number(fact.value)
        if (isNaN(current)) {
            current = minV
        }
        var next = Math.max(minV, Math.min(maxV, current + (direction * step)))
        next = Math.round(next * 1000) / 1000
        if (root.showSpraySettings) {
            root._setPlanRateDraftValue(fact, next)
            return
        }
        fact.value = next
    }

    function _commitRateFactFromSlider(fact, value) {
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
        if (root.showSpraySettings) {
            var currentDraft = root._planRateDraftValue(fact)
            if (isFinite(currentDraft) && Math.abs(currentDraft - rounded) < 0.0005) {
                return
            }
            root._setPlanRateDraftValue(fact, rounded)
            return
        }
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

    // Low/High own survey altitude, camera trigger distance, and pattern speed.
    // AdjustedFootprintFrontal is emitted as MAV_CMD_DO_SET_CAM_TRIGG_DIST when
    // the mission is built.
    function applyResolutionPreset() {
        if (!root._resolutionPresetSelected || !root._cameraCalc || !root.surveyItem) {
            return
        }
        var high = root.resolution === 1
        var altitudeMeters = high ? root._highResolutionAltitudeMeters
                                  : root._lowResolutionAltitudeMeters
        var triggerDistanceMeters = high ? root._highResolutionTriggerDistanceMeters
                                         : root._lowResolutionTriggerDistanceMeters
        var speedMetersPerSecond = root._resolutionPresetSpeedMetersPerSecond

        // A pending slider write must not restore the value that preceded the
        // preset. rawValue is intentional: these presets are defined in SI
        // mission units, independent of the user's display-unit preference.
        patternAltitudeWriteTimer.stop()
        patternSpeedWriteTimer.stop()

        if (root._cameraCalc.valueSetIsDistance) {
            root._cameraCalc.valueSetIsDistance.rawValue = true
        }
        if (root._patternAltitudeFact) {
            root._patternAltitudeFact.rawValue = altitudeMeters
        }
        root._syncTakeoffAltitudeToPattern()
        if (root._patternSpeedFact) {
            root._patternSpeedFact.rawValue = speedMetersPerSecond
            // QGC generates MAV_CMD_DO_CHANGE_SPEED around the survey only
            // when the pattern-speed override is enabled.
            root.surveyItem.specifyPatternFlightSpeed = true
        }
        if (root._cameraCalc.adjustedFootprintFrontal) {
            // Set this after altitude: known-camera altitude recalculation also
            // updates the footprint, and the explicit preset distance must win.
            root._cameraCalc.adjustedFootprintFrontal.rawValue = triggerDistanceMeters
        }

        root._syncPatternAltitudeSlider()
        root._syncPatternSpeedSlider()
        console.info("[RouteMapping] Resolution preset applied:",
                     high ? "High" : "Low",
                     "| planned altitude:", altitudeMeters, "m",
                     "| trigger distance:", triggerDistanceMeters, "m",
                     "| speed:", speedMetersPerSecond, "m/s",
                     "| takeoff altitude:",
                     root._missionAltitudeFact
                     ? Number(root._missionAltitudeFact.rawValue) : NaN, "m")
    }

    // A newly completed Route Mapping plan defaults to High Resolution. Keep
    // an explicit Low/High choice made while drawing the route unchanged.
    function selectHighResolutionByDefault() {
        if (root._resolutionPresetSelected) {
            return
        }
        root.resolution = 1
        root.applyResolutionPreset()
    }

    function syncResolutionFromSurvey() {
        if (!root._cameraCalc) {
            root.resolution = -1
            return
        }

        var altitudeMeters = root._patternAltitudeFact
                ? Number(root._patternAltitudeFact.rawValue) : 0
        var triggerDistanceMeters = root._cameraCalc.adjustedFootprintFrontal
                ? Number(root._cameraCalc.adjustedFootprintFrontal.rawValue) : 0
        var speedMetersPerSecond = root._patternSpeedFact
                ? Number(root._patternSpeedFact.rawValue) : 0
        var speedMatches = Math.abs(speedMetersPerSecond - root._resolutionPresetSpeedMetersPerSecond) < 0.01
        var highMatches = Math.abs(altitudeMeters - root._highResolutionAltitudeMeters) < 0.01
                && Math.abs(triggerDistanceMeters - root._highResolutionTriggerDistanceMeters) < 0.01
                && speedMatches
        var lowMatches = Math.abs(altitudeMeters - root._lowResolutionAltitudeMeters) < 0.01
                && Math.abs(triggerDistanceMeters - root._lowResolutionTriggerDistanceMeters) < 0.01
                && speedMatches

        if (highMatches) {
            root.resolution = 1
        } else if (lowMatches) {
            root.resolution = 0
        } else {
            root.resolution = -1
        }
    }

    Component.onCompleted: {
        syncResolutionFromSurvey()
        Qt.callLater(root._syncTakeoffAltitudeToPattern)
        root._refreshSprayFacts()
    }

    // Call from Upload/Save so pending slider drags are not lost.
    // Only commits when a write is pending or the slider differs from the Fact,
    // so an uninitialized slider cannot clobber the real altitude.
    function flushPendingWrites() {
        var patternAltitudePending = patternAltitudeWriteTimer.running
        var patternSpeedPending = patternSpeedWriteTimer.running
        var missionAltitudePending = missionAltitudeWriteTimer.running
        var patternAltitudeDiffers = root._patternAltitudeAvailable
                && isFinite(Number(patternAltitudeSlider.value))
                && isFinite(Number(root._patternAltitudeFact.value))
                && Math.abs(Number(patternAltitudeSlider.value)
                            - Number(root._patternAltitudeFact.value)) > 0.01
        var patternSpeedDiffers = root._patternSpeedAvailable
                && isFinite(Number(patternSpeedSlider.value))
                && isFinite(Number(root._patternSpeedFact.value))
                && Math.abs(Number(patternSpeedSlider.value)
                            - Number(root._patternSpeedFact.value)) > 0.01
        var missionAltitudeDiffers = root._missionAltitudeAvailable
                && isFinite(Number(missionAltitudeSlider.value))
                && isFinite(Number(root._missionAltitudeFact.value))
                && Math.abs(Number(missionAltitudeSlider.value)
                            - Number(root._missionAltitudeFact.value)) > 0.01

        patternAltitudeWriteTimer.stop()
        patternSpeedWriteTimer.stop()
        missionAltitudeWriteTimer.stop()
        nozzleRateWriteTimer.stop()
        pumpRateWriteTimer.stop()

        if (root._patternAltitudeAvailable
                && (patternAltitudePending || patternAltitudeDiffers))
            root._commitPatternAltitude(patternAltitudeSlider.value)
        if (root._patternSpeedAvailable
                && (patternSpeedPending || patternSpeedDiffers))
            root._commitPatternSpeed(patternSpeedSlider.value)
        if (root._missionAltitudeAvailable && !root._takeoffFollowsPattern
                && (missionAltitudePending || missionAltitudeDiffers))
            root._commitMissionAltitude(missionAltitudeSlider.value)
        root._syncTakeoffAltitudeToPattern()
        // Altitude edits can make CameraCalc recalculate its footprint. Re-apply
        // the selected Low/High altitude and capture interval so the preset wins.
        if (root._resolutionPresetSelected)
            root.applyResolutionPreset()
        if (root.showSpraySettings) {
            if (root._sprayNozRateFact !== null) {
                root._commitRateFactFromSlider(root._sprayNozRateFact, nozzleRateSlider.value)
            } else if (isFinite(Number(nozzleRateSlider.value))) {
                root._planSprayNozzleRateDraft = Math.round(Number(nozzleRateSlider.value) * 1000) / 1000
            }
            if (root._sprayPumpRateFact !== null) {
                root._commitRateFactFromSlider(root._sprayPumpRateFact, pumpRateSlider.value)
            } else if (isFinite(Number(pumpRateSlider.value))) {
                root._planSprayPumpRateDraft = Math.round(Number(pumpRateSlider.value) * 1000) / 1000
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
                visible:            root.showRouteModeSettings
            }

            QGCLabel {
                Layout.fillWidth:   true
                Layout.topMargin:   ScreenTools.defaultFontPixelHeight * 0.6
                text:               qsTr("Route Mode")
                color:              root._titleColor
                font.pointSize:     ScreenTools.defaultFontPointSize
                visible:            root.showRouteModeSettings
            }

            Repeater {
                id: boundarrate
                visible: root.showRouteModeSettings
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
                    visible:            root.showRouteModeSettings
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
                            value:    root.showSpraySettings
                                      ? (isFinite(root._planSprayNozzleRateDraft)
                                         ? root._planSprayNozzleRateDraft
                                         : nozzleRateSlider.from)
                                      : (root._sprayNozRateFact
                                         ? Number(root._sprayNozRateFact.value)
                                         : nozzleRateSlider.from)
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
                            value:    root.showSpraySettings
                                      ? (isFinite(root._planSprayPumpRateDraft)
                                         ? root._planSprayPumpRateDraft
                                         : pumpRateSlider.from)
                                      : (root._sprayPumpRateFact
                                         ? Number(root._sprayPumpRateFact.value)
                                         : pumpRateSlider.from)
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
                spacing:            ScreenTools.defaultFontPixelWidth * 0.6
                clip:               true
                visible:            root.showPhotoSettings

                Repeater {
                    model: [qsTr("Low"), qsTr("High")]

                    delegate: Rectangle {
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
                                if (root.resolution === index) {
                                    // Clicking the active preset clears it and
                                    // returns altitude/speed control to the user.
                                    root.resolution = -1
                                    patternAltitudeWriteTimer.stop()
                                    patternSpeedWriteTimer.stop()
                                } else {
                                    root.resolution = index
                                    root.applyResolutionPreset()
                                }
                            }
                        }
                    }
                }
            }

            QGCLabel {
                Layout.fillWidth:   true
                Layout.topMargin:   ScreenTools.defaultFontPixelHeight * 0.15
                text:               root.resolution === 0
                                    ? qsTr("%1 m altitude, photos every %2 m, %3 m/s flight speed. Select Low again to unlock altitude and speed.")
                                      .arg(root._lowResolutionAltitudeMeters)
                                      .arg(root._lowResolutionTriggerDistanceMeters)
                                      .arg(root._resolutionPresetSpeedMetersPerSecond)
                                    : root.resolution === 1
                                      ? qsTr("%1 m altitude, photos every %2 m, %3 m/s flight speed. Select High again to unlock altitude and speed.")
                                        .arg(root._highResolutionAltitudeMeters)
                                        .arg(root._highResolutionTriggerDistanceMeters)
                                        .arg(root._resolutionPresetSpeedMetersPerSecond)
                                      : qsTr("Select a resolution preset to set and lock the route altitude and speed.")
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
                enabled:             root.missionSettingsEnabled
                opacity:             enabled ? 1.0 : 0.55

                QGCLabel {
                    text:       qsTr("Angle")
                    color:      root._bodyColor
                }

                FactTextField {
                    id:                 gridAngleField
                    fact:               root.surveyItem ? root.surveyItem.gridAngle : null
                    Layout.fillWidth:   true
                    enabled:            root._showGridAngle && root.missionSettingsEnabled
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
                    enabled:                root._showGridAngle && root.missionSettingsEnabled
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
                    enabled: root._showGridAngle && root.missionSettingsEnabled
                    activeFocusBorderColor: root._accentGreen
                    persistentBorder:       false
                    fieldBorderWidth:       root.thinFieldBorders ? 1 : 2
                    fieldTextColor:         "#3f3f3f"
                    fieldBackgroundColor:   "white"
                }

                QGCLabel {
                    text:       qsTr("Trigger Dist")
                    color:      root._bodyColor
                    visible:    root.showPhotoSettings
                }

                FactTextField {
                    fact: root._cameraCalc
                          ? root._cameraCalc.adjustedFootprintFrontal
                          : null
                    Layout.fillWidth: true
                    enabled: root._showGridAngle
                             && root.missionSettingsEnabled
                             && !root._resolutionPresetSelected
                    activeFocusBorderColor: root._accentGreen
                    persistentBorder:       false
                    fieldBorderWidth:       root.thinFieldBorders ? 1 : 2
                    fieldTextColor:         "#3f3f3f"
                    fieldBackgroundColor:   "white"
                    visible:                root.showPhotoSettings
                }

                QGCLabel {
                    text:  qsTr("Turnaround")
                    color: root._bodyColor
                }

                FactTextField {
                    fact: root.surveyItem ? root.surveyItem.turnAroundDistance : null
                    Layout.fillWidth: true
                    enabled: root._showGridAngle && root.missionSettingsEnabled
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
                                        && root.missionSettingsEnabled
                                        && !root._resolutionPresetSelected
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
                                            && root.missionSettingsEnabled
                                            && !root._resolutionPresetSelected
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
                                        && root.missionSettingsEnabled
                                        && !root._resolutionPresetSelected
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
                                            && root.missionSettingsEnabled
                                            && !root._resolutionPresetSelected
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
                enabled:                root._surveyPolygonValid && root.missionSettingsEnabled
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
                enabled:            root.missionSettingsEnabled
                opacity:            enabled ? 1.0 : 0.55

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
                                        && root.missionSettingsEnabled
                                        && !root._takeoffFollowsPattern
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
                                            && root.missionSettingsEnabled
                                            && !root._takeoffFollowsPattern
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
                text:               root._takeoffFollowsPattern
                                    ? qsTr("Takeoff altitude follows the Survey Pattern altitude so the vehicle climbs vertically first, then holds that altitude to the first waypoint.")
                                    : qsTr("Takeoff altitude only. Survey Pattern altitude is separate — if Mission is higher than Survey, the vehicle will descend into the pattern after takeoff.")
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
            root._syncTakeoffAltitudeToPattern()
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
        target: root._cameraCalc ? root._cameraCalc.adjustedFootprintFrontal : null
        ignoreUnknownSignals: true
        function onValueChanged() {
            // Known-camera altitude edits recalculate the footprint. Restore
            // the selected Low/High altitude and photo interval afterward.
            if (root._resolutionPresetSelected) {
                Qt.callLater(root.applyResolutionPreset)
            } else {
                root.syncResolutionFromSurvey()
            }
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
            root._reloadParamController()
        }
    }

    onShowSpraySettingsChanged: root._reloadParamController()
    onShowPhotoSettingsChanged: root._reloadParamController()
    on_ParamsReadyChanged: root._refreshSprayFacts()

    onSurveyItemChanged: {
        root.syncResolutionFromSurvey()
        if (root.surveyItem && root.surveyItem.gridAngle) {
            gridAngleSlider.value = root.surveyItem.gridAngle.value
        }
        root._syncPatternAltitudeSlider()
        root._syncPatternSpeedSlider()
        Qt.callLater(root._syncTakeoffAltitudeToPattern)
    }

    onTakeoffItemChanged: {
        root._syncMissionAltitudeSlider()
        Qt.callLater(root._syncTakeoffAltitudeToPattern)
    }
}
