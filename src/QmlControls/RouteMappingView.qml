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

    onVisibleChanged: {
        if (!visible) {
            hideTaskSettings()
            resetAreaRouteState()
        }
    }

    readonly property int  _decimalPlaces: 8
    readonly property real _margin: ScreenTools.defaultFontPixelHeight * 0.5
    readonly property real _toolsMargin: ScreenTools.defaultFontPixelWidth * 0.75

    property var  _planMasterController: planMasterController
    property var  _missionController: _planMasterController.missionController
    property var  _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property bool _taskSettingsVisible: false
    property bool _areaRouteActive: false
    property bool _surveyFinished: false
    property var  _startCoordinate: QtPositioning.coordinate()
    property var  _endCoordinate: QtPositioning.coordinate()

    readonly property bool _canFinishRoute: _areaRouteActive && !_surveyFinished && fieldTracePointsModel.count >= 3

    ListModel {
        id: fieldTracePointsModel
    }

    property var _surveyItem: {
        for (var i = 0; i < _missionController.visualItems.count; i++) {
            var visualItem = _missionController.visualItems.get(i)
            if (visualItem && visualItem.surveyAreaPolygon) {
                return visualItem
            }
        }
        return null
    }

    property bool _hasPlanItems: _missionController.visualItems.count > 1

    property string _mappingAreaText: {
        if (!_surveyFinished || !_surveyItem) {
            return "0.0 Ha"
        }
        var areaHa = QGroundControl.unitsConversion.squareMetersToAppSettingsAreaUnits(_surveyItem.coveredArea)
        if (QGroundControl.unitsConversion.appSettingsAreaUnitsString === "ha") {
            return areaHa.toFixed(1) + " Ha"
        }
        return areaHa.toFixed(1) + " " + QGroundControl.unitsConversion.appSettingsAreaUnitsString
    }

    property string _photoCountText: _surveyFinished && _surveyItem ? String(_surveyItem.cameraShots)
                                                 : (_areaRouteActive ? String(fieldTracePointsModel.count) : "0")

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
        _startCoordinate = QtPositioning.coordinate()
        _endCoordinate = QtPositioning.coordinate()
    }

    function startAreaRouteSession() {
        if (taskSettingsPanel.routeMode !== 0) {
            return
        }

        var coord = mapCenter()
        _planMasterController.removeAll()
        resetAreaRouteState()

        _startCoordinate = coord
        _missionController.insertTakeoffItem(coord, -1, false)

        var surveyItem = _missionController.insertComplexMissionItem(_surveyItemName(), coord, -1, true)
        if (!surveyItem || !surveyItem.surveyAreaPolygon) {
            return
        }

        surveyItem.surveyAreaPolygon.clear()
        surveyItem.surveyAreaPolygon.traceMode = false
        surveyItem.surveyAreaPolygon.interactive = false

        _missionController.setCurrentPlanViewSeqNum(surveyItem.sequenceNumber, true)
        _areaRouteActive = true
    }

    function finishAreaRoute() {
        if (!_canFinishRoute) {
            return
        }

        var surveyItem = _surveyItem
        if (!surveyItem || !surveyItem.surveyAreaPolygon) {
            return
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

        var endCoord = mapCenter()
        _endCoordinate = endCoord
        _missionController.insertLandItem(endCoord, -1, false)
        _missionController.setCurrentPlanViewSeqNum(surveyItem.sequenceNumber, true)

        fieldTracePointsModel.clear()
        _surveyFinished = true
    }

    function showTaskSettings() {
        _taskSettingsVisible = true
    }

    function hideTaskSettings() {
        _taskSettingsVisible = false
    }

    function onAddButtonClicked() {
        showTaskSettings()
        startAreaRouteSession()
    }

    function clearRouteMappingPlan() {
        mainWindow.showMessageDialog(
                    qsTr("Clear"),
                    qsTr("Are you sure you want to remove all items from the route mapping plan?"),
                    Dialog.Yes | Dialog.Cancel,
                    function() {
                        _planMasterController.removeAll()
                        _missionController.setCurrentPlanViewSeqNum(0, true)
                        resetAreaRouteState()
                    })
    }

    function saveRouteMappingToFlyView() {
        if (!_surveyFinished) {
            mainWindow.showMessageDialog(
                        qsTr("Save"),
                        qsTr("Please tap Finish to complete the field boundary before saving."))
            return
        }

        if (!_hasPlanItems) {
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

        var saveResult = mainWindow.saveRouteMappingPlanToFlyView(_planMasterController)
        if (!saveResult || !saveResult.success) {
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
    }

    PlanMasterController {
        id: planMasterController
        flyView: false

        Component.onCompleted: {
            _planMasterController.start()
            _missionController.setCurrentPlanViewSeqNum(0, true)
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
                model: _missionController.visualItems
                delegate: MissionItemMapVisual {
                    map: routeMap
                    opacity: 1
                    interactive: false
                    vehicle: _planMasterController.controllerVehicle
                    onClicked: (sequenceNumber) => _missionController.setCurrentPlanViewSeqNum(sequenceNumber, false)
                }
            }

            MapItemView {
                visible: _root._areaRouteActive && !_root._surveyFinished
                model: fieldTracePointsModel

                delegate: MapQuickItem {
                    coordinate: QtPositioning.coordinate(model.lat, model.lon, model.alt)
                    anchorPoint.x: fieldWaypointDot.width / 2
                    anchorPoint.y: fieldWaypointDot.height / 2
                    z: QGroundControl.zOrderMapItems + 2

                    sourceItem: Rectangle {
                        id: fieldWaypointDot
                        width: ScreenTools.defaultFontPixelHeight * 0.55
                        height: width
                        radius: width / 2
                        color: "magenta"
                        border.color: "white"
                        border.width: 2
                    }
                }
            }

            MapQuickItem {
                visible: _root._startCoordinate.isValid && (_root._areaRouteActive || _root._surveyFinished)
                coordinate: _root._startCoordinate
                anchorPoint.x: startMarkerItem.width / 2
                anchorPoint.y: startMarkerItem.height / 2
                z: QGroundControl.zOrderMapItems + 3

                sourceItem: Column {
                    id: startMarkerItem
                    spacing: ScreenTools.defaultFontPixelHeight * 0.1

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: ScreenTools.defaultFontPixelHeight * 0.7
                        height: width
                        radius: width / 2
                        color: "#78d957"
                        border.color: "white"
                        border.width: 2
                    }

                    QGCLabel {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Start")
                        color: "#78d957"
                        font.bold: true
                        font.pointSize: ScreenTools.smallFontPointSize
                    }
                }
            }

            MapQuickItem {
                visible: _root._surveyFinished && _root._endCoordinate.isValid
                coordinate: _root._endCoordinate
                anchorPoint.x: endMarkerItem.width / 2
                anchorPoint.y: endMarkerItem.height / 2
                z: QGroundControl.zOrderMapItems + 3

                sourceItem: Column {
                    id: endMarkerItem
                    spacing: ScreenTools.defaultFontPixelHeight * 0.1

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: ScreenTools.defaultFontPixelHeight * 0.7
                        height: width
                        radius: width / 2
                        color: "#FF9800"
                        border.color: "white"
                        border.width: 2
                    }

                    QGCLabel {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Complete")
                        color: "#FF9800"
                        font.bold: true
                        font.pointSize: ScreenTools.smallFontPointSize
                    }
                }
            }

            MissionLineView {
                showSpecialVisual: _missionController.isROIBeginCurrentItem
                model: _missionController.simpleFlightPathSegments
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

        RouteMappingTaskSettings {
            id: taskSettingsPanel
            visible: _taskSettingsVisible
            surveyItem: _root._surveyItem
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
                radius: ScreenTools.defaultFontPixelWidth * 0.25
                color: "white"
                border.color: "#78d957"
                border.width: 2
                visible: _areaRouteActive && !_surveyFinished

                QGCLabel {
                    anchors.centerIn: parent
                    text: qsTr("Finish")
                    color: "#515151"
                    font.bold: true
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
                radius: ScreenTools.defaultFontPixelWidth * 0.35
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
                radius: ScreenTools.defaultFontPixelWidth * 0.25
                color: "white"
                border.color: _taskSettingsVisible ? "#78d957" : "transparent"
                border.width: _taskSettingsVisible ? 2 : 0

                QGCLabel {
                    id:addbtn
                    anchors.centerIn: parent
                    text: qsTr("Add")
                    color: "#515151"
                    font.bold: true
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
                width: clearRow.implicitWidth + ScreenTools.defaultFontPixelWidth * 6
                height: ScreenTools.defaultFontPixelHeight * 2
                radius: ScreenTools.defaultFontPixelWidth * 0.60
                color: "white"

                Row {
                    id: clearRow
                    anchors.centerIn: parent
                    spacing: ScreenTools.defaultFontPixelWidth * 0.5

                    QGCLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Clear")
                        color: "#515151"
                        font.bold: true
                    }
                }

                QGCMouseArea {
                    anchors.fill: parent
                    enabled: _hasPlanItems
                    onClicked: _root.clearRouteMappingPlan()
                }
            }

            Rectangle {
                width: exitRow.implicitWidth + ScreenTools.defaultFontPixelWidth * 6.5
                height: ScreenTools.defaultFontPixelHeight * 2
                radius: ScreenTools.defaultFontPixelWidth * 0.60
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
                        color: "#515151"
                        font.bold: true
                    }
                }

                QGCMouseArea {
                    anchors.fill: parent
                    onClicked: {
                        _root.hideTaskSettings()
                        mainWindow.showFlyView()
                    }
                }
            }

            Rectangle {
                width: saveRow.implicitWidth + ScreenTools.defaultFontPixelWidth * 6
                height: ScreenTools.defaultFontPixelHeight * 2
                radius: ScreenTools.defaultFontPixelWidth * 0.60
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
                        color: "#515151"
                        font.bold: true
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

    Item {
        id: _guidedValueSliderStub
        visible: false
    }

    FlyViewToolBar {
        id: mainToolBar
        z: QGroundControl.zOrderWidgets + 20
        guidedValueSlider: _guidedValueSliderStub
        utmspSliderTrigger: false
        visible: !QGroundControl.videoManager.fullScreen && !mainWindow.modeSelectionVisible
    }
}
