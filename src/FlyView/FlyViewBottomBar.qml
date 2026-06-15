import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Item {
    id: root

    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property real _altitude: _activeVehicle && _activeVehicle.altitudeRelative ? _activeVehicle.altitudeRelative.rawValue : 0
    property real _distanceToHome: _activeVehicle && _activeVehicle.distanceToHome ? _activeVehicle.distanceToHome.rawValue : 0

    // Flow rate
    property real _flowRate: 18.0
    property real _groundSpeed: _activeVehicle && _activeVehicle.groundSpeed ? _activeVehicle.groundSpeed.rawValue : 0
    property real _heading: _activeVehicle && _activeVehicle.heading ? _activeVehicle.heading.rawValue : 0
    property real _margins: ScreenTools.defaultFontPixelWidth
    property Fact _mpcAltModeFact: paramLoader.item ? paramLoader.item.fact : null
    property bool _obstacleAvoidanceActive: false
    property bool _paramExists: paramLoader.item ? paramLoader.item.paramExists : false
    property real _pitch: _activeVehicle && _activeVehicle.pitch ? _activeVehicle.pitch.rawValue : 0
    property real _roll: _activeVehicle && _activeVehicle.roll ? _activeVehicle.roll.rawValue : 0

    // Tank capacity (Litres)
    property real _tankCapacityMax: 16.0
    property real _tankCurrentLevel: 10.4
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
        _obstacleAvoidanceActive = !_obstacleAvoidanceActive;
        console.log("Obstacle Avoidance toggle: " + _obstacleAvoidanceActive);
    }
    function toggleTerrainFlow() {
        if (_mpcAltModeFact) {
            var newValue = _terrainFlowActive ? 2 : 1;
            console.log("Terrain Flow toggle: current=" + _mpcAltModeFact.rawValue + " setting to=" + newValue);
            _mpcAltModeFact.value = newValue;
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
        paramLoader.active = false;
        paramLoader.active = true;
    }

    // === TERRAIN FLOW PARAMETER ===
    // === TERRAIN FLOW PARAMETER ===
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
            property bool paramExists: fact !== null
            // Re-evaluate when parameters become ready
            property bool paramsReady: _activeVehicle && _activeVehicle.parameterManager ? _activeVehicle.parameterManager.parametersReady : false

            FactPanelController {
                id: controller

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

        property var mainItem: mainContainer

        // Redraw when layout changes
        property var telemetryItem: telemetryContainer

        anchors.fill: parent

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
            var naturalLh = telemetryItem.height + (ScreenTools.defaultFontPixelHeight * 1.1) + paddingBottom;

            // Enforce MINIMUM height (25% of Main) to prevent shrinking too much
            // Enforce MAXIMUM height (Main height) to keep it a "cutout" (step down)
            var lh = Math.min(Math.max(naturalLh, rh * 0.25), rh);

            // Align Bottoms: The bar sits on the bottom edge
            var bottomY = ry + rh;
            var ly = bottomY - lh; // Calculate top Y based on height diff

            // Left edge radius for corners
            var topLeftRadius = ScreenTools.defaultFontPixelHeight * 1.8; // Large radius for top-left
            var leftBottomRadius = ScreenTools.defaultFontPixelHeight * 0.8; // Small radius for bottom-left

            // Radii
            var rightRadius = rh / 2;

            ctx.fillStyle = Qt.rgba(root._glassFill.r, root._glassFill.g, root._glassFill.b, root._glassFill.a);
            ctx.strokeStyle = Qt.rgba(root._glassBorder.r, root._glassBorder.g, root._glassBorder.b, root._glassBorder.a);
            ctx.lineWidth = 1;

            ctx.beginPath();

            // 1. Start at top-left with LARGE radius for professional look
            ctx.moveTo(lx, ly + topLeftRadius);
            ctx.arc(lx + topLeftRadius, ly + topLeftRadius, topLeftRadius, Math.PI, 1.5 * Math.PI, false);

            // 2. Top Edge (Continuous straight line to Right S-Curve start)
            ctx.lineTo(lx + lw, ly);

            // 3. S-Curve transition (Step UP to Right Section)
            var startX = lx + lw;
            var startY = ly;
            var endX = rx;
            var endY = ry;
            var dx = endX - startX;
            // Use 0.65 pull for a matching professional flare
            ctx.bezierCurveTo(startX + dx * 0.65, startY, endX - dx * 0.65, endY, endX, endY);

            // 4. Top Edge of Main & Right Pill
            var rightCenterX = rx + rw - rightRadius;
            var rightCenterY = ry + rightRadius;
            ctx.lineTo(rightCenterX, ry);
            ctx.arc(rightCenterX, rightCenterY, rightRadius, 1.5 * Math.PI, 0.5 * Math.PI, false);

            // 5. Bottom Edge back to Left with small radius
            ctx.lineTo(lx + leftBottomRadius, bottomY);

            // 6. Left Bottom Corner - Small rounded radius
            ctx.arc(lx + leftBottomRadius, bottomY - leftBottomRadius, leftBottomRadius, 0.5 * Math.PI, 1.0 * Math.PI, false);

            // 7. Left Edge up to start (connecting to the large top-left radius)
            ctx.lineTo(lx, ly + topLeftRadius);

            ctx.closePath();
            ctx.fill();
            ctx.stroke();
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
        spacing: ScreenTools.defaultFontPixelWidth * 9

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
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 2.5 // Add left padding to clear the rounded corner
                spacing: ScreenTools.defaultFontPixelWidth * 4

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

                        Layout.fillHeight: true
                        implicitHeight: statCol.height
                        implicitWidth: statCol.width

                        Column {
                            id: statCol

                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.1
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: -ScreenTools.defaultFontPixelHeight * 1

                            // Top Row: Value + Unit (Now Top)
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: ScreenTools.defaultFontPixelWidth * 0.2

                                Text {
                                    anchors.baseline: unitText.baseline
                                    color: qgcPal.text
                                    font.bold: true
                                    font.family: "Noto Sans"
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 1.6
                                    text: statRoot.value
                                }
                                Text {
                                    id: unitText

                                    color: qgcPal.buttonText
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.65
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
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.75
                                    height: ScreenTools.defaultFontPixelHeight // Fixed height to prevent row shifting
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
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.42
                                    height: ScreenTools.defaultFontPixelHeight // Fixed height match
                                    text: statRoot.label
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }
                }

                // 1. ALTITUDE
                Loader {
                    Layout.fillHeight: true
                    sourceComponent: statItemComponent

                    onLoaded: {
                        item.label = "ALTITUDE";
                        item.icon = "↑";
                        item.iconColor = "#00ff88";
                        item.value = Qt.binding(function () {
                            return root._altitude.toFixed(1);
                        });
                        item.unit = "m";
                    }
                }

                // 2. GROUND SPEED
                Loader {
                    Layout.fillHeight: true
                    sourceComponent: statItemComponent

                    onLoaded: {
                        item.label = "GROUND SPEED";
                        item.icon = "◎"; // Speedometer
                        item.iconColor = "#00ff88";
                        item.value = Qt.binding(function () {
                            return root._groundSpeed.toFixed(1);
                        });
                        item.unit = "m/s";
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
                        item.unit = "L/m";
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
                spacing: root._margins * 2

                // Separator between Telemetry and Main is handled by the gap/curve,
                // but we might want a separator inside if desired.
                // The original plan had them separate.
                // Users reference image shows they are visually separated by the cut.
                // So we start with Toggles directly.

                // === TOGGLES ===
                Rectangle {
                    id: togglesContainer

                    Layout.preferredHeight: togglesCol.height + root._margins * 2
                    Layout.preferredWidth: togglesCol.width + root._margins * 3
                    border.color: root._togglePanelBorder
                    border.width: 1
                    color: root._togglePanelFill
                    radius: root._glassPanelRadius

                    Column {
                        id: togglesCol

                        anchors.centerIn: parent
                        spacing: root._margins * 0.6

                        // TERRAIN FLOW
                        MouseArea {
                            cursorShape: Qt.PointingHandCursor
                            height: tfRow.height
                            width: tfRow.width

                            onClicked: root.toggleTerrainFlow()

                            Row {
                                id: tfRow

                                spacing: root._margins

                                Column {
                                    spacing: 1

                                    Text {
                                        color: root._terrainFlowActive ? "#00ff88" : root._hudGrayWhite
                                        font.bold: true
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                                        text: "TERRAIN FLOW"
                                    }
                                    Row {
                                        spacing: 4

                                        Text {
                                            color: root._terrainFlowActive ? "#00ff88" : root._hudGrayWhite
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                                            text: "▲"
                                        }
                                        Text {
                                            color: root._terrainFlowActive ? "#00ff88" : root._hudGrayWhite
                                            font.bold: true
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                                            text: root._terrainFlowActive ? "ACTIVE" : "OFF"
                                        }
                                        Item {
                                            height: 1
                                            width: 2
                                        } // Spacer
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: root._terrainFlowActive ? "#00ff88" : root._hudGrayWhite
                                            height: ScreenTools.defaultFontPixelHeight * 0.4
                                            radius: width / 2
                                            width: height
                                        }
                                    }
                                }
                            }
                        }
                        Rectangle {
                            color: root._compassSeparator
                            height: 1
                            width: parent.width
                        }

                        // OBSTACLE AVOID
                        MouseArea {
                            cursorShape: Qt.PointingHandCursor
                            height: oaRow.height
                            width: oaRow.width

                            onClicked: root.toggleObstacleAvoidance()

                            Row {
                                id: oaRow

                                spacing: root._margins

                                Column {
                                    spacing: 1

                                    Text {
                                        color: root._obstacleAvoidanceActive ? "#ff6666" : root._hudGrayWhite
                                        font.bold: true
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                                        text: "OBSTACLE AVOID"
                                    }
                                    Row {
                                        spacing: 4

                                        Text {
                                            color: root._obstacleAvoidanceActive ? "#ff6666" : root._hudGrayWhite
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                                            text: "▲"
                                        }
                                        Text {
                                            color: root._obstacleAvoidanceActive ? "#ff6666" : root._hudGrayWhite
                                            font.bold: true
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                                            text: root._obstacleAvoidanceActive ? "ACTIVE" : "OFF"
                                        }
                                        Item {
                                            height: 1
                                            width: 2
                                        } // Spacer
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: root._obstacleAvoidanceActive ? "#ff6666" : root._hudGrayWhite
                                            height: ScreenTools.defaultFontPixelHeight * 0.4
                                            radius: width / 2
                                            width: height
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Separator
                Rectangle {
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 4.5
                    Layout.preferredWidth: 1
                    color: root._compassSeparator
                }

                // === TANK ===
                Column {
                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 2
                    spacing: 2

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: qgcPal.buttonText
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.4
                        text: root._tankCapacityMax.toFixed(0) + "L"
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        border.color: root._glassPanelBorder
                        border.width: 1
                        color: root._glassPanelFill
                        height: ScreenTools.defaultFontPixelHeight * 3.5
                        radius: root._glassPanelRadius * 0.6
                        width: ScreenTools.defaultFontPixelHeight * 1.2

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
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.45
                        text: root._tankCurrentLevel.toFixed(1) + "L"
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: qgcPal.buttonText
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.35
                        text: "0L"
                    }
                }

                // Separator
                Rectangle {
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 4.5
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
                    property real attitudeArcWidth: ScreenTools.defaultFontPixelHeight * 0.5
                    property real attitudeSpacing: ScreenTools.defaultFontPixelHeight * 0.15
                    property real compassSize: ScreenTools.defaultFontPixelHeight * 5
                    property real totalSize: compassSize + (attitudeArcWidth + attitudeSpacing) * 2

                    Layout.preferredHeight: totalSize
                    Layout.preferredWidth: totalSize

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
                        color: root._togglePanelFill
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
