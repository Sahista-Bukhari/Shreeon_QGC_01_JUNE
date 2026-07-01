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
    property bool   _startMissionPopupVisible: false
    property var    routeMappingBoundaryPath: []
    property var    routeMappingTransectPath: []
    property var    routeMappingEntryCoordinate: QtPositioning.coordinate()
    property var    routeMappingExitCoordinate: QtPositioning.coordinate()
    property real   routeMappingEntryHeading: 0
    property real   routeMappingExitHeading: 0

    readonly property int _layerMission:    1
    readonly property int _layerFence:      2
    readonly property int _layerRally:      3
    readonly property int _layerUTMSP:      4

    readonly property int   _decimalPlaces: 8

    function showStartMissionPopup() {
        _startMissionPopupVisible = true
    }

    function hideStartMissionPopup() {
        _startMissionPopupVisible = false
    }

    PlanMasterController {
        id:                     _planController
        flyView:                false   // Must be false for proper plan editing with correct terrain calculations
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

    property var _appSettings: QGroundControl.settingsManager.appSettings

    QGCFileDialog {
        id: planFileDialog
        folder: _appSettings ? _appSettings.missionSavePath : ""

        property bool planFiles: true    ///< true: working with plan files, false: working with kml file

        onAcceptedForSave: (file) => {
            if (planFiles) {
                _planController.saveToFile(file)
            } else {
                _planController.saveToKml(file)
            }
            close()
        }

        onAcceptedForLoad: (file) => {
            _planController.loadFromFile(file)
            _missionController.setCurrentPlanViewSeqNum(0, true)
            close()
        }
    }

    property bool   _mainWindowIsMap:       mapControl.pipState.state === mapControl.pipState.fullState
    property bool   _isFullWindowItemDark:  _mainWindowIsMap ? mapControl.isSatelliteMap : true
    property var    _activeVehicle:         QGroundControl.multiVehicleManager.activeVehicle
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


    property real   _fullItemZorder:    0
    property real   _pipItemZorder:     QGroundControl.zOrderWidgets

    QGCPalette { id: qgcPal }

    // Reset mission index when items change to prevent stale index issues
    Connections {
        target: _missionController

        function onNewItemsFromVehicle() {
            _missionController.setCurrentPlanViewSeqNum(0, true)
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
            routeMappingEntryCoordinate: _root.routeMappingEntryCoordinate
            routeMappingExitCoordinate: _root.routeMappingExitCoordinate
            routeMappingEntryHeading: _root.routeMappingEntryHeading
            routeMappingExitHeading: _root.routeMappingExitHeading

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
            anchors.left:           parent.left
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

            property real leftEdgeBottomInset: visible ? width + anchors.margins : 0
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
            anchors.left:           parent.left
            anchors.right:          guidedValueSlider.visible ? guidedValueSlider.left : parent.right
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
            anchors.left:           parent.left
            anchors.right:          guidedValueSlider.visible ? guidedValueSlider.left : parent.right
            z:                      widgetLayer.z + 1
            insetsToView:           widgetLayer.totalToolInsets
            visible:                false
        }

        GuidedActionsController {
            id:                 guidedActionsController
            missionController:  _missionController
            guidedValueSlider:     _guidedValueSlider
        }

        //-- Guided value slider (e.g. altitude)
        GuidedValueSlider {
            id:                 guidedValueSlider
            anchors.right:      parent.right
            anchors.top:        parent.top
            anchors.bottom:     parent.bottom
            anchors.topMargin:  toolbar.height
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
        visible:            !_root.planEditMode
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
        visible:            !QGroundControl.videoManager.fullScreen && !mainWindow.modeSelectionVisible
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

    // "+ Add" / "Edit" / "Course Lock" button on right side center
    // Shows "Add" when no plan, "Edit" when plan exists, "Course Lock" when mission is running
    Rectangle {
        id: addButton
        
        property bool _missionRunning: _root._activeVehicle ? _root._activeVehicle.flying && _root._activeVehicle.flightMode === _root._activeVehicle.missionFlightMode : false
        property bool _hasPlan: _root._missionController ? _root._missionController.visualItems.count > 1 : false
        
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
                    if (addButton._missionRunning) return qsTr("Course Lock")
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
            onClicked: mainWindow.showRouteMappingView()
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
        planMasterController: _planController
        planEditMode:       _root.planEditMode
        visible:            !QGroundControl.videoManager.fullScreen && _root._mainWindowIsMap
        z:                  QGroundControl.zOrderTopMost + 10
    }

    // Plan View Action Buttons (Bottom Right)
    Column {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: ScreenTools.defaultFontPixelWidth * 1.5
        spacing: ScreenTools.defaultFontPixelHeight * 0.5
        visible: _root.planEditMode
        z: 4000

        // Exit Button
        Rectangle {
            id: exitButton
            height: ScreenTools.defaultFontPixelHeight * 2
            width: exitRow.implicitWidth + ScreenTools.defaultFontPixelWidth * 6.5
            radius: ScreenTools.defaultFontPixelWidth * 0.45
            color: "white"

            Row {
                id: exitRow
                anchors.centerIn: parent
                spacing: ScreenTools.defaultFontPixelWidth * 0.5

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: ScreenTools.defaultFontPixelHeight * 1.1
                    height: width
                    source: "/res/exit.png"
                    fillMode: Image.PreserveAspectFit
                }

                QGCLabel {
                    text: qsTr("Exit")
                    font.weight: Font.DemiBold
                    color: "#6a6a6a"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            QGCMouseArea {
                anchors.fill: parent
                onClicked: _root.planEditMode = false
                onPressed: parent.scale = 0.96
                onReleased: parent.scale = 1.0
            }
            
            Behavior on scale { NumberAnimation { duration: 50 } }
        }

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

    Item {
        id: startMissionPopupOverlay
        anchors.fill: parent
        visible: _root._startMissionPopupVisible
        z: QGroundControl.zOrderTopMost + 1000

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.42)
        }

        Loader {
            id: startMissionPopupLoader
            active: startMissionPopupOverlay.visible
            source: "qrc:/qml/QGroundControl/FlyView/startMission.qml"
            anchors.centerIn: parent
            width: Math.min(parent.width - ScreenTools.defaultFontPixelWidth * 2,
                            ScreenTools.defaultFontPixelWidth * 48)
        }

        Connections {
            target: startMissionPopupLoader.item

            function onCollapsed() {
                _root.hideStartMissionPopup()
            }

            function onExecuteRequested() {
                _root.hideStartMissionPopup()
            }
        }
    }
}
