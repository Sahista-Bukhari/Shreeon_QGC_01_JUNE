import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtLocation
import QtPositioning
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap

/// This provides the smarts behind the guided mode commands, minus the user interface. This way you can change UI
/// without affecting the underlying functionality.
Item {
    id: _root

    property var missionController
    property var confirmDialog
    property var guidedValueSlider
    property var fwdFlightGotoMapCircle
    property var orbitMapCircle

    readonly property string emergencyStopTitle:            qsTr("EMERGENCY STOP")
    readonly property string armTitle:                      qsTr("Arm")
    readonly property string mvArmTitle:                    qsTr("Arm (MV)")
    readonly property string forceArmTitle:                 qsTr("Force Arm")
    readonly property string disarmTitle:                   qsTr("Disarm")
    readonly property string mvDisarmTitle:                 qsTr("Disarm (MV)")
    readonly property string rtlTitle:                      qsTr("Return")
    readonly property string takeoffTitle:                  qsTr("Takeoff")
    readonly property string landTitle:                     qsTr("Land")
    readonly property string startMissionTitle:             qsTr("Start Mission")
    readonly property string mvStartMissionTitle:           qsTr("Start Mission (MV)")
    readonly property string continueMissionTitle:          qsTr("Continue Mission")
    readonly property string resumeMissionUploadFailTitle:  qsTr("Resume FAILED")
    readonly property string pauseTitle:                    qsTr("Pause")
    readonly property string mvPauseTitle:                  qsTr("Pause (MV)")
    readonly property string changeAltTitle:                qsTr("Change Altitude")
    readonly property string changeLoiterRadiusTitle:       qsTr("Change Loiter Radius")
    readonly property string changeCruiseSpeedTitle:        qsTr("Change Max Ground Speed")
    readonly property string changeAirspeedTitle:           qsTr("Change Airspeed")
    readonly property string orbitTitle:                    qsTr("Orbit")
    readonly property string landAbortTitle:                qsTr("Land Abort")
    readonly property string setWaypointTitle:              qsTr("Set Waypoint")
    readonly property string gotoTitle:                     qsTr("Go To Location")
    readonly property string roiTitle:                      qsTr("ROI")
    readonly property string setHomeTitle:                  qsTr("Set Home")
    readonly property string setEstimatorOriginTitle:       qsTr("Set Estimator Origin")
    readonly property string setFlightMode:                 qsTr("Set Flight Mode")
    readonly property string changeHeadingTitle:            qsTr("Change Heading")

    readonly property string armMessage:                        qsTr("Arm the vehicle.")
    readonly property string mvArmMessage:                      qsTr("Arm selected vehicles.")
    readonly property string forceArmMessage:                   qsTr("WARNING: This will force arming of the vehicle bypassing any safety checks.")
    readonly property string disarmMessage:                     qsTr("Disarm the vehicle")
    readonly property string mvDisarmMessage:                   qsTr("Disarm selected vehicles.")
    readonly property string emergencyStopMessage:              qsTr("WARNING: THIS WILL STOP ALL MOTORS. IF VEHICLE IS CURRENTLY IN THE AIR IT WILL CRASH.")
    readonly property string takeoffMessage:                    qsTr("Takeoff and hold position")
    readonly property string startMissionMessage:               qsTr("Takeoff and start the current mission")
    readonly property string mvStartMissionMessage:             qsTr("Takeoff and start the current mission for selected vehicles")
    readonly property string continueMissionMessage:            qsTr("Continue the mission from the current waypoint")
    readonly property string resumeMissionUploadFailMessage:    qsTr("Upload of resume mission failed. Confirm to retry upload")
    readonly property string landMessage:                       qsTr("Land the vehicle at the current position")
    readonly property string rtlMessage:                        qsTr("Return to the launch position of the vehicle")
    readonly property string changeAltMessage:                  qsTr("Change the altitude of the vehicle up or down")
    readonly property string changeLoiterRadiusMessage:         qsTr("Change the forward flight loiter radius")
    readonly property string changeCruiseSpeedMessage:          qsTr("Change the maximum horizontal cruise speed")
    readonly property string changeAirspeedMessage:             qsTr("Change the equivalent airspeed setpoint")
    readonly property string gotoMessage:                       qsTr("Move the vehicle to the specified location")
             property string setWaypointMessage:                qsTr("Adjust current waypoint to %1").arg(_actionData)
    readonly property string orbitMessage:                      qsTr("Orbit the vehicle around the specified location")
    readonly property string landAbortMessage:                  qsTr("Abort the landing sequence")
    readonly property string pauseMessage:                      qsTr("Pause at current position")
    readonly property string mvPauseMessage:                    qsTr("Pause selected vehicles at their current position")
    readonly property string roiMessage:                        qsTr("Make the specified location a Region Of Interest")
    readonly property string setHomeMessage:                    qsTr("Set vehicle home as the specified location. This will affect Return to Home position")
    readonly property string setEstimatorOriginMessage:         qsTr("Make the specified location the estimator origin")
    readonly property string setFlightModeMessage:              qsTr("Set the vehicle flight mode to %1").arg(_actionData)
    readonly property string changeHeadingMessage:              qsTr("Set the vehicle heading towards the specified location")

    readonly property int actionRTL:                        1
    readonly property int actionLand:                       2
    readonly property int actionTakeoff:                    3
    readonly property int actionArm:                        4
    readonly property int actionDisarm:                     5
    readonly property int actionEmergencyStop:              6
    readonly property int actionChangeAlt:                  7
    readonly property int actionGoto:                       8
    readonly property int actionSetWaypoint:                9
    readonly property int actionOrbit:                      10
    readonly property int actionLandAbort:                  11
    readonly property int actionStartMission:               12
    readonly property int actionContinueMission:            13
    readonly property int actionResumeMission:              14
    readonly property int _actionUnused:                    15
    readonly property int actionResumeMissionUploadFail:    16
    readonly property int actionPause:                      17
    readonly property int actionMVPause:                    18
    readonly property int actionMVStartMission:             19
    readonly property int actionROI:                        20
    readonly property int actionForceArm:                   21
    readonly property int actionChangeSpeed:                22
    readonly property int actionSetHome:                    24
    readonly property int actionSetEstimatorOrigin:         25
    readonly property int actionSetFlightMode:              26
    readonly property int actionChangeHeading:              27
    readonly property int actionMVArm:                      28
    readonly property int actionMVDisarm:                   29
    readonly property int actionChangeLoiterRadius:         30

    readonly property int customActionStart:                10000 // Custom actions ids should start here so that they don't collide with the built in actions

    property var    _activeVehicle:             QGroundControl.multiVehicleManager.activeVehicle
    property var    _flyViewSettings:           QGroundControl.settingsManager.flyViewSettings
    property var    _unitsConversion:           QGroundControl.unitsConversion
    property bool   _useChecklist:              QGroundControl.settingsManager.appSettings.useChecklist.rawValue && QGroundControl.corePlugin.options.preFlightChecklistUrl.toString().length
    property bool   _enforceChecklist:          _useChecklist && QGroundControl.settingsManager.appSettings.enforceChecklist.rawValue
    property bool   _checklistPassed:           _activeVehicle ? (_useChecklist ? (_enforceChecklist ? _activeVehicle.checkListState === Vehicle.CheckListPassed : true) : true) : true
    property bool   _canArm:                    _activeVehicle ? (_checklistPassed && (!_activeVehicle.healthAndArmingCheckReport.supported || _activeVehicle.healthAndArmingCheckReport.canArm)) : false
    property bool   _canTakeoff:                _activeVehicle ? (_checklistPassed && (!_activeVehicle.healthAndArmingCheckReport.supported || _activeVehicle.healthAndArmingCheckReport.canTakeoff)) : false
    property bool   _canStartMission:           _activeVehicle ? (_checklistPassed && (!_activeVehicle.healthAndArmingCheckReport.supported || _activeVehicle.healthAndArmingCheckReport.canStartMission)) : false
    property bool   _initialConnectComplete:    _activeVehicle ? _activeVehicle.initialConnectComplete : false

    property bool showEmergenyStop:         _guidedActionsEnabled && !_hideEmergenyStop && _vehicleArmed && _vehicleFlying
    property bool showArm:                  _guidedActionsEnabled && !_vehicleArmed && _canArm
    property bool showForceArm:             _guidedActionsEnabled && !_vehicleArmed
    property bool showDisarm:               _guidedActionsEnabled && _vehicleArmed && !_vehicleFlying
    property bool showRTL:                  _guidedActionsEnabled && _vehicleArmed && _activeVehicle.guidedModeSupported && _vehicleFlying && !_vehicleInRTLMode
    property bool showTakeoff:              _guidedActionsEnabled && _activeVehicle.takeoffVehicleSupported && !_vehicleFlying && _canTakeoff
    property bool showLand:                 _guidedActionsEnabled && _activeVehicle.guidedModeSupported && _vehicleArmed && !_activeVehicle.fixedWing && !_vehicleInLandMode
    property bool showStartMission:         _guidedActionsEnabled && _missionAvailable && !_missionActive && !_vehicleFlying && _canStartMission
    property bool showContinueMission:      _guidedActionsEnabled && _missionAvailable && !_missionActive && _vehicleArmed && _vehicleFlying && (_currentMissionIndex < _missionItemCount - 1)
    property bool showPause:                _guidedActionsEnabled && _vehicleArmed && _activeVehicle.pauseVehicleSupported && _vehicleFlying && !_vehiclePaused && !_fixedWingOnApproach
    property bool showChangeAlt:            _guidedActionsEnabled && _vehicleFlying && _activeVehicle.guidedModeSupported && _vehicleArmed
    property bool showChangeLoiterRadius:   _guidedActionsEnabled && _vehicleFlying && _activeVehicle.guidedModeSupported && _vehicleArmed && !_missionActive && _vehicleInFwdFlight && fwdFlightGotoMapCircle.visible
    property bool showChangeSpeed:          _guidedActionsEnabled && _vehicleFlying && _activeVehicle.guidedModeSupported && _vehicleArmed && _speedLimitsAvailable
    property bool showOrbit:                _guidedActionsEnabled && _vehicleFlying && __orbitSupported && !_missionActive && _activeVehicle.homePosition.isValid && !isNaN(_activeVehicle.homePosition.altitude)
    property bool showROI:                  _guidedActionsEnabled && _vehicleFlying && __roiSupported
    property bool showLandAbort:            _guidedActionsEnabled && _vehicleFlying && _fixedWingOnApproach
    property bool showGotoLocation:         _guidedActionsEnabled && _vehicleFlying
    property bool showSetHome:              _guidedActionsEnabled
    property bool showSetEstimatorOrigin:   _activeVehicle && !(_activeVehicle.sensorsPresentBits & Vehicle.SysStatusSensorGPS)
    property bool showChangeHeading:        _guidedActionsEnabled && _vehicleFlying

    property string changeSpeedTitle:   _vehicleInFwdFlight ? changeAirspeedTitle : changeCruiseSpeedTitle
    property string changeSpeedMessage: _vehicleInFwdFlight ? changeAirspeedMessage : changeCruiseSpeedMessage

    // Note: The '_missionItemCount - 2' is a hack to not trigger resume mission when a mission ends with an RTL item
    property bool showResumeMission:    _activeVehicle && !_vehicleArmed && _vehicleWasFlying && _missionAvailable && _resumeMissionIndex > 0 && (_resumeMissionIndex < _missionItemCount - 2)

    property bool guidedUIVisible:          confirmDialog.visible

    property var    _corePlugin:            QGroundControl.corePlugin
    property var    _corePluginOptions:     QGroundControl.corePlugin.options
    property bool   _guidedActionsEnabled:  (!ScreenTools.isDebug && _corePluginOptions.guidedActionsRequireRCRSSI && _activeVehicle) ? _rcRSSIAvailable : _activeVehicle
    property string _flightMode:            _activeVehicle ? _activeVehicle.flightMode : ""
    property bool   _missionAvailable:      missionController.containsItems
    property bool   _missionActive:         _activeVehicle ? _vehicleArmed && (_vehicleInLandMode || _vehicleInRTLMode || _vehicleInMissionMode) : false
    property bool   _vehicleArmed:          _activeVehicle ? _activeVehicle.armed  : false
    property bool   _vehicleFlying:         _activeVehicle ? _activeVehicle.flying  : false
    property bool   _vehicleLanding:        _activeVehicle ? _activeVehicle.landing  : false
    property bool   _vehiclePaused:         false
    property bool   _vehicleInMissionMode:  false
    property bool   _vehicleInRTLMode:      false
    property bool   _vehicleInLandMode:     false
    property int    _missionItemCount:      missionController.missionItemCount
    property int    _currentMissionIndex:   missionController.currentMissionIndex
    property int    _resumeMissionIndex:    missionController.resumeMissionIndex
    property bool   _hideEmergenyStop:      !_corePluginOptions.flyView.guidedBarShowEmergencyStop
    property bool   _hideOrbit:             !_corePluginOptions.flyView.guidedBarShowOrbit
    property bool   _hideROI:               !_corePluginOptions.flyView.guidedBarShowROI
    property bool   _vehicleWasFlying:      false
    property bool   _rcRSSIAvailable:       _activeVehicle ? _activeVehicle.rcRSSI > 0 && _activeVehicle.rcRSSI <= 100 : false
    property bool   _fixedWingOnApproach:   _activeVehicle ? _activeVehicle.fixedWing && _vehicleLanding : false
    property bool   _vehicleInFwdFlight:    _activeVehicle ? _activeVehicle.inFwdFlight : false
    property bool  _speedLimitsAvailable:   _activeVehicle && ((_vehicleInFwdFlight && _activeVehicle.haveFWSpeedLimits) || (!_vehicleInFwdFlight && _activeVehicle.haveMRSpeedLimits))

    // You can turn on log output for GuidedActionsController by turning on GuidedActionsControllerLog category
    property bool __guidedModeSupported:    _activeVehicle ? _activeVehicle.guidedModeSupported : false
    property bool __pauseVehicleSupported:  _activeVehicle ? _activeVehicle.pauseVehicleSupported : false
    property bool __roiSupported:           _activeVehicle ? !_hideROI && _activeVehicle.roiModeSupported : false
    property bool __orbitSupported:         _activeVehicle ? !_hideOrbit && _activeVehicle.orbitModeSupported : false
    property bool __flightMode:             _flightMode
    property real commandedAltitudeMeters:  NaN
    property real commandedSpeedMetersSecond: NaN
    // Persistent cruise speed set by the pilot via Change Speed. Kept for the whole flight
    // so mid-mission altitude resume can restore it after Mission mode reloads plan speed.
    property real _userCruiseSpeedMetersSecond: NaN
    // When Change Altitude exits Mission→Hold, showContinueMission becomes true and
    // (by default) auto-opens Continue Mission. Confirming that resumes the plan and
    // immediately flies the old mission altitudes again. Suppress that popup temporarily.
    property bool _suppressAutoContinueMission: false
    property bool _pendingAltMissionResume: false
    property int  _pendingAltResumeIndex: -1
    property int  _pendingAltResumeFromIndex: -1
    property real _pendingAltResumeSpeed: NaN
    property real _pendingAltTargetMeters: NaN
    property int  _pendingAltPollCount: 0
    property int  _restoreSpeedRetryCount: 0
    property int  _pendingAltStartSequence: -1
    property int  _pendingAltStartPollCount: 0
    property real _pendingAltStartSpeed: NaN
    property bool _pendingAltStartWriteOk: true

    // Allow custom builds to add custom actions by overriding CustomGuidedActionsController.qml
    CustomGuidedActionsController {
        id: customController
    }
    property var _customController: customController

    function _isGuidedActionsControllerLogEnabled() {
        return QGroundControl.categoryLoggingOn("GuidedActionsControllerLog")
    }

    function _outputState() {
        if (_isGuidedActionsControllerLogEnabled()) {
            console.log(qsTr("_activeVehicle(%1) _vehicleArmed(%2) guidedModeSupported(%3) _vehicleFlying(%4) _vehicleWasFlying(%5) _vehicleInRTLMode(%6) pauseVehicleSupported(%7) _vehiclePaused(%8) _flightMode(%9) _missionItemCount(%10) roiSupported(%11) orbitSupported(%12) _missionActive(%13) _hideROI(%14) _hideOrbit(%15)").arg(_activeVehicle ? 1 : 0).arg(_vehicleArmed ? 1 : 0).arg(__guidedModeSupported ? 1 : 0).arg(_vehicleFlying ? 1 : 0).arg(_vehicleWasFlying ? 1 : 0).arg(_vehicleInRTLMode ? 1 : 0).arg(__pauseVehicleSupported ? 1 : 0).arg(_vehiclePaused ? 1 : 0).arg(_flightMode).arg(_missionItemCount).arg(__roiSupported).arg(__orbitSupported).arg(_missionActive).arg(_hideROI).arg(_hideOrbit))
        }
    }

    function setupSlider(actionCode) {
        if (actionCode === actionTakeoff) {
            guidedValueSlider.setupSlider(
                GuidedValueSlider.SliderType.Takeoff,
                _unitsConversion.metersToAppSettingsVerticalDistanceUnits(_activeVehicle.minimumTakeoffAltitudeMeters()),
                _flyViewSettings.guidedMaximumAltitude.value,
                _unitsConversion.metersToAppSettingsVerticalDistanceUnits(_activeVehicle.minimumTakeoffAltitudeMeters()),
                qsTr("Height (rel)"))
        } else if (actionCode === actionChangeSpeed) {
            if (_vehicleInFwdFlight) {
                var currentAirspeed = _activeVehicle.airSpeed
                                      ? _activeVehicle.airSpeed.rawValue
                                      : _activeVehicle.minimumEquivalentAirspeed()
                if (isFinite(commandedSpeedMetersSecond) && commandedSpeedMetersSecond > 0.1) {
                    currentAirspeed = commandedSpeedMetersSecond
                } else if (isFinite(_userCruiseSpeedMetersSecond) && _userCruiseSpeedMetersSecond > 0.1) {
                    currentAirspeed = _userCruiseSpeedMetersSecond
                }
                guidedValueSlider.setupSlider(
                    GuidedValueSlider.SliderType.Speed,
                    _unitsConversion.metersSecondToAppSettingsSpeedUnits(_activeVehicle.minimumEquivalentAirspeed()).toFixed(1),
                    _unitsConversion.metersSecondToAppSettingsSpeedUnits(_activeVehicle.maximumEquivalentAirspeed()).toFixed(1),
                    _unitsConversion.metersSecondToAppSettingsSpeedUnits(currentAirspeed),
                    qsTr("Airspeed"))
            } else if (!_vehicleInFwdFlight && _activeVehicle.haveMRSpeedLimits) {
                // Prefer last commanded / pilot cruise speed, then live ground speed,
                // so the slider opens on the value currently shown in the bottom bar.
                var currentSpeedMs = NaN
                if (isFinite(_userCruiseSpeedMetersSecond) && _userCruiseSpeedMetersSecond > 0.1) {
                    currentSpeedMs = _userCruiseSpeedMetersSecond
                } else if (isFinite(commandedSpeedMetersSecond) && commandedSpeedMetersSecond > 0.1) {
                    currentSpeedMs = commandedSpeedMetersSecond
                } else if (_activeVehicle.groundSpeed && _activeVehicle.groundSpeed.rawValue > 0.1) {
                    currentSpeedMs = _activeVehicle.groundSpeed.rawValue
                } else {
                    currentSpeedMs = _activeVehicle.maximumHorizontalSpeedMultirotor() / 2
                }
                guidedValueSlider.setupSlider(
                    GuidedValueSlider.SliderType.Speed,
                    _unitsConversion.metersSecondToAppSettingsSpeedUnits(0.1).toFixed(1),
                    _unitsConversion.metersSecondToAppSettingsSpeedUnits(_activeVehicle.maximumHorizontalSpeedMultirotor()).toFixed(1),
                    _unitsConversion.metersSecondToAppSettingsSpeedUnits(currentSpeedMs),
                    qsTr("Speed"))
            } else {
                console.error("setupSlider called for inapproproate change speed action", _vehicleInFwdFlight, _activeVehicle.haveMRSpeedLimits)
            }
        } else if (actionCode === actionChangeAlt || actionCode === actionOrbit || actionCode === actionGoto || actionCode === actionPause) {
            var currentAlt = _activeVehicle.altitudeRelative.value
            if (isFinite(commandedAltitudeMeters)) {
                currentAlt = _unitsConversion.metersToAppSettingsVerticalDistanceUnits(commandedAltitudeMeters)
            }
            guidedValueSlider.setupSlider(
                GuidedValueSlider.SliderType.Altitude,
                _flyViewSettings.guidedMinimumAltitude.value,
                _flyViewSettings.guidedMaximumAltitude.value,
                currentAlt,
                qsTr("Alt (rel)"))
        }
    }

    on_ActiveVehicleChanged: {
        commandedAltitudeMeters = NaN
        commandedSpeedMetersSecond = NaN
        _userCruiseSpeedMetersSecond = NaN
        commandedAltitudeClearTimer.stop()
        commandedSpeedClearTimer.stop()
        restoreSpeedAfterAltTimer.stop()
        _outputState()
    }

    Component.onCompleted:              _outputState()
    on_VehicleArmedChanged:             _outputState()
    on_VehicleInRTLModeChanged:         _outputState()
    on_VehiclePausedChanged:            _outputState()
    on__FlightModeChanged:              _outputState()
    on__GuidedModeSupportedChanged:     _outputState()
    on__PauseVehicleSupportedChanged:   _outputState()
    on__RoiSupportedChanged:            _outputState()
    on__OrbitSupportedChanged:          _outputState()
    on_MissionItemCountChanged:         _outputState()
    on_MissionActiveChanged:            _outputState()

    on_CurrentMissionIndexChanged: {
        if (_isGuidedActionsControllerLogEnabled()) {
            console.log("_currentMissionIndex", _currentMissionIndex)
        }
    }
    on_ResumeMissionIndexChanged: {
        if (_isGuidedActionsControllerLogEnabled()) {
            console.log("_resumeMissionIndex", _resumeMissionIndex)
        }
    }
    onShowResumeMissionChanged: {
        if (_isGuidedActionsControllerLogEnabled()) {
            console.log("showResumeMission", showResumeMission)
        }
        _outputState()
    }
    onShowStartMissionChanged: {
        if (_isGuidedActionsControllerLogEnabled()) {
            console.log("showStartMission", showStartMission)
        }
        _outputState()
        if (showStartMission &&
            _flyViewSettings.enableAutomaticMissionPopups.rawValue) {
            confirmAction(actionStartMission)
        }
    }
    onShowContinueMissionChanged: {
        if (_isGuidedActionsControllerLogEnabled()) {
            console.log("showContinueMission", showContinueMission, "suppress", _suppressAutoContinueMission)
        }
        _outputState()
        if (showContinueMission &&
            !_suppressAutoContinueMission &&
            _flyViewSettings.enableAutomaticMissionPopups.rawValue) {
            confirmAction(actionContinueMission)
        }
    }
    onShowRTLChanged: {
        if (_isGuidedActionsControllerLogEnabled()) {
            console.log("showRTL", showRTL)
        }
        _outputState()
    }
    onShowChangeAltChanged: {
        if (_isGuidedActionsControllerLogEnabled()) {
            console.log("showChangeAlt", showChangeAlt)
        }
        _outputState()
    }
    onShowROIChanged: {
        if (_isGuidedActionsControllerLogEnabled()) {
            console.log("showROI", showROI)
        }
        _outputState()
    }
    onShowOrbitChanged: {
        if (_isGuidedActionsControllerLogEnabled()) {
            console.log("showOrbit", showOrbit)
        }
        _outputState()
    }
    onShowGotoLocationChanged: {
        if (_isGuidedActionsControllerLogEnabled()) {
            console.log("showGotoLocation", showGotoLocation)
        }
        _outputState()
    }
    onShowLandAbortChanged: {
        if (showLandAbort) {
            confirmAction(actionLandAbort)
        }
    }

    on_VehicleFlyingChanged: {
        _outputState()
        if (!_vehicleFlying) {
            // We use _vehicleWasFLying to help trigger Resume Mission only if the vehicle actually flew and came back down.
            // Otherwise it may trigger during the Start Mission sequence due to signal ordering or armed and resume mission index.
            _vehicleWasFlying = true
            commandedAltitudeMeters = NaN
            commandedSpeedMetersSecond = NaN
            _userCruiseSpeedMetersSecond = NaN
            commandedAltitudeClearTimer.stop()
            commandedSpeedClearTimer.stop()
            restoreSpeedAfterAltTimer.stop()
        }
    }

    property var _actionData

    on_FlightModeChanged: {
        _vehiclePaused =        _activeVehicle ? _flightMode === _activeVehicle.pauseFlightMode : false
        _vehicleInRTLMode =     _activeVehicle ? _flightMode === _activeVehicle.rtlFlightMode || _flightMode === _activeVehicle.smartRTLFlightMode : false
        _vehicleInLandMode =    _activeVehicle ? _flightMode === _activeVehicle.landFlightMode : false
        _vehicleInMissionMode = _activeVehicle ? _flightMode === _activeVehicle.missionFlightMode : false // Must be last to get correct signalling for showStartMission popups
    }

    Connections {
        target:                     missionController
        function onResumeMissionUploadFail() { confirmAction(actionResumeMissionUploadFail) }
    }

    Connections {
        target:                             mainWindow
        function onArmVehicleRequest() { armVehicleRequest() }
        function onForceArmVehicleRequest() { forceArmVehicleRequest() }
        function onDisarmVehicleRequest() { disarmVehicleRequest() }
    }

    function armVehicleRequest() {
        confirmAction(actionArm)
    }

    function forceArmVehicleRequest() {
        confirmAction(actionForceArm)
    }

    function disarmVehicleRequest() {
        if (showEmergenyStop) {
            confirmAction(actionEmergencyStop)
        } else {
            confirmAction(actionDisarm)
        }

    }

    function closeAll() {
        confirmDialog.visible = false
        guidedValueSlider.visible = false
    }

    Timer {
        id: commandedAltitudeClearTimer
        interval: 15000
        repeat: false
        onTriggered: _root.commandedAltitudeMeters = NaN
    }

    Timer {
        id: commandedSpeedClearTimer
        interval: 15000
        repeat: false
        onTriggered: _root.commandedSpeedMetersSecond = NaN
    }

    Timer {
        id: suppressAutoContinueClearTimer
        interval: 60000
        repeat: false
        onTriggered: {
            if (!_root._pendingAltMissionResume) {
                _root._suppressAutoContinueMission = false
            }
        }
    }

    // Wait until vehicle reaches commanded altitude, then update mission alts + resume
    Timer {
        id: altReachedPollTimer
        interval: 500
        repeat: true
        running: false
        onTriggered: {
            if (!_root._pendingAltMissionResume || !_activeVehicle) {
                stop()
                return
            }
            _root._pendingAltPollCount++
            var currentAlt = _activeVehicle.altitudeRelative.rawValue
            var reached = Math.abs(currentAlt - _root._pendingAltTargetMeters) < 1.5
            var timedOut = _root._pendingAltPollCount > 90 // ~45s
            if (reached || timedOut) {
                stop()
                _root._finishAltitudeChangeAndResumeMission()
            }
        }
    }

    // Do not switch back to Mission until the autopilot reports the requested
    // forward sequence. The first SET_CURRENT can arrive while PX4 is still
    // finalizing the rewritten mission, so retry it while the vehicle is safely
    // paused instead of only waiting for a confirmation that may never arrive.
    Timer {
        id: altResumeSequenceConfirmTimer
        interval: 200
        repeat: true
        running: false
        onTriggered: {
            if (!_activeVehicle || _root._pendingAltStartSequence < 0) {
                stop()
                return
            }

            var currentSequence = (_activeVehicle.missionItemIndex)
                                  ? Number(_activeVehicle.missionItemIndex.rawValue) : -1
            // PX4 may immediately skip a reached item and report a later one.
            // A later sequence is also safe; only an earlier sequence is rejected.
            var validCurrentSequence = isFinite(currentSequence)
                                       && currentSequence >= 0
                                       && currentSequence < _root._missionItemCount
            if (validCurrentSequence
                    && currentSequence >= _root._pendingAltStartSequence) {
                stop()
                _root._startMissionAtConfirmedAltitudeSequence()
                return
            }

            _root._pendingAltStartPollCount++
            if ((_root._pendingAltStartPollCount % 5) === 0) {
                // Retry once per second. MISSION_SET_CURRENT has no command ACK,
                // and PX4 can ignore the first request at the end of an upload.
                _activeVehicle.setCurrentMissionSequence(_root._pendingAltStartSequence)
            }

            if (_root._pendingAltStartPollCount >= 75) { // 15 seconds
                stop()
                _root._pendingAltStartSequence = -1
                _root._pendingAltStartPollCount = 0
                _root._pendingAltStartSpeed = NaN
                _root._pendingAltStartWriteOk = true
                _root._suppressAutoContinueMission = false
                mainWindow.showMessageDialog(
                    qsTr("Altitude Change"),
                    qsTr("The next forward mission point could not be confirmed. The vehicle will remain paused to prevent it from flying backward."))
            }
        }
    }

    Connections {
        target: _activeVehicle
        enabled: _activeVehicle !== null
        ignoreUnknownSignals: true
        function onRemainingMissionAltitudeUpdated(success) {
            if (!_root._pendingAltMissionResume) {
                return
            }
            _root._resumeMissionAfterAltitudeChange(success)
        }
    }

    function _finishAltitudeChangeAndResumeMission() {
        if (!_activeVehicle || !_pendingAltMissionResume) {
            return
        }
        // Rewrite remaining onboard waypoints to the new altitude (and cruise speed if set)
        // so resume does not pull the old plan height/speed.
        var speedForMission = isFinite(_pendingAltResumeSpeed) ? _pendingAltResumeSpeed : Number.NaN
        _activeVehicle.updateRemainingMissionAltitudeRelative(_pendingAltTargetMeters, speedForMission)
        // Safety timeout if write never completes
        altMissionWriteTimeout.restart()
    }

    function _applyUserCruiseSpeed(metersSecondSpeed) {
        if (!_activeVehicle || !isFinite(metersSecondSpeed) || metersSecondSpeed <= 0.1) {
            return
        }
        commandedSpeedMetersSecond = metersSecondSpeed
        commandedSpeedClearTimer.restart()
        if (_vehicleInFwdFlight) {
            _activeVehicle.guidedModeChangeEquivalentAirspeedMetersSecond(metersSecondSpeed)
        } else {
            _activeVehicle.guidedModeChangeGroundSpeedMetersSecond(metersSecondSpeed)
        }
    }

    function _startMissionAtConfirmedAltitudeSequence() {
        if (!_activeVehicle || _pendingAltStartSequence < 0) {
            return
        }

        var resumeSpeed = _pendingAltStartSpeed
        var altitudeWriteOk = _pendingAltStartWriteOk
        _pendingAltStartSequence = -1
        _pendingAltStartPollCount = 0
        _pendingAltStartSpeed = NaN
        _pendingAltStartWriteOk = true

        _activeVehicle.startMission()

        // Mission mode re-applies plan cruise shortly after startMission. Re-send the
        // pilot's speed several times so it wins over the plan default.
        if (isFinite(resumeSpeed) && resumeSpeed > 0.1) {
            _pendingAltResumeSpeed = resumeSpeed
            _restoreSpeedRetryCount = 0
            restoreSpeedAfterAltTimer.restart()
        }

        // Allow Continue Mission popup again after we ourselves resumed.
        suppressAutoContinueClearTimer.restart()
        if (!altitudeWriteOk) {
            mainWindow.showMessageDialog(
                qsTr("Altitude Change"),
                qsTr("Mission resumed, but updating remaining waypoints altitudes failed. The vehicle may return to the previous plan altitude."))
        }
    }

    function _resumeMissionAfterAltitudeChange(altitudeWriteOk) {
        altMissionWriteTimeout.stop()
        if (!_activeVehicle || !_pendingAltMissionResume) {
            return
        }
        var resumeFromIndex = _pendingAltResumeFromIndex
        var resumeIndex = _pendingAltResumeIndex
        var resumeSpeed = _pendingAltResumeSpeed
        _pendingAltResumeSpeed = NaN
        _pendingAltMissionResume = false
        _pendingAltResumeIndex = -1
        _pendingAltResumeFromIndex = -1
        _pendingAltPollCount = 0

        // Climb stays at current position (guided altitude). On resume, set current
        // to the next WP ahead of the vehicle — never takeoff / never earlier WP.
        // Re-evaluate after climb from the original floor so near WPs are skipped.
        var fromIdx = resumeFromIndex >= 0 ? resumeFromIndex : resumeIndex
        if (_activeVehicle.altitudeChangeResumeMissionSequence) {
            var aheadIdx = _activeVehicle.altitudeChangeResumeMissionSequence(fromIdx)
            if (aheadIdx >= 0) {
                resumeIndex = aheadIdx
            }
        }
        if (resumeIndex < 0) {
            _suppressAutoContinueMission = false
            mainWindow.showMessageDialog(
                qsTr("Altitude Change"),
                qsTr("No forward mission point remains. The vehicle will stay paused instead of flying backward."))
            return
        }

        _pendingAltStartSequence = resumeIndex
        _pendingAltStartPollCount = 0
        _pendingAltStartSpeed = resumeSpeed
        _pendingAltStartWriteOk = altitudeWriteOk
        _activeVehicle.setCurrentMissionSequence(resumeIndex)
        altResumeSequenceConfirmTimer.restart()
    }

    Timer {
        id: restoreSpeedAfterAltTimer
        interval: 800
        repeat: true
        running: false
        onTriggered: {
            if (!_activeVehicle || !isFinite(_root._pendingAltResumeSpeed) || _root._pendingAltResumeSpeed <= 0.1) {
                stop()
                return
            }
            _root._applyUserCruiseSpeed(_root._pendingAltResumeSpeed)
            _root._restoreSpeedRetryCount++
            // Apply a few times after mission mode settles (0.8s, 1.6s, 2.4s, 3.2s, 4.0s)
            if (_root._restoreSpeedRetryCount >= 5) {
                stop()
                _root._pendingAltResumeSpeed = NaN
            }
        }
    }

    Timer {
        id: altMissionWriteTimeout
        interval: 20000
        repeat: false
        onTriggered: {
            if (_root._pendingAltMissionResume) {
                _root._resumeMissionAfterAltitudeChange(false)
            }
        }
    }

    // Called when an action is about to be executed in order to confirm
    function confirmAction(actionCode, actionData, mapIndicator) {
        var showImmediate = true
        closeAll()
        confirmDialog.action = actionCode
        confirmDialog.actionData = actionData
        confirmDialog.hideTrigger = true
        confirmDialog.mapIndicator = mapIndicator
        confirmDialog.optionText = ""
        _actionData = actionData

        setupSlider(actionCode)

        switch (actionCode) {
        case actionArm:
            if (_vehicleFlying || !_guidedActionsEnabled) {
                return
            }
            confirmDialog.title = armTitle
            confirmDialog.message = armMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showArm })
            break;
        case actionMVArm:
            confirmDialog.title = mvArmTitle
            confirmDialog.message = mvArmMessage
            confirmDialog.hideTrigger = true
            break;
        case actionForceArm:
            confirmDialog.title = forceArmTitle
            confirmDialog.message = forceArmMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showForceArm })
            break;
        case actionDisarm:
            if (_vehicleFlying) {
                return
            }
            confirmDialog.title = disarmTitle
            confirmDialog.message = disarmMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showDisarm })
            break;
        case actionMVDisarm:
            confirmDialog.title = mvDisarmTitle
            confirmDialog.message = mvDisarmMessage
            confirmDialog.hideTrigger = true
            break;
        case actionEmergencyStop:
            confirmDialog.title = emergencyStopTitle
            confirmDialog.message = emergencyStopMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showEmergenyStop })
            break;
        case actionTakeoff:
            confirmDialog.title = takeoffTitle
            confirmDialog.message = takeoffMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showTakeoff })
            guidedValueSlider.visible = _activeVehicle.guidedTakeoffSupported
            break;
        case actionStartMission:
            showImmediate = false
            confirmDialog.title = startMissionTitle
            confirmDialog.message = startMissionMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showStartMission })
            break;
        case actionMVStartMission:
            confirmDialog.title = mvStartMissionTitle
            confirmDialog.message = mvStartMissionMessage
            confirmDialog.hideTrigger = true
            break;
        case actionContinueMission:
            showImmediate = false
            confirmDialog.title = continueMissionTitle
            confirmDialog.message = continueMissionMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showContinueMission })
            break;
        case actionResumeMission:
            // Resume Mission is handled in mission end dialog
            return
        case actionResumeMissionUploadFail:
            confirmDialog.title = resumeMissionUploadFailTitle
            confirmDialog.message = resumeMissionUploadFailMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showResumeMission })
            break;
        case actionLand:
            confirmDialog.title = landTitle
            confirmDialog.message = landMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showLand })
            break;
        case actionRTL:
            confirmDialog.title = rtlTitle
            confirmDialog.message = rtlMessage
            if (_activeVehicle.supportsSmartRTL) {
                confirmDialog.optionText = qsTr("Smart RTL")
                confirmDialog.optionChecked = false
            }
            confirmDialog.hideTrigger = Qt.binding(function() { return !showRTL })
            break;
        case actionChangeAlt:
            confirmDialog.title = changeAltTitle
            confirmDialog.message = changeAltMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showChangeAlt })
            guidedValueSlider.visible = true
            break;
        case actionChangeLoiterRadius:
            confirmDialog.title = changeLoiterRadiusTitle
            confirmDialog.message = changeLoiterRadiusMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showChangeLoiterRadius })
            confirmDialog.mapIndicator = fwdFlightGotoMapCircle
            fwdFlightGotoMapCircle.startLoiterRadiusEdit()
            break
        case actionGoto:
            confirmDialog.title = gotoTitle
            confirmDialog.message = gotoMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showGotoLocation })
            break;
        case actionSetWaypoint:
            confirmDialog.title = setWaypointTitle
            confirmDialog.message = setWaypointMessage
            break;
        case actionOrbit:
            confirmDialog.title = orbitTitle
            confirmDialog.message = orbitMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showOrbit })
            guidedValueSlider.visible = true
            break;
        case actionLandAbort:
            confirmDialog.title = landAbortTitle
            confirmDialog.message = landAbortMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showLandAbort })
            break;
        case actionPause:
            confirmDialog.title = pauseTitle
            confirmDialog.message = pauseMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showPause })
            guidedValueSlider.visible = true
            break;
        case actionMVPause:
            confirmDialog.title = mvPauseTitle
            confirmDialog.message = mvPauseMessage
            confirmDialog.hideTrigger = true
            break;
        case actionROI:
            confirmDialog.title = roiTitle
            confirmDialog.message = roiMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showROI })
            break;
        case actionChangeSpeed:
            confirmDialog.title = changeSpeedTitle
            confirmDialog.message = changeSpeedMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showChangeSpeed })
            guidedValueSlider.visible = true
            break
        case actionSetHome:
            confirmDialog.title = setHomeTitle
            confirmDialog.message = setHomeMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showSetHome })
            break
        case actionSetEstimatorOrigin:
            confirmDialog.title = setEstimatorOriginTitle
            confirmDialog.message = setEstimatorOriginMessage
            break
        case actionSetFlightMode:
            confirmDialog.title = setFlightMode
            confirmDialog.message = setFlightModeMessage
            break
        case actionChangeHeading:
            confirmDialog.title = changeHeadingTitle
            confirmDialog.message = changeHeadingMessage
            break
        default:
            if (!customController.customConfirmAction(actionCode, actionData, mapIndicator, confirmDialog)) {
                console.warn("Unknown actionCode", actionCode)
                return
            }
        }
        confirmDialog.show(showImmediate)
    }

    // Executes the specified action
    function executeAction(actionCode, actionData, sliderOutputValue, optionChecked) {
        var i;
        var selectedVehicles;
        switch (actionCode) {
        case actionRTL:
            _activeVehicle.guidedModeRTL(optionChecked)
            break
        case actionLand:
            _activeVehicle.guidedModeLand()
            break
        case actionTakeoff:
            if (_activeVehicle.guidedTakeoffSupported) {
                var valueInMeters = _unitsConversion.appSettingsVerticalDistanceUnitsToMeters(sliderOutputValue)
                _activeVehicle.guidedModeTakeoff(valueInMeters)
            } else {
                _activeVehicle.startTakeoff()
            }
            break
        case actionResumeMission:
        case actionResumeMissionUploadFail:
            missionController.resumeMission(missionController.resumeMissionIndex)
            break
        case actionStartMission:
        case actionContinueMission:
            _activeVehicle.startMission()
            break
        case actionMVStartMission:
            selectedVehicles = QGroundControl.multiVehicleManager.selectedVehicles
            for (i = 0; i < selectedVehicles.count; i++) {
                var vehicle = selectedVehicles.get(i)
                if (vehicle.armed === true){
                    vehicle.startMission()
                }
            }
            break
        case actionArm:
            _activeVehicle.armed = true
            break
        case actionMVArm:
            selectedVehicles = QGroundControl.multiVehicleManager.selectedVehicles
            for (i = 0; i < selectedVehicles.count; i++) {
                selectedVehicles.get(i).armed = true
            }
            break
        case actionForceArm:
            _activeVehicle.forceArm()
            break
        case actionDisarm:
            _activeVehicle.armed = false
            break
        case actionMVDisarm:
            selectedVehicles = QGroundControl.multiVehicleManager.selectedVehicles
            for (i = 0; i < selectedVehicles.count; i++) {
                selectedVehicles.get(i).armed = false
            }
            break
        case actionEmergencyStop:
            _activeVehicle.emergencyStop()
            break
        case actionChangeAlt:
            var valueInMeters = _unitsConversion.appSettingsVerticalDistanceUnitsToMeters(sliderOutputValue)
            var altitudeChangeInMeters = valueInMeters - _activeVehicle.altitudeRelative.rawValue
            commandedAltitudeMeters = valueInMeters
            commandedAltitudeClearTimer.restart()
            // Changing altitude leaves Mission for Hold (drone slows/stops while climbing).
            // After the new altitude is reached we update remaining waypoint altitudes and
            // auto-resume Mission so the route continues at the new height.
            if (_vehicleInMissionMode) {
                _suppressAutoContinueMission = true
                suppressAutoContinueClearTimer.restart()
                _pendingAltMissionResume = true
                // Capture the live index now (before Hold / mission rewrite clears it).
                // Resume continues forward from here to the next WP ahead — never takeoff/back.
                var fromIdx = (_activeVehicle && _activeVehicle.missionItemIndex)
                              ? _activeVehicle.missionItemIndex.rawValue : _currentMissionIndex
                _pendingAltResumeFromIndex = fromIdx
                _pendingAltResumeIndex = fromIdx
                if (_activeVehicle.altitudeChangeResumeMissionSequence) {
                    var aheadIdx = _activeVehicle.altitudeChangeResumeMissionSequence(fromIdx)
                    if (aheadIdx >= 0) {
                        _pendingAltResumeIndex = aheadIdx
                    }
                }
                _pendingAltTargetMeters = valueInMeters
                _pendingAltPollCount = 0
                // Prefer the last speed the pilot set, then live commanded display, then current GS.
                if (isFinite(_userCruiseSpeedMetersSecond) && _userCruiseSpeedMetersSecond > 0.1) {
                    _pendingAltResumeSpeed = _userCruiseSpeedMetersSecond
                } else if (isFinite(commandedSpeedMetersSecond) && commandedSpeedMetersSecond > 0.1) {
                    _pendingAltResumeSpeed = commandedSpeedMetersSecond
                } else if (_activeVehicle.groundSpeed && _activeVehicle.groundSpeed.rawValue > 0.5) {
                    _pendingAltResumeSpeed = _activeVehicle.groundSpeed.rawValue
                } else {
                    _pendingAltResumeSpeed = NaN
                }
                altReachedPollTimer.restart()
            }
            // Hold the live vehicle position before applying the altitude target.
            // Without this pause PX4 can retain the active mission waypoint as
            // the horizontal reposition target and climb away from the current
            // aircraft position.
            _activeVehicle.guidedModeChangeAltitude(altitudeChangeInMeters, true /* pauseVehicle */)
            break
        case actionChangeLoiterRadius:
            _activeVehicle.guidedModeGotoLocation(
                fwdFlightGotoMapCircle.coordinate,
                (fwdFlightGotoMapCircle.clockwiseRotation ? 1 : -1) *
                        Math.abs(fwdFlightGotoMapCircle.radius.rawValue)
            )
            break
        case actionGoto:
            _activeVehicle.guidedModeGotoLocation(
                actionData,
                _vehicleInFwdFlight /* forwardFlightLoiterRadius */
                    ? _flyViewSettings.forwardFlightGoToLocationLoiterRad.value
                    : 0
            )
            break
        case actionSetWaypoint:
            _activeVehicle.setCurrentMissionSequence(actionData)
            break
        case actionOrbit:
            var valueInMeters = _unitsConversion.appSettingsVerticalDistanceUnitsToMeters(sliderOutputValue)
            _activeVehicle.guidedModeOrbit(orbitMapCircle.center, orbitMapCircle.radius() * (orbitMapCircle.clockwiseRotation ? 1 : -1), _activeVehicle.homePosition.altitude + valueInMeters)
            break
        case actionLandAbort:
            _activeVehicle.abortLanding(50)     // hardcoded value for climbOutAltitude that is currently ignored
            break
        case actionPause:
            var valueInMeters = _unitsConversion.appSettingsVerticalDistanceUnitsToMeters(sliderOutputValue)
            var altitudeChangeInMeters = valueInMeters - _activeVehicle.altitudeRelative.rawValue
            _activeVehicle.guidedModeChangeAltitude(altitudeChangeInMeters, true /* pauseVehicle */)
            break
        case actionMVPause:
            selectedVehicles = QGroundControl.multiVehicleManager.selectedVehicles
            for (i = 0; i < selectedVehicles.count; i++) {
                selectedVehicles.get(i).pauseVehicle()
            }
            break
        case actionROI:
            _activeVehicle.guidedModeROI(actionData)
            break
        case actionChangeSpeed:
            if (_activeVehicle) {
                // We need to convert back to m/s as that is what mavlink standard uses for MAV_CMD_DO_CHANGE_SPEED
                var metersSecondSpeed = _unitsConversion.appSettingsSpeedUnitsToMetersSecond(sliderOutputValue)
                commandedSpeedMetersSecond = metersSecondSpeed
                _userCruiseSpeedMetersSecond = metersSecondSpeed
                commandedSpeedClearTimer.restart()
                if (_vehicleInFwdFlight) {
                   _activeVehicle.guidedModeChangeEquivalentAirspeedMetersSecond(metersSecondSpeed)
                } else {
                    _activeVehicle.guidedModeChangeGroundSpeedMetersSecond(metersSecondSpeed)
                }
            }
            break
        case actionSetHome:
            _activeVehicle.doSetHome(actionData)
            break
        case actionSetEstimatorOrigin:
            _activeVehicle.setEstimatorOrigin(actionData)
            break
        case actionSetFlightMode:
            _activeVehicle.flightMode = actionData
            break
        case actionChangeHeading:
            _activeVehicle.guidedModeChangeHeading(actionData)
            break
        default:
            if (!customController.customExecuteAction(actionCode, actionData, sliderOutputValue, optionChecked)) {
                console.warn(qsTr("Internal error: unknown actionCode"), actionCode)
                return
            }
            break
        }
    }
}
