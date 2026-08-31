import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtLocation
import QtPositioning
import QtQuick.Layouts
import QtQuick.Window


import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap
import QGroundControl.FlyView

Item {
    id: _root

    // -------------------------------------------------------------------------
    // Route Mapping View
    // Create, edit, save, import, and transfer survey/mapping plans to Fly View
    //
    // Function overview:
    //   Route drawing  -> startAreaRouteSession, addRouteMappingPoint, finishAreaRoute
    //   Import/export  -> openRouteMappingImportDialog, loadRouteMappingPlan,
    //                     openSaveMappingTaskDialog, saveMappingTask,
    //                     uploadRouteMappingPlan
    //   Clear/reset    -mapping> clearRouteMappingPlan, resetRouteMappingPlanState
    //   Navigation     -> returnToFlyView, exitRouteMappingPage, _transferPlanToFlyView
    //   Fly View sync  -> _showPlanOnFlyView, _routeMappingOverlayData, _tryUploadFlyViewPlan
    // -------------------------------------------------------------------------

    property bool _missionMapVisualsEnabled: true
    readonly property bool _showMissionOnMap: visible && _missionMapVisualsEnabled

    onVisibleChanged: {
        if (!visible) {
            hideTaskSettings()
            _missionMapVisualsEnabled = false
            _cachedSurveyItem = null
            _taskSettingsSurveyItem = null
            _pendingFlyViewReturn = false
            _backButtonVisibleProgress = 1.0
        } else {
            _missionMapVisualsEnabled = true
            _updateCachedSurveyItem()
            _backButtonVisibleProgress = 0
            Qt.callLater(function() {
                _backButtonVisibleProgress = 1.0
                _centerRouteMapOnVehicle()
            })
        }
    }

    Connections {
        target: QGroundControl.multiVehicleManager
        function onActiveVehicleChanged() {
            if (!_root._hasRouteMappingContent) {
                // FlightMap normally centers on only the first vehicle position.
                // Reset that one-shot state when SITL/vehicle instances change.
                routeMap.firstVehiclePositionReceived = false
                if (_root.visible) {
                    Qt.callLater(function() { _root._centerRouteMapOnVehicle() })
                }
            }

            if (_root.visible && (_root._areaRouteActive || _root._surveyFinished)) {
                _root._missionMapVisualsEnabled = false
                _root._cachedSurveyItem = null
                missionPlanRestoreTimer.restart()
            }
        }
    }

    readonly property int  _decimalPlaces: 8
    readonly property real _margin: ScreenTools.defaultFontPixelHeight * 0.5
    readonly property real _toolsMargin: ScreenTools.defaultFontPixelWidth * 0.75
    readonly property real _actionButtonRadius: ScreenTools.defaultFontPixelWidth * 0.45
    readonly property color _routeActionTextColor: "#6a6a6a"

    property var  _planMasterController: planMasterController
    property var  _missionController: _planMasterController.missionController
    property var  _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property bool _taskSettingsVisible: false
    property real _taskSettingsOpenProgress: _taskSettingsVisible ? 1.0 : 0.0
    property real _backButtonVisibleProgress: 1.0
    property bool _pendingFlyViewReturn: false

    Behavior on _taskSettingsOpenProgress {
        NumberAnimation {
            duration: 320
            easing.type: Easing.OutCubic
        }
    }

    Behavior on _backButtonVisibleProgress {
        NumberAnimation {
            duration: 320
            easing.type: Easing.OutCubic
        }
    }

    on_TaskSettingsOpenProgressChanged: {
        if (_pendingFlyViewReturn && !_taskSettingsVisible && _taskSettingsOpenProgress === 0) {
            _pendingFlyViewReturn = false
            _finishReturnToFlyView()
        }
    }

    readonly property real _taskSettingsPanelWidth: Math.min(
                                                        ScreenTools.defaultFontPixelWidth * 38,
                                                        routeContent.width * 0.42)
    property bool _areaRouteActive: false
    property bool _surveyFinished: false
    property int  _selectedWaypointIndex: -1
    property string _pendingMappingTaskName: ""
    property string _savedMappingTaskName: ""
    property string _importedMappingTaskName: ""
    property string _importedMappingPlanPath: ""
    property bool _showSavedMappingOverlay: false
    property bool _routeMappingPlanUploaded: false
    property var _uploadedRouteMappingOverlayData: null
    property bool _editingUploadedPlan: false
    property string _editBaselineSignature: ""
    property bool _routeMappingUploadPending: false

    // Boundary waypoints stay editable after upload so the plan can be changed and re-uploaded.
    readonly property bool _routeBoundaryEditable: _areaRouteActive
                                                   && (!_surveyFinished
                                                       || _editingUploadedPlan
                                                       || _routeMappingUploadPending)

    readonly property bool _canFinishRoute: _areaRouteActive && !_surveyFinished && fieldTracePointsModel.count >= 3
    // Add creates takeoff once; keep it disabled after takeoff/session exists.
    readonly property bool _canCreateTakeoff: !_areaRouteActive
                                              && !_surveyFinished
                                              && fieldTracePointsModel.count === 0
                                              && !_hasMissionPlanItems
                                              && _missionController.visualItems.count <= 1
                                              && _missionController.isInsertTakeoffValid
    readonly property var _routeSegmentInsertPoints: {
        var insertPoints = []
        if (!_routeBoundaryEditable || fieldTracePointsModel.count < 2) {
            return insertPoints
        }

        var segmentCount = fieldTracePointsModel.count - 1
        if (fieldTracePointsModel.count >= 3) {
            segmentCount++
        }

        for (var i = 0; i < segmentCount; i++) {
            var nextIndex = (i + 1) % fieldTracePointsModel.count
            var startPoint = fieldTracePointsModel.get(i)
            var endPoint = fieldTracePointsModel.get(nextIndex)
            var startCoordinate = QtPositioning.coordinate(startPoint.lat, startPoint.lon, startPoint.alt)
            var endCoordinate = QtPositioning.coordinate(endPoint.lat, endPoint.lon, endPoint.alt)
            var midpoint = startCoordinate.atDistanceAndAzimuth(
                        startCoordinate.distanceTo(endCoordinate) / 2,
                        startCoordinate.azimuthTo(endCoordinate))
            midpoint.altitude = (startPoint.alt + endPoint.alt) / 2
            insertPoints.push({
                                  coordinate: midpoint,
                                  insertIndex: i + 1
                              })
        }
        return insertPoints
    }

    ListModel {
        id: fieldTracePointsModel
    }

    property var  _cachedSurveyItem: null
    property var  _taskSettingsSurveyItem: null
    property bool _hasMissionPlanItems: false

    // True when survey polygon is valid and transects are calculated.
    readonly property bool _hasCalculatedSurvey: _cachedSurveyItem
                                                 && _cachedSurveyItem.surveyAreaPolygon
                                                 && _cachedSurveyItem.surveyAreaPolygon.isValid
    // True when any route, trace points, or saved overlay exists on screen.
    readonly property bool _hasRouteMappingContent: _hasMissionPlanItems
                                                    || _areaRouteActive
                                                    || fieldTracePointsModel.count > 0
                                                    || _showSavedMappingOverlay
    readonly property bool _hasTerrainCollision: _hasCalculatedSurvey
                                                 && _cachedSurveyItem.surveyAreaPolygon.showAltColor
    readonly property real _surveyStartHeading: _hasCalculatedSurvey
                                                && _cachedSurveyItem.visualTransectPoints.length >= 2
                                                ? _cachedSurveyItem.visualTransectPoints[0].azimuthTo(
                                                      _cachedSurveyItem.visualTransectPoints[1])
                                                : 0
    readonly property real _surveyEndHeading: _hasCalculatedSurvey
                                              && _cachedSurveyItem.visualTransectPoints.length >= 2
                                              ? _cachedSurveyItem.visualTransectPoints[
                                                    _cachedSurveyItem.visualTransectPoints.length - 2].azimuthTo(
                                                    _cachedSurveyItem.visualTransectPoints[
                                                        _cachedSurveyItem.visualTransectPoints.length - 1])
                                              : 0

    // Returns the existing takeoff item, or null when none has been created yet.
    function _findTakeoffItem() {
        for (var i = 0; i < _missionController.visualItems.count; i++) {
            var item = _missionController.visualItems.get(i)
            if (item && item.isTakeoffItem) {
                return item
            }
        }
        return null
    }

    // Finds and caches the active survey item from the mission plan.
    function _updateCachedSurveyItem() {
        var found = null
        if (_missionMapVisualsEnabled) {
            for (var i = 0; i < _missionController.visualItems.count; i++) {
                var visualItem = _missionController.visualItems.get(i)
                if (visualItem && visualItem.surveyAreaPolygon) {
                    found = visualItem
                    break
                }
            }
        }
        _cachedSurveyItem = found
        if (found) {
            _taskSettingsSurveyItem = found
        }
        _hasMissionPlanItems = _missionController.visualItems.count > 1
    }

    property string _mappingAreaText: {
        if (!_hasCalculatedSurvey) {
            return "0.00 " + QGroundControl.unitsConversion.appSettingsAreaUnitsString
        }
        // Same formula/format as stock TransectStyleComplexItemStats.
        return QGroundControl.unitsConversion.squareMetersToAppSettingsAreaUnits(_cachedSurveyItem.coveredArea).toFixed(2)
                + " " + QGroundControl.unitsConversion.appSettingsAreaUnitsString
    }

    // Boundary trace points are waypoints, not camera shots. Once at least
    // three points form a valid survey, show QGC's calculated camera shots.
    property string _photoCountText: _hasCalculatedSurvey
                                     ? String(_cachedSurveyItem.cameraShots)
                                     : "0"

    // Same source and HH:MM:SS format as stock MissionStats.getMissionTime().
    property string _flightTimeText: {
        var totalSeconds = Number(_missionController.missionTime)
        if (!totalSeconds || totalSeconds <= 0) {
            return "00:00:00"
        }

        var hours = Math.floor(totalSeconds / 3600)
        var minutes = Math.floor((totalSeconds % 3600) / 60)
        var seconds = Math.floor(totalSeconds % 60)
        var hoursText = hours < 10 ? "0" + hours : String(hours)
        var minutesText = minutes < 10 ? "0" + minutes : String(minutes)
        var secondsText = seconds < 10 ? "0" + seconds : String(seconds)
        return hoursText + ":" + minutesText + ":" + secondsText
    }

    // Returns the default complex mission item name (e.g. "Survey").
    function _surveyItemName() {
        var names = _missionController.complexMissionItemNames
        if (names && names.length > 0) {
            return names[0]
        }
        return "Survey"
    }

    // Extracts task name from a .plan file path (filename without extension).
    function _taskNameFromPlanFile(filePath) {
        if (!filePath || filePath === "") {
            return ""
        }

        var fileName = filePath
        var lastSlash = Math.max(fileName.lastIndexOf("/"), fileName.lastIndexOf("\\"))
        if (lastSlash >= 0) {
            fileName = fileName.substring(lastSlash + 1)
        }
        if (fileName.toLowerCase().endsWith(".plan")) {
            fileName = fileName.substring(0, fileName.length - 5)
        }
        return fileName
    }

    // Returns the folder path from a .plan file path.
    function _folderFromPlanFile(filePath) {
        if (!filePath || filePath === "") {
            return ""
        }

        var lastSlash = Math.max(filePath.lastIndexOf("/"), filePath.lastIndexOf("\\"))
        if (lastSlash < 0) {
            return ""
        }
        return filePath.substring(0, lastSlash)
    }

    // Picks the default name shown in the save-task popup.
    function _defaultSaveTaskName() {
        if (_savedMappingTaskName !== "") {
            return _savedMappingTaskName
        }
        if (_importedMappingTaskName !== "") {
            return _importedMappingTaskName
        }
        return qsTr("")
    }

    // Opens the "Saving Mapping Task" popup with the default task name.
    function _openSaveMappingTaskPopup() {
        var defaultTaskName = _defaultSaveTaskName()
        if (taskbar.item) {
            taskbar.item.initialTaskName = defaultTaskName
            taskbar.item.open()
        } else {
            taskbar.pendingInitialTaskName = defaultTaskName
            taskbar.active = true
        }
    }

    // Returns the current map center coordinate.
    function mapCenter() {
        var coordinate = routeMap.center
        coordinate.latitude  = coordinate.latitude.toFixed(_decimalPlaces)
        coordinate.longitude = coordinate.longitude.toFixed(_decimalPlaces)
        coordinate.altitude  = coordinate.altitude.toFixed(_decimalPlaces)
        return coordinate
    }

    // Centers an empty Route Mapping page on the current vehicle. FlightMap's
    // built-in centering is one-shot and can otherwise retain a previous SITL
    // location while Fly View has already followed the new vehicle.
    function _centerRouteMapOnVehicle() {
        if (!_root.visible || _root._hasRouteMappingContent) {
            return
        }

        routeMap.firstVehiclePositionReceived = false
        if (!_activeVehicle || !_activeVehicle.coordinate || !_activeVehicle.coordinate.isValid) {
            // Leave the flag reset so FlightMap centers when the first valid
            // coordinate arrives from a vehicle that is still connecting.
            return
        }

        routeMap.center = QtPositioning.coordinate(_activeVehicle.coordinate.latitude,
                                                   _activeVehicle.coordinate.longitude,
                                                   _activeVehicle.coordinate.altitude)
        routeMap.zoomLevel = QGroundControl.flightMapInitialZoom
        routeMap.firstVehiclePositionReceived = true
    }

    // Returns vehicle position for route start, or map center if no vehicle.
    function routeStartCoordinate() {
        if (_activeVehicle && _activeVehicle.coordinate && _activeVehicle.coordinate.isValid) {
            return QtPositioning.coordinate(
                        Number(_activeVehicle.coordinate.latitude.toFixed(_decimalPlaces)),
                        Number(_activeVehicle.coordinate.longitude.toFixed(_decimalPlaces)),
                        Number(_activeVehicle.coordinate.altitude.toFixed(_decimalPlaces)))
        }

        return mapCenter()
    }

    // Clears all route-drawing state, trace points, and saved/imported task names.
    function resetAreaRouteState() {
        _areaRouteActive = false
        _surveyFinished = false
        _routeMappingPlanUploaded = false
        _uploadedRouteMappingOverlayData = null
        _editingUploadedPlan = false
        _editBaselineSignature = ""
        _routeMappingUploadPending = false
        fieldTracePointsModel.clear()
        _planMasterController.manualCreation = false
        _cachedSurveyItem = null
        _taskSettingsSurveyItem = null
        _selectedWaypointIndex = -1
        _pendingMappingTaskName = ""
        _savedMappingTaskName = ""
        _importedMappingTaskName = ""
        _importedMappingPlanPath = ""
        _showSavedMappingOverlay = false
        _hasMissionPlanItems = _missionController.visualItems.count > 1
    }

    Timer {
        id: missionPlanMutationTimer
        interval: 0
        repeat: false
        property var pendingOperation: null
        onTriggered: {
            if (pendingOperation) {
                pendingOperation()
                pendingOperation = null
                missionPlanRestoreTimer.restart()
            }
        }
    }

    Timer {
        id: missionPlanRestoreTimer
        interval: 0
        repeat: false
        onTriggered: {
            _updateCachedSurveyItem()
            if (_root.visible) {
                _missionMapVisualsEnabled = true
            }
        }
    }

    // Removes all mission items from the plan if any exist.
    function _clearMissionItemsIfNeeded() {
        if (_missionController.visualItems.count > 1) {
            _planMasterController.removeAll()
        }
    }

    // Clears boundary/transect overlay lines shown on Fly View map.
    function _clearFlyViewRouteMappingOverlay(force) {
        if (flyView && flyView.clearRouteMappingOverlay) {
            flyView.clearRouteMappingOverlay(force === true)
            return
        }
        flyView.routeMappingBoundaryPath = []
        flyView.routeMappingTransectPath = []
        flyView.routeMappingTakeoffCoordinate = QtPositioning.coordinate()
        flyView.routeMappingEntryCoordinate = QtPositioning.coordinate()
        flyView.routeMappingExitCoordinate = QtPositioning.coordinate()
        flyView.routeMappingEntryHeading = 0
        flyView.routeMappingExitHeading = 0
        flyView.routeMappingPlannedPhotoCount = 0
    }

    // Hides map visuals, runs a plan change, then restores visuals after.
    function _runWithMissionVisualsSuspended(operation) {
        _missionMapVisualsEnabled = false
        _cachedSurveyItem = null
        missionPlanMutationTimer.pendingOperation = operation
        missionPlanMutationTimer.restart()
    }

    // Creates takeoff + empty survey + RTL/Land and starts a new area route session.
    // Matches stock SurveyPlanCreator: Takeoff → Survey → Land (RTL on multirotor).
    // Takeoff and Land are each inserted at most once for the plan.
    function _beginAreaRouteAtCoordinate(coord) {
        var takeoffItem = _findTakeoffItem()
        if (!takeoffItem && _missionController.isInsertTakeoffValid) {
            takeoffItem = _missionController.insertTakeoffItem(coord, -1, false)
        }
        if (takeoffItem) {
            if (takeoffItem.specifiesCoordinate) {
                takeoffItem.coordinate = coord
            }
            takeoffItem.launchCoordinate = coord
            takeoffItem.launchTakeoffAtSameLocation = true
        }

        var surveyItem = _cachedSurveyItem
        if (!surveyItem || !surveyItem.surveyAreaPolygon) {
            surveyItem = _missionController.insertComplexMissionItem(_surveyItemName(), coord, -1, true)
        }
        if (!surveyItem || !surveyItem.surveyAreaPolygon) {
            return
        }

        surveyItem.surveyAreaPolygon.clear()
        surveyItem.surveyAreaPolygon.traceMode = false
        surveyItem.surveyAreaPolygon.interactive = false

        // Stock QGC Survey always ends with Land. For multirotor that is
        // MAV_CMD_NAV_RETURN_TO_LAUNCH so the vehicle RTLs after the pattern.
        if (!_missionController.hasLandItem && _missionController.isInsertLandValid) {
            _missionController.insertLandItem(coord, -1, false)
        }

        _missionController.setCurrentPlanViewSeqNum(surveyItem.sequenceNumber, true)
        _planMasterController.manualCreation = true
        _areaRouteActive = true
        _cachedSurveyItem = surveyItem
        _taskSettingsSurveyItem = surveyItem
        _hasMissionPlanItems = true

        // Match stock QGC defaults: takeoff and survey start at the same altitude
        // until the user explicitly changes Mission vs Survey Pattern separately.
        if (takeoffItem && takeoffItem.altitude && surveyItem.cameraCalc
                && surveyItem.cameraCalc.distanceToSurface) {
            takeoffItem.altitude.value = surveyItem.cameraCalc.distanceToSurface.value
        }
    }

    // Builds survey polygon from boundary trace points (min 3 points).
    function _updateSurveyPolygonFromTrace(surveyItem) {
        if (fieldTracePointsModel.count < 3 || !surveyItem || !surveyItem.surveyAreaPolygon) {
            return false
        }

        var polygon = surveyItem.surveyAreaPolygon
        polygon.beginReset()
        polygon.clear()
        for (var i = 0; i < fieldTracePointsModel.count; i++) {
            var point = fieldTracePointsModel.get(i)
            polygon.appendVertex(QtPositioning.coordinate(point.lat, point.lon, point.alt))
        }
        polygon.endReset()
        polygon.traceMode = false
        polygon.interactive = false
        return true
    }

    // Empties the survey polygon vertices on the cached survey item.
    function _clearSurveyPolygon() {
        if (!_cachedSurveyItem || !_cachedSurveyItem.surveyAreaPolygon) {
            return
        }

        var polygon = _cachedSurveyItem.surveyAreaPolygon
        polygon.beginReset()
        polygon.clear()
        polygon.endReset()
        polygon.traceMode = false
        polygon.interactive = false
    }

    // Shows confirm dialog, then deletes a boundary waypoint and updates survey.
    function requestDeleteRouteMappingPoint(pointIndex) {
        if (pointIndex < 0 || pointIndex >= fieldTracePointsModel.count
                || !_routeBoundaryEditable) {
            return
        }

        mainWindow.showMessageDialog(
                    qsTr("Delete Waypoint"),
                    qsTr("Delete waypoint %1?").arg(pointIndex + 1),
                    Dialog.Ok | Dialog.Cancel,
                    function() {
                        var pointCountBeforeDelete = fieldTracePointsModel.count
                        // Use QGC's native polygon mutation whenever possible.
                        // It emits pathChanged, which immediately rebuilds the
                        // generated survey/transect pattern.
                        var polygonUpdated = false
                        if (_cachedSurveyItem && _cachedSurveyItem.surveyAreaPolygon) {
                            var surveyPolygon = _cachedSurveyItem.surveyAreaPolygon
                            if (surveyPolygon.count === pointCountBeforeDelete
                                    && pointCountBeforeDelete > 3) {
                                surveyPolygon.removeVertex(pointIndex)
                                polygonUpdated = true
                            }
                        }

                        fieldTracePointsModel.remove(pointIndex)
                        _selectedWaypointIndex = -1
                        if (!polygonUpdated && fieldTracePointsModel.count >= 3) {
                            _updateSurveyPolygonFromTrace(_cachedSurveyItem)
                        } else if (!polygonUpdated) {
                            _clearSurveyPolygon()
                        }
                    },
                    function() {
                        _selectedWaypointIndex = -1
                    })
    }

    // Moves a boundary waypoint; optionally recalculates the survey polygon.
    function moveRouteMappingPoint(pointIndex, coordinate, updateSurvey) {
        if (pointIndex < 0 || pointIndex >= fieldTracePointsModel.count
                || !coordinate || !coordinate.isValid || !_routeBoundaryEditable) {
            return
        }

        fieldTracePointsModel.setProperty(pointIndex, "lat", coordinate.latitude)
        fieldTracePointsModel.setProperty(pointIndex, "lon", coordinate.longitude)
        if (updateSurvey && fieldTracePointsModel.count >= 3) {
            var surveyPolygon = _cachedSurveyItem && _cachedSurveyItem.surveyAreaPolygon
                    ? _cachedSurveyItem.surveyAreaPolygon
                    : null
            if (surveyPolygon && surveyPolygon.count === fieldTracePointsModel.count) {
                surveyPolygon.adjustVertex(pointIndex, coordinate)
                surveyPolygon.traceMode = false
                surveyPolygon.interactive = false
            } else {
                _updateSurveyPolygonFromTrace(_cachedSurveyItem)
            }
        }
    }

    // Starts a new area route only when no existing route/plan is present.
    // Takeoff is activated exactly once via Add; clear the plan to start again.
    function startAreaRouteSession() {
        if (taskSettingsPanel.routeMode !== 0) {
            return
        }

        // Never replace an existing route from the Add/settings controls.
        // A route must be explicitly cleared before a new session can start.
        if (!_canCreateTakeoff) {
            return
        }

        var coord = routeStartCoordinate()
        resetAreaRouteState()
        _beginAreaRouteAtCoordinate(coord)
    }

    // Finalizes route: closes polygon and marks survey finished.
    // Ensures RTL/Land is present as the last item (stock SurveyPlanCreator behavior).
    function finishAreaRoute() {
        if (!_canFinishRoute) {
            return
        }

        var surveyItem = _cachedSurveyItem
        if (!surveyItem || !surveyItem.surveyAreaPolygon) {
            _updateCachedSurveyItem()
            surveyItem = _cachedSurveyItem
        }
        if (!surveyItem || !surveyItem.surveyAreaPolygon) {
            return
        }

        if (!_updateSurveyPolygonFromTrace(surveyItem)) {
            return
        }

        // Safety net for plans started before RTL auto-insert existed.
        if (!_missionController.hasLandItem && _missionController.isInsertLandValid) {
            var endCoord = surveyItem.exitCoordinate
                    ? surveyItem.exitCoordinate
                    : routeStartCoordinate()
            _missionController.insertLandItem(endCoord, -1, false)
        }

        _missionController.setCurrentPlanViewSeqNum(surveyItem.sequenceNumber, true)

        _surveyFinished = true
    }

    // Opens the left task-settings sidebar panel.
    function showTaskSettings() {
        _taskSettingsVisible = true
    }

    // Closes the left task-settings sidebar panel.
    function hideTaskSettings() {
        _taskSettingsVisible = false
    }

    // Attached navigator: toggles the task-settings sidebar without leaving
    // Route Mapping.
    function toggleTaskSettings() {
        _taskSettingsVisible = !_taskSettingsVisible
    }

    // Back button: closes sidebar then navigates to Fly View (or transfers saved plan).
    function returnToFlyView() {
        var sidebarOpen = _taskSettingsVisible || _taskSettingsOpenProgress > 0.01
        hideTaskSettings()
        if (sidebarOpen) {
            _pendingFlyViewReturn = true
            return
        }
        _finishReturnToFlyView()
    }

    // Animates back button out, then switches to Fly View after a short delay.
    function _finishReturnToFlyView() {
        _backButtonVisibleProgress = 0
        flyViewReturnTimer.restart()
    }

    Timer {
        id: flyViewReturnTimer
        interval: 320
        repeat: false
        onTriggered: mainWindow.showFlyView()
    }

    // Add button: creates takeoff once and starts a new area route session.
    // The attached navigator controls the sidebar independently.
    function onAddButtonClicked() {
        if (!_canCreateTakeoff) {
            return
        }
        startAreaRouteSession()
    }

    // Clears plan, trace points, overlays, and mission items (no confirm dialog).
    function resetRouteMappingPlanState() {
        _runWithMissionVisualsSuspended(function() {
            hideTaskSettings()
            _clearMissionItemsIfNeeded()
            _missionController.setCurrentPlanViewSeqNum(0, true)
            resetAreaRouteState()
            _hasMissionPlanItems = false
            _planMasterController.dirty = false
            _clearFlyViewRouteMappingOverlay(true)
            _clearPersistedUploadedPlan()
        })
    }

    // Vehicle fully disconnected: drop editor UI state but keep the last uploaded
    // plan + yellow overlay so Fly View can re-push to the vehicle on reconnect.
    function clearEditorStateForVehicleDisconnect() {
        _runWithMissionVisualsSuspended(function() {
            hideTaskSettings()
            var uploaded = _routeMappingPlanUploaded
            var overlayData = _uploadedRouteMappingOverlayData
            var editingUploaded = _editingUploadedPlan
            var baselineSig = _editBaselineSignature

            _areaRouteActive = false
            _surveyFinished = false
            fieldTracePointsModel.clear()
            _planMasterController.manualCreation = false
            _cachedSurveyItem = null
            _taskSettingsSurveyItem = null
            _selectedWaypointIndex = -1
            _routeMappingUploadPending = false
            _planMasterController.dirty = false

            _routeMappingPlanUploaded = uploaded
            _uploadedRouteMappingOverlayData = overlayData
            _editingUploadedPlan = editingUploaded
            _editBaselineSignature = baselineSig
            _hasMissionPlanItems = _missionController.visualItems.count > 1
        })
    }

    // After Fly View reloads mission from the vehicle, repaint the yellow overlay.
    function onFlyViewMissionResyncedFromVehicle() {
        if ((!_routeMappingPlanUploaded || !_uploadedRouteMappingOverlayData)
                && hasPersistedUploadedPlan()) {
            loadPersistedUploadedPlan()
        }
        if (_routeMappingPlanUploaded) {
            _restoreUploadedRouteMappingOverlay()
        }
    }

    function _lastUploadedPlanFile() {
        var savePath = QGroundControl.settingsManager.appSettings.missionSavePath
        if (!savePath) {
            return ""
        }
        var separator = savePath.endsWith("/") ? "" : "/"
        return savePath + separator + "agriculture_spraying_last_uploaded.plan"
    }

    function hasPersistedUploadedPlan() {
        var planFile = _lastUploadedPlanFile()
        return planFile !== "" && QGCFileDialogController.fileExists(planFile)
    }

    function _clearPersistedUploadedPlan() {
        var planFile = _lastUploadedPlanFile()
        if (planFile !== "" && QGCFileDialogController.fileExists(planFile)) {
            QGCFileDialogController.deleteFile(planFile)
        }
    }

    // Saved on every successful upload so QGC can restore after restart.
    function _persistUploadedRouteMappingPlan() {
        var planFile = _lastUploadedPlanFile()
        if (planFile === "" || !_hasMissionPlanItems) {
            return false
        }
        _planMasterController.saveToFile(planFile)
        return true
    }

    // Restores the last uploaded Route Mapping plan from disk (new QGC session).
    function loadPersistedUploadedPlan() {
        var planFile = _lastUploadedPlanFile()
        if (planFile !== "" && QGCFileDialogController.fileExists(planFile)) {
            return _loadPersistedPlanFromFile(planFile)
        }

        if (mainWindow.uploadedMissionEditor === "agricultureSpraying") {
            var sharedPlanFile = mainWindow.lastExecutedPlanFilePath()
            if (sharedPlanFile !== "" && QGCFileDialogController.fileExists(sharedPlanFile)) {
                return _loadPersistedPlanFromFile(sharedPlanFile)
            }
        }

        return false
    }

    function _loadPersistedPlanFromFile(planFile) {
        if (planFile === "" || !QGCFileDialogController.fileExists(planFile)) {
            return false
        }

        loadRouteMappingPlan(planFile)
        if (!_hasMissionPlanItems || !_cachedSurveyItem) {
            return false
        }

        _routeMappingPlanUploaded = true
        _editingUploadedPlan = true
        _surveyFinished = false
        var overlayData = _routeMappingOverlayData()
        if (overlayData && overlayData.transectPath && overlayData.transectPath.length >= 2) {
            _uploadedRouteMappingOverlayData = overlayData
        }
        return true
    }

    // ArduPilot refuses takeoff when the first nav item is not a Takeoff command.
    function vehicleMissionIsStartable(missionController) {
        if (!missionController || missionController.missionItemCount <= 0) {
            return false
        }
        for (var i = 0; i < missionController.visualItems.count; i++) {
            var item = missionController.visualItems.get(i)
            if (!item || !item.specifiesCoordinate) {
                continue
            }
            if (!item.coordinate || !item.coordinate.isValid) {
                continue
            }
            return item.isTakeoffItem
        }
        return false
    }

    // Vehicle came back with no onboard mission — push the last uploaded plan again.
    function tryReuploadRouteMappingPlanAfterReconnect() {
        if (_routeMappingUploadPending) {
            return false
        }

        if (mainWindow.uploadedMissionEditor !== "" && mainWindow.uploadedMissionEditor !== "agricultureSpraying") {
            return false
        }

        if (!_routeMappingPlanUploaded || _missionController.visualItems.count <= 1) {
            if (!loadPersistedUploadedPlan()) {
                return false
            }
        }

        _missionMapVisualsEnabled = true
        _updateCachedSurveyItem()
        if (_missionController.visualItems.count <= 1 || !_cachedSurveyItem) {
            return false
        }

        var overlayData = _routeMappingOverlayData()
        if (!overlayData || !overlayData.transectPath || overlayData.transectPath.length < 2) {
            overlayData = _uploadedRouteMappingOverlayData
        }
        if (!overlayData || !overlayData.transectPath || overlayData.transectPath.length < 2) {
            return false
        }

        _uploadedRouteMappingOverlayData = overlayData
        _routeMappingUploadPending = true
        if (!_planMasterController.upload()) {
            _routeMappingUploadPending = false
            return false
        }
        return true
    }

    // Clear icon: validates plan exists, then confirms and clears from both views.
    function clearRouteMappingPlan() {
        mainWindow.confirmClearRouteMappingPlan()
    }

    // Folder icon: opens file picker to import an existing .plan file.
    function openRouteMappingImportDialog() {
        function openFilePicker() {
            fileDialog.title = qsTr("Import Route Mapping Plan")
            fileDialog.planFiles = true
            fileDialog.nameFilters = _planMasterController.loadNameFilters
            fileDialog.openForLoad()
        }

        if (_hasMissionPlanItems) {
            mainWindow.showMessageDialog(
                        qsTr("Import Route Mapping Plan"),
                        qsTr("Importing a plan will replace the current route mapping plan. Continue?"),
                        Dialog.Yes | Dialog.Cancel,
                        openFilePicker)
        } else {
            openFilePicker()
        }
    }

    // Loads a .plan file and restores boundary points + survey for editing.
    function loadRouteMappingPlan(file) {
        hideTaskSettings()
        resetAreaRouteState()
        _planMasterController.loadFromFile(file)
        _importedMappingPlanPath = file
        _importedMappingTaskName = _taskNameFromPlanFile(file)

        _missionMapVisualsEnabled = true
        _updateCachedSurveyItem()

        if (_cachedSurveyItem && _cachedSurveyItem.surveyAreaPolygon) {
            var polygon = _cachedSurveyItem.surveyAreaPolygon
            polygon.traceMode = false
            polygon.interactive = false
            for (var i = 0; i < polygon.count; i++) {
                var coordinate = polygon.vertexCoordinate(i)
                fieldTracePointsModel.append({
                                                 lat: coordinate.latitude,
                                                 lon: coordinate.longitude,
                                                 alt: coordinate.altitude
                                             })
            }
            _areaRouteActive = true
            // Keep imported plans editable so boundary tweaks recalculate transects.
            _surveyFinished = false
            _planMasterController.manualCreation = true
            _taskSettingsSurveyItem = _cachedSurveyItem
            _missionController.setCurrentPlanViewSeqNum(_cachedSurveyItem.sequenceNumber, true)
        }

        _hasMissionPlanItems = _missionController.visualItems.count > 1
        missionPlanRestoreTimer.restart()
    }

    // Restores the retained SurveyComplexItem instead of the flattened MAVLink
    // waypoint list shown by Fly View.
    function _resumeRetainedRouteMappingPlanForEdit() {
        _missionMapVisualsEnabled = true
        _updateCachedSurveyItem()
        if (!_hasMissionPlanItems || !_cachedSurveyItem
                || !_cachedSurveyItem.surveyAreaPolygon) {
            return false
        }

        // Keep the last uploaded version available until the editable survey
        // is actually changed. Opening and closing Edit alone must preserve it.
        _editingUploadedPlan = _routeMappingPlanUploaded
                && _uploadedRouteMappingOverlayData
                && _uploadedRouteMappingOverlayData.transectPath
                && _uploadedRouteMappingOverlayData.transectPath.length >= 2
        _surveyFinished = false
        _showSavedMappingOverlay = false
        _areaRouteActive = true
        _planMasterController.manualCreation = true

        if (fieldTracePointsModel.count === 0) {
            var polygon = _cachedSurveyItem.surveyAreaPolygon
            for (var i = 0; i < polygon.count; i++) {
                var coordinate = polygon.vertexCoordinate(i)
                fieldTracePointsModel.append({
                                                 lat: coordinate.latitude,
                                                 lon: coordinate.longitude,
                                                 alt: coordinate.altitude
                                             })
            }
        }

        _taskSettingsSurveyItem = _cachedSurveyItem
        _missionController.setCurrentPlanViewSeqNum(_cachedSurveyItem.sequenceNumber, true)
        _editBaselineSignature = _routeMappingPlanSignature()
        missionPlanRestoreTimer.restart()
        return true
    }

    // Re-opens an uploaded plan for editing when returning from Fly View.
    function resumeRouteMappingForEdit() {
        // The in-memory survey is the authoritative editable version and keeps
        // the original polygon, transects, camera settings, and map position.
        if (_resumeRetainedRouteMappingPlanForEdit()) {
            return
        }

        // Fallback for a plan loaded from another session.
        var flyPlanController = flyView.planController
        if (flyPlanController && flyPlanController.containsItems) {
            var sourcePlanPath = _planFileForFlyViewEdit(flyPlanController)
            if (sourcePlanPath !== "") {
                loadRouteMappingPlan(sourcePlanPath)
                return
            }
        }

        if (_importedMappingPlanPath !== "") {
            loadRouteMappingPlan(_importedMappingPlanPath)
        }
    }

    // Uses the Fly View plan file, or saves the in-memory plan to a temp file first.
    function _planFileForFlyViewEdit(flyPlanController) {
        if (flyPlanController.currentPlanFile && flyPlanController.currentPlanFile !== "") {
            return flyPlanController.currentPlanFile
        }

        var savePath = QGroundControl.settingsManager.appSettings.missionSavePath
        if (!savePath) {
            mainWindow.showMessageDialog(
                        qsTr("Edit"),
                        qsTr("Mission save path must be set in Application Settings."))
            return ""
        }

        var separator = savePath.endsWith("/") ? "" : "/"
        var transferPlanFile = savePath + separator + "route_mapping_transfer.plan"
        flyPlanController.saveToFile(transferPlanFile)
        return transferPlanFile
    }

    // Save button: validates route, then opens save-task name popup.
    function openSaveMappingTaskDialog() {
        if (taskSettingsPanel.flushPendingWrites) {
            taskSettingsPanel.flushPendingWrites()
        }

        if (!_surveyFinished) {
            finishAreaRoute()
            if (!_surveyFinished) {
                mainWindow.showMessageDialog(
                            qsTr("Save"),
                            qsTr("Add at least three waypoints before saving the route."))
                return
            }
        }

        if (!_hasMissionPlanItems) {
            mainWindow.showMessageDialog(qsTr("Save"), qsTr("No route mapping plan to save."))
            return
        }

        var readyState = _planMasterController.readyForSaveState()
        if (readyState === VisualMissionItem.NotReadyForSaveData) {
            mainWindow.showMessageDialog(
                        qsTr("Save"),
                        qsTr("Plan has incomplete items. Complete the route before saving."))
            return
        }

        _openSaveMappingTaskPopup()
    }

    // Upload button: finish a valid route and use QGC's normal plan upload
    // checks/pipeline. Uploading does not require saving the plan to a file and
    // does not navigate away from Route Mapping.
    function uploadRouteMappingPlan() {
        mainWindow.confirmUploadToFlyView("agricultureSpraying", function() {
            _root._performRouteMappingUpload()
        })
    }

    function _performRouteMappingUpload() {
        if (_planMasterController.syncInProgress) {
            return
        }

        // Commit any in-progress altitude/speed slider edits before MAVLink build.
        if (taskSettingsPanel.flushPendingWrites) {
            taskSettingsPanel.flushPendingWrites()
        }

        if (!_surveyFinished && _canFinishRoute) {
            finishAreaRoute()
        }

        // Keep boundary/settings editable after finalize so the user can tweak and re-upload.
        _editingUploadedPlan = true
        _surveyFinished = false

        if (!_planMasterController.containsItems) {
            mainWindow.showMessageDialog(
                        qsTr("Upload"),
                        qsTr("No route mapping plan to upload."))
            return
        }

        // Capture the yellow transect overlay now, but only mark the plan as
        // uploaded after the vehicle write finishes. Otherwise Fly View can show
        // the correct pattern while the vehicle still holds an old/partial mission.
        var overlayData = _routeMappingOverlayData()
        if (!overlayData || !overlayData.transectPath || overlayData.transectPath.length < 2) {
            mainWindow.showMessageDialog(
                        qsTr("Upload"),
                        qsTr("Survey pattern is not ready yet. Wait for the yellow grid to finish calculating, then upload again."))
            return
        }

        _uploadedRouteMappingOverlayData = overlayData
        _routeMappingUploadPending = true
        if (!_planMasterController.upload()) {
            _routeMappingUploadPending = false
            _uploadedRouteMappingOverlayData = null
        }
    }

    // Called when the vehicle mission write finishes successfully.
    function _markRouteMappingUploadComplete() {
        if (!_uploadedRouteMappingOverlayData
                || !_uploadedRouteMappingOverlayData.transectPath
                || _uploadedRouteMappingOverlayData.transectPath.length < 2) {
            _routeMappingPlanUploaded = false
            _editingUploadedPlan = true
            _surveyFinished = false
            _routeMappingUploadPending = false
            return
        }

        _syncRouteMappingOverlayToFlyView(true /* replaceExisting */)
        _routeMappingPlanUploaded = true
        _editingUploadedPlan = true
        _surveyFinished = false
        _routeMappingUploadPending = false
        _editBaselineSignature = _routeMappingPlanSignature()
        _persistUploadedRouteMappingPlan()
        flyView.hideVehicleMissionForUnuploadedRoute = false
        mainWindow.markMissionPlanUploaded("agricultureSpraying")

        // Match stock QGC: after Plan upload, Fly View reloads from the vehicle
        // so Start Mission / containsItems stay in sync.
        var flyPlanController = flyView.planController
        if (flyPlanController && !flyPlanController.offline) {
            flyPlanController.showPlanFromManagerVehicle()
        }
    }

    // Captures the native survey geometry for Fly View and records that this
    // version of the route has entered QGC's vehicle-upload pipeline.
    function _markRouteMappingUploadStarted() {
        // Kept for older call sites; prefer success-gated completion.
        _markRouteMappingUploadComplete()
    }

    // Re-applies the exact SurveyComplexItem geometry captured before MAVLink
    // flattened the mission into simple vehicle waypoints.
    function _restoreUploadedRouteMappingOverlay() {
        var overlayData = _uploadedRouteMappingOverlayData
        if (!overlayData || !overlayData.transectPath
                || overlayData.transectPath.length < 2) {
            return false
        }

        flyView.planEditMode = false
        if (!flyView.routeMappingTransectPath
                || flyView.routeMappingTransectPath.length < 2) {
            flyView.clearRouteMappingOverlay(true /* force */)
            _showPlanOnFlyView(overlayData)
        }

        if (flyView.mapControl) {
            flyView.mapControl._updateRouteMappingCoverage()
        }
        return flyView.routeMappingTransectPath
                && flyView.routeMappingTransectPath.length >= 2
    }

    // Called from save popup: opens file dialog with the entered task name.
    function saveMappingTask(taskName) {
        if (taskSettingsPanel.flushPendingWrites) {
            taskSettingsPanel.flushPendingWrites()
        }
        var safeTaskName = taskName.trim().replace(new RegExp('[\\\\/:*?"<>|]', "g"), "_")
        _pendingMappingTaskName = taskName.trim()
        fileDialog.title = qsTr("Choose Where to Save Mapping Task")
        fileDialog.nameFilters = _planMasterController.saveNameFilters
        fileDialog.defaultSuffix = "plan"
        fileDialog.suggestedFileName = safeTaskName + ".plan"
        var importedFolder = _folderFromPlanFile(_importedMappingPlanPath)
        if (importedFolder !== "") {
            fileDialog.folder = importedFolder
        }
        fileDialog.openForSave()
    }

    // Exit always navigates to Fly View. Only a route sent through Upload is
    // retained as the frozen yellow overlay; otherwise resync Fly View from the
    // vehicle like stock QGC after leaving Plan View.
    function exitRouteMappingPage() {
        var currentSignature = _routeMappingPlanSignature()
        var hasUnuploadedEdits = _editingUploadedPlan
                && _editBaselineSignature !== ""
                && currentSignature !== _editBaselineSignature
        if (_routeMappingPlanUploaded && !hasUnuploadedEdits) {
            flyView.hideVehicleMissionForUnuploadedRoute = false
            // Keep Fly View's mission list in sync with the vehicle so the
            // trailing RTL/Land item is present when Start Mission runs.
            var uploadedFlyPlanController = flyView.planController
            if (uploadedFlyPlanController && !uploadedFlyPlanController.offline) {
                uploadedFlyPlanController.showPlanFromManagerVehicle()
            }
            _restoreUploadedRouteMappingOverlay()
        } else {
            if (mainWindow.uploadedMissionEditor === "agricultureSpraying") {
                mainWindow.clearUploadedMissionEditor()
            }
            _routeMappingPlanUploaded = false
            _editingUploadedPlan = false
            flyView.clearRouteMappingOverlay(true /* force */)
            flyView.planEditMode = false

            // Stock QGC keeps Fly View synced to the vehicle mission after leaving
            // the editor. Never wipe Fly plan items here — that hides Start Mission
            // even when the vehicle still holds a valid uploaded survey.
            var flyPlanController = flyView.planController
            if (flyPlanController && !flyPlanController.offline) {
                flyView.hideVehicleMissionForUnuploadedRoute = false
                flyPlanController.showPlanFromManagerVehicle()
            } else {
                flyView.hideVehicleMissionForUnuploadedRoute = true
                if (flyPlanController && flyPlanController.containsItems) {
                    flyPlanController.removeAll()
                    flyPlanController.dirty = false
                    flyPlanController.missionController.setCurrentPlanViewSeqNum(0, true)
                }
            }
        }
        returnToFlyView()
    }

    // Stable representation of the editable survey. QGC's controller dirty
    // state is intentionally not used because opening an editor can change it
    // without any user-visible plan change.
    function _routeMappingPlanSignature() {
        var surveyItem = _cachedSurveyItem ? _cachedSurveyItem : _taskSettingsSurveyItem
        if (!surveyItem || !surveyItem.surveyAreaPolygon) {
            return ""
        }

        function coordinateSignature(coordinate) {
            if (!coordinate || !coordinate.isValid) {
                return "invalid"
            }
            return Number(coordinate.latitude).toFixed(7)
                    + "," + Number(coordinate.longitude).toFixed(7)
                    + "," + Number(coordinate.altitude).toFixed(2)
        }

        function factSignature(fact) {
            return fact ? String(fact.rawValue) : ""
        }

        var parts = []
        var polygon = surveyItem.surveyAreaPolygon
        parts.push("polygon:" + polygon.count)
        for (var p = 0; p < polygon.count; p++) {
            parts.push(coordinateSignature(polygon.vertexCoordinate(p)))
        }

        var transects = surveyItem.visualTransectPoints
        parts.push("transects:" + transects.length)
        for (var t = 0; t < transects.length; t++) {
            parts.push(coordinateSignature(transects[t]))
        }

        parts.push("angle:" + factSignature(surveyItem.gridAngle))
        parts.push("turn:" + factSignature(surveyItem.turnAroundDistance))
        // Include the pattern speed state so Exit can distinguish an actual
        // user edit from simply opening and closing the editor.
        parts.push("patternSpeedEnabled:" + String(surveyItem.specifyPatternFlightSpeed))
        parts.push("patternSpeed:" + factSignature(surveyItem.patternFlightSpeed))
        if (surveyItem.cameraCalc) {
            parts.push("altMode:" + String(surveyItem.cameraCalc.distanceMode))
            parts.push("alt:" + factSignature(surveyItem.cameraCalc.distanceToSurface))
            parts.push("side:" + factSignature(surveyItem.cameraCalc.adjustedFootprintSide))
            parts.push("front:" + factSignature(surveyItem.cameraCalc.adjustedFootprintFrontal))
            parts.push("sideLap:" + factSignature(surveyItem.cameraCalc.sideOverlap))
            parts.push("frontLap:" + factSignature(surveyItem.cameraCalc.frontalOverlap))
        }

        for (var i = 0; i < _missionController.visualItems.count; i++) {
            var item = _missionController.visualItems.get(i)
            if (item && item.isTakeoffItem) {
                parts.push("takeoff:" + coordinateSignature(item.coordinate))
                parts.push("takeoffAlt:" + factSignature(item.altitude))
                break
            }
        }
        return parts.join("|")
    }

    // Demo-only helpers (logic copied from QGC MainWindow / FlyView — kept here so core QGC files stay unchanged)
    // Saves plan to temp file, loads it on Fly View, and uploads to vehicle.
    function _transferPlanToFlyView() {
        var savePath = QGroundControl.settingsManager.appSettings.missionSavePath
        if (!savePath) {
            mainWindow.showMessageDialog(
                        qsTr("Save"),
                        qsTr("Mission save path must be set in Application Settings."))
            return { success: false, uploaded: false }
        }

        // Capture overlay while Route Mapping survey cache is still valid.
        // showFlyView() clears _cachedSurveyItem via onVisibleChanged.
        if (!_hasCalculatedSurvey) {
            _missionMapVisualsEnabled = true
            _updateCachedSurveyItem()
        }
        var routeMappingOverlayData = _routeMappingOverlayData()

        var separator = savePath.endsWith("/") ? "" : "/"
        var transferPlanFile = savePath + separator + "route_mapping_transfer.plan"

        _planMasterController.saveToFile(transferPlanFile)
        _persistUploadedRouteMappingPlan()

        var flyPlanController = flyView.planController
        flyPlanController.loadFromFile(transferPlanFile)

        if (!flyPlanController.containsItems) {
            mainWindow.showMessageDialog(
                        qsTr("Save"),
                        qsTr("Unable to load the route mapping plan on the Fly screen."))
            return { success: false, uploaded: false }
        }

        planView._planMasterController.loadFromFile(transferPlanFile)
        _planMasterController.dirty = false

        // Apply overlay before switching views so Fly View map already has paths
        // when it becomes visible.
        _showPlanOnFlyView(routeMappingOverlayData)
        if (!flyView.routeMappingTransectPath || flyView.routeMappingTransectPath.length < 2) {
            flyView._routeMappingOverlayFromMission()
        }

        mainWindow.showFlyView()

        if (flyView.mapControl) {
            Qt.callLater(function() {
                if (flyView.mapControl) {
                    flyView.mapControl._updateRouteMappingCoverage()
                }
            })
        }

        // After the plan is on Fly View and uploaded, Start Mission appears under
        // Actions when guidedController.showStartMission becomes true.
        return { success: true, uploaded: _tryUploadFlyViewPlan(flyPlanController) }
    }

    // Builds boundary/transect path data for the Fly View map overlay.
    function _routeMappingOverlayData() {
        if (!_hasCalculatedSurvey) {
            return null
        }

        var boundary = []
        var polygonPath = _cachedSurveyItem.surveyAreaPolygon.path
        for (var i = 0; i < polygonPath.length; i++) {
            var boundaryCoord = polygonPath[i]
            boundary.push(QtPositioning.coordinate(boundaryCoord.latitude,
                                                   boundaryCoord.longitude,
                                                   boundaryCoord.altitude))
        }
        if (boundary.length >= 3) {
            boundary.push(boundary[0])
        }

        var transectPath = []
        var visualTransectPoints = _cachedSurveyItem.visualTransectPoints
        for (var j = 0; j < visualTransectPoints.length; j++) {
            var transectCoord = visualTransectPoints[j]
            transectPath.push(QtPositioning.coordinate(transectCoord.latitude,
                                                       transectCoord.longitude,
                                                       transectCoord.altitude))
        }

        var takeoffCoord = QtPositioning.coordinate()
        for (var t = 0; t < _missionController.visualItems.count; t++) {
            var takeoffItem = _missionController.visualItems.get(t)
            if (takeoffItem && takeoffItem.isTakeoffItem && takeoffItem.coordinate
                    && takeoffItem.coordinate.isValid) {
                takeoffCoord = QtPositioning.coordinate(takeoffItem.coordinate.latitude,
                                                        takeoffItem.coordinate.longitude,
                                                        takeoffItem.coordinate.altitude)
                break
            }
        }

        return {
            boundaryPath: boundary,
            transectPath: transectPath,
            takeoffCoordinate: takeoffCoord,
            entryCoordinate: _cachedSurveyItem.coordinate,
            exitCoordinate: _cachedSurveyItem.exitCoordinate,
            entryHeading: _surveyStartHeading,
            exitHeading: _surveyEndHeading,
            plannedPhotoCount: 0
        }
    }

    // Applies boundary/transect overlay lines onto the Fly View map.
    function _showPlanOnFlyView(routeMappingOverlayData) {
        flyView.planEditMode = false
        flyView._editingLayer = flyView._layerMission
        flyView._missionController.setCurrentPlanViewSeqNum(0, true)

        // Never replace a frozen survey graphic after transfer / mid-mission.
        if (flyView._routeMappingOverlayLocked
                || (QGroundControl.multiVehicleManager.activeVehicle
                    && (QGroundControl.multiVehicleManager.activeVehicle.flying
                        || QGroundControl.multiVehicleManager.activeVehicle.armed)
                    && flyView.routeMappingTransectPath
                    && flyView.routeMappingTransectPath.length >= 2)) {
            return
        }

        if (routeMappingOverlayData) {
            flyView.routeMappingBoundaryPath = routeMappingOverlayData.boundaryPath
            flyView.routeMappingTransectPath = routeMappingOverlayData.transectPath
            flyView.routeMappingTakeoffCoordinate = routeMappingOverlayData.takeoffCoordinate
                    ? routeMappingOverlayData.takeoffCoordinate : QtPositioning.coordinate()
            flyView.routeMappingEntryCoordinate = routeMappingOverlayData.entryCoordinate
            flyView.routeMappingExitCoordinate = routeMappingOverlayData.exitCoordinate
            flyView.routeMappingEntryHeading = routeMappingOverlayData.entryHeading
            flyView.routeMappingExitHeading = routeMappingOverlayData.exitHeading
            // Photo progress UI is Route Mapping only.
            flyView.routeMappingPlannedPhotoCount = 0
            if (routeMappingOverlayData.transectPath
                    && routeMappingOverlayData.transectPath.length >= 2) {
                flyView._routeMappingOverlayLocked = true
            }
        }

        if (flyView.mapControl) {
            flyView.mapControl._updateRouteMappingCoverage()
        }
    }

    // Copies the unflattened survey geometry to Fly View while Route Mapping
    // still owns the SurveyComplexItem. MAVLink mission upload contains only
    // simple waypoints, which cannot reconstruct the original polygon exactly.
    function _syncRouteMappingOverlayToFlyView(replaceExisting) {
        if (!_hasCalculatedSurvey) {
            _missionMapVisualsEnabled = true
            _updateCachedSurveyItem()
        }

        var routeMappingOverlayData = _routeMappingOverlayData()
        if (!routeMappingOverlayData
                || !routeMappingOverlayData.transectPath
                || routeMappingOverlayData.transectPath.length < 2) {
            return false
        }

        if (flyView._routeMappingOverlayLocked) {
            if (!replaceExisting) {
                return true
            }

            var vehicle = QGroundControl.multiVehicleManager.activeVehicle
            if (vehicle && (vehicle.flying || vehicle.armed)) {
                // Never replace an active flight's frozen planned geometry.
                return false
            }
            flyView.clearRouteMappingOverlay(true /* force */)
        }

        _showPlanOnFlyView(routeMappingOverlayData)
        return flyView.routeMappingTransectPath
                && flyView.routeMappingTransectPath.length >= 2
    }

    // Uploads the loaded plan to the connected vehicle if ready.
    function _tryUploadFlyViewPlan(flyPlanController) {
        if (!flyPlanController || flyPlanController.offline) {
            return false
        }
        if (flyPlanController.readyForSaveState() !== VisualMissionItem.ReadyForSave) {
            mainWindow.showMessageDialog(
                        qsTr("Upload"),
                        qsTr("Plan is not ready to upload yet. Wait for terrain/data to finish, then use Save/Upload on Fly View."))
            return false
        }
        flyPlanController.upload()
        return true
    }

    // Returns the index of an existing trace point within maxMeters, or -1.
    function _nearbyTracePoint(coordinate, maxMeters) {
        if (!coordinate || !coordinate.isValid) return -1
        for (var i = 0; i < fieldTracePointsModel.count; i++) {
            var p = fieldTracePointsModel.get(i)
            var d = coordinate.distanceTo(QtPositioning.coordinate(p.lat, p.lon, p.alt))
            if (d <= maxMeters) return i
        }
        return -1
    }

    // Add button on map: appends a boundary point at map center.
    // Does nothing when another waypoint is already within 2 m of that spot —
    // pan the map first, then press + to place the next point.
    function addRouteMappingPoint() {
        if (!_routeBoundaryEditable || taskSettingsPanel.routeMode !== 0) {
            console.log("[RouteMapping] Waypoint add skipped: route boundary not editable")
            return
        }

        var coord = mapCenter()
        var nearbyIndex = _nearbyTracePoint(coord, 2.0)
        if (nearbyIndex >= 0) {
            console.log("[RouteMapping] Waypoint add blocked: too close to waypoint",
                        nearbyIndex + 1,
                        "lat:", coord.latitude, "lon:", coord.longitude)
            return
        }

        fieldTracePointsModel.append({
                                         lat: coord.latitude,
                                         lon: coord.longitude,
                                         alt: coord.altitude
                                     })
        console.log("[RouteMapping] Waypoint created:",
                    fieldTracePointsModel.count,
                    "lat:", coord.latitude,
                    "lon:", coord.longitude,
                    "alt:", coord.altitude)
        if (fieldTracePointsModel.count >= 3) {
            _updateSurveyPolygonFromTrace(_cachedSurveyItem)
        }
    }

    // Inserts a boundary point at a specific index (e.g. midpoint on a segment).
    // Skips the insert when the coordinate is already occupied by an existing point.
    function insertRouteMappingPoint(insertIndex, coordinate) {
        if (!_routeBoundaryEditable || !coordinate || !coordinate.isValid) {
            console.log("[RouteMapping] Waypoint insert skipped: invalid state or coordinate")
            return
        }

        var nearbyIndex = _nearbyTracePoint(coordinate, 2.0)
        if (nearbyIndex >= 0) {
            console.log("[RouteMapping] Waypoint insert blocked: too close to waypoint",
                        nearbyIndex + 1,
                        "lat:", coordinate.latitude, "lon:", coordinate.longitude)
            return
        }

        var boundedIndex = Math.max(0, Math.min(insertIndex, fieldTracePointsModel.count))
        fieldTracePointsModel.insert(boundedIndex, {
                                         lat: coordinate.latitude,
                                         lon: coordinate.longitude,
                                         alt: coordinate.altitude
                                     })
        console.log("[RouteMapping] Waypoint inserted at index",
                    boundedIndex + 1,
                    "of", fieldTracePointsModel.count,
                    "lat:", coordinate.latitude,
                    "lon:", coordinate.longitude,
                    "alt:", coordinate.altitude)
        _selectedWaypointIndex = -1
        if (fieldTracePointsModel.count >= 3) {
            _updateSurveyPolygonFromTrace(_cachedSurveyItem)
        }
    }

    PlanMasterController {
        id: planMasterController
        flyView: false
        missionMode: "agricultureSpraying"

        Component.onCompleted: {
            _planMasterController.start()
            _missionController.setCurrentPlanViewSeqNum(0, true)
            _updateCachedSurveyItem()
        }

        function waitingOnIncompleteDataMessage(save) {
            var saveOrUpload = save ? qsTr("Save") : qsTr("Upload")
            mainWindow.showMessageDialog(
                        qsTr("Unable to %1").arg(saveOrUpload),
                        qsTr("Plan has incomplete items. Complete all items and %1 again.").arg(saveOrUpload))
        }

        function waitingOnTerrainDataMessage(save) {
            var saveOrUpload = save ? qsTr("Save") : qsTr("Upload")
            mainWindow.showMessageDialog(
                        qsTr("Unable to %1").arg(saveOrUpload),
                        qsTr("Plan is waiting on terrain data from server for correct altitude values."))
        }

        function checkReadyForSaveUpload(save) {
            if (readyForSaveState() === VisualMissionItem.NotReadyForSaveData) {
                waitingOnIncompleteDataMessage(save)
                return false
            } else if (readyForSaveState() === VisualMissionItem.NotReadyForSaveTerrain) {
                waitingOnTerrainDataMessage(save)
                return false
            }
            return true
        }

        // Mirrors the native Plan View upload flow so all mission, fence and
        // rally data continue through PlanMasterController::sendToVehicle.
        function upload() {
            if (!checkReadyForSaveUpload(false /* save */)) {
                return false
            }

            switch (_missionController.sendToVehiclePreCheck()) {
            case MissionController.SendToVehiclePreCheckStateOk:
                sendToVehicle()
                return true
            case MissionController.SendToVehiclePreCheckStateNoActiveVehicle:
                mainWindow.showMessageDialog(
                            qsTr("Upload"),
                            qsTr("Connect a vehicle before uploading the plan."))
                return false
            case MissionController.SendToVehiclePreCheckStateActiveMission:
                mainWindow.showMessageDialog(
                            qsTr("Send To Vehicle"),
                            qsTr("Current mission must be paused prior to uploading a new Plan"))
                return false
            case MissionController.SendToVehiclePreCheckStateFirwmareVehicleMismatch:
                mainWindow.showMessageDialog(
                            qsTr("Plan Upload"),
                            qsTr("This Plan was created for a different firmware or vehicle type than the firmware/vehicle type of vehicle you are uploading to. "
                                 + "This can lead to errors or incorrect behavior. "
                                 + "It is recommended to recreate the Plan for the correct firmware/vehicle type.\n\n"
                                 + "Click 'Ok' to upload the Plan anyway."),
                            Dialog.Ok | Dialog.Cancel,
                            function() {
                                var overlayData = _root._routeMappingOverlayData()
                                if (overlayData && overlayData.transectPath
                                        && overlayData.transectPath.length >= 2) {
                                    _root._uploadedRouteMappingOverlayData = overlayData
                                    _root._routeMappingUploadPending = true
                                }
                                planMasterController.sendToVehicle()
                            })
                return false
            }
            return false
        }

        function saveToSelectedFile() {
            fileDialog.title = qsTr("Save Route Mapping Plan")
            fileDialog.planFiles = true
            fileDialog.nameFilters = _planMasterController.saveNameFilters
            fileDialog.openForSave()
        }
    }

    QGCFileDialog {
        id: fileDialog
        folder: _appSettings ? _appSettings.missionSavePath : ""

        property bool planFiles: true
        property var _appSettings: QGroundControl.settingsManager.appSettings

        onAcceptedForLoad: (file) => {
                               _root.loadRouteMappingPlan(file)
                               close()
                           }

        onAcceptedForSave: (file) => {
                               if (taskSettingsPanel.flushPendingWrites) {
                                   taskSettingsPanel.flushPendingWrites()
                               }
                               _planMasterController.saveToFile(file)
                               hideTaskSettings()
                               _savedMappingTaskName = _pendingMappingTaskName
                               _importedMappingPlanPath = file
                               _importedMappingTaskName = _pendingMappingTaskName
                               _showSavedMappingOverlay = true
                               close()
                           }
    }

    Item {
        id: routeContent
        anchors.fill: parent

        FlightMap {
            id: routeMap
            anchors.fill: parent
            mapName: "RouteMapping"
            allowGCSLocationCenter: true
            allowVehicleLocationCenter: true
            // The settings panel consumes pointer events within its own bounds.
            // Keep map gestures enabled so interaction follows the cursor even
            // while the panel remains open.
            allowZoomGestures: true
            planView: true
            zoomLevel: QGroundControl.flightMapZoom
            center: QGroundControl.flightMapPosition

            readonly property real _leftToolWidth: ScreenTools.defaultFontPixelWidth * 0.5
            readonly property real _mapMargin: ScreenTools.defaultFontPixelHeight * 0.5
            property rect centerViewport: Qt.rect(
                                              _leftToolWidth,
                                              mainToolBar.height + _mapMargin,
                                              Math.max(0, width - _leftToolWidth - ScreenTools.defaultFontPixelWidth),
                                              Math.max(0, height - mainToolBar.height - (_mapMargin * 2))
                                              )

            onZoomLevelChanged: QGroundControl.flightMapZoom = routeMap.zoomLevel
            onCenterChanged: QGroundControl.flightMapPosition = routeMap.center

            Repeater {
                model: _root._showMissionOnMap ? _missionController.visualItems : null
                delegate: MissionItemMapVisual {
                    map: routeMap
                    // Route Mapping draws its own clean boundary and transects.
                    // Hide only the standard filled survey visual, which turns
                    // the entire polygon red when terrain collision is detected.
                    opacity: object && object.surveyAreaPolygon ? 0 : 1
                    interactive: false
                    vehicle: _planMasterController.controllerVehicle
                    onClicked: (sequenceNumber) => _missionController.setCurrentPlanViewSeqNum(sequenceNumber, false)
                }
            }

            MapItemView {
                visible: _root._areaRouteActive
                model: fieldTracePointsModel

                delegate: MapQuickItem {
                    id: fieldWaypointMapItem
                    property int waypointIndex: index

                    coordinate: QtPositioning.coordinate(model.lat, model.lon, model.alt)
                    anchorPoint.x: fieldWaypointMarker.markerCenter
                    anchorPoint.y: fieldWaypointMarker.markerCenter
                    z: QGroundControl.zOrderMapItems + 3

                    sourceItem: Item {
                        id: fieldWaypointMarker
                        readonly property real markerCenter: ScreenTools.defaultFontPixelHeight

                        width: ScreenTools.defaultFontPixelWidth * 10
                        height: ScreenTools.defaultFontPixelHeight * 2

                        Rectangle {
                            id: waypointDot
                            x: fieldWaypointMarker.markerCenter - width / 2
                            y: fieldWaypointMarker.markerCenter - height / 2
                            width: ScreenTools.defaultFontPixelHeight * 0.55
                            height: width
                            radius: width / 2
                            color: "magenta"
                            border.color: "white"
                            border.width: 2
                        }

                        QGCMouseArea {
                            x: 0
                            y: 0
                            width: ScreenTools.defaultFontPixelHeight * 2
                            height: width
                            enabled: _root._routeBoundaryEditable
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true
                            onClicked: _root._selectedWaypointIndex = waypointIndex
                            onPositionChanged: (mouse) => {
                                                   if (!pressed) {
                                                       return
                                                   }
                                                   var mapPoint = fieldWaypointMarker.mapToItem(routeMap, mouse.x, mouse.y)
                                                   var newCoordinate = routeMap.toCoordinate(mapPoint, false)
                                                   _root.moveRouteMappingPoint(waypointIndex, newCoordinate, false)
                                               }
                            onReleased: {
                                if (fieldTracePointsModel.count >= 3) {
                                    var point = fieldTracePointsModel.get(waypointIndex)
                                    _root.moveRouteMappingPoint(
                                                waypointIndex,
                                                QtPositioning.coordinate(point.lat, point.lon, point.alt),
                                                true)
                                }
                            }
                        }

                        Rectangle {
                            anchors.left: waypointDot.right
                            anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.6
                            anchors.verticalCenter: waypointDot.verticalCenter
                            width: ScreenTools.defaultFontPixelHeight * 1.35
                            height: width
                            radius: width / 2
                            color: "#d93025"
                            border.color: "white"
                            border.width: 1
                            visible: _root._selectedWaypointIndex === waypointIndex

                            QGCLabel {
                                anchors.centerIn: parent
                                text: "\u2212"
                                color: "white"
                                font.bold: true
                                font.pixelSize: parent.height * 0.72
                            }

                            QGCMouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: _root.requestDeleteRouteMappingPoint(waypointIndex)
                            }
                        }
                    }

                }
            }

            MapPolyline {
                line.color: _root._showSavedMappingOverlay
                            ? Qt.rgba(1.0, 0.94, 0.38, 0.78)
                            : "white"
                line.width: _root._showSavedMappingOverlay ? 1.5 : 2
                path: {
                    var boundaryPoints = []
                    for (var i = 0; i < fieldTracePointsModel.count; i++) {
                        var point = fieldTracePointsModel.get(i)
                        boundaryPoints.push(QtPositioning.coordinate(point.lat, point.lon, point.alt))
                    }
                    if (boundaryPoints.length >= 3) {
                        boundaryPoints.push(boundaryPoints[0])
                    }
                    return boundaryPoints
                }
                visible: _root._areaRouteActive && fieldTracePointsModel.count >= 2
                z: QGroundControl.zOrderMapItems + 1
            }

            MapItemView {
                model: _root._routeSegmentInsertPoints

                delegate: MapQuickItem {
                    coordinate: modelData.coordinate
                    anchorPoint.x: segmentAddMarker.width / 2
                    anchorPoint.y: segmentAddMarker.height / 2
                    z: QGroundControl.zOrderMapItems + 5

                    sourceItem: Rectangle {
                        id: segmentAddMarker
                        width: ScreenTools.defaultFontPixelHeight * 1.75
                        height: width
                        radius: width / 2
                        color: Qt.rgba(0, 0, 0, 0.22)
                        border.color: Qt.rgba(1, 1, 1, 0.92)
                        border.width: 1

                        QGCLabel {
                            anchors.centerIn: parent
                            text: "+"
                            color: "white"
                            font.pixelSize: parent.height * 0.76
                            font.weight: Font.Light
                        }

                        QGCMouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: _root.insertRouteMappingPoint(
                                           modelData.insertIndex,
                                           modelData.coordinate)
                        }
                    }
                }
            }

            MapPolygon {
                path: _root._hasCalculatedSurvey && _root._cachedSurveyItem
                      ? _root._cachedSurveyItem.surveyAreaPolygon.path
                      : []
                color: Qt.rgba(1.0, 0.72, 0.0, 0.20)
                border.width: 0
                visible: _root._showSavedMappingOverlay && _root._hasCalculatedSurvey
                z: QGroundControl.zOrderMapItems
            }

            MapPolyline {
                line.color: Qt.rgba(1.0, 0.94, 0.38, 0.78)
                line.width: 2
                path: _root._hasCalculatedSurvey && _root._cachedSurveyItem
                      ? _root._cachedSurveyItem.visualTransectPoints
                      : []
                visible: _root._hasCalculatedSurvey
                z: QGroundControl.zOrderMapItems + 2
            }

            MapQuickItem {
                coordinate: _root._cachedSurveyItem
                            ? _root._cachedSurveyItem.coordinate
                            : QtPositioning.coordinate()
                anchorPoint.x: surveyStartMarker.dotCenter
                anchorPoint.y: surveyStartMarker.dotCenter
                visible: _root._hasCalculatedSurvey
                         && _root._cachedSurveyItem.coordinate.isValid
                z: QGroundControl.zOrderMapItems + 4

                sourceItem: Item {
                    id: surveyStartMarker
                    readonly property real markerSize: ScreenTools.defaultFontPixelHeight * 0.85
                    readonly property real dotCenter: markerSize / 2

                    width: markerSize * 2.25
                    height: markerSize

                    transform: Rotation {
                        origin.x: surveyStartMarker.dotCenter
                        origin.y: surveyStartMarker.dotCenter
                        angle: _root._surveyStartHeading - routeMap.bearing - 90
                    }

                    Canvas {
                        anchors.fill: parent

                        onPaint: {
                            var ctx = getContext("2d")
                            var centerY = height / 2
                            var shaftStart = surveyStartMarker.markerSize * 0.55
                            var arrowTip = width - 1
                            var arrowBase = width - surveyStartMarker.markerSize * 0.55
                            var arrowHalfHeight = surveyStartMarker.markerSize * 0.34

                            function drawArrow(color, lineWidth) {
                                ctx.strokeStyle = color
                                ctx.lineWidth = lineWidth
                                ctx.lineCap = "round"
                                ctx.lineJoin = "round"
                                ctx.beginPath()
                                ctx.moveTo(shaftStart, centerY)
                                ctx.lineTo(arrowTip, centerY)
                                ctx.moveTo(arrowBase, centerY - arrowHalfHeight)
                                ctx.lineTo(arrowTip, centerY)
                                ctx.lineTo(arrowBase, centerY + arrowHalfHeight)
                                ctx.stroke()
                            }

                            ctx.clearRect(0, 0, width, height)
                            drawArrow("white", 5)
                            drawArrow("#19d12f", 3)
                        }
                    }

                    Rectangle {
                        width: surveyStartMarker.markerSize
                        height: width
                        radius: width / 2
                        color: "#19d12f"
                        border.color: "white"
                        border.width: 2
                    }
                }
            }

            MapQuickItem {
                coordinate: _root._hasCalculatedSurvey
                            ? _root._cachedSurveyItem.surveyAreaPolygon.center
                            : QtPositioning.coordinate()
                anchorPoint.x: savedTaskMarker.width / 2
                anchorPoint.y: savedTaskMarker.height / 2
                visible: _root._showSavedMappingOverlay
                         && _root._savedMappingTaskName !== ""
                         && coordinate.isValid
                z: QGroundControl.zOrderMapItems + 6

                sourceItem: Item {
                    id: savedTaskMarker
                    width: ScreenTools.defaultFontPixelWidth * 16
                    height: ScreenTools.defaultFontPixelHeight * 2.8

                    QGCLabel {
                        anchors.bottom: savedCheckMarker.top
                        anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.08
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        text: _root._savedMappingTaskName
                        color: "white"
                        font.pointSize: ScreenTools.smallFontPointSize
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.55)
                    }

                    Rectangle {
                        id: savedCheckMarker
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: ScreenTools.defaultFontPixelHeight * 1.65
                        height: width
                        radius: width / 2
                        color: "#16c943"
                        border.width: 2
                        border.color: "#202020"

                        QGCLabel {
                            anchors.centerIn: parent
                            text: "\u2713"
                            color: "white"
                            font.bold: true
                            font.pixelSize: parent.height * 0.58
                        }
                    }
                }
            }

            MapQuickItem {
                coordinate: _root._cachedSurveyItem
                            ? _root._cachedSurveyItem.exitCoordinate
                            : QtPositioning.coordinate()
                anchorPoint.x: surveyEndMarker.dotCenter
                anchorPoint.y: surveyEndMarker.dotCenter
                visible: _root._hasCalculatedSurvey
                         && _root._cachedSurveyItem.exitCoordinate.isValid
                z: QGroundControl.zOrderMapItems + 4

                sourceItem: Item {
                    id: surveyEndMarker
                    readonly property real markerSize: ScreenTools.defaultFontPixelHeight * 0.85
                    readonly property real dotCenter: markerSize / 2

                    width: markerSize * 2.25
                    height: markerSize

                    transform: Rotation {
                        origin.x: surveyEndMarker.dotCenter
                        origin.y: surveyEndMarker.dotCenter
                        angle: _root._surveyEndHeading - routeMap.bearing - 90
                    }

                    Canvas {
                        anchors.fill: parent

                        onPaint: {
                            var ctx = getContext("2d")
                            var centerY = height / 2
                            var shaftStart = surveyEndMarker.markerSize * 0.55
                            var arrowTip = width - 1
                            var arrowBase = width - surveyEndMarker.markerSize * 0.55
                            var arrowHalfHeight = surveyEndMarker.markerSize * 0.34

                            function drawArrow(color, lineWidth) {
                                ctx.strokeStyle = color
                                ctx.lineWidth = lineWidth
                                ctx.lineCap = "round"
                                ctx.lineJoin = "round"
                                ctx.beginPath()
                                ctx.moveTo(shaftStart, centerY)
                                ctx.lineTo(arrowTip, centerY)
                                ctx.moveTo(arrowBase, centerY - arrowHalfHeight)
                                ctx.lineTo(arrowTip, centerY)
                                ctx.lineTo(arrowBase, centerY + arrowHalfHeight)
                                ctx.stroke()
                            }

                            ctx.clearRect(0, 0, width, height)
                            drawArrow("white", 5)
                            drawArrow("#ffc400", 3)
                        }
                    }

                    Rectangle {
                        width: surveyEndMarker.markerSize
                        height: width
                        radius: width / 2
                        color: "#ffc400"
                        border.color: "white"
                        border.width: 2
                    }
                }
            }

            MissionLineView {
                showSpecialVisual: _missionController.isROIBeginCurrentItem
                model: _root._showMissionOnMap ? _missionController.simpleFlightPathSegments : null
            }

            MapItemView {
                model: QGroundControl.multiVehicleManager.vehicles
                delegate: VehicleMapItem {
                    vehicle: object
                    coordinate: object.coordinate
                    map: routeMap
                    size: ScreenTools.defaultFontPixelHeight * 3
                    z: QGroundControl.zOrderMapItems - 1
                }
            }

            Item {
                id: centerTarget
                anchors.centerIn: parent
                width: ScreenTools.defaultFontPixelHeight * 2.5
                height: width
                z: QGroundControl.zOrderWidgets + 10

                property real lineLength: width * 0.45
                property real centerGap: ScreenTools.defaultFontPixelHeight * 0.5

                Repeater {
                    model: [
                        { x: parent.width / 2 - 1, y: 0, w: 2, h: centerTarget.lineLength },
                        { x: parent.width / 2 - 1, y: parent.height - centerTarget.lineLength, w: 2, h: centerTarget.lineLength },
                        { x: 0, y: parent.height / 2 - 1, w: centerTarget.lineLength, h: 2 },
                        { x: parent.width - centerTarget.lineLength, y: parent.height / 2 - 1, w: centerTarget.lineLength, h: 2 }
                    ]

                    Rectangle {
                        x: modelData.x
                        y: modelData.y
                        width: modelData.w
                        height: modelData.h
                        color: "white"
                    }
                }
            }
        }

        Rectangle {
            id: routeBackButton
            anchors.left: parent.left
            anchors.leftMargin: _taskSettingsOpenProgress
                                * (_taskSettingsPanelWidth + ScreenTools.defaultFontPixelWidth * 0.5)
            anchors.verticalCenter: parent.verticalCenter
            width: ScreenTools.defaultFontPixelHeight * 3.1
            height: ScreenTools.defaultFontPixelHeight * 5
            radius: 0
            color: routeBackMouseArea.pressed
                   ? Qt.rgba(0.12, 0.12, 0.14, 0.55)
                   : Qt.rgba(0.12, 0.12, 0.14, 0.38)
            opacity: _backButtonVisibleProgress
            z: QGroundControl.zOrderWidgets + 12

            transform: Translate {
                x: (1.0 - _backButtonVisibleProgress) * -routeBackButton.width * 0.55
            }

            Image {
                anchors.centerIn: parent
                source: "/res/caret-left.png"
                width: ScreenTools.defaultFontPixelHeight * 1.4
                height: width
                fillMode: Image.PreserveAspectFit
                rotation: (1.0 - _taskSettingsOpenProgress) * 180
            }

            RippleEffect {
                id: routeBackRipple
                rippleColor: Qt.rgba(1, 1, 1, 0.35)
                clipRadius: 0
            }

            // Attached navigator: collapse or reopen Task Settings in place.
            QGCMouseArea {
                id: routeBackMouseArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: function(mouse) {
                    routeBackRipple.tap(mouse.x, mouse.y)
                    _root.toggleTaskSettings()
                }
            }
        }

        Item {
            id: taskSettingsHost
            anchors.left: parent.left
            anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.5
            anchors.top: parent.top
            anchors.topMargin: mainToolBar.height + ScreenTools.defaultFontPixelHeight * 0.5
            anchors.bottom: parent.bottom
            anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.6
            width: _taskSettingsPanelWidth
            opacity: _taskSettingsOpenProgress
            visible: _taskSettingsVisible || _taskSettingsOpenProgress > 0
            enabled: _taskSettingsOpenProgress > 0.05
            z: QGroundControl.zOrderWidgets + 11

            transform: Translate {
                x: (1.0 - _taskSettingsOpenProgress) * -taskSettingsHost.width
            }

            RouteMappingTaskSettings {
                id: taskSettingsPanel
                anchors.fill: parent
                patternSectionTitle: qsTr("Agriculture Spraying Pattern")
                showPhotoSettings: false
                showSpraySettings: true
                surveyItem: _root._taskSettingsSurveyItem ? _root._taskSettingsSurveyItem : _root._cachedSurveyItem
                takeoffItem: {
                    // Depend on count so this re-evaluates when takeoff is added/removed.
                    var itemCount = _missionController.visualItems.count
                    return itemCount > 1 ? _root._findTakeoffItem() : null
                }

                onAreaRouteSelected: _root.startAreaRouteSession()
            }

            Rectangle {
                anchors.left: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: ScreenTools.defaultFontPixelWidth * 0.35
                opacity: _taskSettingsOpenProgress * 0.35
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#30000000" }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }

        // Stats panel: mapping area, photo count, estimated flight time.
        Rectangle {

            id: mappingStats
            anchors.top: parent.top
            anchors.topMargin: mainToolBar.height + ScreenTools.defaultFontPixelHeight * 0.5
            anchors.right: parent.right
            anchors.rightMargin: ScreenTools.defaultFontPixelWidth
            width: ScreenTools.defaultFontPixelWidth * 30
            height: statsGrid.implicitHeight + ScreenTools.defaultFontPixelHeight
            radius: ScreenTools.defaultFontPixelWidth * 0.35
            color: Qt.rgba(0.03, 0.03, 0.03, 0.52)
            z: QGroundControl.zOrderWidgets + 10

            GridLayout {
                id: statsGrid
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                anchors.rightMargin: ScreenTools.defaultFontPixelWidth
                columns: 2
                rowSpacing: ScreenTools.defaultFontPixelHeight * 0.35
                columnSpacing: ScreenTools.defaultFontPixelWidth

                QGCLabel { text: qsTr("Mapping Area"); color: "white"; Layout.fillWidth: true }
                QGCLabel { text: _mappingAreaText; color: "white"; font.bold: true; horizontalAlignment: Text.AlignRight; Layout.fillWidth: true }
                QGCLabel { text: qsTr("Est. Flight Time"); color: "white"; Layout.fillWidth: true }
                QGCLabel { text: _flightTimeText; color: "white"; font.bold: true; horizontalAlignment: Text.AlignRight; Layout.fillWidth: true }
                QGCLabel { text: qsTr("Terrain Warning"); color: "#ff6961"; font.bold: true; Layout.fillWidth: true; visible: _hasTerrainCollision }
                QGCLabel { text: qsTr("Collision"); color: "#ff6961"; font.bold: true; horizontalAlignment: Text.AlignRight; Layout.fillWidth: true; visible: _hasTerrainCollision }
            }
        }

        Rectangle {
            id: fieldsPanel
            anchors.right: parent.right
            anchors.top: mappingStats.bottom
            anchors.topMargin: ScreenTools.defaultFontPixelHeight * 2.0
            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.8
            width: Math.min(ScreenTools.defaultFontPixelWidth * 22, parent.width * 0.30)
            height: ScreenTools.defaultFontPixelHeight * 4.8
            radius: ScreenTools.defaultFontPixelWidth * 0.55
            color: Qt.rgba(0, 0, 0, 0.34)
            z: QGroundControl.zOrderWidgets + 11

            Rectangle {
                width: ScreenTools.defaultFontPixelHeight * 0.5
                height: width
                radius: width / 2
                color: "magenta"
                anchors.left: parent.left
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 1.4
                anchors.top: parent.top
                anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.65
            }

            QGCLabel {
                anchors.left: parent.left
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 4.2
                anchors.top: parent.top
                anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.5
                text: qsTr("Fields")
                color: "white"
                font.bold: true
            }

            Rectangle {
                id: plusButton
                anchors.left: parent.left
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 1.0
                anchors.bottom: parent.bottom
                anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.45
                width: ScreenTools.defaultFontPixelHeight * 2.1
                height: width
                radius: _actionButtonRadius
                color: "white"
                border.color: "#78d957"
                border.width: 2
                clip: true

                QGCLabel {
                    anchors.centerIn: parent
                    text: "+"
                    color: "#515151"
                    font.bold: true
                }

                RippleEffect {
                    id: plusRipple
                    rippleColor: Qt.rgba(0, 0, 0, 0.18)
                    clipRadius: _actionButtonRadius
                }

                QGCMouseArea {
                    anchors.fill: parent
                    enabled: _routeBoundaryEditable
                    onClicked: function(mouse) {
                        plusRipple.tap(mouse.x, mouse.y)
                        addRouteMappingPoint()
                    }
                }
            }

            Rectangle {
                id: addFieldButton
                anchors.left: plusButton.right
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.5
                anchors.right: parent.right
                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.75
                anchors.verticalCenter: plusButton.verticalCenter
                height: plusButton.height
                radius: _actionButtonRadius
                color: "white"
                opacity: _canCreateTakeoff ? 1.0 : 0.45
                border.color: _taskSettingsVisible ? "#78d957" : "transparent"
                border.width: _taskSettingsVisible ? 2 : 0
                clip: true

                QGCLabel {
                    id:addbtn
                    anchors.centerIn: parent
                    text: qsTr("Add")
                    color: "#515151"
                    font.weight: Font.DemiBold
                }

                RippleEffect {
                    id: addRipple
                    rippleColor: Qt.rgba(0, 0, 0, 0.18)
                    clipRadius: _actionButtonRadius
                }

                QGCMouseArea {
                    anchors.fill: parent
                    enabled: _canCreateTakeoff
                    cursorShape: _canCreateTakeoff ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                    onClicked: function(mouse) {
                        addRipple.tap(mouse.x, mouse.y)
                        _root.onAddButtonClicked()
                    }
                }

            }

        }

        Column {
            id: exitSaveColumn
            anchors.right: parent.right
            anchors.rightMargin: ScreenTools.defaultFontPixelWidth
            anchors.bottom: parent.bottom
            anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.6
            spacing: ScreenTools.defaultFontPixelHeight * 0.5
            z: QGroundControl.zOrderWidgets + 10

            Rectangle {
                id: routeUploadButton
                readonly property bool uploadEnabled: !_planMasterController.syncInProgress
                                                      && _planMasterController.containsItems
                                                      && !_planMasterController.offline

                width: routeSaveButton.width
                height: routeSaveButton.height
                radius: _actionButtonRadius
                color: "white"
                opacity: uploadEnabled ? 1.0 : 0.55
                clip: true

                Row {
                    id: routeUploadRow
                    anchors.centerIn: parent
                    spacing: ScreenTools.defaultFontPixelWidth * 0.6

                    QGCColoredImage {
                        anchors.verticalCenter: parent.verticalCenter
                        source: "/res/modern-icons/MaterialSymbolsUpload2Rounded.svg"
                        width: ScreenTools.defaultFontPixelHeight * 1.1
                        height: width
                        sourceSize.width: width * Screen.devicePixelRatio
                        sourceSize.height: height * Screen.devicePixelRatio
                        fillMode: Image.PreserveAspectFit
                        // Match Exit icon (/res/exit.png), which is solid black.
                        color: "#000000"
                    }

                    QGCLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        text: _planMasterController.syncInProgress
                              ? qsTr("Uploading...") : qsTr("Upload")
                        color: _routeActionTextColor
                        font.weight: Font.DemiBold
                    }
                }

                RippleEffect {
                    id: uploadRipple
                    rippleColor: Qt.rgba(0, 0, 0, 0.18)
                    clipRadius: _actionButtonRadius
                }

                QGCMouseArea {
                    anchors.fill: parent
                    enabled: routeUploadButton.uploadEnabled
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: function(mouse) {
                        uploadRipple.tap(mouse.x, mouse.y)
                        _root.uploadRouteMappingPlan()
                    }
                    onPressed: routeUploadButton.scale = 0.96
                    onReleased: routeUploadButton.scale = 1.0
                    onCanceled: routeUploadButton.scale = 1.0
                }
            }

            Rectangle {
                id: routeExitButton
                width: routeSaveButton.width
                height: routeSaveButton.height
                radius: _actionButtonRadius
                color: "white"
                clip: true

                Row {
                    id: exitRow
                    anchors.centerIn: parent
                    spacing: ScreenTools.defaultFontPixelWidth * 0.6

                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        source: "/res/exit.png"
                        width: ScreenTools.defaultFontPixelHeight * 1.1
                        height: width
                        fillMode: Image.PreserveAspectFit
                    }

                    QGCLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Exit")
                        color: _routeActionTextColor
                        font.weight: Font.DemiBold
                    }
                }

                RippleEffect {
                    id: exitRipple
                    rippleColor: Qt.rgba(0, 0, 0, 0.18)
                    clipRadius: _actionButtonRadius
                }

                QGCMouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        exitRipple.tap(mouse.x, mouse.y)
                        _root.exitRouteMappingPage()
                    }
                    onPressed: routeExitButton.scale = 0.96
                    onReleased: routeExitButton.scale = 1.0
                    onCanceled: routeExitButton.scale = 1.0
                }
            }


            Rectangle {
                id: routeSaveButton
                width: saveRow.implicitWidth + ScreenTools.defaultFontPixelWidth * 6
                height: ScreenTools.defaultFontPixelHeight * 2
                radius: _actionButtonRadius
                color: "white"
                clip: true

                Row {
                    id: saveRow
                    anchors.centerIn: parent
                    spacing: ScreenTools.defaultFontPixelWidth * 0.5

                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        source: "/res/checkmark_forsave.png"
                        width: ScreenTools.defaultFontPixelHeight * 1.1
                        height: width
                        fillMode: Image.PreserveAspectFit
                    }

                    QGCLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Save")
                        color: _routeActionTextColor
                        font.weight: Font.DemiBold
                    }
                }

                RippleEffect {
                    id: saveRipple
                    rippleColor: Qt.rgba(0, 0, 0, 0.18)
                    clipRadius: _actionButtonRadius
                }

                QGCMouseArea {
                    anchors.fill: parent
                    enabled: _surveyFinished || _canFinishRoute
                    onClicked: function(mouse) {
                        saveRipple.tap(mouse.x, mouse.y)
                        _root.openSaveMappingTaskDialog()
                    }
                }

                // Popup loader for "Saving Mapping Task" name entry dialog.
                Loader {
                    id: taskbar
                    active: false
                    source: "saveMappingTask.qml"
                    property string pendingInitialTaskName: ""

                    onLoaded: {
                        item.saveRequested.connect(_root.saveMappingTask)
                        item.dismissed.connect(function() {
                            Qt.callLater(function() { taskbar.active = false })
                        })
                        if (taskbar.pendingInitialTaskName !== "") {
                            item.initialTaskName = taskbar.pendingInitialTaskName
                            taskbar.pendingInitialTaskName = ""
                        }
                        item.open()
                    }
                }

            }

        }

    }

    Rectangle {
        id: mainToolBar
        property real _missionUploadProgress: 0
        property bool _missionUploadProgressVisible: false

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: ScreenTools.toolbarHeight
        color: Qt.rgba(0, 0, 0, 0.34)
        z: QGroundControl.zOrderWidgets + 20
        visible: !QGroundControl.videoManager.fullScreen && !mainWindow.modeSelectionVisible

        RowLayout {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: ScreenTools.defaultFontPixelWidth
            spacing: ScreenTools.defaultFontPixelWidth * 0.75

            Item {
                id: shreeonLogoButton
                Layout.fillHeight: true
                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 3.2

                Image {
                    anchors.centerIn: parent
                    source: "qrc:/ModeSelection/shreeon_logo.png"
                    width: ScreenTools.defaultFontPixelHeight * 2.4
                    height: width
                    fillMode: Image.PreserveAspectFit
                }

                RippleEffect {
                    id: logoRipple
                    rippleColor: Qt.rgba(1, 1, 1, 0.40)
                    clipRadius: ScreenTools.defaultFontPixelWidth * 0.5
                }

                QGCMouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        logoRipple.tap(mouse.x, mouse.y)
                        var point = shreeonLogoButton.mapToItem(mainWindow.contentItem, shreeonLogoButton.width / 2, shreeonLogoButton.height / 2)
                        mainWindow.showModeSelection(point)
                    }
                }
            }

            Item {
                Layout.preferredWidth: routeMappingTitle.implicitWidth
                Layout.fillHeight: true
                Layout.leftMargin: ScreenTools.defaultFontPixelWidth * 0.5

                QGCLabel {
                    id: routeMappingTitle
                    anchors.centerIn: parent
                    text: qsTr("Agriculture Spraying")
                    color: "white"
                    font.bold: true
                    font.pointSize: ScreenTools.largeFontPointSize
                }

                Rectangle {
                    anchors.left: routeMappingTitle.left
                    anchors.right: routeMappingTitle.right
                    anchors.top: routeMappingTitle.bottom
                    anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.12
                    height: 1
                    color: "#4af200"
                    opacity: 0.55
                }
            }
        }

        // Import and clear actions belong to the toolbar so their stacking,
        // alignment and click handling are independent of the map overlay.
        Row {
            id: mapTools
            anchors.right: parent.right
            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 1.2
            anchors.verticalCenter: parent.verticalCenter
            spacing: ScreenTools.defaultFontPixelWidth * 1.5

            Item {
                width: Math.round(ScreenTools.defaultFontPixelWidth * 5)
                height: width

                QGCColoredImage {
                    anchors.centerIn: parent
                    width: Math.round(parent.width * 0.85)
                    height: width
                    source: "/res/modern-icons/MaterialSymbolsCreateNewFolder.svg"
                    sourceSize.width: width * Screen.devicePixelRatio
                    sourceSize.height: height * Screen.devicePixelRatio
                    fillMode: Image.PreserveAspectFit
                    color: "white"
                    smooth: true
                    mipmap: true
                }

                RippleEffect {
                    id: importRipple
                    rippleColor: Qt.rgba(1, 1, 1, 0.40)
                    clipRadius: width / 2
                }

                QGCMouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        importRipple.tap(mouse.x, mouse.y)
                        _root.openRouteMappingImportDialog()
                    }
                }
            }

            Item {
                width: Math.round(ScreenTools.defaultFontPixelWidth * 5)
                height: width

                QGCColoredImage {
                    anchors.centerIn: parent
                    width: Math.round(parent.width * 0.85)
                    height: width
                    source: "/res/modern-icons/MaterialSymbolsLightDirectorySync.svg"
                    sourceSize.width: width * Screen.devicePixelRatio
                    sourceSize.height: height * Screen.devicePixelRatio
                    fillMode: Image.PreserveAspectFit
                    color: "white"
                    smooth: true
                    mipmap: true
                }

                RippleEffect {
                    id: clearRipple
                    rippleColor: Qt.rgba(1, 1, 1, 0.40)
                    clipRadius: width / 2
                }

                QGCMouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        clearRipple.tap(mouse.x, mouse.y)
                        _root.clearRouteMappingPlan()
                    }
                }
            }
        }

        // Native QGC-style mission transfer progress along the bottom edge of
        // the toolbar. The value comes directly from MissionController.
        Rectangle {
            id: missionUploadProgressTrack
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 4
            color: Qt.rgba(1, 1, 1, 0.22)
            visible: mainToolBar._missionUploadProgressVisible
            z: 2

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.max(0, Math.min(1, mainToolBar._missionUploadProgress)) * parent.width
                color: "#35e000"
            }
        }

        Connections {
            target: _missionController
            ignoreUnknownSignals: true

            function onProgressPctChanged(progressPct) {
                mainToolBar._missionUploadProgress = Math.max(0, Math.min(1, progressPct))
                if (progressPct > 0) {
                    mainToolBar._missionUploadProgressVisible = true
                }
                if (progressPct >= 1 && !_planMasterController.syncInProgress) {
                    missionUploadProgressResetTimer.restart()
                }
            }
        }

        Connections {
            target: _planMasterController
            ignoreUnknownSignals: true

            function onSyncInProgressChanged() {
                if (_planMasterController.syncInProgress) {
                    missionUploadProgressResetTimer.stop()
                    if (!mainToolBar._missionUploadProgressVisible) {
                        mainToolBar._missionUploadProgress = 0
                    }
                    mainToolBar._missionUploadProgressVisible = true
                } else if (_root._routeMappingUploadPending) {
                    // Vehicle write finished. Mark complete like stock Plan View
                    // after sendToVehicle returns — do not require progressPct==1,
                    // which can already be reset when syncInProgress clears.
                    _root._markRouteMappingUploadComplete()
                    if (mainToolBar._missionUploadProgressVisible) {
                        mainToolBar._missionUploadProgress = 1
                        missionUploadProgressResetTimer.restart()
                    }
                } else if (mainToolBar._missionUploadProgressVisible) {
                    if (_missionController.progressPct >= 1) {
                        mainToolBar._missionUploadProgress = 1
                    }
                    missionUploadProgressResetTimer.restart()
                }
            }
        }

        Timer {
            id: missionUploadProgressResetTimer
            interval: 3000
            repeat: false
            onTriggered: {
                mainToolBar._missionUploadProgressVisible = false
                mainToolBar._missionUploadProgress = 0
            }
        }

    }
}
