import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Item {
    id: root

    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var _guidedController: globals.guidedControllerFlyView
    property var blurSourceItem: null
    property real _altitude: {
        if (!_activeVehicle || !_activeVehicle.altitudeRelative)
            return 0
        var v = Number(_activeVehicle.altitudeRelative.rawValue)
        return isFinite(v) ? v : 0
    }
    property real _distanceToHome: {
        if (!_activeVehicle || !_activeVehicle.distanceToHome)
            return 0
        var v = Number(_activeVehicle.distanceToHome.rawValue)
        return isFinite(v) ? v : 0
    }

    // Flow rate (L/min) — live from tank.flowRateLpm
    property real _flowRate: 0

    Connections {
        target: (root._activeVehicle && root._activeVehicle.tank) ? root._activeVehicle.tank.flowRateLpm : null
        function onRawValueChanged(value) {
            var v = Number(value)
            root._flowRate = isFinite(v) ? v : 0
        }
    }
    property real _groundSpeed: {
        if (!_activeVehicle || !_activeVehicle.groundSpeed)
            return 0
        var v = Number(_activeVehicle.groundSpeed.rawValue)
        return isFinite(v) ? v : 0
    }
    property bool _showCommandedAltitude: _guidedController && isFinite(_guidedController.commandedAltitudeMeters)
    property bool _showCommandedSpeed: _guidedController && isFinite(_guidedController.commandedSpeedMetersSecond)
    property real _displayAltitude: _showCommandedAltitude ? Number(_guidedController.commandedAltitudeMeters) : _altitude
    property real _displayGroundSpeed: _showCommandedSpeed ? Number(_guidedController.commandedSpeedMetersSecond) : _groundSpeed
    property real _heading: {
        if (!_activeVehicle || !_activeVehicle.heading)
            return 0
        var v = Number(_activeVehicle.heading.rawValue)
        return isFinite(v) ? v : 0
    }
    property real _margins: ScreenTools.defaultFontPixelWidth
    property Fact _mpcAltModeFact: paramLoader.item ? paramLoader.item.fact : null
    property Fact _cpDistFact: paramLoader.item ? paramLoader.item.cpDistFact : null
    property Fact _sprayEnFact: paramLoader.item ? paramLoader.item.sprayEnFact : null
    property Fact _sprayNozRateFact: paramLoader.item ? paramLoader.item.sprayNozRateFact : null
    property Fact _sprayPumpRateFact: paramLoader.item ? paramLoader.item.sprayPumpRateFact : null
    readonly property Fact sprayEnableFact: _sprayEnFact
    readonly property Fact sprayNozzleRateFact: _sprayNozRateFact
    readonly property Fact sprayPumpRateFact: _sprayPumpRateFact
    readonly property bool _sprayEnabled: _sprayEnFact !== null && Number(_sprayEnFact.rawValue) !== 0
    property var _pendingPlanSprayerRates: null
    property bool _obstacleAvoidanceActive: _cpDistFact ? _cpDistFact.rawValue > 0 : false
    property bool _terrainFlowIconActive: false
    property bool _paramExists: paramLoader.item ? paramLoader.item.paramExists : false
    property real _pitch: {
        if (!_activeVehicle || !_activeVehicle.pitch)
            return 0
        var v = Number(_activeVehicle.pitch.rawValue)
        return isFinite(v) ? v : 0
    }
    property real _roll: {
        if (!_activeVehicle || !_activeVehicle.roll)
            return 0
        var v = Number(_activeVehicle.roll.rawValue)
        return isFinite(v) ? v : 0
    }
    property bool _greenLoopRunning: root.visible
                                     && root._activeVehicle
                                     && root._activeVehicle.flying
                                     && !root._activeVehicle.communicationLost

    Timer {
        interval: 1000
        repeat: true
        running: root._showCommandedAltitude || root._showCommandedSpeed
        onTriggered: {
            if (root._guidedController && root._showCommandedAltitude && Math.abs(root._altitude - root._guidedController.commandedAltitudeMeters) < 0.3) {
                root._guidedController.commandedAltitudeMeters = NaN
            }
            if (root._guidedController && root._showCommandedSpeed && Math.abs(root._groundSpeed - root._guidedController.commandedSpeedMetersSecond) < 0.3) {
                root._guidedController.commandedSpeedMetersSecond = NaN
            }
        }
    }

    // Tank (kg)
    // _tankCapacityMax : fixed UI max for fill-bar percentage (20 kg)
    // _tankCurrentLevel: live value from PX4 NAMED_VALUE_FLOAT name "LC_WEIGHT"
    //                    via VehicleTankFactGroup -> activeVehicle.tank.weightKg
    property real _tankCapacityMax: 20.0
    property real _tankCurrentLevel: {
        if (!_activeVehicle || !_activeVehicle.tank || !_activeVehicle.tank.weightKg)
            return 0
        var v = Number(_activeVehicle.tank.weightKg.rawValue)
        return isFinite(v) ? v : 0
    }
    property bool _terrainFlowActive: _mpcAltModeFact ? _mpcAltModeFact.rawValue === 1 : false

    // Action buttons model for horizontal panel above bottom bar
    property var actionButtonsModel: null
    property alias obstacleAvoidanceActive: root._obstacleAvoidanceActive
    readonly property real telemetryHeight: telemetryContainer.height

    // Exposed for external anchoring (e.g., action buttons panel)
    property alias telemetryItem: telemetryContainer
    readonly property real telemetryLeftX: bottomBarRow.x + telemetryContainer.x
    readonly property real telemetryRightEdge: bottomBarRow.x + telemetryContainer.x + telemetryContainer.width
    readonly property real telemetryTopY: bottomBarRow.y + telemetryContainer.y

    // === TERRAIN FLOW INFOGRAPHIC POPUP ===
    // Expose alias for parent layer to trigger full-screen overlay
    property alias terrainFlowActive: root._terrainFlowActive

    function toggleObstacleAvoidance() {
        if (_cpDistFact) {
            var enabling = _cpDistFact.rawValue <= 0
            _cpDistFact.value = enabling ? 5 : -1
            QGroundControl.settingsManager.flyViewSettings.showObstacleDistanceOverlay.value = enabling ? 1 : 0
            console.log("Obstacle Avoidance toggle: CP_DIST=" + _cpDistFact.rawValue)
            return
        }

        if (!_activeVehicle || !_activeVehicle.objectAvoidance) {
            console.log("Obstacle Avoidance toggle FAILED: no vehicle or CP_DIST parameter")
            return
        }

        var oa = _activeVehicle.objectAvoidance
        if (oa.enabled) {
            oa.stop()
            QGroundControl.settingsManager.flyViewSettings.showObstacleDistanceOverlay.value = 0
            console.log("Obstacle Avoidance toggle: OFF")
        } else {
            oa.start(5)
            QGroundControl.settingsManager.flyViewSettings.showObstacleDistanceOverlay.value = 1
            console.log("Obstacle Avoidance toggle: ON (CP_DIST=5)")
        }
    }
    function toggleTerrainFlow() {
        if (_mpcAltModeFact) {
            var requestedActive = !_terrainFlowIconActive;
            var newValue = requestedActive ? 1 : 2;
            console.log("Terrain Flow toggle: current=" + _mpcAltModeFact.rawValue + " setting to=" + newValue);
            _mpcAltModeFact.value = newValue;
            _terrainFlowIconActive = requestedActive;
            console.log("Terrain Flow toggle: after set, rawValue=" + _mpcAltModeFact.rawValue);
        } else {
            console.log("Terrain Flow toggle FAILED:");
            console.log("  - _activeVehicle: " + (_activeVehicle ? "connected" : "not connected"));
            console.log("  - _paramExists: " + _paramExists);

            if (paramLoader.item) {
                var controller = paramLoader.item.controller;
                console.log("  - Check Comp -1: " + controller.parameterExists(-1, "MPC_ALT_MODE"));
                console.log("  - Check Comp 1: " + controller.parameterExists(1, "MPC_ALT_MODE"));
                console.log("  - Check MIS_TAKEOFF_ALT: " + controller.parameterExists(-1, "MIS_TAKEOFF_ALT"));
                console.log("  - Parameters Ready: " + (_activeVehicle && _activeVehicle.parameterManager ? _activeVehicle.parameterManager.parametersReady : "unknown"));
            }
        }
    }

    function _setEnableDisableFact(fact, enabled) {
        if (!fact)
            return

        var enumStrings = fact.enumStrings
        if (enumStrings && enumStrings.length > 0) {
            var requestedText = enabled ? "enabled" : "disabled"
            for (var index = 0; index < enumStrings.length; index++) {
                if (String(enumStrings[index]).toLowerCase().indexOf(requestedText) >= 0) {
                    fact.value = fact.enumValues[index]
                    return
                }
            }
        }
        fact.value = enabled ? 1 : 0
    }

    function setSprayerEnabled(enabled) {
        if (!_sprayEnFact)
            return

        _setEnableDisableFact(_sprayEnFact, enabled)
        if (enabled && paramLoader.item)
            paramLoader.item.requestDependentSprayFacts()
    }

    function _applyPendingPlanSprayerRates() {
        if (!_pendingPlanSprayerRates || !_sprayEnabled)
            return

        var allApplied = true
        if (isFinite(_pendingPlanSprayerRates.nozzleRate)) {
            if (_sprayNozRateFact) {
                _sprayNozRateFact.value = _pendingPlanSprayerRates.nozzleRate
            } else {
                allApplied = false
            }
        }
        if (isFinite(_pendingPlanSprayerRates.pumpRate)) {
            if (_sprayPumpRateFact) {
                _sprayPumpRateFact.value = _pendingPlanSprayerRates.pumpRate
            } else {
                allApplied = false
            }
        }

        if (allApplied)
            _pendingPlanSprayerRates = null
    }

    function applyPlanSprayerSettings(enabled, nozzleRate, pumpRate) {
        if (!_sprayEnFact)
            return

        var pendingNozzle = Number(nozzleRate)
        var pendingPump = Number(pumpRate)
        if (isFinite(pendingNozzle) || isFinite(pendingPump)) {
            _pendingPlanSprayerRates = {
                nozzleRate: isFinite(pendingNozzle) ? pendingNozzle : NaN,
                pumpRate: isFinite(pendingPump) ? pendingPump : NaN
            }
        } else {
            _pendingPlanSprayerRates = null
        }

        setSprayerEnabled(enabled)
        _applyPendingPlanSprayerRates()
    }

    function toggleSprayer() {
        setSprayerEnabled(!_sprayEnabled)
    }

    on_SprayNozRateFactChanged: _applyPendingPlanSprayerRates()
    on_SprayPumpRateFactChanged: _applyPendingPlanSprayerRates()

    Timer {
        id: pendingSprayerRatesTimer

        interval: 200
        repeat: true
        running: root._pendingPlanSprayerRates !== null && root._sprayEnabled
        onTriggered: root._applyPendingPlanSprayerRates()
    }

    implicitHeight: bottomBarRow.height + root._margins * 2
    implicitWidth: bottomBarRow.width + root._margins * 3

    // Initialize loader on startup if vehicle exists
    Component.onCompleted: {
        if (_activeVehicle) {
            paramLoader.active = true;
        }
    }

    // Reload controller when vehicle changes
    on_ActiveVehicleChanged: {
        console.log("TerrainFlow: Active vehicle changed, reloading controller...");
        _terrainFlowIconActive = false;
        paramLoader.active = false;
        paramLoader.active = true;

        if (_activeVehicle && _activeVehicle.tank && _activeVehicle.tank.flowRateLpm) {
            var v = Number(_activeVehicle.tank.flowRateLpm.rawValue)
            _flowRate = isFinite(v) ? v : 0
        } else {
            _flowRate = 0
        }
    }

    // Vehicle parameters used by the terrain, obstacle and agriculture HUD controls.
    // Use Loader to force recreation of FactPanelController when active vehicle changes.
    // This is necessary because FactPanelController binds to the active vehicle only at construction time.
    Loader {
        id: paramLoader

        active: false
        sourceComponent: paramControllerComponent

        onLoaded: {
            console.log("TerrainFlow: Controller loaded for vehicle");
        }
    }
    Component {
        id: paramControllerComponent

        Item {
            id: paramContainer

            property Fact sprayEnFact: null
            property Fact sprayNozRateFact: null
            property Fact sprayPumpRateFact: null
            property bool sprayParamsRequested: false

            // Try default component (-1) first, then try Autopilot component (1) explicitly if needed
            property Fact fact: {
                if (!paramsReady && !controller.parameterExists(-1, "MPC_ALT_MODE"))
                    return null;

                var f = controller.getParameterFact(-1, "MPC_ALT_MODE");
                if (f)
                    return f;

                // Fallback to strict component 1
                return controller.getParameterFact(1, "MPC_ALT_MODE");
            }
            property Fact cpDistFact: {
                if (!paramsReady && !controller.parameterExists(-1, "CP_DIST"))
                    return null;

                return controller.getParameterFact(-1, "CP_DIST");
            }
            property bool paramExists: fact !== null
            // Re-evaluate when parameters become ready
            property bool paramsReady: _activeVehicle && _activeVehicle.parameterManager ? _activeVehicle.parameterManager.parametersReady : false

            function lookupFact(name) {
                if (!paramsReady || !controller.parameterExists(-1, name))
                    return null
                return controller.getParameterFact(-1, name, false)
            }

            function refreshSprayFacts() {
                sprayEnFact = lookupFact("SPRAY_EN")
                sprayNozRateFact = lookupFact("SPRAY_NOZ_RATE")
                sprayPumpRateFact = lookupFact("SPRAY_PUMP_RATE")
                requestDependentSprayFacts()
            }

            // Some sprayer firmwares expose rate parameters only after SPRAY_EN
            // is enabled. Ask for those values once and refresh when they arrive.
            function requestDependentSprayFacts() {
                if (!paramsReady || !sprayEnFact || Number(sprayEnFact.rawValue) === 0
                        || sprayParamsRequested || (sprayNozRateFact && sprayPumpRateFact)) {
                    return
                }

                var missing = []
                if (!sprayNozRateFact)
                    missing.push("SPRAY_NOZ_RATE")
                if (!sprayPumpRateFact)
                    missing.push("SPRAY_PUMP_RATE")
                if (missing.length > 0) {
                    sprayParamsRequested = true
                    controller.getMissingParameters(missing)
                }
            }

            onParamsReadyChanged: {
                if (paramsReady)
                    refreshSprayFacts()
            }

            Component.onCompleted: {
                if (paramsReady)
                    refreshSprayFacts()
            }

            FactPanelController {
                id: controller

                onMissingParametersAvailable: paramContainer.refreshSprayFacts()
            }

            // Explicitly notify when rawValue changes to ensure UI updates
            Connections {
                function onRawValueChanged() {
                    console.log("TerrainFlow: Fact changed to " + fact.rawValue);
                    // Trigger property re-evaluation
                    paramLoader.item.factChanged();
                }

                ignoreUnknownSignals: true
                target: fact
            }

            Connections {
                function onRawValueChanged() {
                    console.log("Obstacle Avoidance: CP_DIST changed to " + cpDistFact.rawValue);
                    paramLoader.item.cpDistFactChanged();
                }

                ignoreUnknownSignals: true
                target: cpDistFact
            }

            Connections {
                function onRawValueChanged() {
                    paramContainer.sprayEnFactChanged()
                    paramContainer.requestDependentSprayFacts()
                }

                ignoreUnknownSignals: true
                target: sprayEnFact
            }

            Connections {
                function onRawValueChanged() {
                    paramContainer.sprayNozRateFactChanged()
                }

                ignoreUnknownSignals: true
                target: sprayNozRateFact
            }

            Connections {
                function onRawValueChanged() {
                    paramContainer.sprayPumpRateFactChanged()
                }

                ignoreUnknownSignals: true
                target: sprayPumpRateFact
            }
        }
    }
    QGCPalette {
        id: qgcPal

        colorGroupEnabled: root.enabled
    }

    // HUD glass — main ~15% tint, inner panels ~8–10% with thin white borders (reference style)
    readonly property color _glassFill:         Qt.rgba(0.12, 0.12, 0.14, 0.15)
    readonly property color _glassBorder:       Qt.rgba(1.00, 1.00, 1.00, 0.28)
    readonly property color _glassPanelFill:    Qt.rgba(0.08, 0.08, 0.10, 0.08)
    readonly property color _glassPanelBorder:  Qt.rgba(1.00, 1.00, 1.00, 0.25)
    readonly property color _glassSeparator:    Qt.rgba(1.00, 1.00, 1.00, 0.12)
    readonly property color _compassSeparator:  Qt.rgba(0.00, 0.00, 0.00, 0.55)
    readonly property color _togglePanelFill:   Qt.rgba(0.12, 0.12, 0.12, 0.78)
    readonly property color _togglePanelBorder: Qt.rgba(0.20, 0.20, 0.20, 0.65)
    readonly property color _hudGrayWhite:      Qt.rgba(0.82, 0.82, 0.82, 0.95)
    readonly property real  _glassPanelRadius:  ScreenTools.defaultFontPixelHeight * 0.5

    // Custom Background Shape
    Canvas {
        id: bgCanvas

        property real greenLoopPhase: 0
        property var mainItem: mainContainer

        // Redraw when layout changes
        property var telemetryItem: telemetryContainer

        anchors.fill: parent

        Timer {
            interval: 50
            repeat: true
            running: root._greenLoopRunning
            onTriggered: bgCanvas.greenLoopPhase = (bgCanvas.greenLoopPhase + interval / 9800) % 1
        }

        onGreenLoopPhaseChanged: requestPaint()
        Connections {
            function on_GreenLoopRunningChanged() {
                bgCanvas.requestPaint()
            }
            target: root
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();

            if (!telemetryItem || !mainItem || telemetryItem.width === 0)
                return;
            var tPos = telemetryItem.mapToItem(bgCanvas, 0, 0);
            var mPos = mainItem.mapToItem(bgCanvas, 0, 0);

            var padding = root._margins;
            var paddingTop = padding * 0; // Tight top padding per user request
            var paddingBottom = padding * 0;
            var radius = ScreenTools.defaultFontPixelHeight * 0.8; // Slightly more rounded for premium feel

            // Right section (Main) - The Anchor
            var rx = mPos.x - padding;
            var ry = mPos.y - paddingTop;
            var rw = mainItem.width + padding * 2;
            var rh = mainItem.height + paddingTop + paddingBottom;

            // Left section (Telemetry) - Robust Cutout with tight padding
            var lx = tPos.x - (padding * 1.2);
            var lw = telemetryItem.width + (padding * 2.4);

            // Calculate natural height of telemetry based on content
            var naturalLh = telemetryItem.height + (ScreenTools.defaultFontPixelHeight * 0.65) + paddingBottom;

            // Enforce MINIMUM height (25% of Main) to prevent shrinking too much
            // Enforce MAXIMUM height (Main height) to keep it a "cutout" (step down)
            var lh = Math.min(Math.max(naturalLh, rh * 0.25), rh);

            // Align Bottoms: The bar sits on the bottom edge
            var bottomY = ry + rh;
            var ly = bottomY - lh; // Calculate top Y based on height diff

            var rightRadius = rh / 2;
            var leftRadius = Math.min(ScreenTools.defaultFontPixelHeight * 0.45, lh / 2);

            ctx.fillStyle = Qt.rgba(root._glassFill.r, root._glassFill.g, root._glassFill.b, root._glassFill.a);
            ctx.strokeStyle = Qt.rgba(root._glassBorder.r, root._glassBorder.g, root._glassBorder.b, root._glassBorder.a);
            ctx.lineWidth = 1;

            var startX = lx + lw;
            var startY = ly;
            var endX = rx;
            var endY = ry;
            var stepRadius = Math.min(ScreenTools.defaultFontPixelHeight * 0.35,
                                      Math.abs(startY - endY) / 2);
            var rightCenterX = rx + rw - rightRadius;
            var rightCenterY = ry + rightRadius;

            function drawHudShape() {
                ctx.beginPath();

                // 1. Small rounded corners beside the altitude metric.
                ctx.moveTo(lx, ly + leftRadius);
                ctx.quadraticCurveTo(lx, ly, lx + leftRadius, ly);

                // 2. Top Edge (Continuous straight line to Right S-Curve start)
                ctx.lineTo(lx + lw, ly);

                // 3. Straight right-angle transition up to the tank/compass section.
                ctx.lineTo(endX - stepRadius, startY);
                ctx.quadraticCurveTo(endX, startY,
                                     endX, startY - stepRadius);
                ctx.lineTo(endX, endY + stepRadius);
                ctx.quadraticCurveTo(endX, endY,
                                     endX + stepRadius, endY);

                // 4. Straight top above the tank, with only the compass-side end rounded.
                ctx.lineTo(rightCenterX, ry);
                ctx.arc(rightCenterX, rightCenterY, rightRadius,
                        1.5 * Math.PI, 0.5 * Math.PI, false);

                // 5. Straight bottom with a small rounded altitude-side corner.
                ctx.lineTo(lx + leftRadius, bottomY);
                ctx.quadraticCurveTo(lx, bottomY,
                                     lx, bottomY - leftRadius);
                ctx.lineTo(lx, ly + leftRadius);

                ctx.closePath();
            }

            drawHudShape();
            ctx.fill();
            ctx.stroke();

            if (root._greenLoopRunning && ctx.setLineDash) {
                var shapeLength = (lw + Math.abs(endX - startX) + Math.abs(startY - endY) +
                                   (rightCenterX - endX) + Math.PI * rightRadius +
                                   (rightCenterX - lx) + lh);
                var runnerOffset = -bgCanvas.greenLoopPhase * shapeLength;

                ctx.save();
                drawHudShape();
                ctx.strokeStyle = Qt.rgba(0.42, 0.92, 0.09, 0.22);
                ctx.lineWidth = Math.max(1, ScreenTools.defaultFontPixelHeight * 0.09);
                ctx.lineCap = "round";
                ctx.shadowColor = "#6beb17";
                ctx.shadowBlur = ScreenTools.defaultFontPixelHeight * 0.18;
                ctx.setLineDash([
                    ScreenTools.defaultFontPixelWidth * 14,
                    shapeLength
                ]);
                ctx.lineDashOffset = runnerOffset + ScreenTools.defaultFontPixelWidth * 5;
                ctx.stroke();
                ctx.restore();

                ctx.save();
                drawHudShape();
                ctx.strokeStyle = "#6beb17";
                ctx.lineWidth = Math.max(0.8, ScreenTools.defaultFontPixelHeight * 0.035);
                ctx.lineCap = "round";
                ctx.shadowColor = "#6beb17";
                ctx.shadowBlur = ScreenTools.defaultFontPixelHeight * 0.08;
                ctx.setLineDash([
                    ScreenTools.defaultFontPixelWidth * 8,
                    shapeLength
                ]);
                ctx.lineDashOffset = runnerOffset;
                ctx.stroke();
                ctx.restore();
            }
        }

        // Triggers for repaint
        Connections {
            function onHeightChanged() {
                bgCanvas.requestPaint();
            }
            function onWidthChanged() {
                bgCanvas.requestPaint();
            }
            function onXChanged() {
                bgCanvas.requestPaint();
            }
            function onYChanged() {
                bgCanvas.requestPaint();
            }

            target: telemetryContainer
        }
        Connections {
            function onHeightChanged() {
                bgCanvas.requestPaint();
            }
            function onWidthChanged() {
                bgCanvas.requestPaint();
            }
            function onXChanged() {
                bgCanvas.requestPaint();
            }
            function onYChanged() {
                bgCanvas.requestPaint();
            }

            target: mainContainer
        }
        Connections {
            function onSpacingChanged() {
                bgCanvas.requestPaint();
            }
            function onXChanged() {
                bgCanvas.requestPaint();
            }
            function onYChanged() {
                bgCanvas.requestPaint();
            }

            target: bottomBarRow
        }
        // Force repaint on window resize
        Connections {
            function onHeightChanged() {
                bgCanvas.requestPaint();
            }
            function onWidthChanged() {
                bgCanvas.requestPaint();
            }

            target: parent
        }
        // Repaint when theme changes
        Connections {
            function onPaletteChanged() {
                bgCanvas.requestPaint();
            }
            target: qgcPal
        }
    }
    RowLayout {
        id: bottomBarRow

        anchors.bottom: parent.bottom
        anchors.bottomMargin: root._margins
        anchors.right: parent.right
        anchors.rightMargin: root._margins
        // Balanced spacing to allow for a large-radius, circular S-Curve transition
        spacing: ScreenTools.defaultFontPixelWidth * 6

        // === TELEMETRY GROUP ===
        Item {
            id: telemetryContainer

            Layout.alignment: Qt.AlignBottom
            Layout.preferredHeight: telemetryRow.height
            Layout.preferredWidth: telemetryRow.width

            RowLayout {
                id: telemetryRow

                anchors.bottom: parent.bottom // Re-align to bottom
                anchors.left: parent.left
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 1.7
                spacing: ScreenTools.defaultFontPixelWidth * 2.4

                // Reusable Stat Component
                Component {
                    id: statItemComponent

                    Item {
                        id: statRoot

                        property string dropColor: "#00ccff"
                        property string icon
                        property string iconColor: "#00ff88"
                        property string label
                        property string unit
                        property string value
                        property bool clickable: false
                        property var onStatClicked: null

                        Layout.fillHeight: true
                        implicitHeight: statCol.height
                        implicitWidth: statCol.width

                        Column {
                            id: statCol

                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.1
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: -ScreenTools.defaultFontPixelHeight * 0.58

                            // Top Row: Value + Unit (Now Top)
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: ScreenTools.defaultFontPixelWidth * 0.2

                                Text {
                                    anchors.baseline: unitText.baseline
                                    color: qgcPal.text
                                    font.bold: true
                                    font.family: "Noto Sans"
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 1.08
                                    text: statRoot.value
                                }
                                Text {
                                    id: unitText

                                    color: qgcPal.buttonText
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.48
                                    text: statRoot.unit
                                }
                            }

                            // Bottom Row: Icon + Label (Now Bottom)
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: ScreenTools.defaultFontPixelWidth * 0.5

                                // Visualize alignment: [Icon] [Label]
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: statRoot.iconColor === "drop" ? statRoot.dropColor : statRoot.iconColor
                                    font.bold: true
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.52
                                    height: ScreenTools.defaultFontPixelHeight * 0.72
                                    horizontalAlignment: Text.AlignHCenter
                                    text: statRoot.icon
                                    verticalAlignment: Text.AlignVCenter // Ensure glyph centers in its box
                                    width: height // Enforce square aspect for alignment consistency
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: qgcPal.buttonText
                                    font.bold: true
                                    font.capitalization: Font.AllUppercase
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.32
                                    height: ScreenTools.defaultFontPixelHeight * 0.72
                                    text: statRoot.label
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }

                        QGCMouseArea {
                            id: statMouseArea
                            anchors.fill: parent
                            enabled: statRoot.clickable && typeof statRoot.onStatClicked === "function"
                            hoverEnabled: enabled
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (typeof statRoot.onStatClicked === "function") {
                                    statRoot.onStatClicked()
                                }
                            }
                        }
                    }
                }

                // 1. ALTITUDE — tap while flying to change target altitude
                Loader {
                    Layout.fillHeight: true
                    sourceComponent: statItemComponent

                    onLoaded: {
                        item.label = "ALTITUDE";
                        item.icon = "↑";
                        item.iconColor = "#00ff88";
                        item.value = Qt.binding(function () {
                            return root._displayAltitude.toFixed(1);
                        });
                        item.unit = "m";
                        item.clickable = Qt.binding(function () {
                            return !!(root._guidedController && root._guidedController.showChangeAlt);
                        });
                        item.onStatClicked = function () {
                            if (root._guidedController && root._guidedController.showChangeAlt) {
                                root._guidedController.confirmAction(root._guidedController.actionChangeAlt);
                            }
                        };
                    }
                }

                // 2. GROUND SPEED — tap while flying to change max cruise speed
                Loader {
                    Layout.fillHeight: true
                    sourceComponent: statItemComponent

                    onLoaded: {
                        item.label = "GROUND SPEED";
                        item.icon = "◎"; // Speedometer
                        item.iconColor = "#00ff88";
                        item.value = Qt.binding(function () {
                            return root._displayGroundSpeed.toFixed(1);
                        });
                        item.unit = "m/s";
                        item.clickable = Qt.binding(function () {
                            return !!(root._guidedController && root._guidedController.showChangeSpeed);
                        });
                        item.onStatClicked = function () {
                            if (root._guidedController && root._guidedController.showChangeSpeed) {
                                root._guidedController.confirmAction(root._guidedController.actionChangeSpeed);
                            }
                        };
                    }
                }

                // 3. DIST TO HOME
                Loader {
                    Layout.fillHeight: true
                    sourceComponent: statItemComponent

                    onLoaded: {
                        item.label = "DIST TO HOME";
                        item.icon = "📍";
                        item.iconColor = "#00ff88";
                        item.value = Qt.binding(function () {
                            return root._distanceToHome.toFixed(1);
                        });
                        item.unit = "m";
                    }
                }

                // 4. FLOW RATE
                Loader {
                    Layout.fillHeight: true
                    sourceComponent: statItemComponent

                    onLoaded: {
                        item.label = "FLOW RATE";
                        item.icon = "💧";
                        item.iconColor = "drop";
                        item.value = Qt.binding(function () {
                            return root._flowRate.toFixed(1);
                        });
                        item.unit = "L/min";
                    }
                }
            } // End telemetryRow
        } // End telemetryContainer

        // === MAIN GROUP (Toggles, Tank, Compass) ===
        Item {
            id: mainContainer

            Layout.alignment: Qt.AlignBottom
            Layout.preferredHeight: mainRow.height
            Layout.preferredWidth: mainRow.width

            RowLayout {
                id: mainRow

                anchors.bottom: parent.bottom
                spacing: root._margins * 1.35

                // Separator between Telemetry and Main is handled by the gap/curve,
                // but we might want a separator inside if desired.
                // The original plan had them separate.
                // Users reference image shows they are visually separated by the cut.
                // So we start with Toggles directly.

                // === TANK ===
                // Top label    : _tankCapacityMax (20 kg)
                // Fill bar     : _tankCurrentLevel / _tankCapacityMax
                // Center label : live LC_WEIGHT value in kg
                // Bottom label : static 0 kg reference
                Column {
                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 1.7
                    spacing: 2

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: qgcPal.buttonText
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.50
                        text: root._tankCapacityMax.toFixed(0) + "kg"
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        border.color: root._glassPanelBorder
                        border.width: 1
                        color: root._glassPanelFill
                        height: ScreenTools.defaultFontPixelHeight * 2.8
                        radius: root._glassPanelRadius * 0.6
                        width: ScreenTools.defaultFontPixelHeight

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 2
                            anchors.horizontalCenter: parent.horizontalCenter
                            height: (parent.height - 4) * Math.min(1, root._tankCurrentLevel / root._tankCapacityMax)
                            radius: parent.radius - 1
                            width: parent.width - 4

                            gradient: Gradient {
                                GradientStop {
                                    color: "#00ccff"
                                    position: 0.0
                                }
                                GradientStop {
                                    color: "#0088cc"
                                    position: 0.5
                                }
                                GradientStop {
                                    color: "#005588"
                                    position: 1.0
                                }
                            }
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: qgcPal.colorBlue
                        font.bold: true
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.50
                        text: root._tankCurrentLevel.toFixed(1) + "kg"
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: qgcPal.buttonText
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.50
                        text: "0kg"
                    }
                }

                // Separator
                Rectangle {
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.8
                    Layout.preferredWidth: 1
                    color: root._compassSeparator
                }

                // === COMPASS WITH ATTITUDE INDICATORS ===
                Item {
                    id: compassContainer

                    // Attitude arc properties
                    property real _maxAngleDegrees: 30
                    property real _maxRadians: _maxAngleDegrees * Math.PI / 180
                    property real _pitchPercent: Math.min(Math.max(root._pitch, -_maxAngleDegrees), _maxAngleDegrees) / _maxAngleDegrees
                    property real _rollPercent: Math.min(Math.max(root._roll, -_maxAngleDegrees), _maxAngleDegrees) / _maxAngleDegrees
                    property real attitudeArcWidth: ScreenTools.defaultFontPixelHeight * 0.38
                    property real attitudeSpacing: ScreenTools.defaultFontPixelHeight * 0.10
                    property real compassSize: ScreenTools.defaultFontPixelHeight * 4.25
                    property real sideIconSize: ScreenTools.defaultFontPixelHeight
                    property real totalSize: compassSize + (attitudeArcWidth + attitudeSpacing) * 2

                    Layout.preferredHeight: totalSize
                    Layout.preferredWidth: totalSize
                    Layout.leftMargin: sideIconSize * 0.75

                    ShaderEffectSource {
                        id: compassBackdropSource
                        anchors.centerIn: parent
                        width: compassContainer.compassSize
                        height: width
                        sourceItem: root.blurSourceItem
                        live: true
                        recursive: false
                        visible: false
                        sourceRect: {
                            if (!root.blurSourceItem) {
                                return Qt.rect(0, 0, width, height)
                            }
                            var topLeft = compassContainer.mapToItem(
                                        root.blurSourceItem,
                                        (compassContainer.width - width) / 2,
                                        (compassContainer.height - height) / 2)
                            return Qt.rect(topLeft.x, topLeft.y, width, height)
                        }
                    }

                    FastBlur {
                        id: compassBackdropBlur
                        anchors.fill: compassBackdropSource
                        source: compassBackdropSource
                        radius: 5
                        transparentBorder: true
                        visible: false
                    }

                    OpacityMask {
                        anchors.fill: compassBackdropSource
                        source: compassBackdropBlur
                        visible: root.blurSourceItem !== null
                        opacity: 0.62
                        z: -1
                        maskSource: Rectangle {
                            width: compassBackdropSource.width
                            height: compassBackdropSource.height
                            radius: width / 2
                        }
                    }

                    // Terrain Follow control, positioned outside the upper-left
                    // edge of the compass while retaining the MPC_ALT_MODE logic.
                    Item {
                        id: terrainFlowCompassButton
                        x: -width * 0.78
                        y: ScreenTools.defaultFontPixelHeight * 0.15
                        width: compassContainer.sideIconSize
                        height: width
                        z: 10

                        Canvas {
                            anchors.fill: parent
                            property bool active: root._terrainFlowIconActive

                            onActiveChanged: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                var color = active ? "#00ff88" : "#ffffff"
                                var cx = width / 2
                                var cy = height / 2
                                var radius = width * 0.29

                                ctx.strokeStyle = color
                                ctx.fillStyle = color
                                ctx.lineWidth = Math.max(1.5, width * 0.075)
                                ctx.beginPath()
                                ctx.arc(cx, cy, radius, 0, Math.PI * 2)
                                ctx.stroke()

                                ctx.beginPath()
                                ctx.arc(cx, cy, width * 0.075, 0, Math.PI * 2)
                                ctx.fill()

                                var tickInner = width * 0.36
                                var tickOuter = width * 0.46
                                ctx.beginPath()
                                ctx.moveTo(cx, cy - tickOuter)
                                ctx.lineTo(cx, cy - tickInner)
                                ctx.moveTo(cx + tickInner, cy)
                                ctx.lineTo(cx + tickOuter, cy)
                                ctx.moveTo(cx, cy + tickInner)
                                ctx.lineTo(cx, cy + tickOuter)
                                ctx.moveTo(cx - tickOuter, cy)
                                ctx.lineTo(cx - tickInner, cy)
                                ctx.stroke()
                            }
                        }

                        QGCMouseArea {
                            id: terrainFlowCompassMouseArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: root.toggleTerrainFlow()

                            ToolTip.visible: containsMouse
                            ToolTip.text: root._terrainFlowIconActive
                                          ? qsTr("Terrain Follow: Active")
                                          : qsTr("Terrain Follow: Off")
                        }
                    }

                    // Obstacle Avoidance control, positioned outside the
                    // lower-left edge of the compass.
                    Item {
                        id: obstacleAvoidCompassButton
                        x: -width * 0.78
                        y: compassContainer.height - height - ScreenTools.defaultFontPixelHeight * 0.15
                        width: compassContainer.sideIconSize
                        height: width
                        z: 10

                        Canvas {
                            id: obstacleAvoidCompassCanvas
                            anchors.fill: parent
                            property bool active: root._obstacleAvoidanceActive

                            onActiveChanged: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                var color = active ? "#00ff88" : "#ffffff"
                                var cx = width / 2

                                ctx.strokeStyle = color
                                ctx.fillStyle = color
                                ctx.lineWidth = Math.max(1.5, width * 0.075)
                                ctx.lineCap = "round"

                                ctx.beginPath()
                                ctx.arc(cx, height * 0.64, width * 0.20, Math.PI * 0.18, Math.PI * 0.82)
                                ctx.stroke()
                                ctx.beginPath()
                                ctx.arc(cx, height * 0.62, width * 0.34, Math.PI * 0.18, Math.PI * 0.82)
                                ctx.stroke()

                                ctx.beginPath()
                                ctx.arc(cx, height * 0.72, width * 0.07, 0, Math.PI * 2)
                                ctx.fill()
                            }
                        }

                        QGCMouseArea {
                            id: obstacleAvoidCompassMouseArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            enabled: root._cpDistFact || (root._activeVehicle && root._activeVehicle.objectAvoidance)
                            onClicked: root.toggleObstacleAvoidance()

                            ToolTip.visible: containsMouse
                            ToolTip.text: !enabled ? qsTr("Obstacle Avoidance: Not Available")
                                          : root._obstacleAvoidanceActive
                                          ? qsTr("Obstacle Avoidance: Active")
                                          : qsTr("Obstacle Avoidance: Off")
                        }
                    }

                    Connections {
                        target: root._activeVehicle ? root._activeVehicle.objectAvoidance : null
                        function onObjectAvoidanceChanged() {
                            obstacleAvoidCompassCanvas.requestPaint()
                        }
                    }

                    // Repaint compass canvases when theme changes
                    Connections {
                        function onPaletteChanged() {
                            rollBg.requestPaint();
                            pitchBg.requestPaint();
                        }
                        target: qgcPal
                    }

                    // Roll arc background (top)
                    Canvas {
                        id: rollBg

                        anchors.fill: parent

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            var centerX = width / 2;
                            var centerY = height / 2;
                            var radius = (compassContainer.compassSize / 2) + compassContainer.attitudeSpacing + (compassContainer.attitudeArcWidth / 2);

                            ctx.strokeStyle = Qt.rgba(root._togglePanelBorder.r, root._togglePanelBorder.g, root._togglePanelBorder.b, root._togglePanelBorder.a);
                            ctx.lineWidth = compassContainer.attitudeArcWidth;
                            ctx.lineCap = "butt";
                            ctx.beginPath();
                            // Arc from -30° to +30° (top of circle, centered at -90°/270°)
                            ctx.arc(centerX, centerY, radius, -Math.PI / 2 - compassContainer._maxRadians, -Math.PI / 2 + compassContainer._maxRadians);
                            ctx.stroke();
                        }
                    }

                    // Roll arc value indicator
                    Canvas {
                        id: rollValue

                        property real rollPercent: compassContainer._rollPercent

                        anchors.fill: parent
                        visible: Math.abs(root._roll) > 0.5

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            var centerX = width / 2;
                            var centerY = height / 2;
                            var radius = (compassContainer.compassSize / 2) + compassContainer.attitudeSpacing + (compassContainer.attitudeArcWidth / 2);

                            ctx.strokeStyle = "#00cc66";
                            ctx.lineWidth = compassContainer.attitudeArcWidth - 2;
                            ctx.lineCap = "butt";
                            ctx.beginPath();

                            var startAngle = -Math.PI / 2;
                            var endAngle = -Math.PI / 2 + (rollPercent * compassContainer._maxRadians);
                            if (startAngle > endAngle) {
                                var temp = startAngle;
                                startAngle = endAngle;
                                endAngle = temp;
                            }
                            ctx.arc(centerX, centerY, radius, startAngle, endAngle);
                            ctx.stroke();
                        }
                        onRollPercentChanged: requestPaint()
                    }

                    // Roll center tick
                    Canvas {
                        anchors.fill: parent

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            var centerX = width / 2;
                            ctx.strokeStyle = Qt.rgba(qgcPal.buttonText.r, qgcPal.buttonText.g, qgcPal.buttonText.b, 1);
                            ctx.lineWidth = 2;
                            ctx.beginPath();
                            ctx.moveTo(centerX, 0);
                            ctx.lineTo(centerX, compassContainer.attitudeArcWidth + compassContainer.attitudeSpacing);
                            ctx.stroke();
                        }
                    }

                    // Pitch arc background (left side)
                    Canvas {
                        id: pitchBg

                        anchors.fill: parent

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            var centerX = width / 2;
                            var centerY = height / 2;
                            var radius = (compassContainer.compassSize / 2) + compassContainer.attitudeSpacing + (compassContainer.attitudeArcWidth / 2);

                            ctx.strokeStyle = Qt.rgba(root._togglePanelBorder.r, root._togglePanelBorder.g, root._togglePanelBorder.b, root._togglePanelBorder.a);
                            ctx.lineWidth = compassContainer.attitudeArcWidth;
                            ctx.lineCap = "butt";
                            ctx.beginPath();
                            // Arc from -30° to +30° (left of circle, centered at 180°/π)
                            ctx.arc(centerX, centerY, radius, Math.PI - compassContainer._maxRadians, Math.PI + compassContainer._maxRadians);
                            ctx.stroke();
                        }
                    }

                    // Pitch arc value indicator
                    Canvas {
                        id: pitchValue

                        property real pitchPercent: compassContainer._pitchPercent

                        anchors.fill: parent
                        visible: Math.abs(root._pitch) > 0.5

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            var centerX = width / 2;
                            var centerY = height / 2;
                            var radius = (compassContainer.compassSize / 2) + compassContainer.attitudeSpacing + (compassContainer.attitudeArcWidth / 2);

                            ctx.strokeStyle = "#0099ff";
                            ctx.lineWidth = compassContainer.attitudeArcWidth - 2;
                            ctx.lineCap = "butt";
                            ctx.beginPath();

                            var startAngle = Math.PI;
                            var endAngle = Math.PI - (pitchPercent * compassContainer._maxRadians);
                            if (startAngle > endAngle) {
                                var temp = startAngle;
                                startAngle = endAngle;
                                endAngle = temp;
                            }
                            ctx.arc(centerX, centerY, radius, startAngle, endAngle);
                            ctx.stroke();
                        }
                        onPitchPercentChanged: requestPaint()
                    }

                    // Pitch center tick
                    Canvas {
                        anchors.fill: parent

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            var centerY = height / 2;
                            ctx.strokeStyle = Qt.rgba(qgcPal.buttonText.r, qgcPal.buttonText.g, qgcPal.buttonText.b, 1);
                            ctx.lineWidth = 2;
                            ctx.beginPath();
                            ctx.moveTo(0, centerY);
                            ctx.lineTo(compassContainer.attitudeArcWidth + compassContainer.attitudeSpacing, centerY);
                            ctx.stroke();
                        }
                    }

                    // Main compass circle
                    Rectangle {
                        id: compassBg

                        anchors.centerIn: parent
                        border.color: root._togglePanelBorder
                        border.width: 1
                        color: Qt.rgba(root._togglePanelFill.r,
                                       root._togglePanelFill.g,
                                       root._togglePanelFill.b, 0.48)
                        height: compassContainer.compassSize
                        radius: width / 2
                        width: compassContainer.compassSize

                        // Rotating compass content
                        Item {
                            anchors.fill: parent
                            rotation: -root._heading

                            Behavior on rotation {
                                RotationAnimation {
                                    direction: RotationAnimation.Shortest
                                    duration: 200
                                }
                            }

                            // N
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.35
                                color: "#e74c3c"
                                font.bold: true
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                                rotation: root._heading
                                text: "N"
                            }
                            // E
                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: ScreenTools.defaultFontPixelHeight * 0.35
                                anchors.verticalCenter: parent.verticalCenter
                                color: "white"
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5
                                rotation: root._heading
                                text: "E"
                            }
                            // S
                            Text {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.35
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: "white"
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5
                                rotation: root._heading
                                text: "S"
                            }
                            // W
                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: ScreenTools.defaultFontPixelHeight * 0.35
                                anchors.verticalCenter: parent.verticalCenter
                                color: "white"
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5
                                rotation: root._heading
                                text: "W"
                            }

                            // Tick marks
                            Repeater {
                                model: 12

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: "white"
                                    height: index % 3 === 0 ? ScreenTools.defaultFontPixelHeight * 0.35 : ScreenTools.defaultFontPixelHeight * 0.2
                                    transformOrigin: Item.Bottom
                                    width: index % 3 === 0 ? 2 : 1
                                    y: 4

                                    transform: Rotation {
                                        angle: index * 30
                                        origin.x: width / 2
                                        origin.y: compassContainer.compassSize / 2 - 4
                                    }
                                }
                            }
                        }

                        // Fixed aircraft indicator
                        Canvas {
                            anchors.centerIn: parent
                            height: parent.height * 0.26
                            width: parent.width * 0.26

                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();
                                ctx.fillStyle = "#00ff88";
                                ctx.beginPath();
                                ctx.moveTo(width / 2, height * 0.1);
                                ctx.lineTo(width * 0.18, height * 0.85);
                                ctx.lineTo(width * 0.5, height * 0.6);
                                ctx.lineTo(width * 0.82, height * 0.85);
                                ctx.closePath();
                                ctx.fill();
                            }
                        }

                        // Heading value
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.6
                            anchors.horizontalCenter: parent.horizontalCenter
                            border.width: 0
                            color: "transparent"
                            height: hdgText.height + 2
                            radius: root._glassPanelRadius * 0.4
                            width: hdgText.width + 6

                            Text {
                                id: hdgText

                                anchors.centerIn: parent
                                color: "white"
                                font.bold: true
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.8
                                text: root._heading.toFixed(0) + "°"
                            }
                        }
                    }
                }
            }
        }
    }
}
