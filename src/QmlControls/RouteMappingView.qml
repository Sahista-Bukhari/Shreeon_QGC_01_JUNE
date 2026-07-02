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
            Qt.callLater(function() { _backButtonVisibleProgress = 1.0 })
        }
    }

    Connections {
        target: QGroundControl.multiVehicleManager
        function onActiveVehicleChanged() {
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

    readonly property bool _canFinishRoute: _areaRouteActive && !_surveyFinished && fieldTracePointsModel.count >= 3
    readonly property var _routeSegmentInsertPoints: {
        var insertPoints = []
        if (!_areaRouteActive || _surveyFinished || fieldTracePointsModel.count < 2) {
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

    readonly property bool _hasCalculatedSurvey: _cachedSurveyItem
                                                 && _cachedSurveyItem.surveyAreaPolygon
                                                 && _cachedSurveyItem.surveyAreaPolygon.isValid
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
            return "0.0 Ha"
        }
        var areaHa = QGroundControl.unitsConversion.squareMetersToAppSettingsAreaUnits(_cachedSurveyItem.coveredArea)
        if (QGroundControl.unitsConversion.appSettingsAreaUnitsString === "ha") {
            return areaHa.toFixed(1) + " Ha"
        }
        return areaHa.toFixed(1) + " " + QGroundControl.unitsConversion.appSettingsAreaUnitsString
    }

    // Boundary trace points are waypoints, not camera shots. Once at least
    // three points form a valid survey, show QGC's calculated camera shots.
    property string _photoCountText: _hasCalculatedSurvey
                                     ? String(_cachedSurveyItem.cameraShots)
                                     : "0"

    property string _flightTimeText: {
        var totalSeconds = _missionController.missionTime
        if (!totalSeconds || totalSeconds <= 0) {
            return "0 min"
        }
        var minutes = Math.max(1, Math.round(totalSeconds / 60))
        return minutes + " min"
    }

    function _surveyItemName() {
        var names = _missionController.complexMissionItemNames
        if (names && names.length > 0) {
            return names[0]
        }
        return "Survey"
    }

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

    function _defaultSaveTaskName() {
        if (_importedMappingTaskName !== "") {
            return _importedMappingTaskName
        }
        if (_savedMappingTaskName !== "") {
            return _savedMappingTaskName
        }
        return qsTr("Mapping Task")
    }

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

    function mapCenter() {
        var coordinate = routeMap.center
        coordinate.latitude  = coordinate.latitude.toFixed(_decimalPlaces)
        coordinate.longitude = coordinate.longitude.toFixed(_decimalPlaces)
        coordinate.altitude  = coordinate.altitude.toFixed(_decimalPlaces)
        return coordinate
    }

    function routeStartCoordinate() {
        if (_activeVehicle && _activeVehicle.coordinate && _activeVehicle.coordinate.isValid) {
            return QtPositioning.coordinate(
                        Number(_activeVehicle.coordinate.latitude.toFixed(_decimalPlaces)),
                        Number(_activeVehicle.coordinate.longitude.toFixed(_decimalPlaces)),
                        Number(_activeVehicle.coordinate.altitude.toFixed(_decimalPlaces)))
        }

        return mapCenter()
    }

    function resetAreaRouteState() {
        _areaRouteActive = false
        _surveyFinished = false
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

    function _clearMissionItemsIfNeeded() {
        if (_missionController.visualItems.count > 1) {
            _planMasterController.removeAll()
        }
    }

    function _clearFlyViewRouteMappingOverlay() {
        flyView.routeMappingBoundaryPath = []
        flyView.routeMappingTransectPath = []
        flyView.routeMappingEntryCoordinate = QtPositioning.coordinate()
        flyView.routeMappingExitCoordinate = QtPositioning.coordinate()
        flyView.routeMappingEntryHeading = 0
        flyView.routeMappingExitHeading = 0
    }

    function _runWithMissionVisualsSuspended(operation) {
        _missionMapVisualsEnabled = false
        _cachedSurveyItem = null
        missionPlanMutationTimer.pendingOperation = operation
        missionPlanMutationTimer.restart()
    }

    function _beginAreaRouteAtCoordinate(coord) {
        _missionController.insertTakeoffItem(coord, -1, false)
        for (var i = 0; i < _missionController.visualItems.count; i++) {
            var takeoffItem = _missionController.visualItems.get(i)
            if (takeoffItem && takeoffItem.isTakeoffItem) {
                if (takeoffItem.specifiesCoordinate) {
                    takeoffItem.coordinate = coord
                }
                takeoffItem.launchCoordinate = coord
                takeoffItem.launchTakeoffAtSameLocation = true
                break
            }
        }

        var surveyItem = _missionController.insertComplexMissionItem(_surveyItemName(), coord, -1, true)
        if (!surveyItem || !surveyItem.surveyAreaPolygon) {
            return
        }

        surveyItem.surveyAreaPolygon.clear()
        surveyItem.surveyAreaPolygon.traceMode = false
        surveyItem.surveyAreaPolygon.interactive = false

        _missionController.setCurrentPlanViewSeqNum(surveyItem.sequenceNumber, true)
        _planMasterController.manualCreation = true
        _areaRouteActive = true
        _cachedSurveyItem = surveyItem
        _taskSettingsSurveyItem = surveyItem
        _hasMissionPlanItems = true
    }

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

    function requestDeleteRouteMappingPoint(pointIndex) {
        if (pointIndex < 0 || pointIndex >= fieldTracePointsModel.count || _surveyFinished) {
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

    function moveRouteMappingPoint(pointIndex, coordinate, updateSurvey) {
        if (pointIndex < 0 || pointIndex >= fieldTracePointsModel.count
                || !coordinate || !coordinate.isValid || _surveyFinished) {
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

    function startAreaRouteSession() {
        if (taskSettingsPanel.routeMode !== 0) {
            return
        }

        // Never replace an existing route from the Add/settings controls.
        // A route must be explicitly cleared before a new session can start.
        if (_areaRouteActive || _surveyFinished
                || fieldTracePointsModel.count > 0
                || _hasMissionPlanItems
                || _missionController.visualItems.count > 1) {
            return
        }

        var coord = routeStartCoordinate()
        resetAreaRouteState()
        _beginAreaRouteAtCoordinate(coord)
    }

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

        if (!_missionController.hasLandItem) {
            _missionController.insertLandItem(mapCenter(), -1, false)
        }
        _missionController.setCurrentPlanViewSeqNum(surveyItem.sequenceNumber, true)

        _surveyFinished = true
    }

    function showTaskSettings() {
        _taskSettingsVisible = true
    }

    function hideTaskSettings() {
        _taskSettingsVisible = false
    }

    function returnToFlyView() {
        var sidebarOpen = _taskSettingsVisible || _taskSettingsOpenProgress > 0.01
        hideTaskSettings()
        if (sidebarOpen) {
            _pendingFlyViewReturn = true
            return
        }
        _finishReturnToFlyView()
    }

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

    function onAddButtonClicked() {
        if (_taskSettingsVisible) {
            hideTaskSettings()
            return
        }

        showTaskSettings()
        startAreaRouteSession()
    }

    function clearRouteMappingPlan() {
        if (!_hasRouteMappingContent) {
            return
        }

        mainWindow.showMessageDialog(
                    qsTr("Clear"),
                    qsTr("Are you sure you want to remove all items from the route mapping plan?"),
                    Dialog.Yes | Dialog.Cancel,
                    function() {
                        _runWithMissionVisualsSuspended(function() {
                            hideTaskSettings()
                            _clearMissionItemsIfNeeded()
                            _missionController.setCurrentPlanViewSeqNum(0, true)
                            resetAreaRouteState()
                            _hasMissionPlanItems = false
                            _planMasterController.dirty = false
                            _clearFlyViewRouteMappingOverlay()
                        })
                    })
    }

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

    function openSaveMappingTaskDialog() {
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

    function saveMappingTask(taskName) {
        var safeTaskName = taskName.trim().replace(/[\\\/:*?\"<>|]/g, "_")
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

    // This function controls the exit functionlity
    function exitRouteMappingPage() {
        if (_showSavedMappingOverlay && _savedMappingTaskName !== "") {
            var transferResult = _transferPlanToFlyView()
            if (!transferResult.success) {
                return
            }
            return
        }

        mainWindow.showFlyView()
    }


    // Demo-only helpers (logic copied from QGC MainWindow / FlyView — kept here so core QGC files stay unchanged)
    function _transferPlanToFlyView() {
        var savePath = QGroundControl.settingsManager.appSettings.missionSavePath
        if (!savePath) {
            mainWindow.showMessageDialog(
                        qsTr("Save"),
                        qsTr("Mission save path must be set in Application Settings."))
            return { success: false, uploaded: false }
        }

        var separator = savePath.endsWith("/") ? "" : "/"
        var transferPlanFile = savePath + separator + "route_mapping_transfer.plan"

        _planMasterController.saveToFile(transferPlanFile)

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

        var routeMappingOverlayData = _routeMappingOverlayData()
        mainWindow.showFlyView()
        _showPlanOnFlyView(routeMappingOverlayData)

        return { success: true, uploaded: _tryUploadFlyViewPlan(flyPlanController) }
    }

    function _routeMappingOverlayData() {
        if (!_hasCalculatedSurvey) {
            return null
        }

        var boundary = []
        var polygonPath = _cachedSurveyItem.surveyAreaPolygon.path
        for (var i = 0; i < polygonPath.length; i++) {
            boundary.push(polygonPath[i])
        }
        if (boundary.length >= 3) {
            boundary.push(boundary[0])
        }

        var transectPath = []
        var visualTransectPoints = _cachedSurveyItem.visualTransectPoints
        for (var j = 0; j < visualTransectPoints.length; j++) {
            transectPath.push(visualTransectPoints[j])
        }

        return {
            boundaryPath: boundary,
            transectPath: transectPath,
            entryCoordinate: _cachedSurveyItem.coordinate,
            exitCoordinate: _cachedSurveyItem.exitCoordinate,
            entryHeading: _surveyStartHeading,
            exitHeading: _surveyEndHeading
        }
    }

    function _showPlanOnFlyView(routeMappingOverlayData) {
        flyView.planEditMode = false
        flyView._editingLayer = flyView._layerMission
        flyView._missionController.setCurrentPlanViewSeqNum(0, true)

        if (routeMappingOverlayData) {
            flyView.routeMappingBoundaryPath = routeMappingOverlayData.boundaryPath
            flyView.routeMappingTransectPath = routeMappingOverlayData.transectPath
            flyView.routeMappingEntryCoordinate = routeMappingOverlayData.entryCoordinate
            flyView.routeMappingExitCoordinate = routeMappingOverlayData.exitCoordinate
            flyView.routeMappingEntryHeading = routeMappingOverlayData.entryHeading
            flyView.routeMappingExitHeading = routeMappingOverlayData.exitHeading
        }
    }

    function _tryUploadFlyViewPlan(flyPlanController) {
        // Copied from FlyView.tryUploadLoadedPlan
        if (!flyPlanController || flyPlanController.offline) {
            return false
        }
        if (flyPlanController.readyForSaveState() !== VisualMissionItem.ReadyForSave) {
            return false
        }
        flyPlanController.upload()
        return true
    }

    function addRouteMappingPoint() {
        if (!_areaRouteActive || _surveyFinished || taskSettingsPanel.routeMode !== 0) {
            return
        }

        var coord = mapCenter()
        fieldTracePointsModel.append({
                                         lat: coord.latitude,
                                         lon: coord.longitude,
                                         alt: coord.altitude
                                     })
        if (fieldTracePointsModel.count >= 3) {
            _updateSurveyPolygonFromTrace(_cachedSurveyItem)
        }
    }

    function insertRouteMappingPoint(insertIndex, coordinate) {
        if (!_areaRouteActive || _surveyFinished || !coordinate || !coordinate.isValid) {
            return
        }

        var boundedIndex = Math.max(0, Math.min(insertIndex, fieldTracePointsModel.count))
        fieldTracePointsModel.insert(boundedIndex, {
                                         lat: coordinate.latitude,
                                         lon: coordinate.longitude,
                                         alt: coordinate.altitude
                                     })
        _selectedWaypointIndex = -1
        if (fieldTracePointsModel.count >= 3) {
            _updateSurveyPolygonFromTrace(_cachedSurveyItem)
        }
    }

    PlanMasterController {
        id: planMasterController
        flyView: false

        Component.onCompleted: {
            _planMasterController.start()
            _missionController.setCurrentPlanViewSeqNum(0, true)
            _updateCachedSurveyItem()
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
                               _planMasterController.saveToFile(file)
                               hideTaskSettings()
                               _savedMappingTaskName = _pendingMappingTaskName
                               _importedMappingPlanPath = file
                               _importedMappingTaskName = _taskNameFromPlanFile(file)
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
                            enabled: !_root._surveyFinished
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
            radius: ScreenTools.defaultFontPixelWidth * 0.45
            color: routeBackMouseArea.pressed ? Qt.rgba(1, 1, 1, 0.34) : Qt.rgba(1, 1, 1, 0.22)
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
            }

            QGCMouseArea {
                id: routeBackMouseArea
                anchors.fill: parent
                onClicked: _root.returnToFlyView()
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
                surveyItem: _root._taskSettingsSurveyItem ? _root._taskSettingsSurveyItem : _root._cachedSurveyItem

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

        Row {
            id: mapTools
            anchors.top: parent.top
            anchors.topMargin: mainToolBar.height + ScreenTools.defaultFontPixelHeight * 1.2
            anchors.right: parent.right
            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 1.2
            spacing: ScreenTools.defaultFontPixelWidth * 1.5
            z: QGroundControl.zOrderWidgets + 10

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

                QGCMouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: _root.openRouteMappingImportDialog()
                }
            }

            Item {
                width: Math.round(ScreenTools.defaultFontPixelWidth * 5)
                height: width
                opacity: 1.0

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

                QGCMouseArea {
                    anchors.fill: parent
                    enabled: _hasRouteMappingContent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: _root.clearRouteMappingPlan()
                }
            }
        }

        Rectangle {

            id: mappingStats
            anchors.top: mapTools.bottom
            anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.5
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
                QGCLabel { text: qsTr("Est. Photo Count"); color: "white"; Layout.fillWidth: true }
                QGCLabel { text: _photoCountText; color: "white"; font.bold: true; horizontalAlignment: Text.AlignRight; Layout.fillWidth: true }
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

                QGCLabel {
                    anchors.centerIn: parent
                    text: "+"
                    color: "#515151"
                    font.bold: true
                }

                QGCMouseArea {
                    anchors.fill: parent
                    enabled: _areaRouteActive && !_surveyFinished
                    onClicked: addRouteMappingPoint()
                }
            }

            Rectangle {
                anchors.left: plusButton.right
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.5
                anchors.right: parent.right
                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.75
                anchors.verticalCenter: plusButton.verticalCenter
                height: plusButton.height
                radius: _actionButtonRadius
                color: "white"
                border.color: _taskSettingsVisible ? "#78d957" : "transparent"
                border.width: _taskSettingsVisible ? 2 : 0

                QGCLabel {
                    id:addbtn
                    anchors.centerIn: parent
                    text: qsTr("Add")
                    color: "#515151"
                    font.weight: Font.DemiBold
                }

                QGCMouseArea {
                    anchors.fill: parent
                    onClicked: _root.onAddButtonClicked()
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
                width: exitRow.implicitWidth + ScreenTools.defaultFontPixelWidth * 6.5
                height: ScreenTools.defaultFontPixelHeight * 2
                radius: _actionButtonRadius
                color: "white"

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

                QGCMouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: _root.exitRouteMappingPage()
                    onPressed: parent.scale = 0.96
                    onReleased: parent.scale = 1.0
                }
            }


            Rectangle {
                width: saveRow.implicitWidth + ScreenTools.defaultFontPixelWidth * 6
                height: ScreenTools.defaultFontPixelHeight * 2
                radius: _actionButtonRadius
                color: "white"

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

                QGCMouseArea {
                    anchors.fill: parent
                    enabled: _surveyFinished || _canFinishRoute
                    onClicked: _root.openSaveMappingTaskDialog()
                }

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

                QGCMouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
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
                    text: qsTr("Route Mapping")
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

        FlyViewToolBarIndicators {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.rightMargin: ScreenTools.defaultFontPixelWidth
            height: parent.height
        }

    }
}
