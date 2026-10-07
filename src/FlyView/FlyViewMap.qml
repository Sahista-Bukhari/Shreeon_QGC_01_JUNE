import QtQuick
import QtQuick.Controls
import QtLocation
import QtPositioning
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView
import QGroundControl.FlightMap

FlightMap {
    id:                         _root
    allowGCSLocationCenter:     true
    allowVehicleLocationCenter: !_keepVehicleCentered
    planView:                   planEditMode
    zoomLevel:                  QGroundControl.flightMapZoom
    center:                     QGroundControl.flightMapPosition

    property Item   pipView
    property Item   pipState:                   _pipState
    property var    rightPanelWidth
    property var    planMasterController
    property bool   pipMode:                    false   // true: map is shown in a small pip mode
    property var    toolInsets                          // Insets for the center viewport area

    property var    _activeVehicle:             QGroundControl.multiVehicleManager.activeVehicle
    property var    _planMasterController:      planMasterController
    property var    _geoFenceController:        planMasterController.geoFenceController
    property var    _rallyPointController:      planMasterController.rallyPointController
    property var    _activeVehicleCoordinate:   _activeVehicle ? _activeVehicle.coordinate : QtPositioning.coordinate()
    property real   _toolButtonTopMargin:       parent.height - mainWindow.height + (ScreenTools.defaultFontPixelHeight / 2)
    property real   _toolsMargin:               ScreenTools.defaultFontPixelWidth * 0.75
    property var    _flyViewSettings:           QGroundControl.settingsManager.flyViewSettings
    property bool   _keepMapCenteredOnVehicle:  _flyViewSettings.keepMapCenteredOnVehicle.rawValue

    property bool   _disableVehicleTracking:    false
    property bool   _keepVehicleCentered:       pipMode ? true : false
    property bool   _saveZoomLevelSetting:      true

    // Plan Edit Mode properties
    property bool   planEditMode:               false
    property int    editingLayer:               1       // 1=Mission, 2=Fence, 3=Rally
    // Removed: centerTargetMode - crosshair is now always visible in plan edit mode
    property var    missionController
    property var    geoFenceController
    property var    rallyPointController
    property var    routeMappingBoundaryPath: []
    property var    routeMappingTransectPath: []
    property var    routeMappingPhotoCaptureTransectPoints: []
    property var    routeMappingTakeoffCoordinate: QtPositioning.coordinate()
    property var    routeMappingEntryCoordinate: QtPositioning.coordinate()
    property var    routeMappingExitCoordinate: QtPositioning.coordinate()
    property real   routeMappingEntryHeading: 0
    property real   routeMappingExitHeading: 0
    property real   routeMappingPhotoFootprintSide: 25
    property real   routeMappingPhotoFootprintFrontal: 25
    property real   routeMappingTriggerDistance: 25
    property var    routeMappingLivePhotoModel: null
    property string routeMappingOrthophotoUrl: ""
    property var    routeMappingOrthophotoNorthWest: QtPositioning.coordinate()
    property var    routeMappingOrthophotoSouthEast: QtPositioning.coordinate()
    property bool   routeMappingOrthophotoReady: false
    property bool   hideVehicleMissionForUnuploadedRoute: false
    readonly property var _routeMappingTakeoffPath: {
        if (!routeMappingTakeoffCoordinate || !routeMappingTakeoffCoordinate.isValid
                || !routeMappingEntryCoordinate || !routeMappingEntryCoordinate.isValid) {
            return []
        }
        return [routeMappingTakeoffCoordinate, routeMappingEntryCoordinate]
    }

    // Return-to-launch leg: survey exit back to the takeoff/home coordinate.
    // Mission line segments are suppressed under the yellow overlay, so the RTL
    // line is drawn here to stay visible on Fly View.
    readonly property var _routeMappingReturnPath: {
        if (!routeMappingExitCoordinate || !routeMappingExitCoordinate.isValid
                || !routeMappingTakeoffCoordinate || !routeMappingTakeoffCoordinate.isValid) {
            return []
        }
        return [routeMappingExitCoordinate, routeMappingTakeoffCoordinate]
    }

    property real   _routeMappingCoveredDistance: 0
    property var    _routeMappingRemainingTransectPath: []
    property var    _routeMappingCompletedGradientSegments: []

    readonly property real routeMappingProgressRatio: {
        var path = routeMappingTransectPath
        var covered = _routeMappingCoveredDistance
        if (!path || path.length < 2 || covered <= 0) {
            return 0
        }
        var total = _pathLength(path)
        if (total <= 0) {
            return 0
        }
        return Math.min(1, covered / total)
    }
    readonly property int routeMappingProgressPercent: Math.floor(routeMappingProgressRatio * 100)

    readonly property var _routeCompletedGradientColors: [
        "#00ccff", "#00b8e6", "#00a3cc", "#008fbf", "#007ab3", "#005588"
    ]
    readonly property color _routeRemainingColor: Qt.rgba(1.0, 0.94, 0.38, 0.78)

    onRouteMappingTransectPathChanged: {
        // Never wipe covered progress mid-flight. Progress only resets when the
        // plan overlay is cleared, the vehicle is swapped, or the user clears the plan.
        var pathEmpty = !routeMappingTransectPath || routeMappingTransectPath.length < 2
        var keepProgress = _activeVehicle && (_activeVehicle.flying || _activeVehicle.armed)
                && _routeMappingCoveredDistance > 0
                && !pathEmpty
        if (!keepProgress) {
            _routeMappingCoveredDistance = 0
        }
        Qt.callLater(_updateRouteMappingCoverage)
    }

    function _pathLength(path) {
        var length = 0
        for (var i = 1; i < path.length; i++) {
            length += path[i - 1].distanceTo(path[i])
        }
        return length
    }

    function _projectPointOnSegment(point, segStart, segEnd) {
        var segLen = segStart.distanceTo(segEnd)
        if (segLen < 0.01) {
            return segStart
        }

        var azSeg = segStart.azimuthTo(segEnd)
        var azToPoint = segStart.azimuthTo(point)
        var distToPoint = segStart.distanceTo(point)
        var angleRad = (azToPoint - azSeg) * Math.PI / 180.0
        var along = distToPoint * Math.cos(angleRad)
        along = Math.max(0, Math.min(segLen, along))
        return segStart.atDistanceAndAzimuth(along, azSeg)
    }

    function _photoCapturePathToleranceMeters() {
        var spacing = Number(routeMappingTriggerDistance)
        if (!isFinite(spacing) || spacing <= 0) {
            spacing = 25
        }
        // GPS/cross-track error on the last leg must not block final triggers.
        return Math.max(40, spacing * 1.5)
    }

    function _distanceAlongTransect(path, coord, maxCrossTrackMeters) {
        var bestAlong = 0
        var minDist = Number.MAX_VALUE
        var accumulated = 0
        var crossTrackLimit = maxCrossTrackMeters > 0
                ? maxCrossTrackMeters
                : _photoCapturePathToleranceMeters()

        for (var i = 0; i < path.length - 1; i++) {
            var segStart = path[i]
            var segEnd = path[i + 1]
            var projected = _projectPointOnSegment(coord, segStart, segEnd)
            var distToPath = coord.distanceTo(projected)
            if (distToPath < minDist) {
                minDist = distToPath
                bestAlong = accumulated + segStart.distanceTo(projected)
            }
            accumulated += segStart.distanceTo(segEnd)
        }

        if (minDist > crossTrackLimit) {
            return -1
        }
        return bestAlong
    }

    function routeMappingHeadingAtCoordinate(coord) {
        var path = routeMappingTransectPath
        if (!path || path.length < 2 || !coord || !coord.isValid) {
            return routeMappingEntryHeading
        }

        var bestHeading = routeMappingEntryHeading
        var minDistance = Number.MAX_VALUE
        for (var i = 0; i < path.length - 1; i++) {
            var projected = _projectPointOnSegment(coord, path[i], path[i + 1])
            var distance = coord.distanceTo(projected)
            if (distance < minDistance) {
                minDistance = distance
                bestHeading = path[i].azimuthTo(path[i + 1])
            }
        }
        return bestHeading
    }

    function _routeMappingTriggerPath() {
        if (routeMappingTransectPath && routeMappingTransectPath.length >= 2) {
            return routeMappingTransectPath
        }
        return _routeMappingPhotoCapturePolyline()
    }

    function _routeMappingPhotoProgressPath() {
        var capturePath = _routeMappingPhotoCapturePolyline()
        if (capturePath && capturePath.length >= 2) {
            return capturePath
        }
        return _routeMappingTriggerPath()
    }

    function routeMappingCoordinateAtDistanceAlongPath(distanceAlongPath) {
        var path = _routeMappingPhotoProgressPath()
        if (!path || path.length === 0) {
            return QtPositioning.coordinate()
        }
        if (distanceAlongPath <= 0 || path.length < 2) {
            return path[0]
        }
        var slice = _slicePathFromStart(path, distanceAlongPath)
        return slice.length > 0 ? slice[slice.length - 1] : path[0]
    }

    function _routeMappingPhotoCapturePolyline() {
        var points = routeMappingPhotoCaptureTransectPoints
        if (points && points.length >= 2) {
            var path = []
            for (var i = 0; i + 1 < points.length; i += 2) {
                if (points[i] && points[i].isValid && points[i + 1] && points[i + 1].isValid) {
                    path.push(points[i])
                    path.push(points[i + 1])
                }
            }
            if (path.length >= 2) {
                return path
            }
        }
        return routeMappingTransectPath
    }

    function routeMappingPhotoCapturePathLength() {
        var path = _routeMappingPhotoProgressPath()
        if (!path || path.length < 2) {
            return 0
        }
        return _pathLength(path)
    }

    function routeMappingDistanceAlongPath(coord) {
        var path = _routeMappingPhotoProgressPath()
        if (!path || path.length < 2 || !coord || !coord.isValid) {
            return -1
        }
        return _distanceAlongTransect(path, coord)
    }

    function routeMappingPhotoCaptureInfo(coord) {
        var points = routeMappingPhotoCaptureTransectPoints
        if (!points || points.length < 2 || !coord || !coord.isValid) {
            return {
                valid: false,
                segmentIndex: -1,
                distanceToSegment: Number.MAX_VALUE,
                alongSegment: 0,
                segmentLength: 0,
                heading: routeMappingEntryHeading
            }
        }

        var bestInfo = null
        for (var i = 0; i + 1 < points.length; i += 2) {
            var segmentStart = points[i]
            var segmentEnd = points[i + 1]
            if (!segmentStart || !segmentStart.isValid
                    || !segmentEnd || !segmentEnd.isValid) {
                continue
            }

            var projected = _projectPointOnSegment(coord, segmentStart, segmentEnd)
            var distanceToSegment = coord.distanceTo(projected)
            if (!bestInfo || distanceToSegment < bestInfo.distanceToSegment) {
                bestInfo = {
                    valid: true,
                    segmentIndex: Math.floor(i / 2),
                    distanceToSegment: distanceToSegment,
                    alongSegment: segmentStart.distanceTo(projected),
                    segmentLength: segmentStart.distanceTo(segmentEnd),
                    heading: segmentStart.azimuthTo(segmentEnd),
                    startCoordinate: segmentStart,
                    endCoordinate: segmentEnd,
                    projectedCoordinate: projected
                }
            }
        }

        return bestInfo ? bestInfo : {
            valid: false,
            segmentIndex: -1,
            distanceToSegment: Number.MAX_VALUE,
            alongSegment: 0,
            segmentLength: 0,
            heading: routeMappingEntryHeading
        }
    }

    function _photoFootprintPixels(coord, meters, azimuth) {
        if (!coord || !coord.isValid || !meters || meters <= 0) {
            return ScreenTools.defaultFontPixelHeight * 2
        }

        var halfDistance = meters / 2
        var startCoord = coord.atDistanceAndAzimuth(-halfDistance, azimuth)
        var endCoord = coord.atDistanceAndAzimuth(halfDistance, azimuth)
        var startPoint = fromCoordinate(startCoord, false)
        var endPoint = fromCoordinate(endCoord, false)
        var dx = endPoint.x - startPoint.x
        var dy = endPoint.y - startPoint.y
        var pixelDistance = Math.sqrt(dx * dx + dy * dy)
        return Math.max(8, Math.min(600, pixelDistance))
    }

    function _slicePathFromStart(path, endDistance) {
        if (path.length < 2 || endDistance <= 0) {
            return path.length >= 1 ? [path[0]] : []
        }

        var accumulated = 0
        var result = [path[0]]
        for (var i = 1; i < path.length; i++) {
            var segLen = path[i - 1].distanceTo(path[i])
            if (accumulated + segLen <= endDistance + 0.01) {
                result.push(path[i])
                accumulated += segLen
            } else {
                var remain = endDistance - accumulated
                if (remain > 0.5) {
                    result.push(path[i - 1].atDistanceAndAzimuth(remain, path[i - 1].azimuthTo(path[i])))
                }
                break
            }
        }
        return result
    }

    function _slicePathFromDistance(path, startDistance) {
        if (path.length < 2 || startDistance <= 0) {
            return path.slice()
        }

        var accumulated = 0
        var result = []
        for (var i = 1; i < path.length; i++) {
            var segLen = path[i - 1].distanceTo(path[i])
            if (accumulated + segLen <= startDistance) {
                accumulated += segLen
                continue
            }

            if (result.length === 0) {
                var intoSeg = startDistance - accumulated
                if (intoSeg > 0.5) {
                    result.push(path[i - 1].atDistanceAndAzimuth(intoSeg, path[i - 1].azimuthTo(path[i])))
                } else {
                    result.push(path[i - 1])
                }
            }
            result.push(path[i])
        }

        return result.length > 0 ? result : (path.length > 0 ? [path[path.length - 1]] : [])
    }

    function _slicePathBetween(path, startDistance, endDistance) {
        return _slicePathFromStart(_slicePathFromDistance(path, startDistance), endDistance - startDistance)
    }

    function _buildCompletedGradientSegments(path) {
        if (!path || path.length < 2) {
            return []
        }

        var totalLen = _pathLength(path)
        if (totalLen < 1) {
            return []
        }

        var steps = _routeCompletedGradientColors.length
        var segments = []
        for (var s = 0; s < steps; s++) {
            var startD = (s / steps) * totalLen
            var endD = ((s + 1) / steps) * totalLen
            var segPath = _slicePathBetween(path, startD, endD)
            if (segPath.length >= 2) {
                segments.push({
                              path: segPath,
                              color: _routeCompletedGradientColors[s]
                              })
            }
        }
        return segments
    }

    function _copyPath(path) {
        var result = []
        if (!path) {
            return result
        }
        for (var i = 0; i < path.length; i++) {
            result.push(path[i])
        }
        return result
    }

    function _updateRouteMappingCoverage() {
        var fullPath = routeMappingTransectPath
        if (!fullPath || fullPath.length < 2) {
            _routeMappingRemainingTransectPath = []
            _routeMappingCompletedGradientSegments = []
            return
        }

        // Always paint the full frozen survey geometry. Progress is shown only
        // via the covered-distance cyan gradient (and the red trajectory) —
        // never by regenerating, rotating, or truncating the yellow plan.
        _routeMappingRemainingTransectPath = _copyPath(fullPath)

        if (_activeVehicle && _activeVehicle.flying
                && _activeVehicle.coordinate && _activeVehicle.coordinate.isValid) {
            var alongPath = _distanceAlongTransect(fullPath, _activeVehicle.coordinate)
            if (alongPath >= 0) {
                _routeMappingCoveredDistance = Math.max(_routeMappingCoveredDistance, alongPath)
            }
        }

        if (_routeMappingCoveredDistance <= 0) {
            _routeMappingCompletedGradientSegments = []
            return
        }

        var completedPath = _slicePathFromStart(fullPath, _routeMappingCoveredDistance)
        _routeMappingCompletedGradientSegments = _buildCompletedGradientSegments(completedPath)
    }

    function resetRouteMappingProgress() {
        _routeMappingCoveredDistance = 0
        _routeMappingRemainingTransectPath = []
        _routeMappingCompletedGradientSegments = []
    }

    Connections {
        target: _activeVehicle
        ignoreUnknownSignals: true

        function onCoordinateChanged() {
            _root._updateRouteMappingCoverage()
        }

        function onFlyingChanged() {
            _root._updateRouteMappingCoverage()
        }

        function onArmedChanged(armed) {
            // A new arm starts a new mapping run. Camera captures are reset by
            // Vehicle at the same transition, so route and area must reset too.
            if (armed && !_activeVehicle.flying) {
                _root.resetRouteMappingProgress()
            }
            _root._updateRouteMappingCoverage()
        }
    }

    Connections {
        target: QGroundControl.multiVehicleManager
        function onActiveVehicleChanged() {
            _root._routeMappingCoveredDistance = 0
            _root._updateRouteMappingCoverage()
        }
    }

    readonly property int _layerMission:        1
    readonly property int _layerFence:          2
    readonly property int _layerRally:          3
    readonly property int _decimalPlaces:       8

    // This is the center rectangle of the map which is not obscured by tools
    // Used by GeoFenceEditor and QGCMapPolygonVisuals to position tools  
    property real _leftToolWidth:   planEditMode ? ScreenTools.defaultFontPixelWidth * 30 : 0  // Left panel (settings) width in plan edit mode
    property real _rightToolWidth:  planEditMode ? ScreenTools.defaultFontPixelWidth * 10 : 0  // Right panel (floating toolbar) width in plan edit mode
    property real _margin:          ScreenTools.defaultFontPixelWidth
    property rect centerViewport:   Qt.rect(_leftToolWidth + _margin, 
                                            ScreenTools.toolbarHeight + _margin, 
                                            width - _leftToolWidth - _rightToolWidth - (_margin * 2), 
                                            height - ScreenTools.toolbarHeight - (_margin * 2))

    signal waypointAdded(var coordinate)
    signal rallyPointAdded(var coordinate)

    QGCPalette { id: planEditPal }

    function _adjustMapZoomForPipMode() {
        _saveZoomLevelSetting = false
        if (pipMode) {
            if (QGroundControl.flightMapZoom > 3) {
                zoomLevel = QGroundControl.flightMapZoom - 3
            }
        } else {
            zoomLevel = QGroundControl.flightMapZoom
        }
        _saveZoomLevelSetting = true
    }

    onPipModeChanged: _adjustMapZoomForPipMode()

    onVisibleChanged: {
        if (visible) {
            // Synchronize center position with Plan View
            center = QGroundControl.flightMapPosition
            _updateRouteMappingCoverage()
        }
    }

    onZoomLevelChanged: {
        if (_saveZoomLevelSetting) {
            QGroundControl.flightMapZoom = _root.zoomLevel
        }
    }
    onCenterChanged: {
        QGroundControl.flightMapPosition = _root.center
    }

    // We track whether the user has panned or not to correctly handle automatic map positioning
    onMapPanStart:  _disableVehicleTracking = true
    onMapPanStop:   panRecenterTimer.restart()

    function pointInRect(point, rect) {
        return point.x > rect.x &&
                point.x < rect.x + rect.width &&
                point.y > rect.y &&
                point.y < rect.y + rect.height;
    }

    property real _animatedLatitudeStart
    property real _animatedLatitudeStop
    property real _animatedLongitudeStart
    property real _animatedLongitudeStop
    property real animatedLatitude
    property real animatedLongitude

    onAnimatedLatitudeChanged: _root.center = QtPositioning.coordinate(animatedLatitude, animatedLongitude)
    onAnimatedLongitudeChanged: _root.center = QtPositioning.coordinate(animatedLatitude, animatedLongitude)

    NumberAnimation on animatedLatitude { id: animateLat; from: _animatedLatitudeStart; to: _animatedLatitudeStop; duration: 1000 }
    NumberAnimation on animatedLongitude { id: animateLong; from: _animatedLongitudeStart; to: _animatedLongitudeStop; duration: 1000 }

    function animatedMapRecenter(fromCoord, toCoord) {
        _animatedLatitudeStart = fromCoord.latitude
        _animatedLongitudeStart = fromCoord.longitude
        _animatedLatitudeStop = toCoord.latitude
        _animatedLongitudeStop = toCoord.longitude
        animateLat.start()
        animateLong.start()
    }

    // returns the rectangle formed by the four center insets
    // used for checking if vehicle is under ui, and as a target for recentering the view
    function _insetCenterRect() {
        return Qt.rect(toolInsets.leftEdgeCenterInset,
                       toolInsets.topEdgeCenterInset,
                       _root.width - toolInsets.leftEdgeCenterInset - toolInsets.rightEdgeCenterInset,
                       _root.height - toolInsets.topEdgeCenterInset - toolInsets.bottomEdgeCenterInset)
    }

    // returns the four rectangles formed by the 8 corner insets
    // used for detecting if the vehicle has flown under the instrument panel, virtual joystick etc
    function _insetCornerRects() {
        var rects = {
        "topleft":      Qt.rect(0,0,
                               toolInsets.leftEdgeTopInset,
                               toolInsets.topEdgeLeftInset),
        "topright":     Qt.rect(_root.width-toolInsets.rightEdgeTopInset,0,
                               toolInsets.rightEdgeTopInset,
                               toolInsets.topEdgeRightInset),
        "bottomleft":   Qt.rect(0,_root.height-toolInsets.bottomEdgeLeftInset,
                               toolInsets.leftEdgeBottomInset,
                               toolInsets.bottomEdgeLeftInset),
        "bottomright":  Qt.rect(_root.width-toolInsets.rightEdgeBottomInset,_root.height-toolInsets.bottomEdgeRightInset,
                               toolInsets.rightEdgeBottomInset,
                               toolInsets.bottomEdgeRightInset)}
        return rects
    }

    function recenterNeeded() {
        var vehiclePoint = _root.fromCoordinate(_activeVehicleCoordinate, false /* clipToViewport */)
        var centerRect = _insetCenterRect()
        //return !pointInRect(vehiclePoint,insetRect)

        // If we are outside the center inset rectangle, recenter
        if(!pointInRect(vehiclePoint, centerRect)){
            return true
        }

        // if we are inside the center inset rectangle
        // then additionally check if we are underneath one of the corner inset rectangles
        var cornerRects = _insetCornerRects()
        if(pointInRect(vehiclePoint, cornerRects["topleft"])){
            return true
        } else if(pointInRect(vehiclePoint, cornerRects["topright"])){
            return true
        } else if(pointInRect(vehiclePoint, cornerRects["bottomleft"])){
            return true
        } else if(pointInRect(vehiclePoint, cornerRects["bottomright"])){
            return true
        }

        // if we are inside the center inset rectangle, and not under any corner elements
        return false
    }

    function updateMapToVehiclePosition() {
        if (animateLat.running || animateLong.running) {
            return
        }
        // We let FlightMap handle first vehicle position
        if (!_keepMapCenteredOnVehicle && firstVehiclePositionReceived && _activeVehicleCoordinate.isValid && !_disableVehicleTracking && !planEditMode) {
            if (_keepVehicleCentered) {
                _root.center = _activeVehicleCoordinate
            } else {
                if (firstVehiclePositionReceived && recenterNeeded()) {
                    // Move the map such that the vehicle is centered within the inset area
                    var vehiclePoint = _root.fromCoordinate(_activeVehicleCoordinate, false /* clipToViewport */)
                    var centerInsetRect = _insetCenterRect()
                    var centerInsetPoint = Qt.point(centerInsetRect.x + centerInsetRect.width / 2, centerInsetRect.y + centerInsetRect.height / 2)
                    var centerOffset = Qt.point((_root.width / 2) - centerInsetPoint.x, (_root.height / 2) - centerInsetPoint.y)
                    var vehicleOffsetPoint = Qt.point(vehiclePoint.x + centerOffset.x, vehiclePoint.y + centerOffset.y)
                    var vehicleOffsetCoord = _root.toCoordinate(vehicleOffsetPoint, false /* clipToViewport */)
                    animatedMapRecenter(_root.center, vehicleOffsetCoord)
                }
            }
        }
    }

    on_ActiveVehicleCoordinateChanged: {
        if (_keepMapCenteredOnVehicle && _activeVehicleCoordinate.isValid && !_disableVehicleTracking && !planEditMode) {
            _root.center = _activeVehicleCoordinate
        }
    }

    PipState {
        id:         _pipState
        pipView:    _root.pipView
        isDark:     _isFullWindowItemDark
    }

    Timer {
        id:         panRecenterTimer
        interval:   10000
        running:    false
        onTriggered: {
            _disableVehicleTracking = false
            updateMapToVehiclePosition()
        }
    }

    Timer {
        interval:       500
        running:        true
        repeat:         true
        onTriggered:    updateMapToVehiclePosition()
    }

    QGCMapPalette { id: mapPal; lightColors: isSatelliteMap }

    Connections {
        target:                 _missionController
        ignoreUnknownSignals:   true
        function onNewItemsFromVehicle() {
            var visualItems = _missionController.visualItems
            if (visualItems && visualItems.count !== 1) {
                mapFitFunctions.fitMapViewportToMissionItems()
                firstVehiclePositionReceived = true
            }
        }
    }

    MapFitFunctions {
        id:                         mapFitFunctions // The name for this id cannot be changed without breaking references outside of this code. Beware!
        map:                        _root
        usePlannedHomePosition:     false
        planMasterController:       _planMasterController
    }

    ObstacleDistanceOverlayMap {
        id: obstacleDistance
        showText: !pipMode
    }

    // NodeODM orthomosaic. Its on-screen dimensions are recomputed from the
    // GeoTIFF's WGS84 bounds, so it remains geographically aligned at every
    // map zoom instead of behaving like a fixed-size image.
    MapQuickItem {
        id: routeMappingOrthophotoOverlay
        coordinate: routeMappingOrthophotoNorthWest
        anchorPoint.x: 0
        anchorPoint.y: 0
        visible: routeMappingOrthophotoReady
                 && routeMappingOrthophotoNorthWest
                 && routeMappingOrthophotoNorthWest.isValid
                 && routeMappingOrthophotoSouthEast
                 && routeMappingOrthophotoSouthEast.isValid
        z: QGroundControl.zOrderWaypointLines - 1

        sourceItem: Image {
            readonly property real _mapZoomDependency: _root.zoomLevel
            readonly property point _northWestPoint: {
                var unused = _mapZoomDependency
                return _root.fromCoordinate(routeMappingOrthophotoNorthWest, false)
            }
            readonly property point _southEastPoint: {
                var unused = _mapZoomDependency
                return _root.fromCoordinate(routeMappingOrthophotoSouthEast, false)
            }

            width: Math.max(1, Math.abs(_southEastPoint.x - _northWestPoint.x))
            height: Math.max(1, Math.abs(_southEastPoint.y - _northWestPoint.y))
            source: routeMappingOrthophotoUrl
            fillMode: Image.Stretch
            asynchronous: true
            cache: false
            smooth: true
            mipmap: true
            opacity: 0.82
        }
    }

    // Add trajectory lines to the map
    MapPolyline {
        id:         trajectoryPolyline
        line.width: 3
        line.color: "red"
        z:          QGroundControl.zOrderTrajectoryLines
        visible:    !pipMode

        Connections {
            target:                 QGroundControl.multiVehicleManager
            function onActiveVehicleChanged(activeVehicle) {
                trajectoryPolyline.path = _activeVehicle ? _activeVehicle.trajectoryPoints.list() : []
            }
        }

        Connections {
            target:                             _activeVehicle ? _activeVehicle.trajectoryPoints : null
            function onPointAdded(coordinate) { trajectoryPolyline.addCoordinate(coordinate) }
            function onUpdateLastPoint(coordinate) { trajectoryPolyline.replaceCoordinate(trajectoryPolyline.pathLength() - 1, coordinate) }
            function onPointsCleared() { trajectoryPolyline.path = [] }
        }
    }

    // Add the vehicles to the map
    MapItemView {
        model: QGroundControl.multiVehicleManager.vehicles
        delegate: VehicleMapItem {
            vehicle:        object
            coordinate:     object.coordinate
            map:            _root
            size:           pipMode ? ScreenTools.defaultFontPixelHeight : ScreenTools.defaultFontPixelHeight * 3
            z:              QGroundControl.zOrderVehicles
        }
    }
    // Add distance sensor view
    MapItemView{
        model: QGroundControl.multiVehicleManager.vehicles
        delegate: ProximityRadarMapView {
            vehicle:        object
            coordinate:     object.coordinate
            map:            _root
            z:              QGroundControl.zOrderVehicles
        }
    }
    // Add ADSB vehicles to the map
    MapItemView {
        model: QGroundControl.adsbVehicleManager.adsbVehicles
        delegate: VehicleMapItem {
            coordinate:     object.coordinate
            altitude:       object.altitude
            callsign:       object.callsign
            heading:        object.heading
            alert:          object.alert
            map:            _root
            size:           pipMode ? ScreenTools.defaultFontPixelHeight : ScreenTools.defaultFontPixelHeight * 2.5
            z:              QGroundControl.zOrderVehicles
        }
    }

    // Add the items associated with each vehicles flight plan to the map
    Repeater {
        model: QGroundControl.multiVehicleManager.vehicles

        PlanMapItems {
            map:                    _root
            largeMapView:           !pipMode
            planMasterController:   masterController
            vehicle:                _vehicle
            routeMappingOverlayActive: routeMappingTransectPath
                                       && routeMappingTransectPath.length >= 2
            hideMissionVisuals: hideVehicleMissionForUnuploadedRoute

            property var _vehicle: object

            PlanMasterController {
                id: masterController
                Component.onCompleted: startStaticActiveVehicle(object)
            }
        }
    }

    // Allow custom builds to add map items
    CustomMapItems {
        map:            _root
        largeMapView:   !pipMode
    }

    GeoFenceMapVisuals {
        map:                    _root
        myGeoFenceController:   _geoFenceController
        interactive:            false
        planView:               false
        homePosition:           _activeVehicle && _activeVehicle.homePosition.isValid ? _activeVehicle.homePosition :  QtPositioning.coordinate()
    }

    // Rally points on map
    MapItemView {
        model: _rallyPointController.points

        delegate: MapQuickItem {
            id:             itemIndicator
            anchorPoint.x:  sourceItem.anchorPointX
            anchorPoint.y:  sourceItem.anchorPointY
            coordinate:     object.coordinate
            z:              QGroundControl.zOrderMapItems

            sourceItem: MissionItemIndexLabel {
                id:         itemIndexLabel
                label:      qsTr("R", "rally point map item label")
            }
        }
    }

    // Camera trigger points — hidden; Route Mapping uses QGC-calculated triggers + Pi SCP.
    MapItemView {
        model: 0
        visible: false

        delegate: CameraTriggerIndicator {
            coordinate:     object.coordinate
            z:              QGroundControl.zOrderTopMost
        }
    }

    // GoTo Location forward flight circle visuals
    QGCMapCircleVisuals {
        id:                 fwdFlightGotoMapCircle
        mapControl:         parent
        mapCircle:          _fwdFlightGotoMapCircle
        radiusLabelVisible: true
        visible:            gotoLocationItem.visible && _activeVehicle &&
                            _activeVehicle.inFwdFlight &&
                            !_activeVehicle.orbitActive

        property alias coordinate: _fwdFlightGotoMapCircle.center
        property alias radius: _fwdFlightGotoMapCircle.radius
        property alias clockwiseRotation: _fwdFlightGotoMapCircle.clockwiseRotation

        Component.onCompleted: {
            // Only allow editing the radius, not the position
            centerDragHandleVisible = false

            globals.guidedControllerFlyView.fwdFlightGotoMapCircle = this
        }

        Binding {
            target: _fwdFlightGotoMapCircle
            property: "center"
            value: gotoLocationItem.coordinate
        }

        function startLoiterRadiusEdit() {
            _fwdFlightGotoMapCircle.interactive = true
        }

        // Called when loiter edit is confirmed
        function actionConfirmed() {
            _fwdFlightGotoMapCircle.interactive = false
            _fwdFlightGotoMapCircle._commitRadius()
        }

        // Called when loiter edit is cancelled
        function actionCancelled() {
            _fwdFlightGotoMapCircle.interactive = false
            _fwdFlightGotoMapCircle._restoreRadius()
        }

        QGCMapCircle {
            id:                 _fwdFlightGotoMapCircle
            interactive:        false
            showRotation:       true
            clockwiseRotation:  true

            property real _defaultLoiterRadius: _flyViewSettings.forwardFlightGoToLocationLoiterRad.value
            property real _committedRadius;

            onCenterChanged: {
                radius.rawValue = _defaultLoiterRadius
                // Don't commit the radius in case this operation is undone
            }

            Component.onCompleted: {
                radius.rawValue = _defaultLoiterRadius
                _commitRadius()
            }

            function _commitRadius() {
                _committedRadius = radius.rawValue
            }

            function _restoreRadius() {
                radius.rawValue = _committedRadius
            }
        }
    }

    // GoTo Location visuals
    MapQuickItem {
        id:             gotoLocationItem
        visible:        false
        z:              QGroundControl.zOrderMapItems
        anchorPoint.x:  sourceItem.anchorPointX
        anchorPoint.y:  sourceItem.anchorPointY
        sourceItem: MissionItemIndexLabel {
            checked:    true
            index:      -1
            label:      qsTr("Go here", "Go to location waypoint")
        }

        property bool inGotoFlightMode: _activeVehicle ? _activeVehicle.flightMode === _activeVehicle.gotoFlightMode : false

        property var _committedCoordinate: null

        onInGotoFlightModeChanged: {
            if (!inGotoFlightMode && gotoLocationItem.visible) {
                // Hide goto indicator when vehicle falls out of guided mode
                hide()
            }
        }

        function show(coord) {
            gotoLocationItem.coordinate = coord
            gotoLocationItem.visible = true
        }

        function hide() {
            gotoLocationItem.visible = false
        }

        function actionConfirmed() {
            _commitCoordinate()

            // Commit the new radius which possibly changed
            fwdFlightGotoMapCircle.actionConfirmed()

            // We leave the indicator visible. The handling for onInGuidedModeChanged will hide it.
        }

        function actionCancelled() {
            _restoreCoordinate()

            // Also restore the loiter radius
            fwdFlightGotoMapCircle.actionCancelled()
        }

        function _commitCoordinate() {
            // Must deep copy
            _committedCoordinate = QtPositioning.coordinate(
                coordinate.latitude,
                coordinate.longitude
            );
        }

        function _restoreCoordinate() {
            if (_committedCoordinate) {
                coordinate = _committedCoordinate
            } else {
                hide()
            }
        }
    }

    // Orbit editing visuals
    QGCMapCircleVisuals {
        id:             orbitMapCircle
        mapControl:     parent
        mapCircle:      _mapCircle
        visible:        false

        property alias center:              _mapCircle.center
        property alias clockwiseRotation:   _mapCircle.clockwiseRotation
        readonly property real defaultRadius: 30

        Connections {
            target: QGroundControl.multiVehicleManager
            function onActiveVehicleChanged(activeVehicle) {
                if (!activeVehicle) {
                    orbitMapCircle.visible = false
                }
            }
        }

        function show(coord) {
            _mapCircle.radius.rawValue = defaultRadius
            orbitMapCircle.center = coord
            orbitMapCircle.visible = true
        }

        function hide() {
            orbitMapCircle.visible = false
        }

        function actionConfirmed() {
            // Live orbit status is handled by telemetry so we hide here and telemetry will show again.
            hide()
        }

        function actionCancelled() {
            hide()
        }

        function radius() {
            return _mapCircle.radius.rawValue
        }

        Component.onCompleted: globals.guidedControllerFlyView.orbitMapCircle = orbitMapCircle

        QGCMapCircle {
            id:                 _mapCircle
            interactive:        true
            radius.rawValue:    30
            showRotation:       true
            clockwiseRotation:  true
        }
    }

    // ROI Location visuals
    MapQuickItem {
        id:             roiLocationItem
        visible:        _activeVehicle && _activeVehicle.isROIEnabled
        z:              QGroundControl.zOrderMapItems
        anchorPoint.x:  sourceItem.anchorPointX
        anchorPoint.y:  sourceItem.anchorPointY

        Connections {
            target: _activeVehicle
            function onRoiCoordChanged(centerCoord) {
                roiLocationItem.show(centerCoord)
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: (position) => {
                position = Qt.point(position.x, position.y)
                var clickCoord = _root.toCoordinate(position, false /* clipToViewPort */)
                // For some strange reason using mainWindow in mapToItem doesn't work, so we use globals.parent instead which also gets us mainWindow
                position = mapToItem(globals.parent, position)
                var dropPanel = roiEditDropPanelComponent.createObject(mainWindow, { clickRect: Qt.rect(position.x, position.y, 0, 0) })
                dropPanel.open()
            }
        }

        sourceItem: MissionItemIndexLabel {
            checked:    true
            index:      -1
            label:      qsTr("ROI here", "Make this a Region Of Interest")
        }

        //-- Visibilty controlled by actual state
        function show(coord) {
            roiLocationItem.coordinate = coord
        }
    }

    // Orbit telemetry visuals
    QGCMapCircleVisuals {
        id:             orbitTelemetryCircle
        mapControl:     parent
        mapCircle:      _activeVehicle ? _activeVehicle.orbitMapCircle : null
        visible:        _activeVehicle ? _activeVehicle.orbitActive : false
    }

    MapQuickItem {
        id:             orbitCenterIndicator
        anchorPoint.x:  sourceItem.anchorPointX
        anchorPoint.y:  sourceItem.anchorPointY
        coordinate:     _activeVehicle ? _activeVehicle.orbitMapCircle.center : QtPositioning.coordinate()
        visible:        orbitTelemetryCircle.visible && !gotoLocationItem.visible

        sourceItem: MissionItemIndexLabel {
            checked:    true
            index:      -1
            label:      qsTr("Orbit", "Orbit waypoint")
        }
    }

    Component {
        id: roiEditPositionDialogComponent

        EditPositionDialog {
            title:                  qsTr("Edit ROI Position")
            coordinate:             roiLocationItem.coordinate
            onCoordinateChanged: {
                roiLocationItem.coordinate = coordinate
                _activeVehicle.guidedModeROI(coordinate)
            }
        }
    }

    Component {
        id: roiEditDropPanelComponent

        DropPanel {
            id: roiEditDropPanel

            sourceComponent: Component {
                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelWidth / 2

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Cancel ROI")
                        onClicked: {
                            _activeVehicle.stopGuidedModeROI()
                            roiEditDropPanel.close()
                        }
                    }

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Edit Position")
                        onClicked: {
                            roiEditPositionDialogComponent.createObject(mainWindow, { showSetPositionFromVehicle: false }).open()
                            roiEditDropPanel.close()
                        }
                    }
                }
            }
        }
    }

    Component {
        id: mapClickDropPanelComponent

        DropPanel {
            id: mapClickDropPanel

            property var mapClickCoord

            Connections {
                target: mainWindow

                function onFlyViewToolbarVisibleChanged() {
                    if (!mainWindow.flyViewToolbarVisible) {
                        mapClickDropPanel.close()
                    }
                }
            }

            sourceComponent: Component {
                ColumnLayout {
                    width:   ScreenTools.defaultFontPixelWidth * 23
                    spacing: ScreenTools.defaultFontPixelHeight * 0.4

                    readonly property color _accentGreen:  "#00a651"
                    readonly property color _primaryText:  "#303030"
                    readonly property color _mutedText:    "#707070"
                    readonly property real  _buttonRadius: ScreenTools.defaultFontPixelHeight * 0.36

                    RowLayout {
                        Layout.fillWidth: true
                        spacing:          ScreenTools.defaultFontPixelWidth * 0.8

                        Rectangle {
                            Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.9
                            Layout.preferredHeight: Layout.preferredWidth
                            radius:                 ScreenTools.defaultFontPixelHeight * 0.48
                            color:                  "#e7f6ee"

                            QGCColoredImage {
                                anchors.centerIn: parent
                                width:            parent.width * 0.48
                                height:           width
                                source:           "qrc:/InstrumentValueIcons/pin.svg"
                                color:            _accentGreen
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing:          0

                            QGCLabel {
                                Layout.fillWidth: true
                                text:             qsTr("Map location")
                                color:            _primaryText
                                font.weight:      Font.DemiBold
                            }

                            QGCLabel {
                                Layout.fillWidth: true
                                text:             qsTr("Choose an action")
                                color:            _mutedText
                                font.pointSize:   ScreenTools.smallFontPointSize
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth:       true
                        Layout.preferredHeight: coordinateGrid.implicitHeight
                                                + ScreenTools.defaultFontPixelHeight * 0.8
                        radius:                 _buttonRadius
                        color:                  "#f2f3f2"
                        border.width:           1
                        border.color:           "#dedede"

                        GridLayout {
                            id:              coordinateGrid
                            anchors.fill:    parent
                            anchors.margins: ScreenTools.defaultFontPixelWidth * 0.8
                            columns:         2
                            rowSpacing:      ScreenTools.defaultFontPixelHeight * 0.08
                            columnSpacing:   ScreenTools.defaultFontPixelWidth

                            QGCLabel {
                                text:           qsTr("Latitude")
                                color:          _mutedText
                                font.pointSize: ScreenTools.smallFontPointSize
                            }

                            QGCLabel {
                                Layout.fillWidth:    true
                                text:                mapClickCoord.latitude.toFixed(6)
                                color:               _primaryText
                                font.weight:         Font.Medium
                                horizontalAlignment: Text.AlignRight
                            }

                            QGCLabel {
                                text:           qsTr("Longitude")
                                color:          _mutedText
                                font.pointSize: ScreenTools.smallFontPointSize
                            }

                            QGCLabel {
                                Layout.fillWidth:    true
                                text:                mapClickCoord.longitude.toFixed(6)
                                color:               _primaryText
                                font.weight:         Font.Medium
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Go to location")
                        lightStyle:         true
                        compact:            true
                        heightFactor:       0.28
                        backRadius:         _buttonRadius
                        visible:            globals.guidedControllerFlyView.showGotoLocation
                        onClicked: {
                            mapClickDropPanel.close()
                            gotoLocationItem.show(mapClickCoord)

                            if ((_activeVehicle.flightMode == _activeVehicle.gotoFlightMode) && !_flyViewSettings.goToLocationRequiresConfirmInGuided.value) {
                                globals.guidedControllerFlyView.executeAction(globals.guidedControllerFlyView.actionGoto, mapClickCoord, gotoLocationItem)
                                gotoLocationItem.actionConfirmed() // Still need to call this to commit the new coordinate and radius
                            } else {
                                globals.guidedControllerFlyView.confirmAction(globals.guidedControllerFlyView.actionGoto, mapClickCoord, gotoLocationItem)
                            }
                        }
                    }

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Orbit at location")
                        lightStyle:         true
                        compact:            true
                        heightFactor:       0.28
                        backRadius:         _buttonRadius
                        visible:            globals.guidedControllerFlyView.showOrbit
                        onClicked: {
                            mapClickDropPanel.close()
                            orbitMapCircle.show(mapClickCoord)
                            globals.guidedControllerFlyView.confirmAction(globals.guidedControllerFlyView.actionOrbit, mapClickCoord, orbitMapCircle)
                        }
                    }

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("ROI at location")
                        lightStyle:         true
                        compact:            true
                        heightFactor:       0.28
                        backRadius:         _buttonRadius
                        visible:            globals.guidedControllerFlyView.showROI
                        onClicked: {
                            mapClickDropPanel.close()
                            globals.guidedControllerFlyView.executeAction(globals.guidedControllerFlyView.actionROI, mapClickCoord, 0, false)
                        }
                    }

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Set home here")
                        lightStyle:         true
                        compact:            true
                        heightFactor:       0.28
                        backRadius:         _buttonRadius
                        visible:            globals.guidedControllerFlyView.showSetHome
                        onClicked: {
                            mapClickDropPanel.close()
                            globals.guidedControllerFlyView.confirmAction(globals.guidedControllerFlyView.actionSetHome, mapClickCoord)
                        }
                    }

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Set Estimator Origin")
                        lightStyle:         true
                        compact:            true
                        heightFactor:       0.28
                        backRadius:         _buttonRadius
                        visible:            globals.guidedControllerFlyView.showSetEstimatorOrigin
                        onClicked: {
                            mapClickDropPanel.close()
                            globals.guidedControllerFlyView.confirmAction(globals.guidedControllerFlyView.actionSetEstimatorOrigin, mapClickCoord)
                        }
                    }

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Set Heading")
                        lightStyle:         true
                        compact:            true
                        heightFactor:       0.28
                        backRadius:         _buttonRadius
                        visible:            globals.guidedControllerFlyView.showChangeHeading
                        onClicked: {
                            mapClickDropPanel.close()
                            globals.guidedControllerFlyView.confirmAction(globals.guidedControllerFlyView.actionChangeHeading, mapClickCoord)
                        }
                    }

                }
            }
        }
    }

    onMapClicked: (position) => {
        // This action panel is owned by Fly View. Since the popup itself is
        // parented to MainWindow, explicitly prevent it from opening while a
        // mission editor or setup/tool page is active.
        if (!mainWindow.flyViewToolbarVisible) {
            return
        }

        // Plan Edit Mode click handling
        if (planEditMode) {
            // In plan edit mode, we use the center crosshair + Add button for waypoint placement
            // Map clicks only work for Rally Points (not mission waypoints)
            if (editingLayer === _layerMission) {
                return // Use Add button for waypoints, not map clicks
            }
            
            position = Qt.point(position.x, position.y)
            var clickCoord = _root.toCoordinate(position, false /* clipToViewPort */)
            clickCoord.latitude = clickCoord.latitude.toFixed(_decimalPlaces)
            clickCoord.longitude = clickCoord.longitude.toFixed(_decimalPlaces)
            clickCoord.altitude = clickCoord.altitude.toFixed(_decimalPlaces)
            
            switch (editingLayer) {
            case _layerRally:
                rallyPointAdded(clickCoord)
                break
            }
            return
        }
        
        // Standard FlyView click handling
        if (!globals.guidedControllerFlyView.guidedUIVisible &&
            (globals.guidedControllerFlyView.showGotoLocation || globals.guidedControllerFlyView.showOrbit ||
             globals.guidedControllerFlyView.showROI || globals.guidedControllerFlyView.showSetHome ||
             globals.guidedControllerFlyView.showSetEstimatorOrigin)) {

            position = Qt.point(position.x, position.y)
            var clickCoord = _root.toCoordinate(position, false /* clipToViewPort */)
            // For some strange reason using mainWindow in mapToItem doesn't work, so we use globals.parent instead which also gets us mainWindow
            position = _root.mapToItem(globals.parent, position)
            var dropPanel = mapClickDropPanelComponent.createObject(mainWindow, { mapClickCoord: clickCoord, clickRect: Qt.rect(position.x, position.y, 0, 0) })
            dropPanel.open()
        }
    }

    MapScale {
        id:                 mapScale
        anchors.margins:    _toolsMargin
        anchors.left:       parent.left
        anchors.top:        parent.top
        mapControl:         _root
        visible:            !ScreenTools.isTinyScreen && QGroundControl.corePlugin.options.flyView.showMapScale && mapControl.pipState.state === mapControl.pipState.windowState

        property real centerInset: visible ? parent.height - y : 0
    }

    // ============ PLAN EDIT MODE MAP VISUALS ============

    // Center crosshair target for waypoint/point placement (always visible in plan edit mode)
    Item {
        id: centerTarget
        anchors.centerIn: parent
        width: ScreenTools.defaultFontPixelHeight * 2.5
        height: width
        visible: planEditMode && editingLayer == _layerMission && !pipMode
        z: QGroundControl.zOrderWidgets + 10
        
        property real lineLength: width * 0.45
        property real centerGap: ScreenTools.defaultFontPixelHeight * 0.5
        
        // DJI-style crosshair with center gap
        // Vertical line - top part with shadow
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.verticalCenter
            anchors.bottomMargin: centerTarget.centerGap / 2
            width: 3
            height: centerTarget.lineLength
            color: "black"
            opacity: 0.4
            radius: 1.5
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.verticalCenter
            anchors.bottomMargin: centerTarget.centerGap / 2
            width: 2
            height: centerTarget.lineLength
            color: "white"
        }
        
        // Vertical line - bottom part with shadow
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.verticalCenter
            anchors.topMargin: centerTarget.centerGap / 2
            width: 3
            height: centerTarget.lineLength
            color: "black"
            opacity: 0.4
            radius: 1.5
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.verticalCenter
            anchors.topMargin: centerTarget.centerGap / 2
            width: 2
            height: centerTarget.lineLength
            color: "white"
        }
        
        // Horizontal line - left part with shadow
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.horizontalCenter
            anchors.rightMargin: centerTarget.centerGap / 2
            width: centerTarget.lineLength
            height: 3
            color: "black"
            opacity: 0.4
            radius: 1.5
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.horizontalCenter
            anchors.rightMargin: centerTarget.centerGap / 2
            width: centerTarget.lineLength
            height: 2
            color: "white"
        }
        
        // Horizontal line - right part with shadow
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.horizontalCenter
            anchors.leftMargin: centerTarget.centerGap / 2
            width: centerTarget.lineLength
            height: 3
            color: "black"
            opacity: 0.4
            radius: 1.5
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.horizontalCenter
            anchors.leftMargin: centerTarget.centerGap / 2
            width: centerTarget.lineLength
            height: 2
            color: "white"
        }
    }
    
    // Add waypoint button (floating button when in center target mode)
    Rectangle {
        id: addWaypointButton
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: _toolsMargin * 3
        width: ScreenTools.defaultFontPixelHeight * 6
        height: ScreenTools.defaultFontPixelHeight * 3
        radius: height / 2
        color: planEditPal.button
        border.color: planEditPal.buttonText
        border.width: 1
        visible: false  // Moved to left toolbar - was: planEditMode && centerTargetMode && editingLayer == _layerMission && !pipMode
        z: QGroundControl.zOrderWidgets + 10
        
        QGCLabel {
            anchors.centerIn: parent
            text: qsTr("+ Add Waypoint")
            color: planEditPal.buttonText
            font.pointSize: ScreenTools.mediumFontPointSize
        }
        
        QGCMouseArea {
            anchors.fill: parent
            onClicked: {
                var centerCoord = _root.center
                centerCoord.latitude = centerCoord.latitude.toFixed(_decimalPlaces)
                centerCoord.longitude = centerCoord.longitude.toFixed(_decimalPlaces)
                centerCoord.altitude = centerCoord.altitude.toFixed(_decimalPlaces)
                
                waypointAdded(centerCoord)
            }
        }
    }

    // Mission item visuals (waypoints, lines) for plan editing
    // Add the mission item visuals to the map (visible in plan edit mode)
    Repeater {
        model: planEditMode ? missionController.visualItems : undefined
        delegate: MissionItemMapVisual {
            map: _root
            opacity: editingLayer == _layerMission ? 1 : 0.5
            interactive: editingLayer == _layerMission
            vehicle: _planMasterController.controllerVehicle
            onClicked: (sequenceNumber) => { missionController.setCurrentPlanViewSeqNum(sequenceNumber, false) }
        }
    }

    // Add lines between waypoints (visible in plan edit mode)
    MissionLineView {
        showSpecialVisual: missionController ? missionController.isROIBeginCurrentItem : false
        model: planEditMode ? missionController.simpleFlightPathSegments : undefined
        opacity: editingLayer == _layerMission ? 1 : 0.5
    }

    MapPolyline {
        line.color: "white"
        line.width: 2
        path: routeMappingBoundaryPath
        visible: !planEditMode && routeMappingBoundaryPath ? routeMappingBoundaryPath.length >= 4 : false
        z: QGroundControl.zOrderWaypointLines + 3
    }

    // Frozen takeoff → survey entry connector (never regenerates mid-flight).
    MapPolyline {
        line.color: _routeRemainingColor
        line.width: 2
        path: _routeMappingTakeoffPath
        visible: !planEditMode && _routeMappingTakeoffPath.length >= 2
        z: QGroundControl.zOrderWaypointLines + 2
    }

    // Survey exit → launch return leg (RTL). Drawn in the same yellow as the
    // transit/takeoff legs so the return path is visible under the overlay.
    MapPolyline {
        line.color: _routeRemainingColor
        line.width: 2
        path: _routeMappingReturnPath
        visible: !planEditMode && _routeMappingReturnPath.length >= 2
        z: QGroundControl.zOrderWaypointLines + 2
    }

    Repeater {
        model: !planEditMode ? _routeMappingCompletedGradientSegments : []
        delegate: MapPolyline {
            line.color: modelData.color
            line.width: 3
            path: modelData.path
            visible: modelData.path.length >= 2
            z: QGroundControl.zOrderWaypointLines + 2
        }
    }

    MapPolyline {
        line.color: _routeRemainingColor
        line.width: 2
        path: _routeMappingRemainingTransectPath
        visible: !planEditMode && _routeMappingRemainingTransectPath.length >= 2
        z: QGroundControl.zOrderWaypointLines + 2
    }

    // Each native CAMERA_TRIGGER becomes a georeferenced camera footprint. It
    // scales with map zoom so successive shots form an in-progress mosaic strip.
    // Once reconstruction finishes, the single aligned orthomosaic replaces
    // these preview tiles.
    MapItemView {
        model: !_root.planEditMode && !_root.routeMappingOrthophotoReady
               ? _root.routeMappingLivePhotoModel : null

        delegate: MapQuickItem {
            id: mappingPhotoItem

            required property real photoLatitude
            required property real photoLongitude
            required property real photoAltitude
            required property real photoHeading
            required property real photoAgl
            required property real photoFootprintSide
            required property real photoFootprintFrontal
            required property int photoSequence
            required property string photoImageSource
            required property bool photoReady
            required property bool photoFetchFailed
            required property bool photoPlaceholder

            property real footprintSide: mappingPhotoItem.photoFootprintSide > 0
                                         ? mappingPhotoItem.photoFootprintSide
                                         : _root.routeMappingPhotoFootprintSide
            property real footprintFrontal: mappingPhotoItem.photoFootprintFrontal > 0
                                            ? mappingPhotoItem.photoFootprintFrontal
                                            : _root.routeMappingPhotoFootprintFrontal
            property real mapZoom: _root.zoomLevel
            property var mapCenter: _root.center
            property real mapBearing: _root.bearing

            function footprintPixels(meters, azimuth) {
                return _root._photoFootprintPixels(coordinate, meters, azimuth)
            }

            coordinate: QtPositioning.coordinate(
                            mappingPhotoItem.photoLatitude,
                            mappingPhotoItem.photoLongitude,
                            mappingPhotoItem.photoAltitude)
            anchorPoint.x: mappingPhotoTile.width / 2
            anchorPoint.y: mappingPhotoTile.height / 2
            // A photo footprint is map content, not a navigation control. Keep
            // it below the route and, critically, below the live vehicle icon.
            z: QGroundControl.zOrderWaypointLines - 1

            sourceItem: Item {
                id: mappingPhotoTile

                width: {
                    var unusedZoom = mappingPhotoItem.mapZoom
                    var unusedCenter = mappingPhotoItem.mapCenter
                    return mappingPhotoItem.footprintPixels(
                                mappingPhotoItem.footprintSide,
                                mappingPhotoItem.photoHeading + 90)
                }
                height: {
                    var unusedZoom = mappingPhotoItem.mapZoom
                    var unusedCenter = mappingPhotoItem.mapCenter
                    return mappingPhotoItem.footprintPixels(
                                mappingPhotoItem.footprintFrontal,
                                mappingPhotoItem.photoHeading)
                }

                transform: Rotation {
                    origin.x: mappingPhotoTile.width / 2
                    origin.y: mappingPhotoTile.height / 2
                    angle: mappingPhotoItem.photoHeading - mappingPhotoItem.mapBearing
                }

                Rectangle {
                    anchors.fill: parent
                    color: mappingPhotoItem.photoFetchFailed ? "#7a1f1f" : "#263238"
                    border.width: 1
                    border.color: mappingPhotoItem.photoFetchFailed
                                  ? "#ff5555"
                                  : Qt.rgba(1, 1, 1, 0.75)
                }

                Rectangle {
                    anchors.fill: parent
                    visible: mappingPhotoItem.photoImageSource.length === 0
                             && !mappingPhotoItem.photoFetchFailed
                    color: mappingPhotoItem.photoPlaceholder
                           ? Qt.rgba(0.22, 0.26, 0.30, 0.94)
                           : Qt.rgba(0.15, 0.22, 0.28, 0.92)
                    border.width: mappingPhotoItem.photoPlaceholder ? 2 : 0
                    border.color: Qt.rgba(0.43, 0.92, 0.09, 0.85)

                    QGCLabel {
                        anchors.centerIn: parent
                        visible: mappingPhotoItem.photoPlaceholder
                        text: String(mappingPhotoItem.photoSequence)
                        font.bold: true
                        font.pointSize: Math.max(
                                          ScreenTools.smallFontPointSize,
                                          Math.min(parent.width, parent.height) * 0.22)
                        color: Qt.rgba(1, 1, 1, 0.92)
                    }

                    BusyIndicator {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) * 0.45
                        height: width
                        visible: !mappingPhotoItem.photoPlaceholder
                        running: mappingPhotoItem.photoImageSource.length === 0
                    }
                }

                Image {
                    id: mappingPhotoImage
                    anchors.fill: parent
                    visible: mappingPhotoItem.photoImageSource.length > 0
                    source: mappingPhotoItem.photoImageSource
                    // Preserve the 1260x720 frame proportions. The surrounding
                    // rectangle represents the IMX708 optical footprint at AGL.
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    // MapItemView + ListModel can miss role updates; force reload when URL arrives.
                    onSourceChanged: {
                        if (source.length > 0 && status === Image.Error) {
                            var retryUrl = source
                            source = ""
                            source = retryUrl
                        }
                    }
                    // Decode only what the map can display. Loading each
                    // 4608x2592 JPEG as a full GPU texture exhausts memory and
                    // exceeds the 4096px texture limit on common QGC devices.
                    sourceSize.width: Math.max(32, Math.ceil(mappingPhotoTile.width * 2))
                    sourceSize.height: Math.max(32, Math.ceil(mappingPhotoTile.height * 2))
                    smooth: true
                    mipmap: true
                    opacity: status === Image.Ready ? 0.88 : 0
                }

                QGCLabel {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: 2
                    text: mappingPhotoItem.photoFetchFailed
                          ? qsTr("Photo %1 (failed)").arg(mappingPhotoItem.photoSequence)
                          : (mappingPhotoItem.photoPlaceholder
                             ? qsTr("Photo %1 (triggered)").arg(mappingPhotoItem.photoSequence)
                             : (mappingPhotoItem.photoImageSource.length === 0
                                ? qsTr("Photo %1 (waiting for Pi…)").arg(mappingPhotoItem.photoSequence)
                                : qsTr("Photo %1").arg(mappingPhotoItem.photoSequence)))
                    color: "white"
                    font.bold: true
                    font.pointSize: ScreenTools.smallFontPointSize
                    visible: mappingPhotoItem.photoImageSource.length === 0
                             || mappingPhotoImage.status !== Image.Ready
                             || mappingPhotoItem.photoFetchFailed
                }
            }
        }
    }

    MapQuickItem {
        coordinate: routeMappingEntryCoordinate
        anchorPoint.x: routeMappingEntryMarker.dotCenter
        anchorPoint.y: routeMappingEntryMarker.dotCenter
        visible: !planEditMode && routeMappingEntryCoordinate ? routeMappingEntryCoordinate.isValid : false
        z: QGroundControl.zOrderWaypointLines + 4

        sourceItem: Item {
            id: routeMappingEntryMarker
            readonly property real markerSize: ScreenTools.defaultFontPixelHeight * 0.85
            readonly property real dotCenter: markerSize / 2

            width: markerSize * 2.25
            height: markerSize

            transform: Rotation {
                origin.x: routeMappingEntryMarker.dotCenter
                origin.y: routeMappingEntryMarker.dotCenter
                angle: _root.routeMappingEntryHeading - _root.bearing - 90
            }

            Canvas {
                anchors.fill: parent

                onPaint: {
                    var ctx = getContext("2d")
                    var centerY = height / 2
                    var shaftStart = routeMappingEntryMarker.markerSize * 0.55
                    var arrowTip = width - 1
                    var arrowBase = width - routeMappingEntryMarker.markerSize * 0.55
                    var arrowHalfHeight = routeMappingEntryMarker.markerSize * 0.34

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
                width: routeMappingEntryMarker.markerSize
                height: width
                radius: width / 2
                color: "#19d12f"
                border.color: "white"
                border.width: 2
            }
        }
    }

    MapQuickItem {
        coordinate: routeMappingExitCoordinate
        anchorPoint.x: routeMappingExitMarker.dotCenter
        anchorPoint.y: routeMappingExitMarker.dotCenter
        visible: !planEditMode && routeMappingExitCoordinate ? routeMappingExitCoordinate.isValid : false
        z: QGroundControl.zOrderWaypointLines + 4

        sourceItem: Item {
            id: routeMappingExitMarker
            readonly property real markerSize: ScreenTools.defaultFontPixelHeight * 0.85
            readonly property real dotCenter: markerSize / 2

            width: markerSize * 2.25
            height: markerSize

            transform: Rotation {
                origin.x: routeMappingExitMarker.dotCenter
                origin.y: routeMappingExitMarker.dotCenter
                angle: _root.routeMappingExitHeading - _root.bearing - 90
            }

            Canvas {
                anchors.fill: parent

                onPaint: {
                    var ctx = getContext("2d")
                    var centerY = height / 2
                    var shaftStart = routeMappingExitMarker.markerSize * 0.55
                    var arrowTip = width - 1
                    var arrowBase = width - routeMappingExitMarker.markerSize * 0.55
                    var arrowHalfHeight = routeMappingExitMarker.markerSize * 0.34

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
                width: routeMappingExitMarker.markerSize
                height: width
                radius: width / 2
                color: "#ffc400"
                border.color: "white"
                border.width: 2
            }
        }
    }

    // Direction arrows in waypoint lines (visible in plan edit mode)
    MapItemView {
        model: planEditMode && editingLayer == _layerMission ? missionController.directionArrows : undefined

        delegate: MapLineArrow {
            fromCoord: object ? object.coordinate1 : undefined
            toCoord: object ? object.coordinate2 : undefined
            arrowPosition: 3
            z: QGroundControl.zOrderWaypointLines + 1
        }
    }

    // UI for splitting the current segment (visible in plan edit mode)
    MapQuickItem {
        id: splitSegmentItem
        anchorPoint.x: sourceItem.width / 2
        anchorPoint.y: sourceItem.height / 2
        z: QGroundControl.zOrderWaypointLines + 1
        visible: planEditMode && editingLayer == _layerMission

        sourceItem: SplitIndicator {
            onClicked: missionController.insertSimpleMissionItem(splitSegmentItem.coordinate,
                                                                   missionController.currentPlanViewVIIndex,
                                                                   true /* makeCurrentItem */)
        }

        function _updateSplitCoord() {
            if (missionController && missionController.splitSegment) {
                var distance = missionController.splitSegment.coordinate1.distanceTo(missionController.splitSegment.coordinate2)
                var azimuth = missionController.splitSegment.coordinate1.azimuthTo(missionController.splitSegment.coordinate2)
                splitSegmentItem.coordinate = missionController.splitSegment.coordinate1.atDistanceAndAzimuth(distance / 2, azimuth)
            } else {
                coordinate = QtPositioning.coordinate()
            }
        }

        Connections {
            target: missionController
            function onSplitSegmentChanged() { splitSegmentItem._updateSplitCoord() }
        }

        Connections {
            target: missionController ? missionController.splitSegment : null
            function onCoordinate1Changed() { splitSegmentItem._updateSplitCoord() }
            function onCoordinate2Changed() { splitSegmentItem._updateSplitCoord() }
        }
    }

    // GeoFence visuals for plan editing
    GeoFenceMapVisuals {
        map: _root
        myGeoFenceController: geoFenceController
        interactive: planEditMode && editingLayer == _layerFence
        homePosition: missionController ? missionController.plannedHomePosition : QtPositioning.coordinate()
        planView: planEditMode
        opacity: planEditMode && editingLayer != _layerFence ? 0.5 : 1
        visible: planEditMode
    }

    // Rally point visuals for plan editing
    RallyPointMapVisuals {
        map: _root
        myRallyPointController: rallyPointController
        interactive: planEditMode && editingLayer == _layerRally
        planView: planEditMode
        opacity: planEditMode && editingLayer != _layerRally ? 0.5 : 1
        visible: planEditMode
    }

    QGCMapPalette { id: qgcPal; lightColors: isSatelliteMap }

}
