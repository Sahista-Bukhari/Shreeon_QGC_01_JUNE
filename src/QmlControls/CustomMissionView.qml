import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtLocation
import QtPositioning
import QtQuick.Layouts
import QtQuick.Window

import QGroundControl
import QGroundControl.FlightMap
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.FlyView
import QGroundControl.UTMSP

Item {
    id: _root

    readonly property int   _decimalPlaces: 8
    readonly property real  _margin: ScreenTools.defaultFontPixelHeight * 0.5
    readonly property real  _toolsMargin: ScreenTools.defaultFontPixelWidth * 0.75
    readonly property real  _radius: ScreenTools.defaultFontPixelWidth  * 0.5
    readonly property real  _rightPanelWidth: Math.min(width * 0.40, ScreenTools.defaultFontPixelWidth * 40)
    readonly property var   _defaultVehicleCoordinate: QtPositioning.coordinate(37.803784, -122.462276)
    readonly property bool  _waypointsOnlyMode: QGroundControl.corePlugin.options.missionWaypointsOnly

    property var    _planMasterController: planMasterController
    property var    _missionController: _planMasterController.missionController
    property var    _geoFenceController: _planMasterController.geoFenceController
    property var    _rallyPointController: _planMasterController.rallyPointController
    property var    _visualItems: _missionController.visualItems
    readonly property var _currentPlanViewItem: _missionController.currentPlanViewItem
    property var    _activeSurveyPolygon: null
    property bool   _lightWidgetBorders: editorMap.isSatelliteMap
    property bool   _singleComplexItem: _missionController.complexMissionItemNames.length === 1
    property int    _editingLayer: _layerMission
    property int    _toolStripBottom: toolStrip.height + toolStrip.y
    property var    _appSettings: QGroundControl.settingsManager.appSettings
    property var    _planViewSettings: QGroundControl.settingsManager.planViewSettings
    property bool   _promptForPlanUsageShowing: false
    property bool   _utmspEnabled: QGroundControl.utmspSupported
    property bool   _resetGeofencePolygon: false   //Reset the Geofence Polygon
    property bool   _triggerSubmit
    property bool   _resetRegisterFlightPlan
    property bool   _addWaypointOnClick: false
    property bool   _addROIOnClick: false
    property bool   _planUploadPending: false
    property bool   _planUploadStarted: false
    property var    _pendingSurveyOverlayData: null
    property var    _uploadedSurveyOverlayData: null
    property string _galleryPlanFile: ""

    readonly property int _layerMission: 1
    readonly property int _layerFence: 2
    readonly property int _layerRally: 3
    readonly property int _layerUTMSP: 4

    readonly property string _armedVehicleUploadPrompt: qsTr("Vehicle is currently armed. Do you want to upload the mission to the vehicle?")

    onVisibleChanged: {
        if(visible) {
            editorMap.zoomLevel = QGroundControl.flightMapZoom
            editorMap.center    = QGroundControl.flightMapPosition
        }
    }

    function mapCenter() {
        var coordinate = editorMap.center
        coordinate.latitude  = coordinate.latitude.toFixed(_decimalPlaces)
        coordinate.longitude = coordinate.longitude.toFixed(_decimalPlaces)
        coordinate.altitude  = coordinate.altitude.toFixed(_decimalPlaces)
        return coordinate
    }

    function _normalizedPlanFilePath(filePath) {
        if (!filePath || filePath === "") {
            return ""
        }

        var fileName = filePath.substring(filePath.lastIndexOf("/") + 1)
        return fileName.indexOf(".") === -1 ? filePath + ".plan" : filePath
    }

    function _loadPersistedPlanFromFile(filePath) {
        if (!filePath || filePath === ""
                || !QGCFileDialogController.fileExists(filePath)) {
            return false
        }

        _planMasterController.loadFromFile(filePath)
        if (!_planMasterController.containsItems) {
            return false
        }

        _galleryPlanFile = _normalizedPlanFilePath(filePath)
        _missionController.setCurrentPlanViewSeqNum(0, true)
        _planMasterController.fitViewportToItems()
        _uploadedSurveyOverlayData = _customMissionSurveyOverlayData()
        return true
    }

    // isSurveyItem is constant for each mission-item type but is not a
    // bindable Q_PROPERTY. Update the polygon explicitly when selection changes
    // instead of reading it from a live QML binding.
    function _updateActiveSurveyPolygon() {
        var currentItem = _missionController.currentPlanViewItem
        _activeSurveyPolygon = currentItem && currentItem.isSurveyItem
                               ? currentItem.surveyAreaPolygon
                               : null
    }

    property bool _firstMissionLoadComplete: false
    property bool _firstFenceLoadComplete: false
    property bool _firstRallyLoadComplete: false
    property bool _firstLoadComplete: false

    MapFitFunctions {
        id: mapFitFunctions  // The name for this id cannot be changed without breaking references outside of this code. Beware!
        map: editorMap
        usePlannedHomePosition: true
        planMasterController: _planMasterController
    }

    PlanMasterController {
        id: planMasterController
        flyView: false
        missionMode: "customMission"

        Component.onCompleted: {
            _planMasterController.start()
            _missionController.setCurrentPlanViewSeqNum(0, true)
            _root._updateActiveSurveyPolygon()
        }

        onPromptForPlanUsageOnVehicleChange: {
            if (!_promptForPlanUsageShowing) {
                _promptForPlanUsageShowing = true
                promptForPlanUsageOnVehicleChangePopupComponent.createObject(mainWindow).open()
            }
        }
        onSyncInProgressChanged: {
            if (_root._planUploadPending && _planMasterController.syncInProgress) {
                _root._planUploadStarted = true
            } else if (_root._planUploadPending && _root._planUploadStarted) {
                Qt.callLater(_root._finishCustomMissionUpload)
            }
        }

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

        function _beginPlanUpload() {
            if (offline || syncInProgress) {
                return false
            }

            // Preserve the complex survey geometry before MAVLink converts it
            // into the flat waypoint list stored by the vehicle.
            _root._pendingSurveyOverlayData = _root._customMissionSurveyOverlayData()
            _root._planUploadPending = true
            _root._planUploadStarted = false
            sendToVehicle()

            // Detect cases where uploading could not enter the normal mission
            // transfer pipeline.
            Qt.callLater(function() {
                if (_root._planUploadPending && !_root._planUploadStarted) {
                    _root._planUploadPending = false
                    _root._pendingSurveyOverlayData = null
                    mainWindow.showMessageDialog(
                                qsTr("Upload"),
                                qsTr("Mission upload to the vehicle could not be started."))
                }
            })

            return true
        }

        function upload() {
            if (!checkReadyForSaveUpload(false /* save */)) {
                return false
            }

            switch (_missionController.sendToVehiclePreCheck()) {
            case MissionController.SendToVehiclePreCheckStateOk:
                return _beginPlanUpload()

            case MissionController.SendToVehiclePreCheckStateActiveMission:
                mainWindow.showMessageDialog(
                            qsTr("Send To Vehicle"),
                            qsTr("Current mission must be paused before uploading a new plan."))
                return false

            case MissionController.SendToVehiclePreCheckStateFirwmareVehicleMismatch:
                mainWindow.showMessageDialog(
                            qsTr("Plan Upload"),
                            qsTr("This plan was created for a different firmware or vehicle type. "
                                 + "Uploading it may cause incorrect behavior.\n\n"
                                 + "Click OK to upload the plan anyway."),
                            Dialog.Ok | Dialog.Cancel,
                            function() {
                                _planMasterController._beginPlanUpload()
                            })
                return false
            }

            return false
        }

        function loadFromSelectedFile() {
            fileDialog.title =          qsTr("Select Plan File")
            fileDialog.planFiles =      true
            fileDialog.nameFilters =    _planMasterController.loadNameFilters
            fileDialog.openForLoad()
        }

        function saveToSelectedFile() {
            if (!checkReadyForSaveUpload(true /* save */)) {
                return
            }
            fileDialog.title =          qsTr("Save Plan")
            fileDialog.planFiles =      true
            fileDialog.nameFilters =    _planMasterController.saveNameFilters
            fileDialog.openForSave()
        }

        function fitViewportToItems() {
            mapFitFunctions.fitMapViewportToMissionItems()
        }

        function saveKmlToSelectedFile() {
            if (!checkReadyForSaveUpload(true /* save */)) {
                return
            }
            fileDialog.title =          qsTr("Save KML")
            fileDialog.planFiles =      false
            fileDialog.nameFilters =    ShapeFileHelper.fileDialogKMLFilters
            fileDialog.openForSave()
        }
    }

    Connections {
        target: _missionController

        function onCurrentPlanViewItemChanged() {
            _root._updateActiveSurveyPolygon()
        }

        function onNewItemsFromVehicle() {
            if (_visualItems && _visualItems.count !== 1) {
                mapFitFunctions.fitMapViewportToMissionItems()
            }
            _missionController.setCurrentPlanViewSeqNum(0, true)
        }
    }

    function insertSimpleItemAfterCurrent(coordinate) {
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertSimpleMissionItem(coordinate, nextIndex, true /* makeCurrentItem */)
    }

    function insertROIAfterCurrent(coordinate) {
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertROIMissionItem(coordinate, nextIndex, true /* makeCurrentItem */)
    }

    function insertCancelROIAfterCurrent() {
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertCancelROIMissionItem(nextIndex, true /* makeCurrentItem */)
    }

    function insertComplexItemAfterCurrent(complexItemName) {
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertComplexMissionItem(complexItemName, mapCenter(), nextIndex, true /* makeCurrentItem */)
    }

    function insertTakeoffItemAfterCurrent() {
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertTakeoffItem(mapCenter(), nextIndex, true /* makeCurrentItem */)
    }

    function insertLandItemAfterCurrent() {
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertLandItem(mapCenter(), nextIndex, true /* makeCurrentItem */)
    }

    // Captures the first Survey item in a Custom Mission. The vehicle receives
    // simple MAVLink waypoints, so Fly View cannot reconstruct this polygon and
    // transect geometry after upload unless the editor preserves it here.
    function _customMissionSurveyOverlayData() {
        var surveyItem = null
        for (var i = 0; i < _missionController.visualItems.count; i++) {
            var visualItem = _missionController.visualItems.get(i)
            if (visualItem && visualItem.isSurveyItem
                    && visualItem.surveyAreaPolygon) {
                surveyItem = visualItem
                break
            }
        }

        if (!surveyItem || !surveyItem.surveyAreaPolygon) {
            return null
        }

        function copyCoordinate(coordinate) {
            if (!coordinate || !coordinate.isValid) {
                return QtPositioning.coordinate()
            }
            return QtPositioning.coordinate(coordinate.latitude,
                                            coordinate.longitude,
                                            coordinate.altitude)
        }

        var boundaryPath = []
        var polygonPath = surveyItem.surveyAreaPolygon.path
        for (var boundaryIndex = 0; boundaryIndex < polygonPath.length; boundaryIndex++) {
            boundaryPath.push(copyCoordinate(polygonPath[boundaryIndex]))
        }
        if (boundaryPath.length >= 3) {
            boundaryPath.push(copyCoordinate(boundaryPath[0]))
        }

        var transectPath = []
        var visualTransectPoints = surveyItem.visualTransectPoints
        for (var transectIndex = 0;
             transectIndex < visualTransectPoints.length;
             transectIndex++) {
            transectPath.push(copyCoordinate(visualTransectPoints[transectIndex]))
        }

        if (boundaryPath.length < 4 || transectPath.length < 2) {
            return null
        }

        var takeoffCoordinate = QtPositioning.coordinate()
        for (var itemIndex = 0; itemIndex < _missionController.visualItems.count; itemIndex++) {
            var missionItem = _missionController.visualItems.get(itemIndex)
            if (missionItem && missionItem.isTakeoffItem
                    && missionItem.coordinate && missionItem.coordinate.isValid) {
                takeoffCoordinate = copyCoordinate(missionItem.coordinate)
                break
            }
        }

        var entryCoordinate = copyCoordinate(surveyItem.coordinate)
        var exitCoordinate = copyCoordinate(surveyItem.exitCoordinate)
        var entryHeading = transectPath[0].azimuthTo(transectPath[1])
        var exitHeading = transectPath[transectPath.length - 2].azimuthTo(
                    transectPath[transectPath.length - 1])

        return {
            boundaryPath: boundaryPath,
            transectPath: transectPath,
            takeoffCoordinate: takeoffCoordinate,
            entryCoordinate: entryCoordinate,
            exitCoordinate: exitCoordinate,
            entryHeading: entryHeading,
            exitHeading: exitHeading
        }
    }

    function _showCustomMissionSurveyOnFlyView(overlayData, replaceExisting) {
        if (!overlayData || !overlayData.transectPath
                || overlayData.transectPath.length < 2) {
            return false
        }

        if (flyView._routeMappingOverlayLocked) {
            if (!replaceExisting) {
                return true
            }

            var activeVehicle = QGroundControl.multiVehicleManager.activeVehicle
            if (activeVehicle && (activeVehicle.flying || activeVehicle.armed)) {
                return false
            }
        }

        flyView.clearRouteMappingOverlay(true)
        flyView.planEditMode = false
        flyView._editingLayer = flyView._layerMission
        flyView.routeMappingBoundaryPath = overlayData.boundaryPath
        flyView.routeMappingTransectPath = overlayData.transectPath
        flyView.routeMappingPhotoCaptureTransectPoints = []
        flyView.routeMappingTakeoffCoordinate = overlayData.takeoffCoordinate
        flyView.routeMappingEntryCoordinate = overlayData.entryCoordinate
        flyView.routeMappingExitCoordinate = overlayData.exitCoordinate
        flyView.routeMappingEntryHeading = overlayData.entryHeading
        flyView.routeMappingExitHeading = overlayData.exitHeading
        flyView._routeMappingOverlayLocked = true

        if (flyView.mapControl) {
            flyView.mapControl._updateRouteMappingCoverage()
        }
        return true
    }

    // This name is also used by Fly View's saved-plan restoration hook.
    function _restoreUploadedRouteMappingOverlay() {
        var overlayData = _uploadedSurveyOverlayData
        if (!overlayData) {
            overlayData = _customMissionSurveyOverlayData()
            _uploadedSurveyOverlayData = overlayData
        }
        return _showCustomMissionSurveyOnFlyView(overlayData, false)
    }

    // Select and unlock the first real mission item when entering from Fly
    // View. Sequence 0 is Mission Settings and does not expose Survey editing.
    function _selectFirstEditablePlanItem() {
        var firstEditableItem = null
        for (var i = 0; i < _missionController.visualItems.count; i++) {
            var visualItem = _missionController.visualItems.get(i)
            if (!visualItem || visualItem.sequenceNumber === 0) {
                continue
            }

            if (!firstEditableItem) {
                firstEditableItem = visualItem
            }

            if (visualItem.isSurveyItem && visualItem.surveyAreaPolygon) {
                visualItem.surveyAreaPolygon.traceMode = false
                visualItem.surveyAreaPolygon.interactive = true
                firstEditableItem = visualItem
                break
            }
        }

        if (firstEditableItem) {
            _missionController.setCurrentPlanViewSeqNum(
                        firstEditableItem.sequenceNumber, true)
        } else {
            _missionController.setCurrentPlanViewSeqNum(0, true)
        }
        _updateActiveSurveyPolygon()
    }

    function _finishCustomMissionUpload() {
        if (!_planUploadPending || _planMasterController.syncInProgress) {
            return
        }

        _planUploadPending = false
        _planUploadStarted = false

        if (_missionController.lastSendToVehicleError === true) {
            _pendingSurveyOverlayData = null
            mainWindow.showMessageDialog(
                        qsTr("Upload"),
                        qsTr("Mission upload to the vehicle failed."))
            return
        }

        _uploadedSurveyOverlayData = _pendingSurveyOverlayData
        _pendingSurveyOverlayData = null
        flyView.hideVehicleMissionForUnuploadedRoute = false

        var flyPlanController = flyView.planController
        if (flyPlanController && !flyPlanController.offline) {
            flyPlanController.showPlanFromManagerVehicle()
            flyPlanController.missionController.setCurrentPlanViewSeqNum(0, true)
        }

        if (_uploadedSurveyOverlayData) {
            _showCustomMissionSurveyOnFlyView(
                        _uploadedSurveyOverlayData, true /* replaceExisting */)
        } else {
            flyView.clearRouteMappingOverlay(true)
        }

        mainWindow.markMissionPlanUploaded("customMission")
    }

    function exitCustomMissionPage() {
        if (_planUploadPending || _planMasterController.syncInProgress) {
            return
        }

        var flyPlanController = flyView.planController
        if (flyPlanController && !flyPlanController.offline) {
            flyPlanController.showPlanFromManagerVehicle()
            flyPlanController.missionController.setCurrentPlanViewSeqNum(0, true)
        }

        _restoreUploadedRouteMappingOverlay()

        mainWindow.showFlyView()
    }

    // Re-opens the active Fly View plan inside Custom Mission when returning from Fly View.
    function resumePlanForEdit() {
        if (_planMasterController.containsItems) {
            _selectFirstEditablePlanItem()
            _planMasterController.fitViewportToItems()
            return
        }

        var flyPlanController = flyView.planController
        if (!flyPlanController) {
            return
        }

        // Prefer the saved Custom Mission source because it retains Survey
        // polygons and settings. The vehicle copy contains flattened waypoints.
        var executionPlanFile = mainWindow.lastExecutedPlanFilePath()
        if (mainWindow.uploadedMissionEditor === "customMission"
                && executionPlanFile !== ""
                && QGCFileDialogController.fileExists(executionPlanFile)) {
            _planMasterController.loadFromFile(executionPlanFile)
            _planMasterController.fitViewportToItems()
            _uploadedSurveyOverlayData = _customMissionSurveyOverlayData()
        } else if (flyPlanController.currentPlanFile
                   && flyPlanController.currentPlanFile !== ""
                   && QGCFileDialogController.fileExists(
                       flyPlanController.currentPlanFile)) {
            _planMasterController.loadFromFile(flyPlanController.currentPlanFile)
            _planMasterController.fitViewportToItems()
        } else if (!flyPlanController.offline) {
            _planMasterController.showPlanFromManagerVehicle()
        }

        _selectFirstEditablePlanItem()
    }

    QGCFileDialog {
        id: fileDialog
        folder: _appSettings ? _appSettings.missionSavePath : ""

        property bool planFiles: true    ///< true: working with plan files, false: working with kml file

        onAcceptedForSave: (file) => {
            if (planFiles) {
                _planMasterController.saveToFile(file)
                _galleryPlanFile = _normalizedPlanFilePath(file)
            } else {
                _planMasterController.saveToKml(file)
            }
            close()
        }

        onAcceptedForLoad: (file) => {
            _planMasterController.loadFromFile(file)
            _galleryPlanFile = _normalizedPlanFilePath(file)
            _planMasterController.fitViewportToItems()
            _missionController.setCurrentPlanViewSeqNum(0, true)
            close()
        }
    }

    Item {
        id: mainPlanViewArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        FlightMap {
            id: editorMap
            anchors.fill: parent
            mapName: "CustomMissionEditor"
            allowGCSLocationCenter: true
            allowVehicleLocationCenter: true
            planView: true

            zoomLevel: QGroundControl.flightMapZoom
            center: QGroundControl.flightMapPosition

            // Free map area below the plan-action strip + Survey tools second row
            property real _planEditToolbarRowHeight: ScreenTools.defaultFontPixelHeight * 2.6
            property real _centerViewportTop: {
                if (planActionStrip.visible) {
                    return planActionStrip.y + planActionStrip.height + _margin + _planEditToolbarRowHeight
                }
                return planToolBar.height + _margin
            }
            property rect centerViewport: Qt.rect(_leftToolWidth + _margin,
                                                  _centerViewportTop,
                                                  editorMap.width - _leftToolWidth - _rightToolWidth - (_margin * 2),
                                                  (missionStatus.visible ? missionStatus.y : height - _margin) - _centerViewportTop)

            // Left tools for map fit (Takeoff strip). Survey toolbar uses planEditToolbarX/Y.
            property real _leftToolWidth: toolStrip.x + toolStrip.width
            property real _rightToolWidth: rightPanel.width + rightPanel.anchors.rightMargin
            property real _nonInteractiveOpacity: 0.5
            // Survey / Polygon tools: same UI, second row under Open/Save/Upload/Clear/Menu
            property bool planEditToolbarAlignLeft: true
            property bool planEditToolbarSecondRow: true
            property real planEditToolbarX: planActionStrip.visible ? planActionStrip.x : (toolStrip.x + toolStrip.width + _margin)
            property real planEditToolbarY: planActionStrip.visible
                                            ? (planActionStrip.y + planActionStrip.height + ScreenTools.defaultFontPixelHeight * 0.35)
                                            : (planToolBar.height + _margin)

            // Initial map position duplicates Fly view position
            Component.onCompleted: editorMap.center = QGroundControl.flightMapPosition

            QGCMapPalette { id: mapPal; lightColors: editorMap.isSatelliteMap }

            onZoomLevelChanged: {
                QGroundControl.flightMapZoom = editorMap.zoomLevel
            }
            onCenterChanged: {
                QGroundControl.flightMapPosition = editorMap.center
            }

            onMapClicked: (mouse) => {
                // Take focus to close any previous editing
                editorMap.focus = true
                if (!mainWindow.allowViewSwitch()) {
                    return
                }

                var coordinate = editorMap.toCoordinate(Qt.point(mouse.x, mouse.y), false /* clipToViewPort */)
                coordinate.latitude = coordinate.latitude.toFixed(_decimalPlaces)
                coordinate.longitude = coordinate.longitude.toFixed(_decimalPlaces)
                coordinate.altitude = coordinate.altitude.toFixed(_decimalPlaces)
                if (_utmspEnabled) {
                    QGroundControl.utmspManager.utmspVehicle.updateLastCoordinates(coordinate.latitude, coordinate.longitude)
                }

                switch (_editingLayer) {
                case _layerMission:
                    if (_addROIOnClick) {
                        _addROIOnClick = false
                        if (_missionController.isROIActive) {
                            var pos = Qt.point(mouse.x, mouse.y)
                            // For some strange reason using mainWindow in mapToItem doesn't work, so we use globals.parent instead which also gets us mainWindow
                            pos = editorMap.mapToItem(globals.parent, pos)
                            var dropPanel = insertOrCancelROIDropPanelComponent.createObject(mainWindow, { mapClickCoord: coordinate, clickRect: Qt.rect(pos.x, pos.y, 0, 0) })
                            dropPanel.open()
                        } else {
                            insertROIAfterCurrent(coordinate)
                        }
                    } else if (_addWaypointOnClick) {
                        insertSimpleItemAfterCurrent(coordinate)
                    }
                    break
                case _layerRally:
                    if (_rallyPointController.supported) {
                        _rallyPointController.addPoint(coordinate)
                    }
                    break
                }
            }

            function _mapRightClicked(position) {
                // Take focus to close any previous editing
                editorMap.focus = true
                if (!mainWindow.allowViewSwitch()) {
                    return
                }
                var coordinate = editorMap.toCoordinate(position, false /* clipToViewPort */)
                coordinate.latitude = coordinate.latitude.toFixed(_decimalPlaces)
                coordinate.longitude = coordinate.longitude.toFixed(_decimalPlaces)
                coordinate.altitude = coordinate.altitude.toFixed(_decimalPlaces)

                if (_editingLayer === _layerMission) {
                    if (!planMasterController.controllerVehicle.roiModeSupported) {
                        return
                    }
                    if (_missionController.isROIActive) {
                        // For some strange reason using mainWindow in mapToItem doesn't work, so we use globals.parent instead which also gets us mainWindow
                        position = editorMap.mapToItem(globals.parent, position)
                        var dropPanel = insertOrCancelROIDropPanelComponent.createObject(mainWindow, { mapClickCoord: coordinate, clickRect: Qt.rect(position.x, position.y, 0, 0) })
                        dropPanel.open()
                    } else {
                        insertROIAfterCurrent(coordinate)
                    }
                }
            }

            onMapRightClicked: (position) => _mapRightClicked(position)
            onMapPressAndHold: (position) => _mapRightClicked(position)

            // Add the mission item visuals to the map
            Repeater {
                model: _missionController.visualItems
                delegate: MissionItemMapVisual {
                    map: editorMap
                    opacity: _editingLayer == _layerMission ? 1 : editorMap._nonInteractiveOpacity
                    interactive: _editingLayer == _layerMission
                    vehicle: _planMasterController.controllerVehicle
                    onClicked: (sequenceNumber) => { _missionController.setCurrentPlanViewSeqNum(sequenceNumber, false) }
                }
            }

            // Add lines between waypoints
            MissionLineView {
                showSpecialVisual: _missionController.isROIBeginCurrentItem
                model: _missionController.simpleFlightPathSegments
                opacity: _editingLayer == _layerMission ? 1 : editorMap._nonInteractiveOpacity
            }

            // Direction arrows in waypoint lines
            MapItemView {
                model: _editingLayer == _layerMission ? _missionController.directionArrows : undefined

                delegate: MapLineArrow {
                    fromCoord: object ? object.coordinate1 : undefined
                    toCoord: object ? object.coordinate2 : undefined
                    arrowPosition: 3
                    z: QGroundControl.zOrderWaypointLines + 1
                }
            }

            // UI for splitting the current segment
            MapQuickItem {
                id: splitSegmentItem
                anchorPoint.x: sourceItem.width / 2
                anchorPoint.y: sourceItem.height / 2
                z: QGroundControl.zOrderWaypointLines + 1
                visible: _editingLayer == _layerMission

                sourceItem: SplitIndicator {
                    onClicked: _missionController.insertSimpleMissionItem(splitSegmentItem.coordinate,
                                                                           _missionController.currentPlanViewVIIndex,
                                                                           true /* makeCurrentItem */)
                }

                function _updateSplitCoord() {
                    if (_missionController.splitSegment) {
                        var distance = _missionController.splitSegment.coordinate1.distanceTo(_missionController.splitSegment.coordinate2)
                        var azimuth = _missionController.splitSegment.coordinate1.azimuthTo(_missionController.splitSegment.coordinate2)
                        splitSegmentItem.coordinate = _missionController.splitSegment.coordinate1.atDistanceAndAzimuth(distance / 2, azimuth)
                    } else {
                        coordinate = QtPositioning.coordinate()
                    }
                }

                Connections {
                    target: _missionController
                    function onSplitSegmentChanged()  { splitSegmentItem._updateSplitCoord() }
                }

                Connections {
                    target: _missionController.splitSegment
                    function onCoordinate1Changed()   { splitSegmentItem._updateSplitCoord() }
                    function onCoordinate2Changed()   { splitSegmentItem._updateSplitCoord() }
                }
            }

            // Add the vehicles to the map
            MapItemView {
                model: QGroundControl.multiVehicleManager.vehicles
                delegate: VehicleMapItem {
                    vehicle: object
                    coordinate: object.coordinate
                    map: editorMap
                    size: ScreenTools.defaultFontPixelHeight * 3
                    z: QGroundControl.zOrderMapItems - 1
                }
            }

            GeoFenceMapVisuals {
                map: editorMap
                myGeoFenceController: _geoFenceController
                interactive: _editingLayer == _layerFence
                homePosition: _missionController.plannedHomePosition
                planView: true
                opacity: _editingLayer != _layerFence ? editorMap._nonInteractiveOpacity : 1
            }

            RallyPointMapVisuals {
                map: editorMap
                myRallyPointController: _rallyPointController
                interactive: _editingLayer == _layerRally
                planView: true
                opacity: _editingLayer != _layerRally ? editorMap._nonInteractiveOpacity : 1
            }

            UTMSPMapVisuals {
                enabled: _utmspEnabled
                map: editorMap
                currentMissionItems: _visualItems
                myGeoFenceController: _geoFenceController
                interactive: _editingLayer == _layerUTMSP
                homePosition: _missionController.plannedHomePosition
                planView: true
                opacity: _editingLayer != _layerUTMSP ? editorMap._nonInteractiveOpacity : 1
                resetCheck: _resetGeofencePolygon
            }

            // Same center crosshair as Route Mapping — aim here, then press +
            Item {
                id: centerTarget
                anchors.centerIn: parent
                width: ScreenTools.defaultFontPixelHeight * 2.5
                height: width
                z: QGroundControl.zOrderWidgets + 10
                visible: _editingLayer === _layerMission

                property real lineLength: width * 0.45

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

        // Survey trace mode uses the map center target. This restores the
        // missing stock control which appends that position to the polygon.
        QGCButton {
            id: surveyTraceAddPointButton
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 3
            width: ScreenTools.defaultFontPixelHeight * 6
            height: ScreenTools.defaultFontPixelHeight * 3
            z: QGroundControl.zOrderWidgets + 10
            text: qsTr("+ Add Point")
            visible: _activeSurveyPolygon && _activeSurveyPolygon.traceMode

            onClicked: {
                if (_activeSurveyPolygon) {
                    _activeSurveyPolygon.appendVertex(mapCenter())
                }
            }
        }

        //-----------------------------------------------------------
        // Left tool strip — Custom Mission grid:
        // Row 1: Takeoff | Row 2: Pattern + Waypoint | Row 3: ROI + Return
        Item {
            id: toolStrip
            anchors.margins: _toolsMargin
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: planToolBar.height + _toolsMargin
            z: QGroundControl.zOrderWidgets
            width: ScreenTools.defaultFontPixelWidth * 16
            height: toolStripInner.height + (_outerPad * 2)
            visible: _editingLayer == _layerMission

            property bool _isRallyLayer: _editingLayer == _layerRally
            property bool _isMissionLayer: _editingLayer == _layerMission
            property var _dropPanel: dropPanel
            property bool dropLeft: false
            // Open Pattern panel past Open/Save strip so those buttons stay usable
            property real dropPanelEdgeX: planActionStrip.visible
                                         ? (planActionStrip.x + planActionStrip.width - x)
                                         : width
            // Space between strip edge and buttons (outer padding area)
            property real _outerPad: ScreenTools.defaultFontPixelWidth * 1.1
            property real _cellGap: ScreenTools.defaultFontPixelWidth * 0.4
            property real _cellSize: (width - (_outerPad * 2) - _cellGap) / 2
            // Route Mapping Task Settings theme — keep strip layout, light chrome
            readonly property real  _panelRadius: ScreenTools.defaultFontPixelWidth * 0.75
            readonly property color _panelFill:   "#ffffff"
            readonly property color _panelBorder: "#e2e2e2"

            Rectangle {
                anchors.fill: parent
                radius: toolStrip._panelRadius
                color: toolStrip._panelFill
                border.width: 1
                border.color: toolStrip._panelBorder
            }

            Binding {
                target: waypointButton
                property: "checked"
                value: _addWaypointOnClick
            }

            Binding {
                target: roiButton
                property: "checked"
                value: _addROIOnClick
            }

            Column {
                id: toolStripInner
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: toolStrip._outerPad
                spacing: toolStrip._cellGap

                // Row 1 — Takeoff only (full width)
                ToolStripHoverButton {
                    width: parent.width
                    height: toolStrip._cellSize
                    radius: ScreenTools.defaultFontPixelWidth / 2
                    fontPointSize: ScreenTools.smallFontPointSize
                    toolStripAction: takeoffAction
                    glassBackgroundSource: editorMap
                    dropPanel: toolStrip._dropPanel
                    buttonIndex: 0
                    onDropped: toolStrip.onDropped()
                }

                // Row 2 — Pattern + Waypoint
                Row {
                    spacing: toolStrip._cellGap
                    width: parent.width

                    ToolStripHoverButton {
                        width: toolStrip._cellSize
                        height: width
                        radius: ScreenTools.defaultFontPixelWidth / 2
                        fontPointSize: ScreenTools.smallFontPointSize
                        toolStripAction: patternAction
                        glassBackgroundSource: editorMap
                        dropPanel: toolStrip._dropPanel
                        buttonIndex: 1
                        onDropped: toolStrip.onDropped()
                    }

                    ToolStripHoverButton {
                        width: toolStrip._cellSize
                        height: width
                        radius: ScreenTools.defaultFontPixelWidth / 2
                        fontPointSize: ScreenTools.smallFontPointSize
                        toolStripAction: waypointButton
                        glassBackgroundSource: editorMap
                        dropPanel: toolStrip._dropPanel
                        buttonIndex: 2
                        onDropped: toolStrip.onDropped()
                    }
                }

                // Row 3 — ROI + Return/Land
                Row {
                    spacing: toolStrip._cellGap
                    width: parent.width

                    ToolStripHoverButton {
                        width: toolStrip._cellSize
                        height: width
                        radius: ScreenTools.defaultFontPixelWidth / 2
                        fontPointSize: ScreenTools.smallFontPointSize
                        toolStripAction: roiButton
                        glassBackgroundSource: editorMap
                        dropPanel: toolStrip._dropPanel
                        buttonIndex: 3
                        onDropped: toolStrip.onDropped()
                    }

                    ToolStripHoverButton {
                        width: toolStrip._cellSize
                        height: width
                        radius: ScreenTools.defaultFontPixelWidth / 2
                        fontPointSize: ScreenTools.smallFontPointSize
                        toolStripAction: landAction
                        glassBackgroundSource: editorMap
                        dropPanel: toolStrip._dropPanel
                        buttonIndex: 4
                        onDropped: toolStrip.onDropped()
                    }
                }

                // Optional Stats (full width)
                ToolStripHoverButton {
                    width: parent.width
                    height: toolStrip._cellSize * 0.72
                    radius: ScreenTools.defaultFontPixelWidth / 2
                    fontPointSize: ScreenTools.smallFontPointSize
                    toolStripAction: statsAction
                    glassBackgroundSource: editorMap
                    dropPanel: toolStrip._dropPanel
                    buttonIndex: 5
                    onDropped: toolStrip.onDropped()
                }
            }

            ToolStripAction {
                id: takeoffAction
                text: qsTr("Takeoff")
                iconSource: "/res/takeoff.svg"
                enabled: _missionController.isInsertTakeoffValid
                visible: toolStrip._isMissionLayer && !_planMasterController.controllerVehicle.rover
                onTriggered: {
                    toolStrip.allAddClickBoolsOff()
                    insertTakeoffItemAfterCurrent()
                    _triggerSubmit = true
                }
            }

            ToolStripAction {
                id: patternAction
                text: _singleComplexItem ? _missionController.complexMissionItemNames[0] : qsTr("Pattern")
                iconSource: "/qmlimages/MapDrawShape.svg"
                enabled: _missionController.flyThroughCommandsAllowed
                visible: toolStrip._isMissionLayer
                dropPanelComponent: _singleComplexItem ? undefined : patternDropPanel
                onTriggered: {
                    toolStrip.allAddClickBoolsOff()
                    if (_singleComplexItem) {
                        insertComplexItemAfterCurrent(_missionController.complexMissionItemNames[0])
                    }
                }
            }

            ToolStripAction {
                id: waypointButton
                text: qsTr("Waypoint")
                iconSource: "/qmlimages/MapAddMission.svg"
                enabled: _missionController.flyThroughCommandsAllowed
                visible: toolStrip._isMissionLayer
                checkable: true
                onTriggered: {
                    _addWaypointOnClick = !_addWaypointOnClick
                    if (_addWaypointOnClick) {
                        _addROIOnClick = false
                    }
                }
            }

            ToolStripAction {
                id: roiButton
                text: _missionController.isROIActive ? qsTr("Cancel ROI") : qsTr("ROI")
                iconSource: "/qmlimages/roi.svg"
                enabled: !_missionController.onlyInsertTakeoffValid
                visible: toolStrip._isMissionLayer && _planMasterController.controllerVehicle.roiModeSupported
                checkable: true
                onTriggered: {
                    if (_missionController.isROIActive) {
                        toolStrip.allAddClickBoolsOff()
                        insertCancelROIAfterCurrent()
                    } else {
                        _addROIOnClick = !_addROIOnClick
                        if (_addROIOnClick) {
                            _addWaypointOnClick = false
                        }
                    }
                }
            }

            ToolStripAction {
                id: landAction
                text: _planMasterController.controllerVehicle.multiRotor
                            ? qsTr("Return")
                            : _missionController.isInsertLandValid && _missionController.hasLandItem
                              ? qsTr("Alt Land")
                              : qsTr("Land")
                iconSource: "/res/rtl.svg"
                enabled: _missionController.isInsertLandValid
                visible: toolStrip._isMissionLayer
                onTriggered: {
                    toolStrip.allAddClickBoolsOff()
                    insertLandItemAfterCurrent()
                }
            }

            ToolStripAction {
                id: statsAction
                text: qsTr("Stats")
                iconSource: "/res/chevron-double-right.svg"
                visible: missionStatus.hidden && QGroundControl.corePlugin.options.showMissionStatus
                onTriggered: missionStatus.showMissionStatus()
            }

            function allAddClickBoolsOff() {
                _addWaypointOnClick = false
                _addROIOnClick = false
            }

            function onDropped() {
                allAddClickBoolsOff()
            }

            signal dropped(int index)
        }

        // Above both strips so Pattern/Menu panels aren't covered
        ToolStripDropPanel {
            id: dropPanel
            toolStrip: toolStrip
            z: QGroundControl.zOrderTopMost
        }

        // Plan file actions — same white/gray Takeoff-panel button UI, beside the tool strip
        Item {
            id: planActionStrip
            anchors.left: toolStrip.visible ? toolStrip.right : parent.left
            anchors.leftMargin: _toolsMargin
            anchors.top: toolStrip.visible ? toolStrip.top : parent.top
            anchors.topMargin: toolStrip.visible ? 0 : (planToolBar.height + _toolsMargin)
            z: QGroundControl.zOrderWidgets
            width: actionInner.width + (toolStrip._outerPad * 2)
            height: actionInner.height + (toolStrip._outerPad * 2)
            visible: planToolBar.visible

            readonly property real _cellSize: toolStrip._cellSize
            readonly property real _cellGap: toolStrip._cellGap
            readonly property bool _hasPlanItems: _planMasterController.containsItems
            readonly property bool _syncInProgress: _planMasterController.syncInProgress
            readonly property bool _utmspEnabled: QGroundControl.utmspSupported
            readonly property bool _controllerDirty: _planMasterController.dirty

            Rectangle {
                anchors.fill: parent
                radius: toolStrip._panelRadius
                color: toolStrip._panelFill
                border.width: 1
                border.color: toolStrip._panelBorder
            }

            Row {
                id: actionInner
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: toolStrip._outerPad
                spacing: planActionStrip._cellGap

                ToolStripHoverButton {
                    width: planActionStrip._cellSize
                    height: width
                    radius: ScreenTools.defaultFontPixelWidth / 2
                    fontPointSize: ScreenTools.smallFontPointSize
                    toolStripAction: openPlanAction
                    glassBackgroundSource: editorMap
                    dropPanel: dropPanel
                    buttonIndex: 10
                }

                ToolStripHoverButton {
                    width: planActionStrip._cellSize
                    height: width
                    radius: ScreenTools.defaultFontPixelWidth / 2
                    fontPointSize: ScreenTools.smallFontPointSize
                    toolStripAction: savePlanAction
                    glassBackgroundSource: editorMap
                    dropPanel: dropPanel
                    buttonIndex: 11
                }

                ToolStripHoverButton {
                    width: planActionStrip._cellSize
                    height: width
                    radius: ScreenTools.defaultFontPixelWidth / 2
                    fontPointSize: ScreenTools.smallFontPointSize
                    toolStripAction: uploadPlanAction
                    glassBackgroundSource: editorMap
                    dropPanel: dropPanel
                    buttonIndex: 12
                }

                ToolStripHoverButton {
                    width: planActionStrip._cellSize
                    height: width
                    radius: ScreenTools.defaultFontPixelWidth / 2
                    fontPointSize: ScreenTools.smallFontPointSize
                    toolStripAction: clearPlanAction
                    glassBackgroundSource: editorMap
                    dropPanel: dropPanel
                    buttonIndex: 13
                }

                ToolStripHoverButton {
                    id: planMenuButton
                    width: planActionStrip._cellSize
                    height: width
                    radius: ScreenTools.defaultFontPixelWidth / 2
                    fontPointSize: ScreenTools.smallFontPointSize
                    toolStripAction: planMenuAction
                    glassBackgroundSource: editorMap
                    dropPanel: dropPanel
                    buttonIndex: 14
                }

                ToolStripHoverButton {
                    width: planActionStrip._cellSize
                    height: width
                    radius: ScreenTools.defaultFontPixelWidth / 2
                    fontPointSize: ScreenTools.smallFontPointSize
                    toolStripAction: exitPlanAction
                    glassBackgroundSource: editorMap
                    dropPanel: dropPanel
                    buttonIndex: 15
                }
            }

            ToolStripAction {
                id: openPlanAction
                text: qsTr("Open")
                iconSource: "/res/modern-icons/MaterialSymbolsCreateNewFolder.svg"
                enabled: !planActionStrip._syncInProgress
                onTriggered: {
                    if (_planMasterController.dirty) {
                        mainWindow.showMessageDialog(qsTr("Open Plan"),
                                                     qsTr("You have unsaved/unsent changes. Loading a new Plan will lose these changes. Are you sure?"),
                                                     Dialog.Yes | Dialog.Cancel,
                                                     function() { _planMasterController.loadFromSelectedFile() })
                    } else {
                        _planMasterController.loadFromSelectedFile()
                    }
                }
            }

            ToolStripAction {
                id: savePlanAction
                text: _galleryPlanFile === "" ? qsTr("Save As") : qsTr("Save")
                iconSource: "/res/modern-icons/MaterialSymbolsSave.svg"
                enabled: !planActionStrip._syncInProgress && planActionStrip._hasPlanItems
                onTriggered: {
                    if (_galleryPlanFile !== "") {
                        _planMasterController.saveToFile(_galleryPlanFile)
                        mainWindow.showMessageDialog(qsTr("Save"),
                                                     qsTr("Plan saved to `%1`").arg(_galleryPlanFile),
                                                     Dialog.Ok)
                    } else {
                        _planMasterController.saveToSelectedFile()
                    }
                }
            }

            ToolStripAction {
                id: uploadPlanAction
                text: qsTr("Upload")
                iconSource: "/res/modern-icons/MaterialSymbolsUpload2Rounded.svg"
                enabled: planActionStrip._utmspEnabled
                         ? (!planActionStrip._syncInProgress && UTMSPStateStorage.enableMissionUploadButton)
                         : (!planActionStrip._syncInProgress && planActionStrip._hasPlanItems)
                visible: !planActionStrip._syncInProgress
                onTriggered: {
                    mainWindow.confirmUploadToFlyView("customMission", function() {
                        if (planActionStrip._utmspEnabled) {
                            QGroundControl.utmspManager.utmspVehicle.triggerActivationStatusBar(true)
                            UTMSPStateStorage.removeFlightPlanState = true
                            UTMSPStateStorage.indicatorDisplayStatus = true
                        }
                        _planMasterController.upload()
                    })
                }
            }

            ToolStripAction {
                id: clearPlanAction
                text: qsTr("Clear")
                iconSource: "/res/modern-icons/MaterialSymbolsDeleteRounded.svg"
                enabled: !planActionStrip._syncInProgress
                onTriggered: {
                    if (_planMasterController.offline) {
                        mainWindow.showMessageDialog(qsTr("Clear"),
                                                     qsTr("Are you sure you want to remove all the items from the plan editor?"),
                                                     Dialog.Yes | Dialog.Cancel,
                                                     function() { _planMasterController.removeAll() })
                    } else {
                        mainWindow.showMessageDialog(qsTr("Clear"),
                                                     qsTr("Are you sure you want to remove the plan from the vehicle and the plan editor?"),
                                                     Dialog.Yes | Dialog.Cancel,
                                                     function() {
                                                         _planMasterController.removeAllFromVehicle()
                                                         if (planActionStrip._utmspEnabled) {
                                                             _resetRegisterFlightPlan = true
                                                             QGroundControl.utmspManager.utmspVehicle.triggerActivationStatusBar(false)
                                                             UTMSPStateStorage.startTimeStamp = ""
                                                             UTMSPStateStorage.showActivationTab = false
                                                             UTMSPStateStorage.flightID = ""
                                                             UTMSPStateStorage.enableMissionUploadButton = false
                                                             UTMSPStateStorage.indicatorPendingStatus = true
                                                             UTMSPStateStorage.indicatorApprovedStatus = false
                                                             UTMSPStateStorage.indicatorActivatedStatus = false
                                                             UTMSPStateStorage.currentStateIndex = 0
                                                         }
                                                     })
                    }
                }
            }

            // Opens under the Menu button (not via takeoff-strip side panel)
            ToolStripAction {
                id: planMenuAction
                text: qsTr("Menu")
                iconSource: "qrc:/qmlimages/Hamburger.svg"
                onTriggered: {
                    var origin = planMenuButton.mapToItem(globals.parent, 0, 0)
                    var panel = planMenuDropPanelComponent.createObject(mainWindow, {
                        clickRect: Qt.rect(origin.x, origin.y, planMenuButton.width, planMenuButton.height),
                        dropBelow: true
                    })
                    panel.open()
                }
            }

            ToolStripAction {
                id: exitPlanAction
                text: qsTr("Exit")
                iconSource: "/res/modern-icons/MaterialSymbolsExitToAppRounded.svg"
                enabled: mainWindow.uploadedMissionEditor === "customMission"
                         && !_root._planUploadPending
                         && !planActionStrip._syncInProgress
                         && !_planMasterController.dirty
                onTriggered: _root.exitCustomMissionPage()
            }

            Component {
                id: planMenuDropPanelComponent

                DropPanel {
                    id: planMenuDrop
                    dropBelow: true

                    sourceComponent: Component {
                        ColumnLayout {
                            spacing: ScreenTools.defaultFontPixelHeight / 3

                            QGCButton {
                                Layout.fillWidth: true
                                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 18
                                text: qsTr("Save as KML")
                                compact: true
                                heightFactor: 0.32
                                enabled: !planActionStrip._syncInProgress && planActionStrip._hasPlanItems
                                onClicked: {
                                    planMenuDrop.close()
                                    if (_missionController.visualItems.count > 1)
                                        _planMasterController.saveKmlToSelectedFile()
                                }
                            }

                            QGCButton {
                                Layout.fillWidth: true
                                text: qsTr("Download")
                                iconSource: "/res/modern-icons/MaterialSymbolsDownload2Rounded.svg"
                                compact: true
                                heightFactor: 0.32
                                enabled: planActionStrip._utmspEnabled
                                         ? (!planActionStrip._syncInProgress && UTMSPStateStorage.enableMissionDownloadButton)
                                         : !planActionStrip._syncInProgress
                                visible: !planActionStrip._syncInProgress
                                onClicked: {
                                    planMenuDrop.close()
                                    if (_planMasterController.dirty) {
                                        mainWindow.showMessageDialog(qsTr("Download"),
                                                                     qsTr("You have unsaved/unsent changes. Downloading from the Vehicle will lose these changes. Are you sure?"),
                                                                     Dialog.Yes | Dialog.Cancel,
                                                                     function() { _planMasterController.loadFromVehicle() })
                                    } else {
                                        _planMasterController.loadFromVehicle()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        MapScale {
            anchors.margins: _toolsMargin
            anchors.left: planActionStrip.visible ? planActionStrip.right : toolStrip.right
            anchors.top: parent.top
            anchors.topMargin: planToolBar.height + _toolsMargin
            mapControl: editorMap
            autoHide: true
        }

        PlanViewRightPanel {
            id: rightPanel
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            // Match Route Mapping Task Settings / Plan View outer margins
            anchors.topMargin: planToolBar.height + ScreenTools.defaultFontPixelHeight * 0.5
            anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.6
            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.5
            width: _utmspEnabled ? _rightPanelWidth + ScreenTools.defaultFontPixelWidth * 21.667 : _rightPanelWidth
            planMasterController: _planMasterController
            editorMap: editorMap
        }

        RowLayout {
            id: missionStatus
            anchors.margins: _toolsMargin
            anchors.left: _calcLeftAnchor()
            anchors.right: rightPanel.left
            anchors.bottom: parent.bottom
            spacing: 0
            visible: !hidden && _editingLayer == _layerMission && QGroundControl.corePlugin.options.showMissionStatus

            readonly property bool hidden: _planViewSettings.showMissionItemStatus.rawValue ? false : true

            function showMissionStatus() {
                _planViewSettings.showMissionItemStatus.rawValue = true
            }

            function _calcLeftAnchor() {
                let bottomOfToolStrip = toolStrip.y + toolStrip.height
                let largestStatsHeight = Math.max(terrainStatus.height, missionStats.height)
                if (bottomOfToolStrip + largestStatsHeight > parent.height - missionStatus.anchors.margins) {
                    return toolStrip.right
                }
                return parent.left
            }

            function _toggleMissionStatusVisibility() {
                _planViewSettings.showMissionItemStatus.rawValue = _planViewSettings.showMissionItemStatus.rawValue ? false : true
            }

            ColumnLayout {
                id: missionStatsButtonLayout
                Layout.alignment: Qt.AlignBottom
                spacing: ScreenTools.defaultFontPixelWidth * 0.15

                MissionStatusToolButton {
                    id: terrainButton
                    checked: true
                    iconSource: "/res/terrain.svg"
                    onClicked: {
                        terrainButton.checked = true
                        missionStatsButton.checked = false
                    }
                }

                MissionStatusToolButton {
                    id: missionStatsButton
                    checked: false
                    iconSource: "/res/sliders.svg"
                    onClicked: {
                        missionStatsButton.checked = true
                        terrainButton.checked = false
                    }
                }

                MissionStatusToolButton {
                    id: bottomStatusOpenCloseButton
                    highlightWhenChecked: false
                    iconSource: "/res/chevron-double-left.svg"
                    onClicked: missionStatus._toggleMissionStatusVisibility()
                }
            }

            TerrainStatus {
                id: terrainStatus
                Layout.alignment: Qt.AlignBottom
                Layout.fillWidth: true
                height: ScreenTools.defaultFontPixelHeight * 7
                missionController: _missionController
                visible: terrainButton.checked
                onSetCurrentSeqNum: _missionController.setCurrentPlanViewSeqNum(seqNum, true)
            }

            MissionStats {
                id: missionStats
                Layout.alignment: Qt.AlignBottom
                Layout.fillWidth: true
                visible: missionStatsButton.checked
                planMasterController: _root._planMasterController
            }
        }
    }

        //- ToolStrip ToolStripDropPanel Components

    Component {
        id: patternDropPanel

        ColumnLayout {
            id: patternColumn
            spacing: ScreenTools.defaultFontPixelHeight * 0.45
            width: Math.max(patternTitle.implicitWidth + ScreenTools.defaultFontPixelWidth, ScreenTools.defaultFontPixelWidth * 34)

            QGCLabel {
                id: patternTitle
                text: qsTr("Create complex pattern")
                color: "#3f3f3f"
                font.bold: true
                font.pointSize: ScreenTools.mediumFontPointSize
                wrapMode: Text.NoWrap
                elide: Text.ElideNone
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.15
            }

            Repeater {
                model: _missionController.complexMissionItemNames

                QGCButton {
                    text: modelData
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: patternColumn.width * 0.72
                    Layout.fillWidth: false
                    compact: true
                    heightFactor: 0.40
                    showBorder: true

                    onClicked: {
                        insertComplexItemAfterCurrent(modelData)
                        dropPanel.hide()
                    }
                }
            }
        } // Column
    }

    Component {
        id: promptForPlanUsageOnVehicleChangePopupComponent
        QGCPopupDialog {
            title: _planMasterController.managerVehicle.isOfflineEditingVehicle ? qsTr("Custom Mission - Vehicle Disconnected") : qsTr("Custom Mission - Vehicle Changed")
            buttons: Dialog.NoButton

            ColumnLayout {
                QGCLabel {
                    Layout.maximumWidth: parent.width
                    wrapMode: QGCLabel.WordWrap
                    text: _planMasterController.managerVehicle.isOfflineEditingVehicle ?
                                                qsTr("The vehicle associated with the plan in Custom Mission is no longer available. What would you like to do with that plan?") : qsTr("The plan being worked on in Custom Mission is not from the current vehicle. What would you like to do with that plan?")
                }

                QGCButton {
                    Layout.fillWidth: true
                    text: _planMasterController.dirty ?
                                            (_planMasterController.managerVehicle.isOfflineEditingVehicle ?
                                                 qsTr("Discard Unsaved Changes") : qsTr("Discard Unsaved Changes, Load New Plan From Vehicle")) : qsTr("Load New Plan From Vehicle")
                    onClicked: {
                        _planMasterController.showPlanFromManagerVehicle()
                        _promptForPlanUsageShowing = false
                        close();
                    }
                }

                QGCButton {
                    Layout.fillWidth: true
                    text: _planMasterController.managerVehicle.isOfflineEditingVehicle ?
                                            qsTr("Keep Current Plan") : qsTr("Keep Current Plan, Don't Update From Vehicle")
                    onClicked: {
                        if (!_planMasterController.managerVehicle.isOfflineEditingVehicle) {
                            _planMasterController.dirty = true
                        }
                        _promptForPlanUsageShowing = false
                        close()
                    }
                }
            }
        }
    }

    Component {
        id: insertOrCancelROIDropPanelComponent

        DropPanel {
            id: insertOrCancelROIDropPanel

            property var mapClickCoord

            sourceComponent: Component {
                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelWidth / 2

                    QGCButton {
                        Layout.fillWidth: true
                        text: qsTr("Insert ROI")

                        onClicked: {
                            insertOrCancelROIDropPanel.close()
                            insertROIAfterCurrent(mapClickCoord)
                        }
                    }

                    QGCButton {
                        Layout.fillWidth: true
                        text: qsTr("Insert Cancel ROI")

                        onClicked: {
                            insertOrCancelROIDropPanel.close()
                            insertCancelROIAfterCurrent()
                        }
                    }
                }
            }
        }
    }

    PlanViewToolBar {
        id: planToolBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        planMasterController: _planMasterController
        visible: !mainWindow.modeSelectionVisible
        onExitPlanEditMode: mainWindow.showFlyView()
    }
}
