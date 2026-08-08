import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.UTMSP

Item {
    required property var editorMap
    required property var planMasterController

    id: root

    // These must match the indices of _editingToolComponents
    readonly property int _editingToolMission:  0
    readonly property int _editingToolFence:    1
    readonly property int _editingToolRally:    2

    property int _editingTool:              _editingToolMission
    property var _missionController:        planMasterController.missionController
    property var _geoFenceController:       planMasterController.geoFenceController
    property var _rallyPointController:     planMasterController.rallyPointController
    property var _visualItems:              _missionController.visualItems
    property var _editingToolComponents:    [ missionToolComponent, fenceToolComponent, rallyToolComponent ]
    property real _toolsMargin:             ScreenTools.defaultFontPixelWidth * 0.75

    function selectNextNotReady() {
        var foundCurrent = false
        for (var i=0; i<_missionController.visualItems.count; i++) {
            var vmi = _missionController.visualItems.get(i)
            if (vmi.readyForSaveState === VisualMissionItem.NotReadyForSaveData) {
                _missionController.setCurrentPlanViewSeqNum(vmi.sequenceNumber, true)
                break
            }
        }
    }

    QGCPalette { id: qgcPal }

    readonly property bool  _customMission: typeof mainWindow !== "undefined"
                                            && mainWindow
                                            && mainWindow.activeMissionEditor === "customMission"
    readonly property real  _glassRadius: ScreenTools.defaultFontPixelHeight * 0.9
    readonly property color _glassTint:   Qt.rgba(0.06, 0.10, 0.09, 0.34)
    readonly property color _glassRim:    Qt.rgba(1, 1, 1, 0.32)
    readonly property color _accentGreen: "#00a651"
    readonly property color _accentSoft:  "#e8e8e8"
    readonly property color _panelFill:   "#ffffff"
    readonly property color _titleColor:  "#3f3f3f"
    readonly property color _cardBorder:  "#e2e2e2"
    readonly property real  _cardRadius:  ScreenTools.defaultFontPixelWidth * 0.75

    // Custom Mission: flush square white panel (Task Settings style). Plan View keeps map glass.
    Rectangle {
        id: rightPanelSolid
        anchors.fill: parent
        visible: root._customMission
        radius: 0
        color: root._panelFill
        border.width: 0
    }

    LiquidGlassSurface {
        id:               rightPanelBackground
        anchors.fill:     parent
        visible:          !root._customMission
        backgroundSource: editorMap
        cornerRadius:     root._glassRadius
        blurAmount:       20
        tintColor:        root._glassTint
        rimColor:         root._glassRim
        accentColor:      Qt.rgba(0.14, 0.69, 0.36, 0.08)
        showGlint:        false
    }


    // Open/Close — Custom Mission: Task Settings dark square + caret; Plan View: glass tab
    Item {
        id:                     panelOpenCloseButton
        anchors.right:          parent.left
        anchors.verticalCenter: parent.verticalCenter
        width:                  root._customMission ? toggleButtonRect.width : (toggleButtonRect.width - root._cardRadius)
        height:                 toggleButtonRect.height
        clip:                   !root._customMission

        property bool _expanded: root.anchors.right == root.parent.right
        readonly property bool _highlighted: toggleMouse.containsMouse || toggleMouse.pressed

        Item {
            id:             toggleButtonRect
            width:          root._customMission
                            ? ScreenTools.defaultFontPixelHeight * 3.1
                            : ScreenTools.defaultFontPixelWidth * 4.6
            height:         root._customMission
                            ? ScreenTools.defaultFontPixelHeight * 5
                            : ScreenTools.defaultFontPixelHeight * 4.2

            // Custom Mission — Task Settings style dark translucent square handle
            Rectangle {
                anchors.fill: parent
                visible: root._customMission
                radius: 0
                color: panelOpenCloseButton._highlighted
                       ? Qt.rgba(0.12, 0.12, 0.14, 0.55)
                       : Qt.rgba(0.12, 0.12, 0.14, 0.38)

                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Image {
                anchors.centerIn: parent
                visible: root._customMission
                source: "/res/caret-left.png"
                width: ScreenTools.defaultFontPixelHeight * 1.4
                height: width
                fillMode: Image.PreserveAspectFit
                // Expanded (panel open on right): point right to close; collapsed: point left to open
                rotation: panelOpenCloseButton._expanded ? 180 : 0
                z: 1

                Behavior on rotation { NumberAnimation { duration: 180 } }
            }

            // Plan View — rounded glass tab
            LiquidGlassSurface {
                anchors.fill:     parent
                visible:          !root._customMission
                backgroundSource: editorMap
                cornerRadius:     root._cardRadius * 1.4
                blurAmount:       18
                tintColor:        panelOpenCloseButton._highlighted
                                  ? Qt.rgba(0.14, 0.66, 0.00, 0.32)
                                  : root._glassTint
                rimColor:         panelOpenCloseButton._highlighted
                                  ? Qt.rgba(0.55, 1.0, 0.72, 0.55)
                                  : root._glassRim
                accentColor:      Qt.rgba(0.14, 0.69, 0.36, 0.08)
                showGlint:        true
                pressed:          toggleMouse.pressed
            }

            QGCLabel {
                id:                 toggleButtonLabel
                anchors.centerIn:   parent
                visible:            !root._customMission
                text:               panelOpenCloseButton._expanded ? ">" : "<"
                color:              "white"
                font.weight:        Font.DemiBold
                font.pointSize:     ScreenTools.mediumFontPointSize
                style:              Text.Outline
                styleColor:         Qt.rgba(0, 0, 0, 0.28)
                z:                  1
            }

            RippleEffect {
                id: toggleRipple
                z:  2
                rippleColor: root._customMission
                             ? Qt.rgba(1, 1, 1, 0.35)
                             : Qt.rgba(1, 1, 1, 0.42)
                clipRadius: root._customMission ? 0 : root._cardRadius * 1.4
            }
        }

        QGCMouseArea {
            id:             toggleMouse
            anchors.fill:   parent
            hoverEnabled:   true
            cursorShape:    Qt.PointingHandCursor

            onClicked: function(mouse) {
                toggleRipple.tap(mouse.x, mouse.y)
                if (panelOpenCloseButton._expanded) {
                    root.anchors.right = undefined
                    root.anchors.left = root.parent.right
                } else {
                    root.anchors.left = undefined
                    root.anchors.right = root.parent.right
                }
            }
        }
    }

    // Right panel content — solid or glass background depending on theme
    Item {
        anchors.fill: root._customMission ? rightPanelSolid : rightPanelBackground

        DeadMouseArea {
            anchors.fill:   parent
        }

        ColumnLayout {
            anchors.fill:         parent
            anchors.topMargin:    ScreenTools.defaultFontPixelWidth * (root._customMission ? 1.45 : 0.55)
            anchors.bottomMargin: ScreenTools.defaultFontPixelWidth * (root._customMission ? 0.75 : 0.55)
            anchors.leftMargin:   ScreenTools.defaultFontPixelWidth * (root._customMission ? 1.45 : 0.55)
            anchors.rightMargin:  ScreenTools.defaultFontPixelWidth * (root._customMission ? 1.45 : 0.55)
            spacing:              ScreenTools.defaultFontPixelHeight * 0.5

            QGCTabBar {
                Layout.fillWidth: true
                Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.15

                QGCTabButton {
                    text:       qsTr("Mission")
                    onClicked:  { root._editingTool = root._editingToolMission; _editingLayer = _layerMission }
                }

                QGCTabButton {
                    text:       qsTr("Fence")
                    onClicked:  { root._editingTool = root._editingToolFence; _editingLayer = _layerFence }
                }

                QGCTabButton {
                    text:       qsTr("Rally")
                    onClicked:  { root._editingTool = root._editingToolRally; _editingLayer = _layerRally }
                }
            }

            Loader {
                id:                 editingToolLoader
                Layout.fillWidth:   true
                Layout.fillHeight:  true
                sourceComponent:    root._editingToolComponents[root._editingTool]
            }
        }

        Component {
            id: missionToolComponent

            ColumnLayout {
                spacing: ScreenTools.defaultFontPixelHeight / 2

                QGCListView {
                    id:                 missionItemEditorListView
                    Layout.fillWidth:   true
                    Layout.fillHeight:  true
                    spacing:            ScreenTools.defaultFontPixelHeight / 4
                    orientation:        ListView.Vertical
                    model:              _missionController.visualItems
                    cacheBuffer:        Math.max(height * 2, 0)
                    clip:               true
                    currentIndex:       _missionController.currentPlanViewSeqNum
                    highlightMoveDuration: 250
                    // Keep a clear gap so the card border is never clipped on any side
                    leftMargin:         root._customMission ? ScreenTools.defaultFontPixelWidth * 0.55 : 0
                    rightMargin:        root._customMission ? ScreenTools.defaultFontPixelWidth * 0.55 : 0
                    topMargin:          root._customMission ? ScreenTools.defaultFontPixelWidth * 0.55 : 0
                    bottomMargin:       root._customMission ? ScreenTools.defaultFontPixelWidth * 0.55 : 0

                    delegate: MissionItemEditor {
                        map:                editorMap
                        masterController:   planMasterController
                        missionItem:        object
                        width:              missionItemEditorListView.width
                                            - missionItemEditorListView.leftMargin
                                            - missionItemEditorListView.rightMargin
                        readOnly:           false

                        onClicked: _missionController.setCurrentPlanViewSeqNum(object.sequenceNumber, false)

                        onRemove: {
                            var removeVIIndex = index
                            _missionController.removeVisualItem(removeVIIndex)
                            if (removeVIIndex >= _missionController.visualItems.count) {
                                removeVIIndex--
                            }
                        }

                        onSelectNextNotReadyItem: selectNextNotReady()
                    }
                }
            }
        }

        Component {
            id: fenceToolComponent

            Column {
                spacing: ScreenTools.defaultFontPixelHeight / 2

                GeoFenceEditor {
                    width:                  parent.width
                    myGeoFenceController:   root._geoFenceController
                    flightMap:              root.editorMap
                }
            }
        }


        Component {
            id: rallyToolComponent

            Column {
                spacing: ScreenTools.defaultFontPixelHeight / 2

                RallyPointEditorHeader {
                    width:              parent.width
                    controller:         root._rallyPointController
                }

                RallyPointItemEditor {
                    width:              parent.width
                    visible:            root._rallyPointController.points.count
                    rallyPoint:         root._rallyPointController.currentRallyPoint
                    controller:         root._rallyPointController
                }
            }
        }

        Component {
            id: utmspToolComponent

            Column {
                spacing: ScreenTools.defaultFontPixelHeight / 2

                UTMSPAdapterEditor{
                    width:                  parent.width
                    currentMissionItems:     root._visualItems
                    myGeoFenceController:    root._geoFenceController
                    flightMap:               root.editorMap
                    triggerSubmitButton:     _triggerSubmit
                    resetRegisterFlightPlan: _resetRegisterFlightPlan

                    onRemoveFlightPlanTriggered: {
                        root.planMasterController.removeAllFromVehicle()
                        root._missionController.setCurrentPlanViewSeqNum(0, true)
                        _resetRegisterFlightPlan = true
                    }

                    onResetGeofencePolygonTriggered: {
                        resetUTMSPGeoFenceTimer.start()
                    }

                    Timer {
                        id:             resetUTMSPGeoFenceTimer
                        interval:       2500
                        running:        false
                        repeat:         false
                        onTriggered:    _resetGeofencePolygon = true
                    }
                }
            }
        }
    }
}
