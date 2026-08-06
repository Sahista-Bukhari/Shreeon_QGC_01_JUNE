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

    readonly property real  _glassRadius: ScreenTools.defaultFontPixelHeight * 0.9
    readonly property color _glassTint:   Qt.rgba(0.06, 0.10, 0.09, 0.34)
    readonly property color _glassRim:    Qt.rgba(1, 1, 1, 0.32)
    readonly property color _accentGreen: "#23a800"
    readonly property color _titleColor:  "#3f3f3f"
    readonly property color _cardBorder:  "#e2e2e2"
    readonly property real  _cardRadius:  ScreenTools.defaultFontPixelWidth * 0.75

    LiquidGlassSurface {
        id:               rightPanelBackground
        anchors.fill:     parent
        backgroundSource: editorMap
        cornerRadius:     root._glassRadius
        blurAmount:       20
        tintColor:        root._glassTint
        rimColor:         root._glassRim
        accentColor:      Qt.rgba(0.14, 0.69, 0.36, 0.08)
        showGlint:        false
    }


    // Open/Close panel — wider Task Settings tab with liquid glass
    Item {
        id:                     panelOpenCloseButton
        anchors.right:          parent.left
        anchors.verticalCenter: parent.verticalCenter
        width:                  toggleButtonRect.width - root._cardRadius
        height:                 toggleButtonRect.height
        clip:                   true

        property bool _expanded: root.anchors.right == root.parent.right
        readonly property bool _highlighted: toggleMouse.containsMouse || toggleMouse.pressed

        Item {
            id:             toggleButtonRect
            width:          ScreenTools.defaultFontPixelWidth * 4.6
            height:         ScreenTools.defaultFontPixelHeight * 4.2

            LiquidGlassSurface {
                anchors.fill:     parent
                backgroundSource: editorMap
                cornerRadius:     root._cardRadius * 1.4
                blurAmount:       18
                // Idle state matches Mission Settings panel glass so the tab doesn't look like a different chrome
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
                rippleColor: Qt.rgba(1, 1, 1, 0.42)
                clipRadius: root._cardRadius * 1.4
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

    //-------------------------------------------------------
    // Right Panel Controls
    Item {
        anchors.fill: rightPanelBackground

        DeadMouseArea {
            anchors.fill:   parent
        }

        ColumnLayout {
            anchors.fill:       parent
            anchors.margins:    ScreenTools.defaultFontPixelWidth * 0.55
            spacing:            ScreenTools.defaultFontPixelHeight * 0.5

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

                    delegate: MissionItemEditor {
                        map:                editorMap
                        masterController:   planMasterController
                        missionItem:        object
                        width:              missionItemEditorListView.width
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
