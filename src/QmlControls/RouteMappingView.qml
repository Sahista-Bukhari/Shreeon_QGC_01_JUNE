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
        } else {
            _missionMapVisualsEnabled = true
            _updateCachedSurveyItem()
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
    property bool _areaRouteActive: false
    property bool _surveyFinished: false
    property int  _selectedWaypointIndex: -1

    readonly property bool _canFinishRoute: _areaRouteActive && !_surveyFinished && fieldTracePointsModel.count >= 3

    ListModel {
        id: fieldTracePointsModel
    }

    property var  _cachedSurveyItem: null
    property var  _taskSettingsSurveyItem: null
    property bool _hasMissionPlanItems: false

    readonly property bool _hasCalculatedSurvey: _cachedSurveyItem
                                                  && _cachedSurveyItem.surveyAreaPolygon
                                                  && _cachedSurveyItem.surveyAreaPolygon.isValid
    readonly property bool _hasTerrainCollision: _hasCalculatedSurvey
                                                  && _cachedSurveyItem.surveyAreaPolygon.showAltColor
    readonly property real _surveyStartHeading: _hasCalculatedSurvey
                                                 && _cachedSurveyItem.visualTransectPoints.length >= 2
                                                 ? _cachedSurveyItem.visualTransectPoints[0].azimuthTo(
                                                       _cachedSurveyItem.visualTransectPoints[1])
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

    function mapCenter() {
        var coordinate = routeMap.center
        coordinate.latitude  = coordinate.latitude.toFixed(_decimalPlaces)
        coordinate.longitude = coordinate.longitude.toFixed(_decimalPlaces)
        coordinate.altitude  = coordinate.altitude.toFixed(_decimalPlaces)
        return coordinate
    }

    function resetAreaRouteState() {
        _areaRouteActive = false
        _surveyFinished = false
        fieldTracePointsModel.clear()
        _planMasterController.manualCreation = false
        _cachedSurveyItem = null
        _taskSettingsSurveyItem = null
        _selectedWaypointIndex = -1
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

    function _runWithMissionVisualsSuspended(operation) {
        _missionMapVisualsEnabled = false
        _cachedSurveyItem = null
        missionPlanMutationTimer.pendingOperation = operation
        missionPlanMutationTimer.restart()
    }

    function _beginAreaRouteAtCoordinate(coord) {
        _missionController.insertTakeoffItem(coord, -1, false)

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
                        fieldTracePointsModel.remove(pointIndex)
                        _selectedWaypointIndex = -1
                        if (fieldTracePointsModel.count >= 3) {
                            _updateSurveyPolygonFromTrace(_cachedSurveyItem)
                        } else {
                            _clearSurveyPolygon()
                        }
                    },
                    function() {
                        _selectedWaypointIndex = -1
                    })
    }

    function startAreaRouteSession() {
        if (taskSettingsPanel.routeMode !== 0) {
            return
        }

        var coord = mapCenter()

        if (_missionController.visualItems.count > 1) {
            _runWithMissionVisualsSuspended(function() {
                _clearMissionItemsIfNeeded()
                resetAreaRouteState()
                _beginAreaRouteAtCoordinate(coord)
            })
        } else {
            resetAreaRouteState()
            _beginAreaRouteAtCoordinate(coord)
        }
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

        _missionController.insertLandItem(mapCenter(), -1, false)
        _missionController.setCurrentPlanViewSeqNum(surveyItem.sequenceNumber, true)

        _surveyFinished = true
    }

    function showTaskSettings() {
        _taskSettingsVisible = true
    }

    function hideTaskSettings() {
        _taskSettingsVisible = false
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
        mainWindow.showMessageDialog(
                    qsTr("Clear"),
                    qsTr("Are you sure you want to remove all items from the route mapping plan?"),
                    Dialog.Yes | Dialog.Cancel,
                    function() {
                        _runWithMissionVisualsSuspended(function() {
                            _clearMissionItemsIfNeeded()
                            _missionController.setCurrentPlanViewSeqNum(0, true)
                            resetAreaRouteState()
                        })
                    })
    }

    function saveRouteMappingToFlyView() {
        if (!_surveyFinished) {
            mainWindow.showMessageDialog(
                        qsTr("Save"),
                        qsTr("Please tap Finish to complete the field boundary before saving."))
            return
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

        hideTaskSettings()

        var saveResult = _transferPlanToFlyView()
        if (!saveResult.success) {
            return
        }

        var uploaded = saveResult.uploaded
        var terrainPending = readyState === VisualMissionItem.NotReadyForSaveTerrain
        var vehicleConnected = !flyView.planController.offline
        mainWindow.showMessageDialog(
                    qsTr("Plan Ready"),
                    uploaded ?
                        qsTr("Your route mapping plan is shown on the Fly screen and uploaded to the vehicle. Start the mission when ready.") :
                        (vehicleConnected && terrainPending ?
                             qsTr("Your route mapping plan is shown on the Fly screen. Terrain data is still loading — tap Use to upload when ready, then start the mission.") :
                             (vehicleConnected ?
                                  qsTr("Your route mapping plan is shown on the Fly screen. Tap Use to upload it to the vehicle, then start the mission.") :
                                  qsTr("Your route mapping plan is shown on the Fly screen. Connect a vehicle, tap Use to upload, then start the mission."))))
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

        _showPlanOnFlyView()
        mainWindow.showFlyView()

        return { success: true, uploaded: _tryUploadFlyViewPlan(flyPlanController) }
    }

    function _showPlanOnFlyView() {
        // Copied from FlyView.showLoadedRouteMappingPlan (plan edit mode so mission is visible)
        flyView.planEditMode = true
        flyView._editingLayer = flyView._layerMission
        flyView._missionController.setCurrentPlanViewSeqNum(0, true)
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

        onAcceptedForSave: (file) => {
                               _planMasterController.saveToFile(file)
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

            readonly property real _leftToolWidth: _root._taskSettingsVisible
                                                   ? taskSettingsPanel.width + ScreenTools.defaultFontPixelWidth * 0.5
                                                   : ScreenTools.defaultFontPixelWidth * 0.5
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
                            onClicked: _root._selectedWaypointIndex = waypointIndex
                        }

                        Rectangle {
                            anchors.left: waypointDot.right
                            anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.6
                            anchors.verticalCenter: waypointDot.verticalCenter
                            width: deleteWaypointLabel.implicitWidth + ScreenTools.defaultFontPixelWidth * 2
                            height: ScreenTools.defaultFontPixelHeight * 1.6
                            radius: ScreenTools.defaultFontPixelWidth * 0.4
                            color: "#d93025"
                            visible: _root._selectedWaypointIndex === waypointIndex

                            QGCLabel {
                                id: deleteWaypointLabel
                                anchors.centerIn: parent
                                text: qsTr("Delete")
                                color: "white"
                                font.weight: Font.DemiBold
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
                line.color: "white"
                line.width: 2
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

            MapPolyline {
                line.color: "#ffea00"
                line.width: 3
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
                coordinate: _root._cachedSurveyItem
                            ? _root._cachedSurveyItem.exitCoordinate
                            : QtPositioning.coordinate()
                anchorPoint.x: surveyEndMarker.width / 2
                anchorPoint.y: surveyEndMarker.height / 2
                visible: _root._hasCalculatedSurvey
                         && _root._cachedSurveyItem.exitCoordinate.isValid
                z: QGroundControl.zOrderMapItems + 4

                sourceItem: Rectangle {
                    id: surveyEndMarker
                    width: ScreenTools.defaultFontPixelHeight * 0.85
                    height: width
                    radius: width / 2
                    color: "#ffc400"
                    border.color: "white"
                    border.width: 2
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
            anchors.leftMargin: _taskSettingsVisible
                                ? taskSettingsPanel.width + ScreenTools.defaultFontPixelWidth * 0.5
                                : 0
            anchors.verticalCenter: parent.verticalCenter
            width: ScreenTools.defaultFontPixelHeight * 3.5
            height: ScreenTools.defaultFontPixelHeight * 3
            radius: ScreenTools.defaultFontPixelWidth * 0.45
            color: routeBackMouseArea.pressed ? Qt.rgba(1, 1, 1, 0.34) : Qt.rgba(1, 1, 1, 0.22)
            z: QGroundControl.zOrderWidgets + 12

            Behavior on anchors.leftMargin {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
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
                onClicked: {
                    _root.hideTaskSettings()
                    mainWindow.showFlyView()
                }
            }
        }

        RouteMappingTaskSettings {
            id: taskSettingsPanel
            visible: _taskSettingsVisible
            surveyItem: _root._taskSettingsSurveyItem ? _root._taskSettingsSurveyItem : _root._cachedSurveyItem
            anchors.left: parent.left
            anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.5
            anchors.top: parent.top
            anchors.topMargin: mainToolBar.height + ScreenTools.defaultFontPixelHeight * 0.5
            anchors.bottom: parent.bottom
            anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.6
            width: Math.min(ScreenTools.defaultFontPixelWidth * 38, parent.width * 0.42)
            z: QGroundControl.zOrderWidgets + 11

            onAreaRouteSelected: _root.startAreaRouteSession()
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
                opacity: _hasMissionPlanItems ? 1.0 : 0.35

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
                    enabled: _hasMissionPlanItems
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
            height: ScreenTools.defaultFontPixelHeight * 8.0
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
                id: finishButton
                anchors.left: parent.left
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 1.0
                anchors.right: parent.right
                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.75
                anchors.bottom: plusButton.top
                anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.4
                height: plusButton.height
                radius: _actionButtonRadius
                color: "white"
                border.color: "transparent"
                border.width: 0
                QGCLabel {
                    anchors.centerIn: parent
                    text: qsTr("Finish")
                    color: _routeActionTextColor
                    font.weight: Font.DemiBold
                }

                QGCMouseArea {
                    anchors.fill: parent
                    enabled: _canFinishRoute
                    onClicked: _root.finishAreaRoute()
                }
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
                    enabled: _surveyFinished
                    onClicked: _root.saveRouteMappingToFlyView()
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
