import QtQuick
import QtLocation
import QtPositioning

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap

// Adds visual items associated with the Flight Plan to the map.
// Currently only used by Fly View even though it's called PlanMapItems!
Item {
    id: _root

    property var    map                     ///< Map control to show items on
    property bool   largeMapView            ///< true: map takes up entire view, false: map is in small window
    property var    planMasterController    ///< Reference to PlanMasterController for vehicle
    property var    vehicle                 ///< Vehicle associated with these items

    property var    _map:                       map
    property var    _vehicle:                   vehicle
    property var    _missionController:         planMasterController.missionController
    property var    _geoFenceController:        planMasterController.geoFenceController
    property var    _rallyPointController:      planMasterController.rallyPointController
    property var    _guidedController:          globals.guidedControllerFlyView
    property var    _missionLineViewComponent

    property string fmode: vehicle.flightMode
    property bool   _showMissionVisuals: largeMapView && !_map.planView

    function _closedSurveyBoundaryPath(path) {
        var boundary = []
        if (!path) {
            return boundary
        }
        for (var i = 0; i < path.length; i++) {
            boundary.push(path[i])
        }
        if (boundary.length >= 3) {
            boundary.push(boundary[0])
        }
        return boundary
    }

    // Add the mission item visuals to the map
    Repeater {
        model: _showMissionVisuals ? _missionController.visualItems : 0

        delegate: MissionItemMapVisual {
            map:        _map
            vehicle:    _vehicle
            opacity:    object && object.surveyAreaPolygon ? 0 : 1
            onClicked:  _guidedController.confirmAction(_guidedController.actionSetWaypoint, Math.max(object.sequenceNumber, 1))
        }
    }

    Component.onCompleted: {
        _missionLineViewComponent = missionLineViewComponent.createObject(map)
        if (_missionLineViewComponent.status === Component.Error)
            console.log(_missionLineViewComponent.errorString())
        map.addMapItemGroup(_missionLineViewComponent)
    }

    Component.onDestruction: {
        if (_missionLineViewComponent) {
            // Must remove MapItemGroup before destruction, otherwise we crash on quit
            map.removeMapItemGroup(_missionLineViewComponent)
            _missionLineViewComponent.destroy()
        }
    }

    Component {
        id: missionLineViewComponent

        MapItemGroup {
            MissionLineView {
                model: _showMissionVisuals ? _missionController.simpleFlightPathSegments : null
            }

            MapItemView {
                model: _showMissionVisuals ? _missionController.visualItems : 0

                delegate: MapPolyline {
                    line.color: "white"
                    line.width: 2
                    path: object && object.surveyAreaPolygon ? _root._closedSurveyBoundaryPath(object.surveyAreaPolygon.path) : []
                    visible: object && object.surveyAreaPolygon ? path.length >= 4 : false
                    z: QGroundControl.zOrderWaypointLines + 3
                }
            }

            MapItemView {
                model: _showMissionVisuals ? _missionController.visualItems : 0

                delegate: MapQuickItem {
                    coordinate: object && object.surveyAreaPolygon ? object.coordinate : QtPositioning.coordinate()
                    anchorPoint.x: surveyStartMarker.dotCenter
                    anchorPoint.y: surveyStartMarker.dotCenter
                    visible: object && object.surveyAreaPolygon ? coordinate.isValid : false
                    z: QGroundControl.zOrderWaypointLines + 4

                    readonly property real _surveyStartHeading: object && object.visualTransectPoints && object.visualTransectPoints.length >= 2 ? object.visualTransectPoints[0].azimuthTo(object.visualTransectPoints[1]) : 0

                    sourceItem: Item {
                        id: surveyStartMarker
                        readonly property real markerSize: ScreenTools.defaultFontPixelHeight * 0.85
                        readonly property real dotCenter: markerSize / 2

                        width: markerSize * 2.25
                        height: markerSize

                        transform: Rotation {
                            origin.x: surveyStartMarker.dotCenter
                            origin.y: surveyStartMarker.dotCenter
                            angle: _surveyStartHeading - _map.bearing - 90
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
            }

            MapItemView {
                model: _showMissionVisuals ? _missionController.visualItems : 0

                delegate: MapQuickItem {
                    coordinate: object && object.surveyAreaPolygon ? object.exitCoordinate : QtPositioning.coordinate()
                    anchorPoint.x: surveyEndMarker.dotCenter
                    anchorPoint.y: surveyEndMarker.dotCenter
                    visible: object && object.surveyAreaPolygon ? coordinate.isValid : false
                    z: QGroundControl.zOrderWaypointLines + 4

                    readonly property real _surveyEndHeading: object && object.visualTransectPoints && object.visualTransectPoints.length >= 2 ? object.visualTransectPoints[object.visualTransectPoints.length - 2].azimuthTo(object.visualTransectPoints[object.visualTransectPoints.length - 1]) : 0

                    sourceItem: Item {
                        id: surveyEndMarker
                        readonly property real markerSize: ScreenTools.defaultFontPixelHeight * 0.85
                        readonly property real dotCenter: markerSize / 2

                        width: markerSize * 2.25
                        height: markerSize

                        transform: Rotation {
                            origin.x: surveyEndMarker.dotCenter
                            origin.y: surveyEndMarker.dotCenter
                            angle: _surveyEndHeading - _map.bearing - 90
                        }

                        Canvas {
                            anchors.fill: parent

                            onPaint: {
                                var ctx = getContext("2d")
                                var centerY = height / 2
                                var shaftStart = surveyEndMarker.markerSize * 0.55
                                var arrowTip = width - 1
                                var arrowBase = width - surveyEndMarker.markerSize * 0.55
                                var arrowHalfHeight = surveyEndMarker.markerSize * 0.34

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
                                drawArrow("#ffc400", 3)
                            }
                        }

                        Rectangle {
                            width: surveyEndMarker.markerSize
                            height: width
                            radius: width / 2
                            color: "#ffc400"
                            border.color: "white"
                            border.width: 2
                        }
                    }
                }
            }

            MapItemView {
                model: undefined

                delegate: MapLineArrow {
                    fromCoord:      object ? object.coordinate1 : undefined
                    toCoord:        object ? object.coordinate2 : undefined
                    arrowPosition:  3
                    z:              QGroundControl.zOrderWaypointLines + 1
                }
            }
        }
    }
}
