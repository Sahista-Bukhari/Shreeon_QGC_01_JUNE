import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView
import QGroundControl.FlightMap
import QGroundControl.UTMSP

/// Sliding right panel for mission item editing in FlyView
/// Contains Mission/Fence/Rally tabs and item editors

Item {
    id: root

    required property var planMasterController
    required property bool planEditMode
    required property int editingLayer
    required property var mapControl

    signal layerSelectionChanged(int layer)
    signal collapseToggled(bool collapsed)

    property real panelWidth: ScreenTools.defaultFontPixelWidth * 30
    property real _toolsMargin: ScreenTools.defaultFontPixelWidth * 0.75
    property bool _collapsed: false

    property var _planMasterController: planMasterController
    property var _missionController: _planMasterController.missionController
    property var _geoFenceController: _planMasterController.geoFenceController
    property var _rallyPointController: _planMasterController.rallyPointController

    readonly property int _layerMission: 1
    readonly property int _layerFence: 2
    readonly property int _layerRally: 3
    readonly property int _layerUTMSP: 4

    // Function to select next item that is not ready for save
    function selectNextNotReady() {
        var foundCurrent = false
        for (var i = 0; i < _missionController.visualItems.count; i++) {
            var vmi = _missionController.visualItems.get(i)
            if (vmi.readyForSaveState === VisualMissionItem.NotReadyForSaveData) {
                _missionController.setCurrentPlanViewSeqNum(vmi.sequenceNumber, true)
                break
            }
        }
    }

    // These must match the indices of _editingToolComponents
    readonly property int _editingToolMission:  0
    readonly property int _editingToolFence:    1
    readonly property int _editingToolRally:    2
    readonly property int _editingToolUTMSP:    3

    property int _editingTool: {
        switch (editingLayer) {
        case _layerMission: return _editingToolMission
        case _layerFence:   return _editingToolFence
        case _layerRally:   return _editingToolRally
        case _layerUTMSP:   return _editingToolUTMSP
        default:            return _editingToolMission
        }
    }

    property var _editingToolComponents: [
        missionToolComponent,
        fenceToolComponent,
        rallyToolComponent,
        utmspToolComponent
    ]

    width: panelWidth
    visible: planEditMode || _animOpacity > 0  // Stay visible during fade-out animation
    opacity: _animOpacity

    // Smooth blur-fade-in animation
    property real _animOpacity: planEditMode ? 1.0 : 0.0
    Behavior on _animOpacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    // Subtle slide-in from left
    transform: Translate {
        x: root.planEditMode ? 0 : -20
        Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    }

    QGCPalette { id: qgcPal }

    // Background panel
    Rectangle {
        id: rightPanelBackground
        anchors.fill: parent
        color: qgcPal.window
        opacity: 0.85

        // Right edge shadow
        Rectangle {
            anchors.left: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 4
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#40000000" }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }

    // Open/Close panel toggle - using PlanViewRightPanel pattern
    Item {
        id: panelOpenCloseButton
        anchors.left: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: toggleButtonRect.width - toggleButtonRect.radius
        height: toggleButtonRect.height
        clip: true
        visible: planEditMode

        property bool _expanded: root.anchors.left == root.parent.left

        Rectangle {
            id: toggleButtonRect
            width: ScreenTools.defaultFontPixelWidth * 2.25
            height: width * 3
            radius: ScreenTools.defaultBorderRadius
            color: rightPanelBackground.color
            opacity: rightPanelBackground.opacity

            QGCLabel {
                id: toggleButtonLabel
                anchors.centerIn: parent
                text: panelOpenCloseButton._expanded ? "<" : ">"
                color: qgcPal.buttonText
            }
        }

        QGCMouseArea {
            anchors.fill: parent

            onClicked: {
                if (panelOpenCloseButton._expanded) {
                    // Close panel - move it off to the left
                    root.anchors.left = undefined
                    root.anchors.right = root.parent.left
                } else {
                    // Open panel - dock it to the left
                    root.anchors.right = undefined
                    root.anchors.left = root.parent.left
                }
                root.collapseToggled(!panelOpenCloseButton._expanded)
            }
        }
    }

    //-------------------------------------------------------
    // Right Panel Controls
    Item {
        anchors.fill: rightPanelBackground

        DeadMouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: ScreenTools.defaultFontPixelHeight * 0.5

            // Layer selection tabs
            QGCTabBar {
                id: layerTabBar
                Layout.fillWidth: true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3

                Component.onCompleted: currentIndex = 0

                QGCTabButton {
                    text: qsTr("Mission")
                }
                QGCTabButton {
                    text: qsTr("Fence")
                }
                QGCTabButton {
                    text: qsTr("Rally")
                }

                onCurrentIndexChanged: {
                    switch (currentIndex) {
                    case 0: root.layerSelectionChanged(_layerMission); break
                    case 1: root.layerSelectionChanged(_layerFence); break
                    case 2: root.layerSelectionChanged(_layerRally); break
                    }
                }
            }

            // Mission item editor
            Loader {
                id: editingToolLoader
                Layout.fillWidth: true
                Layout.fillHeight: true
                sourceComponent: root._editingToolComponents[root._editingTool]
            }
        }

        // Mission editing component
        Component {
            id: missionToolComponent

            ColumnLayout {
                spacing: ScreenTools.defaultFontPixelHeight / 2

                QGCListView {
                    id: missionItemEditorListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: ScreenTools.defaultFontPixelHeight / 4
                    orientation: ListView.Vertical
                    model: _missionController.visualItems
                    cacheBuffer: Math.max(height * 2, 0)
                    clip: true
                    currentIndex: _missionController.currentPlanViewSeqNum
                    highlightMoveDuration: 250

                    delegate: MissionItemEditor {
                        map: mapControl
                        masterController: planMasterController
                        missionItem: object
                        width: missionItemEditorListView.width
                        readOnly: false

                        onClicked: _missionController.setCurrentPlanViewSeqNum(object.sequenceNumber, false)

                        onRemove: {
                            var removeVIIndex = index
                            _missionController.removeVisualItem(removeVIIndex)
                            if (removeVIIndex >= _missionController.visualItems.count) {
                                removeVIIndex--
                            }
                        }

                        onSelectNextNotReadyItem: root.selectNextNotReady()
                    }
                }
            }
        }

        // Fence editing component
        Component {
            id: fenceToolComponent

            Column {
                spacing: ScreenTools.defaultFontPixelHeight / 2

                GeoFenceEditor {
                    width: parent.width
                    myGeoFenceController: root._geoFenceController
                    flightMap: root.mapControl
                }
            }
        }

        // Rally point editing component
        Component {
            id: rallyToolComponent

            Column {
                spacing: ScreenTools.defaultFontPixelHeight / 2

                RallyPointEditorHeader {
                    width: parent.width
                    controller: root._rallyPointController
                }

                RallyPointItemEditor {
                    width: parent.width
                    rallyPoint: root._rallyPointController.currentRallyPoint
                    controller: root._rallyPointController
                }
            }
        }

        // UTMSP editing component
        Component {
            id: utmspToolComponent

            Column {
                spacing: ScreenTools.defaultFontPixelHeight / 2

                QGCLabel {
                    width: parent.width
                    text: qsTr("UTMSP Configuration")
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
