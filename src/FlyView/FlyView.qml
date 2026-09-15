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
    property var    routeMappingLivePhotoModel: _routeMappingLivePhotoModel
    property bool   hideVehicleMissionForUnuploadedRoute: false
    // Once a survey overlay has been painted (transfer/import), keep its geometry
    // frozen for the whole mission. Only the drone position and progress update.
    property bool   _routeMappingOverlayLocked: false
    property bool   _routeMappingPhotoPathWarned: false
    // Photo progress UI is Route Mapping only (not Agriculture / Seed Spreader).
    readonly property bool routeMappingPhotoProgressEnabled: mainWindow.uploadedMissionEditor === "routeMapping"
    // Single-photo prototype: capture a real still on the Pi and transfer it
    // over SSH/SCP. Continuous capture is deliberately gated until this path
    // has been verified with the real camera.
    property bool   routeMappingPiPhotoEnabled: routeMappingPhotoProgressEnabled
    property string routeMappingPiHost: "10.5.0.2"
    property string routeMappingPiUser: "shreeon"
    property bool   _routeMappingPrototypeCaptureRequested: false
    property int    _routeMappingPrototypeRequestSequence: 0
    property bool   _routeMappingPiErrorShown: false

    readonly property bool _hasFlyViewPlanContent: _planController.containsItems
                                                   || routeMappingBoundaryPath.length > 0
                                                   || routeMappingTransectPath.length > 0

    property int _lastAppliedSprayerUploadGeneration: 0

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


        var entryHeading = 0
        var exitHeading = 0
        if (visualTransectPoints.length >= 2) {
            entryHeading = visualTransectPoints[0].azimuthTo(visualTransectPoints[1])
            exitHeading = visualTransectPoints[visualTransectPoints.length - 2].azimuthTo(
                        visualTransectPoints[visualTransectPoints.length - 1])
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
        routeMappingTransectPath = transectPath
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
            if (!sideFootprint || sideFootprint <= 0) {
                sideFootprint = Number(surveyItem.cameraCalc.adjustedFootprintSide.value)
            }
            if (!frontalFootprint || frontalFootprint <= 0) {
                frontalFootprint = Number(surveyItem.cameraCalc.adjustedFootprintFrontal.value)
            }
            routeMappingPhotoFootprintSide = sideFootprint > 0 ? sideFootprint : 25
            routeMappingPhotoFootprintFrontal = frontalFootprint > 0 ? frontalFootprint : 25
        }
        if (transectPath.length >= 2) {
            _routeMappingOverlayLocked = true
        }
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

    // Push the uploaded Agriculture/Seed sprayer plan metadata to the vehicle
    // as soon as Fly View is shown — no manual sprayer icon click required.
    function applyUploadedSprayerSettings() {
        var editor = mainWindow.uploadedMissionEditor
        if (editor !== "agricultureSpraying" && editor !== "seedSpreader")
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
        // truth for saves. Vehicle SPRAY_EN may still be off until the operator
        // applies settings from the sprayer panel.
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

    property bool   _mainWindowIsMap:       mapControl.pipState.state === mapControl.pipState.fullState
    property bool   _isFullWindowItemDark:  _mainWindowIsMap ? mapControl.isSatelliteMap : true
    property var    _activeVehicle:         QGroundControl.multiVehicleManager.activeVehicle
    property int    _processedCameraTriggerCount: 0
    property bool   _mappingPatternCaptureStarted: false
    property real   _mappingPhotoDistanceSinceCapture: 0
    property var    _lastMappingPatternCoordinate: QtPositioning.coordinate()
    property int    _activeMappingPhotoSegmentIndex: -1
    property int    _lastCompletedMappingPhotoSegmentIndex: -1
    property real   _mappingPhotoLastSegmentAlong: 0
    property bool   _mappingPhotoSegmentEndCaptured: false
    property var    _routeMappingSessionPhotoFiles: []

    ListModel {
        id: _routeMappingLivePhotoModel
    }

    RouteMappingPiPhotoFetcher {
        id: routeMappingPiPhotoFetcher

        enabled: _root.routeMappingPiPhotoEnabled
        piHost: _root.routeMappingPiHost
        piUser: _root.routeMappingPiUser

        onPhotoFetched: function(requestId, localFilePath, success, errorMessage) {
            var matchingIndex = -1
            for (var index = 0; index < _routeMappingLivePhotoModel.count; index++) {
                var photo = _routeMappingLivePhotoModel.get(index)
                if (Number(photo.photoSequence) === Number(requestId)) {
                    matchingIndex = index
                    break
                }
            }

            if (!success) {
                if (matchingIndex >= 0) {
                    _routeMappingLivePhotoModel.remove(matchingIndex)
                }
                _root._untrackRouteMappingPhotoFile(localFilePath)
                // The C++ worker already exhausted its safe, idempotent retries.
                // Permit a later valid route position to start a fresh request.
                _root._routeMappingPrototypeCaptureRequested = false
                if (!_root._routeMappingPiErrorShown) {
                    _root._routeMappingPiErrorShown = true
                    qgcApp().showAppMessage(
                                qsTr("Pi still-image capture failed: %1").arg(errorMessage))
                }
                return
            }

            if (matchingIndex >= 0) {
                var refreshedSource = _root._mappingPhotoFileUrl(localFilePath)
                        + "?ready=" + Date.now()
                _routeMappingLivePhotoModel.setProperty(
                            matchingIndex, "photoImageSource", refreshedSource)
            }
        }
    }

    function resetRouteMappingLivePhotos() {
        _processedCameraTriggerCount = 0
        _mappingPatternCaptureStarted = false
        _mappingPhotoDistanceSinceCapture = 0
        _lastMappingPatternCoordinate = QtPositioning.coordinate()
        _activeMappingPhotoSegmentIndex = -1
        _lastCompletedMappingPhotoSegmentIndex = -1
        _mappingPhotoLastSegmentAlong = 0
        _mappingPhotoSegmentEndCaptured = false
        _routeMappingPrototypeCaptureRequested = false
        _routeMappingPrototypeRequestSequence = 0
        _routeMappingPiErrorShown = false
        routeMappingPiPhotoFetcher.resetSession()
        _routeMappingLivePhotoModel.clear()
    }

    function _mappingPhotoFileUrl(filePath) {
        var normalizedPath = String(filePath).split("\\").join("/")
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

    function _untrackRouteMappingPhotoFile(filePath) {
        var files = _routeMappingSessionPhotoFiles.slice()
        var index = files.indexOf(filePath)
        if (index >= 0) {
            files.splice(index, 1)
            _routeMappingSessionPhotoFiles = files
        }
    }

    function _mappingPhotoNearCoordinate(coordinate, duplicateRadiusOverride) {
        var triggerDistance = Math.max(1, Number(routeMappingPhotoFootprintFrontal))
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

    function _mappingPhotoTrackTolerance() {
        return Math.max(6, Math.min(15, Number(routeMappingPhotoFootprintSide) * 0.4))
    }

    function _appendRouteMappingPhoto(coordinate, telemetryConfirmed, endpointCapture) {
        if (!coordinate || !coordinate.isValid) {
            return false
        }

        // Prove one end-to-end still capture before enabling the existing
        // multi-photo route logic.
        if (_routeMappingPrototypeCaptureRequested) {
            return false
        }

        var captureInfo = mapControl
                ? mapControl.routeMappingPhotoCaptureInfo(coordinate) : null
        if (!captureInfo || !captureInfo.valid
                || captureInfo.distanceToSegment > _mappingPhotoTrackTolerance()
                || captureInfo.segmentIndex <= _lastCompletedMappingPhotoSegmentIndex) {
            return false
        }

        // The pattern-progress capture and CAMERA_IMAGE_CAPTURED can describe
        // the same shot. Keep one tile and prefer the telemetry coordinate.
        var matchingIndex = _mappingPhotoNearCoordinate(
                    coordinate, endpointCapture ? 1 : 0)
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

        var rootPhotoDirectory = QGroundControl.settingsManager.appSettings.photoSavePath
        if (!rootPhotoDirectory || rootPhotoDirectory.length === 0) {
            if (!_routeMappingPhotoPathWarned) {
                _routeMappingPhotoPathWarned = true
                qgcApp().showAppMessage(
                            qsTr("Photo save path is not configured. Set it in Application Settings to capture route mapping photos."))
            }
            return false
        }

        var rootSeparator = rootPhotoDirectory.charAt(rootPhotoDirectory.length - 1) === "/" ? "" : "/"
        var photoDirectory = rootPhotoDirectory + rootSeparator + "RouteMapping"
        _routeMappingPrototypeRequestSequence += 1
        var photoNumber = _routeMappingPrototypeRequestSequence
        var fileName = "mapping_" + Date.now() + "_" + photoNumber + ".jpg"
        var separator = photoDirectory.charAt(photoDirectory.length - 1) === "/" ? "" : "/"
        var filePath = photoDirectory + separator + fileName
        var heading = mapControl
                ? captureInfo.heading
                : routeMappingEntryHeading

        _routeMappingPrototypeCaptureRequested = true
        _routeMappingLivePhotoModel.append({
            photoLatitude: coordinate.latitude,
            photoLongitude: coordinate.longitude,
            photoAltitude: coordinate.altitude,
            photoHeading: heading,
            photoSequence: photoNumber,
            photoImageSource: _mappingPhotoFileUrl(filePath),
            photoTelemetryConfirmed: telemetryConfirmed
        })

        _trackRouteMappingPhotoFile(filePath)

        routeMappingPiPhotoFetcher.capturePhoto(filePath, photoNumber)
        return true
    }

    function _captureNewRouteMappingPhotos() {
        var triggerPoints = _activeVehicle ? _activeVehicle.cameraTriggerPoints : null
        var triggerCount = triggerPoints ? triggerPoints.count : 0

        if (triggerCount < _processedCameraTriggerCount) {
            resetRouteMappingLivePhotos()
        }

        if (!routeMappingPhotoProgressEnabled
                || !routeMappingTransectPath
                || routeMappingTransectPath.length < 2
                || !_activeVehicle
                || (!_activeVehicle.armed && !_activeVehicle.flying)) {
            _processedCameraTriggerCount = triggerCount
            return
        }

        while (_processedCameraTriggerCount < triggerCount) {
            var triggerPoint = triggerPoints.get(_processedCameraTriggerCount)
            var coordinate = triggerPoint ? triggerPoint.coordinate : QtPositioning.coordinate()
            if (!coordinate || !coordinate.isValid) {
                coordinate = _activeVehicle.coordinate
            }
            if (!coordinate || !coordinate.isValid) {
                break
            }

            _appendRouteMappingPhoto(coordinate, true)
            if (!_mappingPatternCaptureStarted) {
                _mappingPatternCaptureStarted = true
                _mappingPhotoDistanceSinceCapture = 0
                _lastMappingPatternCoordinate = coordinate
            }
            _processedCameraTriggerCount++
        }
    }

    function _updateAutomaticRouteMappingCapture() {
        if (!routeMappingPhotoProgressEnabled
                || !missionRunning
                || !_activeVehicle
                || !_activeVehicle.flying
                || !routeMappingPhotoCaptureTransectPoints
                || routeMappingPhotoCaptureTransectPoints.length < 2) {
            return
        }

        var coordinate = _activeVehicle.coordinate
        if (!coordinate || !coordinate.isValid) {
            return
        }

        var triggerDistance = Math.max(1, Number(routeMappingPhotoFootprintFrontal))
        var captureInfo = mapControl
                ? mapControl.routeMappingPhotoCaptureInfo(coordinate) : null
        if (!captureInfo || !captureInfo.valid
                || captureInfo.distanceToSegment > _mappingPhotoTrackTolerance()) {
            return
        }

        if (captureInfo.segmentIndex <= _lastCompletedMappingPhotoSegmentIndex) {
            return
        }

        if (_activeMappingPhotoSegmentIndex !== captureInfo.segmentIndex) {
            if (_activeMappingPhotoSegmentIndex >= 0) {
                _lastCompletedMappingPhotoSegmentIndex = Math.max(
                            _lastCompletedMappingPhotoSegmentIndex,
                            _activeMappingPhotoSegmentIndex)
            }
            if (captureInfo.segmentIndex <= _lastCompletedMappingPhotoSegmentIndex) {
                return
            }

            var entryTolerance = Math.max(8, Math.min(18, triggerDistance * 0.75))
            var entryPointTolerance = Math.max(2, Math.min(6, triggerDistance * 0.2))
            if (captureInfo.alongSegment > entryTolerance
                    || coordinate.distanceTo(captureInfo.startCoordinate) > entryPointTolerance) {
                return
            }

            // Each inner transect has its own camera start command with the
            // immediate-image flag. Turns and connectors never enter this state.
            _activeMappingPhotoSegmentIndex = captureInfo.segmentIndex
            _mappingPatternCaptureStarted = true
            _mappingPhotoDistanceSinceCapture = 0
            _mappingPhotoLastSegmentAlong = captureInfo.alongSegment
            _mappingPhotoSegmentEndCaptured = false
            _lastMappingPatternCoordinate = coordinate
            _appendRouteMappingPhoto(coordinate, false, false)
            return
        }

        var stepDistance = captureInfo.alongSegment - _mappingPhotoLastSegmentAlong
        _mappingPhotoLastSegmentAlong = Math.max(
                    _mappingPhotoLastSegmentAlong, captureInfo.alongSegment)
        _lastMappingPatternCoordinate = coordinate
        if (stepDistance <= 0.05 || stepDistance > Math.max(50, triggerDistance * 3)) {
            return
        }

        _mappingPhotoDistanceSinceCapture += stepDistance
        if (_mappingPhotoDistanceSinceCapture >= triggerDistance) {
            _mappingPhotoDistanceSinceCapture %= triggerDistance
            _appendRouteMappingPhoto(coordinate, false, false)
        }

        var endpointTolerance = Math.max(2, Math.min(6, triggerDistance * 0.25))
        if (!_mappingPhotoSegmentEndCaptured
                && captureInfo.segmentLength - captureInfo.alongSegment <= endpointTolerance
                && coordinate.distanceTo(captureInfo.endCoordinate) <= endpointTolerance) {
            // Force a distinct endpoint frame even when the final regular
            // distance shot was close to the polygon edge.
            _appendRouteMappingPhoto(coordinate, false, true)
            _mappingPhotoSegmentEndCaptured = true
            _lastCompletedMappingPhotoSegmentIndex = captureInfo.segmentIndex
            _activeMappingPhotoSegmentIndex = -1
        }
    }

    // This remains live for the complete flight and resets when arming.
    readonly property int routeMappingPhotosTaken: {
        if (!routeMappingPhotoProgressEnabled) {
            return 0
        }
        // Count only captures accepted on an interior photo transect. Raw
        // vehicle feedback can include unrelated camera events during takeoff
        // or RTL and must not inflate Route Mapping progress.
        return _routeMappingLivePhotoModel.count
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
        target: _root._activeVehicle ? _root._activeVehicle.cameraTriggerPoints : null

        function onCountChanged() {
            _root._captureNewRouteMappingPhotos()
        }
    }

    Connections {
        target: _root._activeVehicle
        ignoreUnknownSignals: true

        function onArmedChanged(armed) {
            if (armed) {
                // Start a new capture set without deleting the previous
                // mission's survey photographs from the configured photo path.
                _root._routeMappingSessionPhotoFiles = []
                _root.resetRouteMappingLivePhotos()
            }
        }

        function onCoordinateChanged() {
            _root._updateAutomaticRouteMappingCapture()
        }

        function onFlyingChanged() {
            _root._updateAutomaticRouteMappingCapture()
        }

        function onInitialPlanRequestCompleteChanged(complete) {
            if (complete) {
                _root._scheduleMissionResyncFromVehicle()
            }
        }
    }

    onMissionRunningChanged: _updateAutomaticRouteMappingCapture()

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
            routeMappingLivePhotoModel: _root.routeMappingLivePhotoModel
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
            onClicked: mainWindow.showActiveMissionEditor(addButton._hasPlan)
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
        photosPlanned: _root.routeMappingPhotoProgressEnabled ? _root.routeMappingPlannedPhotoCount : 0
        photosVisible: _root.routeMappingPhotoProgressEnabled
        reconstructionText: qsTr("Pending")

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
