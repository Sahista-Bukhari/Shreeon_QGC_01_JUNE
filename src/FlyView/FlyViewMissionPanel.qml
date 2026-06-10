import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView
import QGroundControl.FlightMap

/// Floating toolbar panel for mission editing in FlyView
/// Contains mission tool buttons (Takeoff, Pattern, Return, Add) in a compact floating strip

Item {
    id: root

    required property var planMasterController
    required property bool planEditMode
    required property var missionController
    required property int editingLayer
    required property var mapControl

    required property bool showMissionStats   // Visibility state of mission stats panel

    signal layerSelectionChanged(int layer)
    signal insertTakeoff()
    signal insertLand()
    signal insertComplexItem(string itemName)
    signal addWaypointAtCenter()      // Add waypoint at map center
    signal addPolygonPoint()          // Add polygon vertex at map center (for Survey trace)
    signal toggleMissionStats()       // Toggle mission stats panel visibility

    // Forcibly sync Stats button when showMissionStats changes externally (e.g. from panel's close button)
    onShowMissionStatsChanged: {
        if (statsAction.checked !== showMissionStats) {
            statsAction.checked = showMissionStats
        }
    }

    // Crosshair is always visible, Add button action depends on context
    property real panelWidth: ScreenTools.defaultFontPixelWidth * 8
    property real _toolsMargin: ScreenTools.defaultFontPixelWidth * 0.75
    property real _panelRadius: ScreenTools.defaultFontPixelWidth * 1.5

    property var _missionController: missionController
    property var _planMasterController: planMasterController
    property bool _singleComplexItem: _missionController.complexMissionItemNames.length === 1
    
    // Check if current item is in trace mode (Survey polygon tracing)
    property var _currentItem: _missionController.currentPlanViewItem
    property bool _isInTraceMode: {
        if (!_currentItem) return false
        if (!_currentItem.surveyAreaPolygon) return false
        return _currentItem.surveyAreaPolygon.traceMode === true
    }

    readonly property int _layerMission: 1
    readonly property int _layerFence: 2
    readonly property int _layerRally: 3

    // Floating panel - positioned from parent, not full height
    width: panelWidth
    height: toolStrip.height + (_toolsMargin * 2)
    
    // Animate x position for show/hide
    x: planEditMode ? parent.width - panelWidth - _toolsMargin : parent.width + panelWidth

    Behavior on x {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutQuad
        }
    }

    QGCPalette { id: qgcPal }

    // Floating rounded background
    Rectangle {
        id: panelBackground
        anchors.fill: parent
        color: qgcPal.window
        radius: root._panelRadius
        opacity: 0.95

        // Drop shadow effect
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            radius: root._panelRadius + 2
            color: "transparent"
            z: -1
            
            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: root._panelRadius
                color: "#30000000"
            }
        }
    }

    // Tool Strip with mission editing actions
    ToolStrip {
        id: toolStrip
        anchors.centerIn: parent
        width: parent.width - (_toolsMargin * 2)
        maxHeight: ScreenTools.defaultFontPixelHeight * 35
        visible: editingLayer == _layerMission
        dropLeft: true  // Dropdown appears to the left since toolbar is on right side

        ToolStripActionList {
            id: toolStripActionList
            model: [
                ToolStripAction {
                    text: qsTr("Takeoff")
                    iconSource: "/res/takeoff.svg"
                    enabled: _missionController.isInsertTakeoffValid
                    visible: !_planMasterController.controllerVehicle.rover
                    onTriggered: root.insertTakeoff()
                },
                ToolStripAction {
                    text: _singleComplexItem ? _missionController.complexMissionItemNames[0] : qsTr("Pattern")
                    iconSource: "/qmlimages/MapDrawShape.svg"
                    enabled: _missionController.flyThroughCommandsAllowed
                    dropPanelComponent: _singleComplexItem ? undefined : patternDropPanel
                    onTriggered: {
                        if (_singleComplexItem) {
                            root.insertComplexItem(_missionController.complexMissionItemNames[0])
                        }
                    }
                },
                ToolStripAction {
                    text: _planMasterController.controllerVehicle.multiRotor
                                ? qsTr("Return")
                                : _missionController.isInsertLandValid && _missionController.hasLandItem
                                  ? qsTr("Alt Land")
                                  : qsTr("Land")
                    iconSource: "/res/rtl.svg"
                    enabled: _missionController.isInsertLandValid
                    onTriggered: root.insertLand()
                },
                ToolStripAction {
                    text: qsTr("Add")
                    iconSource: "/res/target-crosshair.svg"
                    onTriggered: {
                        if (root._isInTraceMode) {
                            // In survey trace mode, add polygon vertex
                            root.addPolygonPoint()
                        } else {
                            // Normal mode, add waypoint at center
                            root.addWaypointAtCenter()
                        }
                    }
                },
                ToolStripAction {
                    id: statsAction
                    text: qsTr("Stats")
                    iconSource: "/res/sliders.svg"
                    checkable: true
                    checked: root.showMissionStats
                    onTriggered: root.toggleMissionStats()
                }
            ]
        }

        model: toolStripActionList.model
    }

    // Pattern drop panel component with proper background styling
    Component {
        id: patternDropPanel

        Rectangle {
            width: patternColumn.width + ScreenTools.defaultFontPixelWidth * 2
            height: patternColumn.height + ScreenTools.defaultFontPixelWidth * 2
            color: qgcPal.window
            radius: ScreenTools.defaultFontPixelWidth * 0.5
            border.color: qgcPal.groupBorder
            border.width: 1

            ColumnLayout {
                id: patternColumn
                anchors.centerIn: parent
                spacing: ScreenTools.defaultFontPixelWidth * 0.5

                QGCLabel { 
                    text: qsTr("Create complex pattern:")
                    font.bold: true
                }

                Repeater {
                    model: root._missionController.complexMissionItemNames

                    QGCButton {
                        text: modelData
                        Layout.fillWidth: true
                        Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 15

                        // Note: dropPanel is injected by ToolStripDropPanel's Loader
                        onClicked: {
                            dropPanel.hide()
                            root.insertComplexItem(modelData)
                        }
                    }
                }
            }
        }
    }
}
