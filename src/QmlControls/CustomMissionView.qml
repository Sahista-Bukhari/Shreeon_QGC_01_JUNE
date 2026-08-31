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
        }

        onPromptForPlanUsageOnVehicleChange: {
            if (!_promptForPlanUsageShowing) {
                _promptForPlanUsageShowing = true
                promptForPlanUsageOnVehicleChangePopupComponent.createObject(mainWindow).open()
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

        function upload() {
            if (!checkReadyForSaveUpload(false /* save */)) {
                return
            }
            switch (_missionController.sendToVehiclePreCheck()) {
                case MissionController.SendToVehiclePreCheckStateOk: sendToVehicle()
                    break
                case MissionController.SendToVehiclePreCheckStateActiveMission: mainWindow.showMessageDialog(qsTr("Send To Vehicle"), qsTr("Current mission must be paused prior to uploading a new Plan"))
                    break
                case MissionController.SendToVehiclePreCheckStateFirwmareVehicleMismatch: mainWindow.showMessageDialog(qsTr("Plan Upload"),
                                                 qsTr("This Plan was created for a different firmware or vehicle type than the firmware/vehicle type of vehicle you are uploading to. " +
                                                      "This can lead to errors or incorrect behavior. " +
                                                      "It is recommended to recreate the Plan for the correct firmware/vehicle type.\n\n" +
                                                      "Click 'Ok' to upload the Plan anyway."),
                                                 Dialog.Ok | Dialog.Cancel,
                                                 function() { _planMasterController.sendToVehicle() })
                    break
            }
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

    // Re-opens the active Fly View plan inside Custom Mission when returning from Fly View.
    function resumePlanForEdit() {
        if (_planMasterController.containsItems) {
            _missionController.setCurrentPlanViewSeqNum(0, true)
            return
        }

        var flyPlanController = flyView.planController
        if (!flyPlanController) {
            return
        }

        if (!flyPlanController.offline) {
            _planMasterController.showPlanFromManagerVehicle()
        } else if (flyPlanController.currentPlanFile && flyPlanController.currentPlanFile !== "") {
            _planMasterController.loadFromFile(flyPlanController.currentPlanFile)
            _planMasterController.fitViewportToItems()
        }

        _missionController.setCurrentPlanViewSeqNum(0, true)
    }

    QGCFileDialog {
        id: fileDialog
        folder: _appSettings ? _appSettings.missionSavePath : ""

        property bool planFiles: true    ///< true: working with plan files, false: working with kml file

        onAcceptedForSave: (file) => {
            if (planFiles) {
                _planMasterController.saveToFile(file)
            } else {
                _planMasterController.saveToKml(file)
            }
            close()
        }

        onAcceptedForLoad: (file) => {
            _planMasterController.loadFromFile(file)
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
                text: _planMasterController.currentPlanFile === "" ? qsTr("Save As") : qsTr("Save")
                iconSource: "/res/modern-icons/MaterialSymbolsSave.svg"
                enabled: !planActionStrip._syncInProgress && planActionStrip._hasPlanItems
                onTriggered: {
                    if (_planMasterController.currentPlanFile !== "") {
                        _planMasterController.saveToCurrent()
                        mainWindow.showMessageDialog(qsTr("Save"),
                                                     qsTr("Plan saved to `%1`").arg(_planMasterController.currentPlanFile),
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
                    mainWindow.confirmUploadToFlyView(mainWindow.activeMissionEditor, function() {
                        if (planActionStrip._utmspEnabled) {
                            QGroundControl.utmspManager.utmspVehicle.triggerActivationStatusBar(true)
                            UTMSPStateStorage.removeFlightPlanState = true
                            UTMSPStateStorage.indicatorDisplayStatus = true
                        }
                        if (_planMasterController.upload()) {
                            mainWindow.markMissionPlanUploaded(mainWindow.activeMissionEditor)
                        }
                    })
                }
            }

            ToolStripAction {
                id: clearPlanAction
                text: qsTr("Clear")
                iconSource: "/res/modern-icons/MaterialSymbolsDeleteRounded.svg"
                enabled: !planActionStrip._syncInProgress
                onTriggered: mainWindow.confirmClearRouteMappingPlan()
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
