import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import QtLocation
import QtPositioning
import QtQuick.Window
import QtQml.Models

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView
import QGroundControl.FlightMap
import QGroundControl.UTMSP
import QGroundControl.Viewer3D

Item {
    id: _root

    // These should only be used by MainRootWindow
    property var planController:    _planController
    property var guidedController:  _guidedController

    // Properties of UTM adapter
    property bool utmspSendActTrigger: false

    // Plan Edit Mode - replaces the old _showPlanView approach
    property bool   planEditMode:           false
    property int    _editingLayer:          _layerMission
    // Removed: _centerTargetMode - crosshair is now always visible in plan edit mode
    property bool   _showMissionStats:      false   // Show mission stats panel for Stats button
    property bool   _importPlanForMission: false
    property var    routeMappingBoundaryPath: []
    property var    routeMappingTransectPath: []
    property var    routeMappingPhotoCaptureTransectPoints: []
    property var    routeMappingTakeoffCoordinate: QtPositioning.coordinate()
    property var    routeMappingEntryCoordinate: QtPositioning.coordinate()
    property var    routeMappingExitCoordinate: QtPositioning.coordinate()
    property real   routeMappingEntryHeading: 0
    property real   routeMappingExitHeading: 0
    property int    routeMappingPlannedPhotoCount: 0
    property real   routeMappingPhotoFootprintSide: 25
    property real   routeMappingPhotoFootprintFrontal: 25
    // Raspberry Pi Camera Module 3 (Sony IMX708), landscape/nadir mounting.
    // Calculate each image's ground footprint from these optical FOVs and AGL.
    readonly property real routeMappingCameraHorizontalFovDegrees: 66
    readonly property real routeMappingCameraVerticalFovDegrees: 41
    // Native SurveyComplexItem camera trigger interval, always in raw meters.
    property real   routeMappingTriggerDistance: 25
    property var    routeMappingLivePhotoModel: _routeMappingLivePhotoModel
    // Keep the completed ODM overlay state on FlyView so every Route Mapping
    // map consumes the exact same raster, bounds, and user-selected opacity.
    readonly property string routeMappingOrthophotoUrl: routeMappingPhotoController.orthophotoUrl
    readonly property var routeMappingOrthophotoNorthWest: routeMappingPhotoController.orthophotoNorthWest
    readonly property var routeMappingOrthophotoSouthEast: routeMappingPhotoController.orthophotoSouthEast
    readonly property bool routeMappingOrthophotoReady: routeMappingPhotoController.orthophotoOverlayReady
    readonly property bool routeMappingOrthophotoLoading: routeMappingPhotoController.orthophotoLoading
    readonly property string routeMappingOrthophotoPath: routeMappingPhotoController.orthophotoPath
    readonly property string routeMappingOrthophotoRoot: routeMappingPhotoController.routeMappingRoot
    property real routeMappingOrthophotoOpacity: 0.82
    property bool   hideVehicleMissionForUnuploadedRoute: false
    // Once a survey overlay has been painted (transfer/import), keep its geometry
    // frozen for the whole mission. Only the drone position and progress update.
    property bool   _routeMappingOverlayLocked: false
    property bool   _routeMappingPhotoPathWarned: false
    // Photo progress UI is Route Mapping only (not Agriculture / Seed Spreader).
    readonly property bool routeMappingPhotoProgressEnabled: mainWindow.uploadedMissionEditor === "routeMapping"
    // Fetch full-resolution Pi JPEGs over SSH instead of saving H.264 video frames.
    property bool   routeMappingPiPhotoFetchEnabled: routeMappingPhotoProgressEnabled
    property string routeMappingPiHost: "10.5.0.2"
    property string routeMappingPiUser: "shreeon"
    property string routeMappingPiPhotoRoot: "/home/shreeon/mapping_photos"
    property int    routeMappingPiTriggerPort: 14551
    property bool   _routeMappingPiFetchErrorShown: false

    readonly property bool _hasFlyViewPlanContent: _planController.containsItems
                                                   || routeMappingBoundaryPath.length > 0
                                                   || routeMappingTransectPath.length > 0

    property int _lastAppliedSprayerUploadGeneration: -1

    onVisibleChanged: {
        if (visible)
            applyUploadedSprayerSettingsTimer.restart()
    }

    Timer {
        id: applyUploadedSprayerSettingsTimer

        interval: 400
        repeat: false
        onTriggered: _root._tryApplyUploadedSprayerSettings()
    }

    function _tryApplyUploadedSprayerSettings() {
        var generation = mainWindow.missionPlanUploadGeneration
        if (generation <= _lastAppliedSprayerUploadGeneration)
            return false
        if (!visible)
            return false
        if (!applyUploadedSprayerSettings())
            return false
        _lastAppliedSprayerUploadGeneration = generation
        return true
    }

    function clearRouteMappingOverlay(force) {
        // Locked survey geometry must survive mission progress, MAVLink rewrites,
        // and airborne state unless the user explicitly clears the plan.
        var vehicle = QGroundControl.multiVehicleManager.activeVehicle
        if (!force && (_routeMappingOverlayLocked || (vehicle && (vehicle.flying || vehicle.armed)))) {
            return
        }
        _routeMappingOverlayLocked = false
        routeMappingBoundaryPath = []
        routeMappingTransectPath = []
        routeMappingPhotoCaptureTransectPoints = []
        routeMappingTakeoffCoordinate = QtPositioning.coordinate()
        routeMappingEntryCoordinate = QtPositioning.coordinate()
        routeMappingExitCoordinate = QtPositioning.coordinate()
        routeMappingEntryHeading = 0
        routeMappingExitHeading = 0
        routeMappingPlannedPhotoCount = 0
        routeMappingPhotoFootprintSide = 25
        routeMappingPhotoFootprintFrontal = 25
        routeMappingTriggerDistance = 25
        resetRouteMappingLivePhotos()
        mapControl.resetRouteMappingProgress()
    }

    function clearFlyViewFlightTraces() {
        var vehicle = QGroundControl.multiVehicleManager.activeVehicle
        if (!vehicle) {
            return
        }
        // Do not erase the red completed path while still airborne.
        if (vehicle.flying) {
            return
        }
        if (vehicle.trajectoryPoints) {
            vehicle.trajectoryPoints.clear()
        }
        if (vehicle.clearCameraTriggerPoints) {
            vehicle.clearCameraTriggerPoints()
        }
    }

    function confirmAndClearPlan() {
        mainWindow.confirmClearRouteMappingPlan()
    }

    function _routeMappingOverlayFromMission() {
        // Never regenerate / rotate / shift a locked survey graphic. Mission
        // progress and drone telemetry must not rewrite planned coordinates.
        var vehicle = QGroundControl.multiVehicleManager.activeVehicle
        if (_routeMappingOverlayLocked
                || (vehicle && (vehicle.flying || vehicle.armed)
                    && routeMappingTransectPath
                    && routeMappingTransectPath.length >= 2)) {
            return
        }

        var surveyItem = null
        for (var i = 0; i < _missionController.visualItems.count; i++) {
            var visualItem = _missionController.visualItems.get(i)
            if (visualItem && visualItem.surveyAreaPolygon) {
                surveyItem = visualItem
                break
            }
        }

        if (!surveyItem || !surveyItem.surveyAreaPolygon || !surveyItem.surveyAreaPolygon.isValid) {
            // Keep any previously painted overlay; do not clear after vehicle
            // flatten wipes SurveyComplexItem from visualItems.
            return
        }

        var boundary = []
        var polygonPath = surveyItem.surveyAreaPolygon.path
        for (var b = 0; b < polygonPath.length; b++) {
            var boundaryCoord = polygonPath[b]
            boundary.push(QtPositioning.coordinate(boundaryCoord.latitude,
                                                   boundaryCoord.longitude,
                                                   boundaryCoord.altitude))
        }
        if (boundary.length >= 3) {
            boundary.push(boundary[0])
        }

        var transectPath = []
        var visualTransectPoints = surveyItem.visualTransectPoints
        for (var j = 0; j < visualTransectPoints.length; j++) {
            var transectCoord = visualTransectPoints[j]
            transectPath.push(QtPositioning.coordinate(transectCoord.latitude,
                                                       transectCoord.longitude,
                                                       transectCoord.altitude))
        }

        var photoCaptureTransectPoints = []
        var nativePhotoCapturePoints = surveyItem.photoCaptureTransectPoints
        for (var p = 0; p < nativePhotoCapturePoints.length; p++) {
            var photoPoint = nativePhotoCapturePoints[p]
            photoCaptureTransectPoints.push(QtPositioning.coordinate(
                                                photoPoint.latitude,
                                                photoPoint.longitude,
                                                photoPoint.altitude))
        }


        var displayTransectPath = transectPath
        if (photoCaptureTransectPoints.length >= 2) {
            var captureLegPath = []
            for (var leg = 0; leg + 1 < photoCaptureTransectPoints.length; leg += 2) {
                var legStart = photoCaptureTransectPoints[leg]
                var legEnd = photoCaptureTransectPoints[leg + 1]
                if (legStart && legStart.isValid && legEnd && legEnd.isValid) {
                    captureLegPath.push(legStart)
                    captureLegPath.push(legEnd)
                }
            }
            if (captureLegPath.length >= 2) {
                displayTransectPath = captureLegPath
            } else {
                displayTransectPath = photoCaptureTransectPoints
            }
        }

        var entryHeading = 0
        var exitHeading = 0
        if (displayTransectPath.length >= 2) {
            entryHeading = displayTransectPath[0].azimuthTo(displayTransectPath[1])
            exitHeading = displayTransectPath[displayTransectPath.length - 2].azimuthTo(
                        displayTransectPath[displayTransectPath.length - 1])
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

        routeMappingBoundaryPath = boundary
        routeMappingTransectPath = displayTransectPath
        routeMappingPhotoCaptureTransectPoints = photoCaptureTransectPoints
        routeMappingTakeoffCoordinate = takeoffCoord
        routeMappingEntryCoordinate = surveyItem.coordinate
        routeMappingExitCoordinate = surveyItem.exitCoordinate
        routeMappingEntryHeading = entryHeading
        routeMappingExitHeading = exitHeading
        routeMappingPlannedPhotoCount = routeMappingPhotoProgressEnabled
                ? (surveyItem.cameraShots ? surveyItem.cameraShots : 0)
                : 0
        if (surveyItem.cameraCalc) {
            var sideFootprint = Number(surveyItem.cameraCalc.imageFootprintSide)
            var frontalFootprint = Number(surveyItem.cameraCalc.imageFootprintFrontal)
            var triggerDistance = surveyItem.cameraCalc.adjustedFootprintFrontal
                    ? Number(surveyItem.cameraCalc.adjustedFootprintFrontal.rawValue) : 0
            if (!sideFootprint || sideFootprint <= 0) {
                sideFootprint = Number(surveyItem.cameraCalc.adjustedFootprintSide.rawValue)
            }
            if (!frontalFootprint || frontalFootprint <= 0) {
                frontalFootprint = triggerDistance
            }
            routeMappingPhotoFootprintSide = sideFootprint > 0 ? sideFootprint : 25
            routeMappingPhotoFootprintFrontal = frontalFootprint > 0 ? frontalFootprint : 25
            routeMappingTriggerDistance = triggerDistance > 0 ? triggerDistance : 25
        }
        if (transectPath.length >= 2) {
            _routeMappingOverlayLocked = true
        }
        _rebuildRouteMappingGcsTriggerSchedule()
    }

    function applyConfirmedSprayerSettings(enabled, nozzleRate, pumpRate) {
        var bottomBar = widgetLayer.bottomBar
        _planController.setSprayerSettings(enabled, nozzleRate, pumpRate)

        // Keep the plan settings even when this firmware does not expose its
        // SPRAY_* parameters. When available, also apply them to the vehicle.
        if (bottomBar) {
            bottomBar.applyPlanSprayerSettings(enabled, nozzleRate, pumpRate)
        }

        // The mission path stays untouched. Persist only the payload state so
        // disabling here also remains disabled after editing or reconnecting.
        var editorType = mainWindow.uploadedMissionEditor
        var editorView = mainWindow.missionEditorView(editorType)
        if (editorView && editorView.applyFlyViewSprayerSettings
                && editorView.applyFlyViewSprayerSettings(enabled, nozzleRate, pumpRate)) {
            mainWindow.persistLastExecutedMission(editorType)
        }
    }

    // Push uploaded Agriculture Sprayer plan metadata to the vehicle as soon as
    // Fly View is shown — no manual sprayer icon click required.
    function applyUploadedSprayerSettings() {
        if (mainWindow.uploadedMissionEditor !== "agricultureSpraying")
            return false
        if (!_planController.sprayerConfigured)
            return false

        var nozzleRate = Number(_planController.sprayerNozzleRate)
        var pumpRate = Number(_planController.sprayerPumpRate)
        applyConfirmedSprayerSettings(
                    _planController.sprayerEnabled,
                    isFinite(nozzleRate) ? nozzleRate : NaN,
                    isFinite(pumpRate) ? pumpRate : NaN)
        return true
    }

    function syncSprayerSettingsToPlan() {
        var pc = _planController
        var bottomBar = widgetLayer.bottomBar
        if (!bottomBar)
            return

        // Plan metadata confirmed via OK (or loaded from file) is the source of
        // truth for saves. Uploaded Agriculture plans are auto-applied on entry.
        if (pc.sprayerConfigured)
            return

        if (!bottomBar.sprayEnableFact)
            return

        if (!bottomBar._sprayEnabled) {
            pc.clearSprayerSettings()
            return
        }

        var nozzleRate = bottomBar.sprayNozzleRateFact
                         ? Number(bottomBar.sprayNozzleRateFact.rawValue) : NaN
        var pumpRate = bottomBar.sprayPumpRateFact
                       ? Number(bottomBar.sprayPumpRateFact.rawValue) : NaN
        pc.setSprayerSettings(true, nozzleRate, pumpRate)
    }

    function importFlyViewPlan(file) {
        _planController.loadFromFile(file)
        _missionController.setCurrentPlanViewSeqNum(0, true)
        planEditMode = false
        _editingLayer = _layerMission
        missionImportFinalizeTimer.restart()
    }

    function _openFlyViewPlanFilePicker() {
        _importPlanForMission = true
        planFileDialog.title = qsTr("Import your plan")
        planFileDialog.planFiles = true
        planFileDialog.nameFilters = _planController.loadNameFilters
        planFileDialog.openForLoad()
    }

    function openFlyViewPlanImportDialog() {
       function openSavedPlanGallery() {
           savedPlanGallery.open()
       }
        if(_hasFlyViewPlanContent){
            mainWindow.showMessageDialog(
                        qsTr("import plan"),
                        qsTr(" A plan is already loaded. Please clear the current plan first."),
                        Dialog.Ok)
            return
        }
        if(_planController.dirty){
            mainWindow.showMessageDialog(
                        qsTr("Open plan"),
                        qsTr("You have unsaved/unsent changes. Loading a new Plan will lose these changes. Are you sure?"),
                        Dialog.Ok | Dialog.Cancel,
                        openSavedPlanGallery
                        )
            return
        }
        openSavedPlanGallery()

    }

    SavedPlanGallery {
        id: savedPlanGallery
        folder: _root._appSettings ? _root._appSettings.missionSavePath : ""

        onPlanSelected: (filePath, missionMode) => {
            if (!mainWindow.loadSavedPlanForMissionMode(filePath, missionMode)) {
                mainWindow.showMessageDialog(
                            qsTr("Unable to Load Saved Plan"),
                            qsTr("The saved plan could not be restored for %1 mode.").arg(
                                mainWindow.missionEditorDisplayName(missionMode)),
                            Dialog.Ok)
                return
            }
            _root._importPlanForMission = false
            _root.importFlyViewPlan(filePath)
        }
        onBrowseRequested: _root._openFlyViewPlanFilePicker()
    }

    Timer {
        id: missionImportFinalizeTimer
        interval: 0
        repeat: false
        onTriggered: {
            _routeMappingOverlayFromMission()
            var editorView = mainWindow.missionEditorView(mainWindow.uploadedMissionEditor)
            if (editorView) {
                if (editorView._restoreUploadedRouteMappingOverlay) {
                    editorView._restoreUploadedRouteMappingOverlay()
                }
                if (editorView._copyRouteMappingTelemetryToFlyViewPlanController) {
                    editorView._copyRouteMappingTelemetryToFlyViewPlanController()
                }
                if (editorView._copySprayerSettingsToFlyViewPlanController) {
                    editorView._copySprayerSettingsToFlyViewPlanController()
                }
            }
            _root._tryApplyUploadedSprayerSettings()
            if (_planController.containsItems && !_planController.offline) {
                if (_planController.readyForSaveState() === VisualMissionItem.ReadyForSave) {
                    _planController.upload()
                }
            }
        }
    }

    readonly property int _layerMission:    1
    readonly property int _layerFence:      2
    readonly property int _layerRally:      3
    readonly property int _layerUTMSP:      4

    readonly property int   _decimalPlaces: 8

    PlanMasterController {
        id:                     _planController
        // Must be true so currentMissionIndex / Start Mission / altitude-resume
        // track the live vehicle. Survey geometry stays frozen via the locked
        // route-mapping overlay + skip-reload while armed/flying — not via flyView:false.
        flyView:                true
        Component.onCompleted:  start()

        property var _missionController: _planController.missionController

        function waitingOnIncompleteDataMessage(save) {
            var saveOrUpload = save ? qsTr("Save") : qsTr("Upload")
            mainWindow.showMessageDialog(qsTr("Unable to %1").arg(saveOrUpload), qsTr("Plan has incomplete items. Complete all items and %1 again.").arg(saveOrUpload))
        }

        function waitingOnTerrainDataMessage(save) {
            var saveOrUpload = save ? qsTr("Save") : qsTr("Upload")
            mainWindow.showMessageDialog(qsTr("Unable to %1").arg(saveOrUpload), qsTr("Plan is waiting on terrain data from server for correct altitude values."))
        }

        function checkReadyForSaveUpload(save) {
            if (readyForSaveState() == VisualMissionItem.NotReadyForSaveData) {
                waitingOnIncompleteDataMessage(save)
                return false
            } else if (readyForSaveState() == VisualMissionItem.NotReadyForSaveTerrain) {
                waitingOnTerrainDataMessage(save)
                return false
            }
            return true
        }

        function upload() {
            if (!checkReadyForSaveUpload(false /* save */)) {
                return
            }
            switch (_missionController.sendToVehiclePreCheck()) {
                case MissionController.SendToVehiclePreCheckStateOk:
                    sendToVehicle()
                    break
                case MissionController.SendToVehiclePreCheckStateActiveMission:
                    mainWindow.showMessageDialog(qsTr("Send To Vehicle"), qsTr("Current mission must be paused prior to uploading a new Plan"))
                    break
                case MissionController.SendToVehiclePreCheckStateFirwmareVehicleMismatch:
                    mainWindow.showMessageDialog(qsTr("Plan Upload"),
                        qsTr("This Plan was created for a different firmware or vehicle type than the firmware/vehicle type of vehicle you are uploading to. " +
                             "This can lead to errors or incorrect behavior. " +
                             "It is recommended to recreate the Plan for the correct firmware/vehicle type.\n\n" +
                             "Click 'Ok' to upload the Plan anyway."),
                        Dialog.Ok | Dialog.Cancel,
                        function() { _planController.sendToVehicle() })
                    break
            }
        }

        function loadFromSelectedFile() {
            planFileDialog.title = qsTr("Select Plan File")
            planFileDialog.planFiles = true
            planFileDialog.nameFilters = _planController.loadNameFilters
            planFileDialog.openForLoad()
        }

        function saveToSelectedFile() {
            if (!checkReadyForSaveUpload(true /* save */)) {
                return
            }
            planFileDialog.title = qsTr("Save Plan")
            planFileDialog.planFiles = true
            planFileDialog.nameFilters = _planController.saveNameFilters
            planFileDialog.openForSave()
        }

        function fitViewportToItems() {
            // Future: fit map viewport to items
        }

        function saveKmlToSelectedFile() {
            if (!checkReadyForSaveUpload(true /* save */)) {
                return
            }
            planFileDialog.title = qsTr("Save KML")
            planFileDialog.planFiles = false
            planFileDialog.nameFilters = ShapeFileHelper.fileDialogKMLFilters
            planFileDialog.openForSave()
        }
    }

    Connections {
        target: _planController
        function onSprayerSettingsChanged() {
            if (_root.visible)
                applyUploadedSprayerSettingsTimer.restart()
        }
    }

    property var _appSettings: QGroundControl.settingsManager.appSettings

    QGCFileDialog {
        id: planFileDialog
        folder: _appSettings ? _appSettings.missionSavePath : ""

        property bool planFiles: true    ///< true: working with plan files, false: working with kml file

        onAcceptedForSave: (file) => {
            if (planFiles) {
                _root.syncSprayerSettingsToPlan()
                _planController.saveToFile(file)
            } else {
                _planController.saveToKml(file)
            }
            close()
        }

        onAcceptedForLoad: (file) => {
            if (_importPlanForMission) {
                _importPlanForMission = false
                _root.importFlyViewPlan(file)
            } else {
                _planController.loadFromFile(file)
                _missionController.setCurrentPlanViewSeqNum(0, true)
            }
            close()
        }
    }

    QGCFileDialog {
        id: orthophotoFileDialog
        title: qsTr("Load Previous Orthomosaic")
        folder: _root.routeMappingOrthophotoRoot.length > 0
                ? _root.routeMappingOrthophotoRoot
                : (_appSettings ? _appSettings.savePath.rawValue : "")
        nameFilters: [qsTr("Georeferenced TIFF (*.tif *.tiff)")]

        onAcceptedForLoad: function(file) {
            routeMappingPhotoController.loadOrthophoto(file)
            close()
        }
    }

    function openRouteMappingOrthophotoDialog() {
        orthophotoFileDialog.openForLoad()
    }

    function clearRouteMappingOrthophoto() {
        routeMappingPhotoController.clearOrthophotoOverlay()
    }

    function fitMapToRouteMappingOrthophoto() {
        if (!mapControl || !routeMappingOrthophotoReady) {
            return
        }
        var northWest = routeMappingOrthophotoNorthWest
        var southEast = routeMappingOrthophotoSouthEast
        if (!northWest || !northWest.isValid || !southEast || !southEast.isValid) {
            return
        }
        // Pad the mosaic slightly so it is not clipped against the viewport edge.
        var padMeters = Math.max(
                    25,
                    northWest.distanceTo(
                        QtPositioning.coordinate(northWest.latitude, southEast.longitude)) * 0.15)
        var paddedNorthWest = northWest.atDistanceAndAzimuth(padMeters, 315)
        var paddedSouthEast = southEast.atDistanceAndAzimuth(padMeters, 135)
        mapControl.setVisibleRegion(QtPositioning.rectangle(paddedNorthWest, paddedSouthEast))
    }

    property bool   _mainWindowIsMap:       mapControl.pipState.state === mapControl.pipState.fullState
    property bool   _isFullWindowItemDark:  _mainWindowIsMap ? mapControl.isSatelliteMap : true
    property var    _activeVehicle:         QGroundControl.multiVehicleManager.activeVehicle
    property var    _routeMappingSessionPhotoFiles: []
    property int    _routeMappingPhotosRetrieved: 0
    property int    _routeMappingCaptureFailures: 0
    // QGC-calculated photo schedule drives the Pi camera. Native MAVLink camera
    // feedback is also accepted, but is de-duplicated against this schedule.
    property var    _routeMappingGcsTriggerDistances: []
    property int    _routeMappingGcsNextTriggerIndex: 0
    property real   _routeMappingMaxAlongPathSeen: 0
    property int    _routeMappingTriggersReceived: 0
    property var    _routeMappingNativeTriggerSequences: []
    property real   _routeMappingLastNativeTriggerMs: 0
    property bool   _routeMappingGcsSessionPathAnnounced: false
    // Set when planned triggers are done, photo legs end, or mission leaves survey (RTH).
    property bool   _routeMappingPhotoTriggersComplete: false
    onRouteMappingPhotoCaptureTransectPointsChanged: _rebuildRouteMappingGcsTriggerSchedule()
    onRouteMappingTransectPathChanged: _rebuildRouteMappingGcsTriggerSchedule()
    onRouteMappingTriggerDistanceChanged: _rebuildRouteMappingGcsTriggerSchedule()
    onRouteMappingPlannedPhotoCountChanged: _rebuildRouteMappingGcsTriggerSchedule()

    ListModel {
        id: _routeMappingLivePhotoModel
    }

    RouteMappingPiPhotoFetcher {
        id: routeMappingPiPhotoFetcher
        enabled: _root.routeMappingPiPhotoFetchEnabled
        piHost: _root.routeMappingPiHost
        piUser: _root.routeMappingPiUser
        piPhotoRoot: _root.routeMappingPiPhotoRoot
        piTriggerPort: _root.routeMappingPiTriggerPort

        onPhotoFullFetched: function(requestId, localFilePath, success, errorMessage) {
            if (!success) {
                console.warn("[RouteMapping] Full-res fetch failed for", requestId, errorMessage)
                return
            }
            for (var fullIndex = 0; fullIndex < _routeMappingLivePhotoModel.count; fullIndex++) {
                if (Number(_routeMappingLivePhotoModel.get(fullIndex).photoSequence) !== Number(requestId)) {
                    continue
                }
                var fullResUrl = _root._mappingPhotoFileUrl(localFilePath)
                        + "?ready=" + Date.now()
                _routeMappingLivePhotoModel.setProperty(fullIndex, "photoImageSource", fullResUrl)
                break
            }
        }

        onPhotoFetched: function(requestId, localFilePath, success, errorMessage) {
            if (!success) {
                for (var failedIndex = 0; failedIndex < _routeMappingLivePhotoModel.count; failedIndex++) {
                    if (Number(_routeMappingLivePhotoModel.get(failedIndex).photoSequence) === Number(requestId)) {
                        if (!_routeMappingLivePhotoModel.get(failedIndex).photoFetchFailed) {
                            _root._routeMappingCaptureFailures++
                        }
                        _routeMappingLivePhotoModel.setProperty(failedIndex, "photoFetchFailed", true)
                        break
                    }
                }
                if (!_root._routeMappingPiFetchErrorShown) {
                    _root._routeMappingPiFetchErrorShown = true
                    mainWindow.showMessageDialog(
                                QGroundControl.appName,
                                qsTr("Route Mapping Pi photo fetch failed: %1").arg(errorMessage))
                }
                return
            }

            for (var i = 0; i < _routeMappingLivePhotoModel.count; i++) {
                var photo = _routeMappingLivePhotoModel.get(i)
                if (Number(photo.photoSequence) !== Number(requestId)) {
                    continue
                }
                if (!photo.photoReady) {
                    _root._routeMappingPhotosRetrieved++
                }
                if (photo.photoFetchFailed && _root._routeMappingCaptureFailures > 0) {
                    _root._routeMappingCaptureFailures--
                }
                var refreshedUrl = _root._mappingPhotoFileUrl(localFilePath)
                        + "?ready=" + Date.now()
                _routeMappingLivePhotoModel.setProperty(i, "photoImageSource", refreshedUrl)
                _routeMappingLivePhotoModel.setProperty(i, "photoReady", true)
                _routeMappingLivePhotoModel.setProperty(i, "photoFetchFailed", false)
                _routeMappingLivePhotoModel.setProperty(i, "photoPlaceholder", false)
                break
            }
        }

        onFetchQueueDrained: {
            if (!routeMappingPhotoController.sessionActive
                    && _root.routeMappingPiPhotoFetchEnabled
                    && routeMappingPiPhotoFetcher.piSessionPath.length > 0) {
                routeMappingPiPhotoFetcher.resumeLiveVideo()
            }
        }

        onSshPrecheckFailed: function(errorMessage) {
            if (_root._routeMappingPiFetchErrorShown) {
                return
            }
            _root._routeMappingPiFetchErrorShown = true
            var detail = errorMessage && String(errorMessage).length > 0
                    ? String(errorMessage)
                    : qsTr("Unknown SSH error")
            var hint = qsTr(
                        "If this is the first time on this GCS, install your SSH key:\n"
                        + "  ssh-copy-id %1@%2\n\n"
                        + "If the vehicle link is down, connect Wi‑Fi/WFB so %2 is reachable, then retry.")
                    .arg(_root.routeMappingPiUser)
                    .arg(_root.routeMappingPiHost)
            mainWindow.showMessageDialog(
                        qsTr("Route Mapping Photo Transfer Blocked"),
                        qsTr("SSH to the Raspberry Pi failed — photos will not transfer.\n\n%1\n\n%2")
                            .arg(detail)
                            .arg(hint))
        }

        onSessionStartFailed: function(errorMessage) {
            if (_root._routeMappingPiFetchErrorShown) {
                return
            }
            _root._routeMappingPiFetchErrorShown = true
            mainWindow.showMessageDialog(
                        qsTr("Route Mapping Photo Session Failed"),
                        qsTr("The Raspberry Pi did not create a photo session. Photos will not transfer.\n\n%1")
                            .arg(errorMessage))
        }
    }

    RouteMappingPhotoController {
        id: routeMappingPhotoController
        Component.onCompleted: setPhotoFetcher(routeMappingPiPhotoFetcher)

        onCaptureFailed: function(sequence, errorMessage) {
            for (var i = 0; i < _routeMappingLivePhotoModel.count; i++) {
                var photo = _routeMappingLivePhotoModel.get(i)
                if (Number(photo.photoSequence) !== Number(sequence)) {
                    continue
                }
                if (!photo.photoFetchFailed) {
                    _root._routeMappingCaptureFailures++
                    _routeMappingLivePhotoModel.setProperty(i, "photoFetchFailed", true)
                    _routeMappingLivePhotoModel.setProperty(i, "photoPlaceholder", false)
                }
                break
            }
            console.warn("[RouteMapping] Capture", sequence, "failed:", errorMessage)
        }

        onGcsSessionStartFailed: function(errorMessage) {
            mainWindow.showMessageDialog(QGroundControl.appName, errorMessage)
        }

        onOdmError: function(errorMessage) {
            mainWindow.showMessageDialog(qsTr("Route Mapping Reconstruction"), errorMessage)
        }

        onOrthophotoOverlayChanged: {
            if (!routeMappingPhotoController.orthophotoOverlayReady) {
                return
            }
            // Field mosaics are often only tens of meters across. Zoom to them
            // after load/replace so the layer is visibly on the map.
            Qt.callLater(_root.fitMapToRouteMappingOrthophoto)
        }

        onSessionActiveChanged: {
            if (_root.routeMappingPhotoProgressEnabled && _root.routeMappingPiPhotoFetchEnabled) {
                if (routeMappingPhotoController.sessionActive) {
                    QGroundControl.videoManager.stopVideo()
                } else {
                    QGroundControl.videoManager.startVideo()
                }
            }
            if (!routeMappingPhotoController.sessionActive || _root._routeMappingGcsSessionPathAnnounced) {
                return
            }
            _root._routeMappingGcsSessionPathAnnounced = true
            console.info(
                        "[RouteMapping] Photos save to",
                        routeMappingPhotoController.sessionDirectory,
                        "(see latest_mission_session.txt under Photo/RouteMapping)")
        }
    }

    function resetRouteMappingLivePhotos(startingNewSession) {
        // Capture this before cancelSession() clears the local path. QGC must
        // restore live video only if this process actually started (or may be
        // starting) a Pi mapping session. Active-vehicle discovery at QGC
        // startup must not operate the aircraft camera.
        var hadPiPhotoSession = routeMappingPhotoController.sessionActive
                || routeMappingPhotoController.piSessionPending
                || routeMappingPiPhotoFetcher.piSessionStarting
                || routeMappingPiPhotoFetcher.piSessionPath.length > 0
        _routeMappingPiFetchErrorShown = false
        _routeMappingPhotosRetrieved = 0
        _routeMappingCaptureFailures = 0
        _routeMappingGcsNextTriggerIndex = 0
        _routeMappingMaxAlongPathSeen = 0
        _routeMappingTriggersReceived = 0
        _routeMappingNativeTriggerSequences = []
        _routeMappingLastNativeTriggerMs = 0
        _routeMappingGcsSessionPathAnnounced = false
        _routeMappingPhotoTriggersComplete = false
        _rebuildRouteMappingGcsTriggerSchedule()
        // Keep completed mission photos: they remain the input for geotagging
        // and ODM after a later flight is armed.
        routeMappingPhotoController.cancelSession()
        // Arming immediately starts a new Pi session. Do not insert a
        // VIDEO_RESUME between cancelSession() and that new VIDEO_PAUSE;
        // concurrent replies can otherwise invalidate the async startup.
        if (routeMappingPiPhotoFetchEnabled && !startingNewSession && hadPiPhotoSession) {
            routeMappingPiPhotoFetcher.resumeLiveVideo()
        }
        _routeMappingLivePhotoModel.clear()
    }

    function _beginRouteMappingPhotoSession() {
        if (!routeMappingPhotoProgressEnabled || !routeMappingPiPhotoFetchEnabled) {
            return
        }
        routeMappingPhotoController.captureEnabled = true
        if (!routeMappingPhotoController.beginSession()) {
            routeMappingPhotoController.captureEnabled = false
            if (routeMappingPiPhotoFetcher.piSessionStarting
                    || routeMappingPiPhotoFetcher.piSessionPath.length > 0) {
                routeMappingPiPhotoFetcher.resumeLiveVideo()
            }
            return false
        }
        return true
    }

    function _endRouteMappingPhotoSession() {
        routeMappingPhotoController.captureEnabled = false
        // Do not synthesize or drain unsent captures after the vehicle leaves
        // mission mode. Only an already accepted camera exposure may finish.
        routeMappingPhotoController.endSession()
    }

    function _retryRouteMappingPiSessionIfNeeded() {
        if (!routeMappingPhotoProgressEnabled || !routeMappingPiPhotoFetchEnabled || !missionRunning) {
            return
        }
        if (_routeMappingPhotoTriggersComplete) {
            return
        }
        // Self-heal an interrupted async start. A pending controller with an
        // idle fetcher can never receive piSessionBeginComplete, so clear that
        // stale state before evaluating the normal retry conditions.
        if (routeMappingPhotoController.piSessionPending
                && !routeMappingPiPhotoFetcher.piSessionStarting) {
            console.warn("[RouteMapping] Recovering stalled Pi photo session startup")
            routeMappingPhotoController.cancelSession()
        }
        if (routeMappingPhotoController.sessionActive
                || routeMappingPhotoController.piSessionPending
                || routeMappingPiPhotoFetcher.piSessionStarting) {
            return
        }
        _routeMappingPiFetchErrorShown = false
        routeMappingPhotoController.captureEnabled = true
        // beginSessionAsync performs the retrying SSH precheck and leaves its
        // ControlMaster connection warm for subsequent SCP transfers.
        routeMappingPhotoController.beginSession()
    }

    function _mappingPhotoFileUrl(filePath) {
        var normalizedPath = String(filePath).split("\\").join("/")
        // encodeURI keeps slashes; spaces become %20 (required for "QGroundControl Daily", etc.)
        if (normalizedPath.charAt(0) === "/") {
            return encodeURI("file://" + normalizedPath)
        }
        return encodeURI("file:///" + normalizedPath)
    }

    function _trackRouteMappingPhotoFile(filePath) {
        var files = _routeMappingSessionPhotoFiles.slice()
        files.push(filePath)
        _routeMappingSessionPhotoFiles = files
    }

    /// Mirror the native survey trigger command: one image at each transect
    /// entry, then the selected 6 m / 9 m interval, plus the exit image.
    function _rebuildRouteMappingGcsTriggerSchedule() {
        var schedule = []
        var spacing = Math.max(0.1, Number(routeMappingTriggerDistance))
        var planned = Number(routeMappingPlannedPhotoCount)
        var points = routeMappingPhotoCaptureTransectPoints

        if (points && points.length >= 2 && spacing > 0) {
            var cumulative = 0
            var previousEnd = null
            for (var leg = 0; leg + 1 < points.length; leg += 2) {
                var start = points[leg]
                var end = points[leg + 1]
                if (!start || !start.isValid || !end || !end.isValid) {
                    continue
                }
                // The map helper uses the flattened [start,end,start,end]
                // polyline. Include the turn connector in its coordinate space,
                // but never schedule a photo on that connector.
                if (previousEnd && previousEnd.isValid) {
                    cumulative += previousEnd.distanceTo(start)
                }
                var legLen = start.distanceTo(end)
                if (legLen <= 0) {
                    previousEnd = end
                    continue
                }
                var shotsOnLeg = Math.ceil(legLen / spacing) + 1
                for (var i = 0; i < shotsOnLeg; i++) {
                    schedule.push(cumulative + Math.min(i * spacing, legLen))
                }
                cumulative += legLen
                previousEnd = end
            }
        }

        if (schedule.length === 0) {
            var path = routeMappingTransectPath
            if (path && path.length >= 2 && spacing > 0) {
                var totalLen = 0
                for (var seg = 1; seg < path.length; seg++) {
                    totalLen += path[seg - 1].distanceTo(path[seg])
                }
                var shots = Math.ceil(totalLen / spacing) + 1
                for (var j = 0; j < shots; j++) {
                    schedule.push(Math.min(j * spacing, totalLen))
                }
            }
        }
        if (planned > 0 && schedule.length > planned) {
            schedule = schedule.slice(0, planned)
        }

        _routeMappingGcsTriggerDistances = schedule
    }

    function _routeMappingSurveyVisualItem() {
        if (!_missionController || !_missionController.visualItems) {
            return null
        }
        for (var i = 0; i < _missionController.visualItems.count; i++) {
            var visualItem = _missionController.visualItems.get(i)
            if (visualItem && visualItem.surveyAreaPolygon) {
                return visualItem
            }
        }
        return null
    }

    function _routeMappingSurveyStartSequence() {
        var survey = _routeMappingSurveyVisualItem()
        if (!survey || survey.sequenceNumber === undefined) {
            return -1
        }
        var sequence = Number(survey.sequenceNumber)
        return isFinite(sequence) ? sequence : -1
    }

    function _routeMappingSurveyLastSequence() {
        var survey = _routeMappingSurveyVisualItem()
        if (!survey || survey.lastSequenceNumber === undefined) {
            return -1
        }
        var sequence = Number(survey.lastSequenceNumber)
        return isFinite(sequence) ? sequence : -1
    }

    function _routeMappingPlannedTriggerCount() {
        var schedule = _routeMappingGcsTriggerDistances
        if (!schedule || schedule.length === 0) {
            return 0
        }
        var planned = Number(routeMappingPlannedPhotoCount)
        return planned > 0 ? Math.min(planned, schedule.length) : schedule.length
    }

    function _routeMappingVehicleOnPhotoCapturePath() {
        if (!_activeVehicle || !mapControl) {
            return false
        }
        var coord = _activeVehicle.coordinate
        if (!coord || !coord.isValid) {
            return false
        }
        var info = mapControl.routeMappingPhotoCaptureInfo(coord)
        if (!info || !info.valid) {
            return false
        }
        var spacing = Math.max(0.1, Number(routeMappingTriggerDistance))
        var corridorMeters = Math.max(8, spacing * 0.75)
        return info.distanceToSegment <= corridorMeters
    }

    function _markRouteMappingPhotoTriggersComplete(reason, drainScheduledCaptures) {
        if (_routeMappingPhotoTriggersComplete) {
            return
        }
        _routeMappingPhotoTriggersComplete = true
        if (drainScheduledCaptures) {
            // Every request already has the GPS pose recorded at its planned
            // distance. Let those requests reach the Pi before closing the
            // session; this prevents the final queued shots being discarded.
            routeMappingPhotoController.finishCaptureQueue()
        } else {
            // Mission exit, disarm, or RTH: never expose at the return/landing
            // position for a request which did not reach the camera in time.
            routeMappingPhotoController.captureEnabled = false
            if (routeMappingPiPhotoFetchEnabled) {
                routeMappingPiPhotoFetcher.haltNewCaptures()
            }
        }
        console.info("[RouteMapping] Photo trigger phase complete:", reason)
    }

    function _mappingPhotoTrackTolerance() {
        var triggerDistance = Math.max(1, Number(routeMappingTriggerDistance))
        return Math.max(2, Math.min(12, triggerDistance * 0.45))
    }

    function _routeMappingGcsCaptureAllowed() {
        if (!routeMappingPhotoProgressEnabled || !missionRunning || !_activeVehicle) {
            return false
        }
        if (_routeMappingPhotoTriggersComplete) {
            return false
        }
        if (!_activeVehicle.armed && !_activeVehicle.flying) {
            return false
        }
        if (!_activeVehicle.missionItemIndex) {
            return false
        }
        var currentIdx = Number(_activeVehicle.missionItemIndex.rawValue)
        if (!isFinite(currentIdx)) {
            return false
        }
        var surveyStart = _routeMappingSurveyStartSequence()
        var surveyLast = _routeMappingSurveyLastSequence()
        if (surveyStart >= 0 && currentIdx < surveyStart) {
            return false
        }
        if (surveyLast >= 0 && currentIdx > surveyLast) {
            return false
        }
        return true
    }

    function _issueGcsRouteMappingTriggerAtIndex(scheduleIndex, vehicleCoordinate) {
        var schedule = _routeMappingGcsTriggerDistances
        if (!schedule || scheduleIndex < 0 || scheduleIndex >= schedule.length
                || !vehicleCoordinate || !vehicleCoordinate.isValid) {
            return false
        }

        var heading = _routeMappingCaptureHeading(vehicleCoordinate)
        if (!_commitRouteMappingPhoto(
                    vehicleCoordinate, true, 0, heading, true, 0)) {
            // Do not retry the same planned position forever if a capture was
            // rejected. Record the missed shot and continue with the route.
            _routeMappingCaptureFailures++
            _routeMappingGcsNextTriggerIndex = scheduleIndex + 1
            return false
        }

        _routeMappingGcsNextTriggerIndex = scheduleIndex + 1
        _routeMappingTriggersReceived++
        return true
    }

    /// Drive the Pi camera from the precomputed survey spacing. This is the
    /// authoritative fallback on vehicles that execute DO_SET_CAM_TRIGG_DIST
    /// but do not publish CAMERA_TRIGGER/CAMERA_IMAGE_CAPTURED telemetry.
    function _processGcsCalculatedPhotoTriggers() {
        if (!routeMappingPhotoProgressEnabled || !routeMappingPiPhotoFetchEnabled
                || _routeMappingPhotoTriggersComplete
                || !_routeMappingGcsCaptureAllowed()
                || !routeMappingPhotoController.captureEnabled
                || !_activeVehicle || !mapControl) {
            return
        }

        var schedule = _routeMappingGcsTriggerDistances
        var maxTriggers = _routeMappingPlannedTriggerCount()
        if (!schedule || schedule.length === 0 || maxTriggers <= 0) {
            return
        }
        if (_routeMappingGcsNextTriggerIndex >= maxTriggers) {
            _markRouteMappingPhotoTriggersComplete(
                        "all planned triggers scheduled", true /* drainScheduledCaptures */)
            return
        }

        if (!routeMappingPhotoController.sessionActive) {
            _retryRouteMappingPiSessionIfNeeded()
            return
        }

        var vehicleCoordinate = _activeVehicle.coordinate
        if (!vehicleCoordinate || !vehicleCoordinate.isValid
                || !_routeMappingVehicleOnPhotoCapturePath()) {
            return
        }

        var alongPath = mapControl.routeMappingDistanceAlongPath(vehicleCoordinate)
        if (!isFinite(alongPath) || alongPath < 0) {
            return
        }
        _routeMappingMaxAlongPathSeen = Math.max(_routeMappingMaxAlongPathSeen, alongPath)

        var spacing = Math.max(0.1, Number(routeMappingTriggerDistance))
        var triggerTolerance = Math.max(1.5, Math.min(6, spacing * 0.45))
        var nextTriggerDistance = Number(schedule[_routeMappingGcsNextTriggerIndex])
        if (!isFinite(nextTriggerDistance)
                || _routeMappingMaxAlongPathSeen + triggerTolerance < nextTriggerDistance) {
            return
        }

        // requestPhotoCapture queues the Pi commands and the controller sends
        // them serially. Do not wait for SCP, which may take longer than the
        // 6 m/9 m exposure interval.
        _issueGcsRouteMappingTriggerAtIndex(
                    _routeMappingGcsNextTriggerIndex, vehicleCoordinate)
        // Latch completion in the same telemetry callback as the Nth request.
        // Waiting for another position tick allowed mission/RTH state to win
        // the race and discard that final queued exposure.
        if (_routeMappingGcsNextTriggerIndex >= maxTriggers) {
            _markRouteMappingPhotoTriggersComplete(
                        "all planned triggers scheduled", true /* drainScheduledCaptures */)
        }
    }

    function _mappingPhotoNearCoordinate(coordinate, duplicateRadiusOverride) {
        var triggerDistance = Math.max(1, Number(routeMappingTriggerDistance))
        var duplicateRadius = duplicateRadiusOverride > 0
                ? duplicateRadiusOverride
                : Math.max(2, Math.min(12, triggerDistance * 0.45))
        for (var i = 0; i < _routeMappingLivePhotoModel.count; i++) {
            var photo = _routeMappingLivePhotoModel.get(i)
            var photoCoordinate = QtPositioning.coordinate(
                        photo.photoLatitude,
                        photo.photoLongitude,
                        photo.photoAltitude)
            if (photoCoordinate.isValid && photoCoordinate.distanceTo(coordinate) <= duplicateRadius) {
                return i
            }
        }
        return -1
    }

    function _routeMappingCaptureAglMeters() {
        if (!_activeVehicle) {
            return 0
        }

        // Above-terrain is correct over sloped ground. Relative altitude is
        // the dependable fallback when terrain data is unavailable.
        var aboveTerrain = _activeVehicle.altitudeAboveTerr
                ? Number(_activeVehicle.altitudeAboveTerr.rawValue) : Number.NaN
        if (isFinite(aboveTerrain) && aboveTerrain > 0.5) {
            return aboveTerrain
        }
        var relativeAltitude = _activeVehicle.altitudeRelative
                ? Number(_activeVehicle.altitudeRelative.rawValue) : Number.NaN
        return isFinite(relativeAltitude) && relativeAltitude > 0.5
                ? relativeAltitude : 0
    }

    function _routeMappingGroundFootprint(aglMeters) {
        if (!isFinite(aglMeters) || aglMeters <= 0) {
            return {
                side: Math.max(1, Number(routeMappingPhotoFootprintSide)),
                frontal: Math.max(1, Number(routeMappingPhotoFootprintFrontal))
            }
        }

        var radiansPerHalfDegree = Math.PI / 360
        return {
            side: 2 * aglMeters * Math.tan(
                      routeMappingCameraHorizontalFovDegrees * radiansPerHalfDegree),
            frontal: 2 * aglMeters * Math.tan(
                         routeMappingCameraVerticalFovDegrees * radiansPerHalfDegree)
        }
    }

    function _routeMappingCaptureHeading(coordinate) {
        var vehicleHeading = _activeVehicle && _activeVehicle.heading
                ? Number(_activeVehicle.heading.rawValue) : Number.NaN
        if (isFinite(vehicleHeading) && vehicleHeading >= 0) {
            return vehicleHeading
        }
        return mapControl.routeMappingHeadingAtCoordinate(coordinate)
    }

    function _handleRouteMappingCameraTrigger(nativeTriggerSequence, capturedCoordinate,
                                               capturedRelativeAltitude) {
        if (!routeMappingPhotoProgressEnabled || !routeMappingPiPhotoFetchEnabled
                || !_routeMappingGcsCaptureAllowed()) {
            return
        }

        var sequence = Number(nativeTriggerSequence)
        if (!isFinite(sequence)) {
            return
        }
        var sequenceKey = String(sequence)
        if (_routeMappingNativeTriggerSequences.indexOf(sequenceKey) >= 0) {
            return
        }

        // Some PX4 camera setups publish both CAMERA_TRIGGER and
        // CAMERA_IMAGE_CAPTURED for the same exposure. They can use different
        // counters, so suppress the paired report by arrival time as well.
        var nowMs = Date.now()
        if (_routeMappingLastNativeTriggerMs > 0
                && nowMs - _routeMappingLastNativeTriggerMs < 500) {
            return
        }

        var coordinate = capturedCoordinate && capturedCoordinate.isValid
                ? capturedCoordinate : _activeVehicle.coordinate
        if (!coordinate || !coordinate.isValid) {
            console.warn("[RouteMapping] CAMERA_TRIGGER", sequence,
                         "ignored because vehicle coordinate is invalid")
            return
        }

        // A native camera event can arrive just after the position scheduler
        // has requested the same Pi exposure. Attach the native sequence to the
        // existing shot instead of issuing a duplicate CAPTURE command.
        var nativeDuplicateRadius = Math.max(
                    2, Math.min(6, Number(routeMappingTriggerDistance) * 0.45))
        var existingPhotoIndex = _mappingPhotoNearCoordinate(
                    coordinate, nativeDuplicateRadius)
        if (existingPhotoIndex >= 0) {
            var duplicateSeen = _routeMappingNativeTriggerSequences.slice()
            duplicateSeen.push(sequenceKey)
            _routeMappingNativeTriggerSequences = duplicateSeen
            _routeMappingLastNativeTriggerMs = nowMs
            _routeMappingLivePhotoModel.setProperty(
                        existingPhotoIndex, "nativeTriggerSequence", sequence)
            _routeMappingLivePhotoModel.setProperty(
                        existingPhotoIndex, "photoTelemetryConfirmed", true)
            return
        }

        var seen = _routeMappingNativeTriggerSequences.slice()
        seen.push(sequenceKey)
        _routeMappingNativeTriggerSequences = seen
        _routeMappingLastNativeTriggerMs = nowMs

        if (_commitRouteMappingPhoto(
                    coordinate,
                    true,
                    0,
                    _routeMappingCaptureHeading(coordinate),
                    true,
                    sequence,
                    capturedRelativeAltitude)) {
            _routeMappingTriggersReceived++
            var plannedTriggerCount = _routeMappingPlannedTriggerCount()
            _routeMappingGcsNextTriggerIndex = Math.min(
                        _routeMappingGcsNextTriggerIndex + 1,
                        plannedTriggerCount)
            if (plannedTriggerCount > 0
                    && _routeMappingGcsNextTriggerIndex >= plannedTriggerCount) {
                _markRouteMappingPhotoTriggersComplete(
                            "all planned triggers scheduled", true /* drainScheduledCaptures */)
            }
        } else {
            _routeMappingCaptureFailures++
        }
    }

    function _commitRouteMappingPhoto(coordinate, telemetryConfirmed, duplicateRadiusOverride, heading,
                                      authoritativeTrigger, nativeTriggerSequence, captureAglOverride) {
        if (_routeMappingPhotoTriggersComplete) {
            return false
        }
        if (routeMappingPiPhotoFetchEnabled && !routeMappingPhotoController.captureEnabled) {
            return false
        }

        // Native CAMERA_TRIGGER sequence numbers are the capture authority.
        // Coordinate matching is only for non-authoritative camera feedback.
        var matchingIndex = authoritativeTrigger ? -1 : _mappingPhotoNearCoordinate(
                    coordinate, duplicateRadiusOverride)
        if (matchingIndex >= 0) {
            if (telemetryConfirmed) {
                _routeMappingLivePhotoModel.setProperty(matchingIndex, "photoLatitude", coordinate.latitude)
                _routeMappingLivePhotoModel.setProperty(matchingIndex, "photoLongitude", coordinate.longitude)
                _routeMappingLivePhotoModel.setProperty(matchingIndex, "photoAltitude", coordinate.altitude)
                _routeMappingLivePhotoModel.setProperty(
                            matchingIndex,
                            "photoHeading",
                            mapControl.routeMappingHeadingAtCoordinate(coordinate))
                _routeMappingLivePhotoModel.setProperty(matchingIndex, "photoTelemetryConfirmed", true)
            }
            return false
        }

        var photoNumber = _routeMappingLivePhotoModel.count + 1
        var filePath = ""
        if (routeMappingPiPhotoFetchEnabled) {
            // Session warms on mission start (beginSession + async Pi). Do not block
            // captures while piSessionPending — queue UDP/SCP and show the tile immediately.
            if (!routeMappingPhotoController.sessionActive) {
                if (!routeMappingPhotoController.sessionDirectory
                        || routeMappingPhotoController.sessionDirectory.length === 0) {
                    routeMappingPhotoController.captureEnabled = true
                    routeMappingPhotoController.beginSession()
                }
            }
            filePath = routeMappingPhotoController.imagePathForSequence(photoNumber)
            if (!filePath || filePath.length === 0) {
                return false
            }
        } else {
            var photoDirectory = QGroundControl.settingsManager.appSettings.photoSavePath
            if (!photoDirectory || photoDirectory.length === 0) {
                if (!_routeMappingPhotoPathWarned) {
                    _routeMappingPhotoPathWarned = true
                    mainWindow.showMessageDialog(
                                QGroundControl.appName,
                                qsTr("Photo save path is not configured. Set it in Application Settings to capture route mapping photos."))
                }
                return false
            }
            var fileName = "mapping_" + Date.now() + "_" + photoNumber + ".jpg"
            var separator = photoDirectory.charAt(photoDirectory.length - 1) === "/" ? "" : "/"
            filePath = photoDirectory + separator + fileName
        }

        // Match m4_picam.py: its GLOBAL_POSITION_INT handler stores
        // relative_alt and writes that value into GPSAltitude.
        var captureRelativeAltitude = Number(captureAglOverride)
        if (!isFinite(captureRelativeAltitude)) {
            captureRelativeAltitude = _activeVehicle && _activeVehicle.altitudeRelative
                    ? Number(_activeVehicle.altitudeRelative.rawValue) : Number.NaN
        }
        if (!isFinite(captureRelativeAltitude)) {
            console.warn("[RouteMapping] Photo", photoNumber,
                         "has no valid relative altitude; reference EXIF geotag cannot be written")
            return false
        }

        // Keep the footprint based on actual height above the surface when it
        // is available. This display value is independent from the reference
        // script's relative-altitude EXIF field.
        var captureAgl = _routeMappingCaptureAglMeters()
        if (!isFinite(captureAgl) || captureAgl <= 0.5) {
            captureAgl = captureRelativeAltitude
        }

        // MapQuickItem retains AMSL when available, although the JPEG EXIF
        // intentionally follows the reference script's relative-altitude value.
        var captureAltitudeAmsl = Number(coordinate.altitude)
        if (!isFinite(captureAltitudeAmsl) && _activeVehicle && _activeVehicle.altitudeAMSL) {
            captureAltitudeAmsl = Number(_activeVehicle.altitudeAMSL.rawValue)
        }
        if (!isFinite(captureAltitudeAmsl)) {
            captureAltitudeAmsl = captureRelativeAltitude
        }
        var groundFootprint = _routeMappingGroundFootprint(captureAgl)

        // Pi path: draw the map footprint immediately, then queue CAPTURE/SCP.
        _routeMappingLivePhotoModel.append({
            photoLatitude: coordinate.latitude,
            photoLongitude: coordinate.longitude,
            photoAltitude: captureAltitudeAmsl,
            photoHeading: heading,
            photoAgl: captureAgl,
            photoFootprintSide: groundFootprint.side,
            photoFootprintFrontal: groundFootprint.frontal,
            photoSequence: photoNumber,
            nativeTriggerSequence: Number(nativeTriggerSequence || 0),
            photoImageSource: routeMappingPiPhotoFetchEnabled ? "" : _mappingPhotoFileUrl(filePath),
            photoTelemetryConfirmed: telemetryConfirmed,
            photoReady: !routeMappingPiPhotoFetchEnabled,
            photoFetchFailed: false,
            photoPlaceholder: routeMappingPiPhotoFetchEnabled
        })

        var committedIndex = _routeMappingLivePhotoModel.count - 1

        if (routeMappingPiPhotoFetchEnabled) {
            if (!routeMappingPhotoController.requestPhotoCapture(
                        photoNumber,
                        Number(nativeTriggerSequence || 0),
                        coordinate.latitude,
                        coordinate.longitude,
                        captureRelativeAltitude,
                        heading)) {
                _routeMappingLivePhotoModel.setProperty(committedIndex, "photoFetchFailed", true)
                _routeMappingLivePhotoModel.setProperty(committedIndex, "photoPlaceholder", false)
                return false
            }
            _trackRouteMappingPhotoFile(filePath)
            return true
        }

        _trackRouteMappingPhotoFile(filePath)
        QGroundControl.videoManager.grabImage(filePath)
        return true
    }

    function _captureNewRouteMappingPhotos() {
        if (routeMappingPhotoProgressEnabled && routeMappingPiPhotoFetchEnabled) {
            _retryRouteMappingPiSessionIfNeeded()
            _processGcsCalculatedPhotoTriggers()
        }
    }

    // Progress panel: native PX4 triggers accepted vs JPEGs copied to the GCS.
    readonly property int routeMappingPhotosTaken: {
        if (!routeMappingPhotoProgressEnabled) {
            return 0
        }
        return routeMappingPiPhotoFetchEnabled
                ? _routeMappingTriggersReceived
                : _routeMappingLivePhotoModel.count
    }

    readonly property int routeMappingPhotosRetrieved: {
        if (!routeMappingPhotoProgressEnabled) {
            return 0
        }
        return routeMappingPiPhotoFetchEnabled
                ? _routeMappingPhotosRetrieved
                : _routeMappingLivePhotoModel.count
    }

    readonly property bool missionRunning:  _guidedController ? _guidedController._missionActive : false
    property var    _missionController:     _planController.missionController
    property var    _geoFenceController:    _planController.geoFenceController
    property var    _rallyPointController:  _planController.rallyPointController
    property real   _margins:               ScreenTools.defaultFontPixelWidth / 2
    property var    _guidedController:      guidedActionsController
    property var    _guidedValueSlider:     guidedValueSlider
    property var    _widgetLayer:           widgetLayer
    property real   _toolsMargin:           ScreenTools.defaultFontPixelWidth * 0.75
    property rect   _centerViewport:        Qt.rect(0, 0, width, height)
    property real   _rightPanelWidth:       ScreenTools.defaultFontPixelWidth * 30
    property var    _mapControl:            mapControl
    property real   _widgetMargin:          ScreenTools.defaultFontPixelWidth * 0.75
    property bool   _missionResyncPending:  false

    property real   _fullItemZorder:    0
    property real   _pipItemZorder:     QGroundControl.zOrderWidgets

    QGCPalette { id: qgcPal }

    // Reset mission index when items change to prevent stale index issues
    Connections {
        target: _missionController

        function onNewItemsFromVehicle() {
            _missionController.setCurrentPlanViewSeqNum(0, true)
            if (_missionResyncPending) {
                _missionResyncPending = false
                missionResyncTimeoutTimer.stop()
                _handleMissionResyncComplete()
            }
        }
    }

    Connections {
        target: _activeVehicle ? _activeVehicle.vehicleLinkManager : null

        function onCommunicationLostChanged(lost) {
            if (!lost) {
                _scheduleMissionResyncFromVehicle()
                _root._retryRouteMappingPiSessionIfNeeded()
            }
        }

    }

    Connections {
        target: QGroundControl.multiVehicleManager

        function onActiveVehicleChanged(vehicle) {
            _root.resetRouteMappingLivePhotos()
            if (vehicle && !vehicle.flying) {
                _root._scheduleMissionResyncFromVehicle()
            }
        }
    }

    Connections {
        target: _root._activeVehicle
        ignoreUnknownSignals: true

        function onArmedChanged(armed) {
            if (armed) {
                // Some vehicle backends can notify the same armed state more
                // than once. Never cancel an async startup that is already in
                // progress: doing so used to leave the controller waiting for
                // a completion signal from a stale fetcher generation.
                if (routeMappingPhotoController.sessionActive
                        || routeMappingPhotoController.piSessionPending
                        || routeMappingPiPhotoFetcher.piSessionStarting) {
                    return
                }
                // Start a new capture set without deleting the previous
                // mission's survey photographs from the configured photo path.
                _root._routeMappingSessionPhotoFiles = []
                _root.resetRouteMappingLivePhotos(true /* startingNewSession */)
                // Session startup is asynchronous. Begin it while armed so SSH
                // and VIDEO_PAUSE are ready before the first survey transect.
                if (_root.routeMappingPhotoProgressEnabled
                        && _root.routeMappingPiPhotoFetchEnabled) {
                    _root._beginRouteMappingPhotoSession()
                }
            } else {
                if (_root.routeMappingPhotoProgressEnabled) {
                    _root._markRouteMappingPhotoTriggersComplete("disarmed")
                }
                _root._endRouteMappingPhotoSession()
            }
        }

        function onCoordinateChanged() {
            _root._captureNewRouteMappingPhotos()
        }

        function onFlyingChanged() {
            _root._captureNewRouteMappingPhotos()
        }

        function onMissionItemIndexChanged() {
            _root._captureNewRouteMappingPhotos()
        }

        function onCameraTriggerReceived(sequence) {
            _root._handleRouteMappingCameraTrigger(sequence)
        }

        function onCameraImageCapturedReceived(imageIndex, coordinate, relativeAltitude) {
            _root._handleRouteMappingCameraTrigger(
                        imageIndex, coordinate, relativeAltitude)
        }

        function onInitialPlanRequestCompleteChanged(complete) {
            if (complete) {
                _root._scheduleMissionResyncFromVehicle()
            }
        }
    }

    onMissionRunningChanged: {
        if (missionRunning && routeMappingPhotoProgressEnabled) {
            if (!_routeMappingPhotoTriggersComplete) {
                routeMappingPhotoController.captureEnabled = true
                if (!routeMappingPhotoController.sessionActive
                        && !routeMappingPhotoController.piSessionPending
                        && !routeMappingPiPhotoFetcher.piSessionStarting) {
                    // This starts the retrying SSH precheck and warms the same
                    // ControlMaster connection later used by SCP. Do not launch
                    // a second warm-up handshake over the vehicle link.
                    routeMappingPhotoController.beginSession()
                }
            }
        } else if (!missionRunning) {
            if (routeMappingPhotoProgressEnabled) {
                _markRouteMappingPhotoTriggersComplete("mission ended")
                _endRouteMappingPhotoSession()
            } else {
                routeMappingPhotoController.captureEnabled = false
            }
        }
        _captureNewRouteMappingPhotos()
    }

    Component.onCompleted: _rebuildRouteMappingGcsTriggerSchedule()

    Timer {
        id: routeMappingGcsTriggerTimer
        interval: 250
        repeat: true
        running: _root.routeMappingPhotoProgressEnabled
                 && _root.routeMappingPiPhotoFetchEnabled
                 && _root.missionRunning
        onTriggered: {
            _root._retryRouteMappingPiSessionIfNeeded()
            _root._processGcsCalculatedPhotoTriggers()
        }
    }

    Timer {
        id: missionResyncDebounceTimer
        interval: 1000
        repeat: false
        onTriggered: _beginMissionResyncFromVehicle()
    }

    Timer {
        id: missionResyncTimeoutTimer
        interval: 8000
        repeat: false
        onTriggered: {
            if (_root._missionResyncPending) {
                _root._missionResyncPending = false
                _root._handleMissionResyncComplete()
            }
        }
    }

    function _scheduleMissionResyncFromVehicle() {
        if (!_activeVehicle || _activeVehicle.flying) {
            return
        }
        missionResyncDebounceTimer.restart()
    }

    function _beginMissionResyncFromVehicle() {
        if (!_activeVehicle || _planController.offline || _activeVehicle.flying
                || _planController.syncInProgress) {
            return
        }
        if (!_activeVehicle.initialPlanRequestComplete) {
            return
        }
        _missionResyncPending = true
        _planController.reloadMissionFromVehicle()
        missionResyncTimeoutTimer.restart()
    }

    // After link loss / reconnect, refresh from the vehicle. If the autopilot
    // has no mission (reboot, partial loss), re-upload the last Route Mapping plan.
    function _handleMissionResyncComplete() {
        if (!_activeVehicle || _planController.syncInProgress) {
            return
        }

        _planController.showPlanFromManagerVehicle()

        var editorView = mainWindow.missionEditorView(mainWindow.uploadedMissionEditor)
        if (editorView && editorView.vehicleMissionIsStartable
                && editorView.vehicleMissionIsStartable(_missionController)) {
            editorView.onFlyViewMissionResyncedFromVehicle()
            return
        }

        if (routeMappingView.vehicleMissionIsStartable(_missionController)) {
            routeMappingView.onFlyViewMissionResyncedFromVehicle()
            return
        }

        if (mainWindow.tryReuploadLastExecutedPlanAfterReconnect()) {
            return
        }

        if (_planController.containsItems) {
            _planController.upload()
        }
    }

    // Helper functions for mission editing
    function insertSimpleItemAfterCurrent(coordinate) {
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        // Ensure we don't try to insert beyond the current count
        var maxIndex = _missionController.visualItems ? _missionController.visualItems.count : 0
        if (nextIndex > maxIndex) {
            nextIndex = maxIndex
        }
        _missionController.insertSimpleMissionItem(coordinate, nextIndex, true /* makeCurrentItem */)
    }

    function insertTakeoffItemAfterCurrent() {
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertTakeoffItem(mapCenter(), nextIndex, true /* makeCurrentItem */)
    }

    function insertLandItemAfterCurrent() {
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertLandItem(mapCenter(), nextIndex, true /* makeCurrentItem */)
    }

    function insertComplexItemAfterCurrent(complexItemName) {
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertComplexMissionItem(complexItemName, mapCenter(), nextIndex, true /* makeCurrentItem */)
    }

    function mapCenter() {
        var coordinate = mapControl.center
        coordinate.latitude  = coordinate.latitude.toFixed(_decimalPlaces)
        coordinate.longitude = coordinate.longitude.toFixed(_decimalPlaces)
        coordinate.altitude  = coordinate.altitude.toFixed(_decimalPlaces)
        return coordinate
    }

    function exitPlanEditMode() {
        planEditMode = false
    }

    function _calcCenterViewPort() {
        var newToolInset = Qt.rect(0, 0, width, height)
        toolstrip.adjustToolInset(newToolInset)
    }

    function dropMainStatusIndicatorTool() {
        toolbar.dropMainStatusIndicatorTool();
    }

    QGCToolInsets {
        id:                     _toolInsets
        topEdgeLeftInset:       toolbar.height
        topEdgeCenterInset:     topEdgeLeftInset
        topEdgeRightInset:      topEdgeLeftInset
        leftEdgeBottomInset:    _pipView.leftEdgeBottomInset
        bottomEdgeLeftInset:    _pipView.bottomEdgeLeftInset
    }

    Item {
        id:                 mapHolder
        anchors.fill:       parent

        FlyViewMap {
            id:                     mapControl
            planMasterController:   _planController
            rightPanelWidth:        ScreenTools.defaultFontPixelHeight * 9
            pipView:                _pipView
            pipMode:                !_mainWindowIsMap
            toolInsets:             customOverlay.totalToolInsets
            mapName:                "FlightDisplayView"
            enabled:                !viewer3DWindow.isOpen

            // Pass plan edit mode properties to map
            planEditMode:           _root.planEditMode
            editingLayer:           _root._editingLayer
            missionController:      _root._missionController
            geoFenceController:     _root._geoFenceController
            rallyPointController:   _root._rallyPointController
            routeMappingBoundaryPath: _root.routeMappingBoundaryPath
            routeMappingTransectPath: _root.routeMappingTransectPath
            routeMappingPhotoCaptureTransectPoints: _root.routeMappingPhotoCaptureTransectPoints
            routeMappingTakeoffCoordinate: _root.routeMappingTakeoffCoordinate
            routeMappingEntryCoordinate: _root.routeMappingEntryCoordinate
            routeMappingExitCoordinate: _root.routeMappingExitCoordinate
            routeMappingEntryHeading: _root.routeMappingEntryHeading
            routeMappingExitHeading: _root.routeMappingExitHeading
            routeMappingPhotoFootprintSide: _root.routeMappingPhotoFootprintSide
            routeMappingPhotoFootprintFrontal: _root.routeMappingPhotoFootprintFrontal
            routeMappingTriggerDistance: _root.routeMappingTriggerDistance
            routeMappingLivePhotoModel: _root.routeMappingLivePhotoModel
            routeMappingOrthophotoUrl: _root.routeMappingOrthophotoUrl
            routeMappingOrthophotoNorthWest: _root.routeMappingOrthophotoNorthWest
            routeMappingOrthophotoSouthEast: _root.routeMappingOrthophotoSouthEast
            routeMappingOrthophotoReady: _root.routeMappingOrthophotoReady
            routeMappingOrthophotoOpacity: _root.routeMappingOrthophotoOpacity
            hideVehicleMissionForUnuploadedRoute: _root.hideVehicleMissionForUnuploadedRoute
            onWaypointAdded: function(coordinate) {
                _root.insertSimpleItemAfterCurrent(coordinate)
            }

            onRallyPointAdded: function(coordinate) {
                if (_rallyPointController.supported) {
                    _rallyPointController.addPoint(coordinate)
                }
            }
        }

        FlyViewVideo {
            id:         videoControl
            pipView:    _pipView
            routeMappingPiStillsActive: _root.routeMappingPhotoProgressEnabled
                                          && _root.routeMappingPiPhotoFetchEnabled
                                          && routeMappingPhotoController.sessionActive
        }

        PipView {
            id:                     _pipView
            anchors.left:           guidedValueSlider.visible && guidedValueSlider.leftSide ? guidedValueSlider.right : parent.left
            anchors.bottom:         parent.bottom
            anchors.margins:        _toolsMargin
            item1IsFullSettingsKey: "MainFlyWindowIsMap"
            item1:                  mapControl
            item2:                  QGroundControl.videoManager.hasVideo ? videoControl : null
            show:                   !planEditMode && QGroundControl.videoManager.hasVideo && !QGroundControl.videoManager.fullScreen &&
                                        (videoControl.pipState.state === videoControl.pipState.pipState || mapControl.pipState.state === mapControl.pipState.pipState)
            z:                      QGroundControl.zOrderWidgets

            // Fixed height matching bottom bar (slightly smaller), with matching aspect ratio
            height:                 widgetLayer.bottomBar.height * 0.9
            width:                  height * (16/9)
            cornerRadius:           height * 0.15 // Decent squircle rounding

            property real leftEdgeBottomInset: visible ? x + width : 0
            property real bottomEdgeLeftInset: visible ? height + anchors.margins : 0

            // Slide down with the bottom bar when entering plan edit mode
            transform: Translate {
                y: _root.planEditMode ? _pipView.height + _toolsMargin * 4 : 0
                Behavior on y { NumberAnimation { duration: 350; easing.type: Easing.InOutQuad } }
            }
        }

        FlyViewWidgetLayer {
            id:                     widgetLayer
            anchors.top:            parent.top
            anchors.bottom:         parent.bottom
            anchors.left:           guidedValueSlider.visible && guidedValueSlider.leftSide ? guidedValueSlider.right : parent.left
            anchors.right:          guidedValueSlider.visible && !guidedValueSlider.leftSide ? guidedValueSlider.left : parent.right
            anchors.margins:        _widgetMargin
            anchors.topMargin:      toolbar.height + _widgetMargin
            z:                      (widgetLayer.bottomBar.terrainFlowActive || widgetLayer.bottomBar.obstacleAvoidanceActive) ? QGroundControl.zOrderTopMost + 1 : _fullItemZorder + 2
            parentToolInsets:       _toolInsets
            mapControl:             _mapControl
            visible:                !QGroundControl.videoManager.fullScreen
            isViewer3DOpen:         viewer3DWindow.isOpen
            planEditMode:           _root.planEditMode
        }

        FlyViewCustomLayer {
            id:                 customOverlay
            anchors.fill:       widgetLayer
            z:                  _fullItemZorder + 2
            parentToolInsets:   widgetLayer.totalToolInsets
            mapControl:         _mapControl
            visible:            !planEditMode && !QGroundControl.videoManager.fullScreen
        }

        // Development tool for visualizing the insets for a paticular layer, show if needed
        FlyViewInsetViewer {
            id:                     widgetLayerInsetViewer
            anchors.top:            parent.top
            anchors.bottom:         parent.bottom
            anchors.left:           guidedValueSlider.visible && guidedValueSlider.leftSide ? guidedValueSlider.right : parent.left
            anchors.right:          guidedValueSlider.visible && !guidedValueSlider.leftSide ? guidedValueSlider.left : parent.right
            z:                      widgetLayer.z + 1
            insetsToView:           widgetLayer.totalToolInsets
            visible:                false
        }

        GuidedActionsController {
            id:                 guidedActionsController
            missionController:  _missionController
            planMasterController: _planController
            guidedValueSlider:     _guidedValueSlider
        }

        //-- Guided value slider (e.g. altitude)
        GuidedValueSlider {
            id:                 guidedValueSlider
            x:                  leftSide ? 0 : parent.width - width
            height:             compactMode
                                    ? Math.max(0, Math.min(ScreenTools.defaultFontPixelHeight * 18,
                                                           parent.height - toolbar.height - (_widgetMargin * 2)))
                                    : Math.max(0, parent.height - toolbar.height)
            y:                  compactMode ? toolbar.height + ((parent.height - toolbar.height - height) / 2) : toolbar.height
            z:                  QGroundControl.zOrderTopMost
            visible:            false
        }

        Viewer3D {
            id: viewer3DWindow
            anchors.fill: parent
        }

        // ============ PLAN EDIT MODE COMPONENTS ============

        // Sliding Toolbar Panel from the right
        FlyViewMissionPanel {
            id:                     missionPanel
            anchors.top:            parent.top
            anchors.topMargin:      toolbar.height + mapTools.height + ScreenTools.defaultFontPixelHeight * 2.0
            planMasterController:   _planController
            planEditMode:           _root.planEditMode
            missionController:      _root._missionController
            editingLayer:           _root._editingLayer
            mapControl:             mapControl
            showMissionStats:       _root._showMissionStats
            z:                      QGroundControl.zOrderWidgets + 5

            onLayerSelectionChanged: function(layer) {
                _root._editingLayer = layer
            }

            onInsertTakeoff: _root.insertTakeoffItemAfterCurrent()
            onInsertLand: _root.insertLandItemAfterCurrent()
            onInsertComplexItem: function(itemName) {
                _root.insertComplexItemAfterCurrent(itemName)
            }
            onAddWaypointAtCenter: {
                var centerCoord = mapControl.center
                _root.insertSimpleItemAfterCurrent(centerCoord)
            }
            onAddPolygonPoint: {
                // Add vertex to current survey polygon
                var currentItem = _root._missionController.currentPlanViewItem
                if (currentItem && currentItem.surveyAreaPolygon) {
                    var centerCoord = mapControl.center
                    currentItem.surveyAreaPolygon.appendVertex(centerCoord)
                }
            }
            onToggleMissionStats: _root._showMissionStats = !_root._showMissionStats
        }

        // Plan View Left Panel (Mission/Fence/Rally settings)
        FlyViewPlanRightPanel {
            id:                     planRightPanel
            anchors.top:            parent.top
            anchors.bottom:         parent.bottom
            anchors.left:           parent.left
            anchors.topMargin:      toolbar.height
            planMasterController:   _planController
            planEditMode:           _root.planEditMode
            editingLayer:           _root._editingLayer
            mapControl:             mapControl
            z:                      QGroundControl.zOrderWidgets + 5

            onLayerSelectionChanged: function(layer) {
                _root._editingLayer = layer
            }
        }

        // Mission Stats Panel (styled like PlanView missionStatus)
        RowLayout {
            id: missionStatsPanel
            anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
            anchors.left: planRightPanel.right
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: 0
            visible: _root.planEditMode && _root._showMissionStats && _root._editingLayer === _root._layerMission
            z: QGroundControl.zOrderWidgets + 10

            function _toggleMissionStatusVisibility() {
                _root._showMissionStats = !_root._showMissionStats
            }

            // Terrain and mission stats content
            TerrainStatus {
                id: terrainStatus
                Layout.alignment: Qt.AlignBottom
                Layout.fillWidth: true
                height: ScreenTools.defaultFontPixelHeight * 7
                missionController: _root._missionController
                visible: terrainButton.checked
                onSetCurrentSeqNum: function(seqNum) { _root._missionController.setCurrentPlanViewSeqNum(seqNum, true) }
            }

            MissionStats {
                id: missionStats
                Layout.alignment: Qt.AlignBottom
                Layout.fillWidth: true
                visible: missionStatsButton.checked
                planMasterController: _planController
            }

            // Toggle buttons on the right side
            ColumnLayout {
                id: missionStatsButtonLayout
                Layout.alignment: Qt.AlignBottom
                spacing: 0

                property real _buttonImplicitWidth: ScreenTools.defaultFontPixelHeight * 1.5
                property real _buttonImageMargins: _buttonImplicitWidth * 0.15

                Rectangle {
                    id: terrainButton
                    implicitWidth: missionStatsButtonLayout._buttonImplicitWidth
                    implicitHeight: implicitWidth
                    color: checked ? qgcPal.buttonHighlight : qgcPal.button

                    property bool checked: true

                    QGCColoredImage {
                        anchors.margins: missionStatsButtonLayout._buttonImageMargins
                        anchors.fill: parent
                        source: "/res/terrain.svg"
                        color: parent.checked ? qgcPal.buttonHighlightText : qgcPal.buttonText
                    }

                    QGCMouseArea {
                        anchors.fill: parent
                        onClicked: {
                            terrainButton.checked = true
                            missionStatsButton.checked = false
                        }
                    }
                }

                Rectangle {
                    id: missionStatsButton
                    implicitWidth: missionStatsButtonLayout._buttonImplicitWidth
                    implicitHeight: implicitWidth
                    color: checked ? qgcPal.buttonHighlight : qgcPal.button

                    property bool checked: false

                    QGCColoredImage {
                        anchors.margins: missionStatsButtonLayout._buttonImageMargins
                        anchors.fill: parent
                        source: "/res/sliders.svg"
                        color: parent.checked ? qgcPal.buttonHighlightText : qgcPal.buttonText
                    }

                    QGCMouseArea {
                        anchors.fill: parent
                        onClicked: {
                            missionStatsButton.checked = true
                            terrainButton.checked = false
                        }
                    }
                }

                Rectangle {
                    id: bottomStatusCloseButton
                    implicitWidth: missionStatsButtonLayout._buttonImplicitWidth
                    implicitHeight: implicitWidth
                    color: qgcPal.button

                    QGCColoredImage {
                        anchors.margins: missionStatsButtonLayout._buttonImageMargins
                        anchors.fill: parent
                        source: "/res/chevron-double-right.svg"
                        color: qgcPal.buttonText
                    }

                    QGCMouseArea {
                        anchors.fill: parent
                        onClicked: missionStatsPanel._toggleMissionStatusVisibility()
                    }
                }
            }
        }
    }

    UTMSPActivationStatusBar {
        activationStartTimestamp:   UTMSPStateStorage.startTimeStamp
        activationApproval:         UTMSPStateStorage.showActivationTab && QGroundControl.utmspManager.utmspVehicle.vehicleActivation
        flightID:                   UTMSPStateStorage.flightID
        anchors.fill:               parent
        visible:                    !_root.planEditMode

        function onActivationTriggered(value) {
            _root.utmspSendActTrigger = value
        }
    }

    // Container to handle visibility of GuidedActionConfirm without overwriting its internal state
    Item {
        anchors.fill:       parent
        visible:            !QGroundControl.videoManager.fullScreen
        z:                  QGroundControl.zOrderTopMost

        GuidedActionConfirm {
            id:                         guidedActionConfirm
            anchors.bottom:             parent.bottom
            anchors.bottomMargin:       ScreenTools.defaultFontPixelHeight * 8 // High enough to clear all bottom UI elements
            anchors.horizontalCenter:   parent.horizontalCenter
            guidedController:           _guidedController
            guidedValueSlider:          _guidedValueSlider
            utmspSliderTrigger:         utmspSendActTrigger
        }
    }

    // ============ TOOLBARS ============

    // FlyView Toolbar (visible when NOT in plan edit mode)
    FlyViewToolBar {
        id:                 toolbar
        guidedValueSlider:  _guidedValueSlider
        utmspSliderTrigger: utmspSendActTrigger
        visible:            mainWindow.flyViewToolbarVisible
                            && !QGroundControl.videoManager.fullScreen
                            && !mainWindow.modeSelectionVisible
    }

    // PlanView Toolbar (visible when IN plan edit mode)
    PlanViewToolBar {
        id:                     planToolBar
        planMasterController:   _planController
        visible:                false

        onMissionUploaded: {
            _root.exitPlanEditMode()
        }
    }

    Connections {
        target: planToolBar
        function onExitPlanEditMode() {
            _root.exitPlanEditMode()
        }
    }

    // "+ Add" / "Edit" / "Editing Locked" button on right side center
    // Shows "Add" when no plan, "Edit" when plan exists, "Editing Locked" when mission is running
    Rectangle {
        id: addButton
        
        property bool _missionRunning: _root.missionRunning
        property bool _hasPlan: _root._hasFlyViewPlanContent
        
        // Match the Route Mapping Save button.
        height: ScreenTools.defaultFontPixelHeight * 2
        width: contentRow.implicitWidth + ScreenTools.defaultFontPixelWidth * 6
        radius: ScreenTools.defaultFontPixelWidth * 0.45
        color: addButtonMouseArea.pressed ? "#f1f1f1" : "white"
        border.width: 0
        
        z: QGroundControl.zOrderTopMost
        visible: !_root.planEditMode && !QGroundControl.videoManager.fullScreen && _root._mainWindowIsMap
        
        anchors.right: parent.right
        anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 2
        anchors.verticalCenter: parent.verticalCenter

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: ScreenTools.defaultFontPixelWidth * 0.5
            
            // Icon
            QGCColoredImage {
                width: ScreenTools.defaultFontPixelHeight * 1.1
                height: width
                source: {
                    if (addButton._missionRunning) return "/res/modern-icons/MaterialSymbolsLock.svg"
                    if (addButton._hasPlan) return "/res/modern-icons/MaterialSymbolsEditLocationAlt.svg"
                    return "/res/modern-icons/MaterialSymbolsAddLocationAlt.svg"
                }
                color: "#6a6a6a"
                anchors.verticalCenter: parent.verticalCenter
                smooth: true
                mipmap: true
            }
            
            // Text Label
            QGCLabel {
                text: {
                    if (addButton._missionRunning) return qsTr("Editing Locked")
                    if (addButton._hasPlan) return qsTr("Edit")
                    return qsTr("Add")
                }
                font.weight: Font.DemiBold
                color: "#6a6a6a"
                anchors.verticalCenter: parent.verticalCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
        
        QGCMouseArea {
            id: addButtonMouseArea
            anchors.fill: parent
            cursorShape: addButton._missionRunning ? Qt.ForbiddenCursor : Qt.PointingHandCursor
            enabled: !addButton._missionRunning
            onClicked: {
                if (addButton._hasPlan) {
                    mainWindow.showFlyViewPlanEditor()
                } else {
                    mainWindow.showActiveMissionEditor(false /* forEdit */)
                }
            }
            onPressed: addButton.scale = 0.96
            onReleased: addButton.scale = 1.0
        }
        
        Behavior on scale { NumberAnimation { duration: 50 } }
    }

    FlyViewMapTools {
        id:                 mapTools
        anchors.top:        parent.top
        anchors.topMargin:  toolbar.height + ScreenTools.defaultFontPixelHeight * 0.5
        anchors.right:      parent.right
        anchors.rightMargin: ScreenTools.defaultFontPixelWidth
        flyViewRoot:        _root
        planMasterController: _planController
        planEditMode:       _root.planEditMode
        sprayEnableFact: widgetLayer.bottomBar.sprayEnableFact
        sprayNozzleRateFact: widgetLayer.bottomBar.sprayNozzleRateFact
        sprayPumpRateFact: widgetLayer.bottomBar.sprayPumpRateFact
        onSprayerSettingsConfirmed: function(enabled, nozzleRate, pumpRate) {
            _root.applyConfirmedSprayerSettings(enabled, nozzleRate, pumpRate)
        }
        visible:            !QGroundControl.videoManager.fullScreen && _root._mainWindowIsMap
        z:                  QGroundControl.zOrderTopMost + 10
    }
    // This is the flyviewmaiing progress bar code
    FlyViewMappingProgressPanel {
        id:                 mappingProgressPanel
        anchors.top:        mapTools.bottom
        anchors.topMargin:  ScreenTools.defaultFontPixelHeight * 0.5
        anchors.right:      parent.right
        anchors.rightMargin: ScreenTools.defaultFontPixelWidth
        z:                  QGroundControl.zOrderTopMost + 10

        routePercent: mapControl ? mapControl.routeMappingProgressPercent : 0
        photosTaken: _root.routeMappingPhotosTaken
        photosRetrieved: _root.routeMappingPhotosRetrieved
        photosPlanned: _root.routeMappingPhotoProgressEnabled ? _root.routeMappingPlannedPhotoCount : 0
        photoFailures: _root.routeMappingPhotoProgressEnabled ? _root._routeMappingCaptureFailures : 0
        triggersReceived: _root.routeMappingPhotoProgressEnabled ? _root._routeMappingTriggersReceived : 0
        photosVisible: _root.routeMappingPhotoProgressEnabled
        photoModel: _root.routeMappingPhotoProgressEnabled ? _root.routeMappingLivePhotoModel : null
        reconstructionText: routeMappingPhotoController.reconstructionStatus
        reconstructionReady: routeMappingPhotoController.odmReady
        reconstructionRunning: routeMappingPhotoController.odmRunning
        reconstructionComplete: routeMappingPhotoController.odmComplete
        reconstructionProgress: routeMappingPhotoController.reconstructionProgress
        orthomosaicVisible: _root.routeMappingOrthophotoReady
        orthomosaicLoading: _root.routeMappingOrthophotoLoading
        orthomosaicOpacity: _root.routeMappingOrthophotoOpacity
        onReconstructionRequested: routeMappingPhotoController.startOdm()
        onOrthomosaicLoadRequested: _root.openRouteMappingOrthophotoDialog()
        onOrthomosaicHideRequested: _root.clearRouteMappingOrthophoto()
        onOrthomosaicOpacityEdited: function(opacity) {
            _root.routeMappingOrthophotoOpacity = Math.max(0, Math.min(1, opacity))
        }

        visible: !_root.planEditMode
                 && !QGroundControl.videoManager.fullScreen
                 && !mainWindow.modeSelectionVisible
                 && _root._mainWindowIsMap
                 && _root.routeMappingTransectPath
                 && _root.routeMappingTransectPath.length >= 2
    }

    // Plan View Action Buttons (Bottom Right)
    Column {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: ScreenTools.defaultFontPixelWidth * 1.5
        spacing: ScreenTools.defaultFontPixelHeight * 0.5
        visible: _root.planEditMode
        z: 4000

        // Use Button (formerly Save)
        Rectangle {
            id: useButton
            property var planController: _root.planController
            property bool buttonEnabled: planController ? (!planController.syncInProgress && planController.containsItems) : false
            
            height: ScreenTools.defaultFontPixelHeight * 2
            width: useRow.implicitWidth + ScreenTools.defaultFontPixelWidth * 6
            radius: ScreenTools.defaultFontPixelWidth * 0.45
            color: "white"
            opacity: buttonEnabled ? 1.0 : 0.5
            enabled: buttonEnabled

            Row {
                id: useRow
                anchors.centerIn: parent
                spacing: ScreenTools.defaultFontPixelWidth * 0.5

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: ScreenTools.defaultFontPixelHeight * 1.1
                    height: width
                    source: "/res/checkmark_forsave.png"
                    fillMode: Image.PreserveAspectFit
                }

                QGCLabel {
                    text: qsTr("Save")
                    font.weight: Font.DemiBold
                    color: "#6a6a6a"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            QGCMouseArea {
                anchors.fill: parent
                onClicked: _root.planController.upload()
                onPressed: parent.scale = 0.96
                onReleased: parent.scale = 1.0
            }
            
            Behavior on scale { NumberAnimation { duration: 50 } }
        }
    }
}
