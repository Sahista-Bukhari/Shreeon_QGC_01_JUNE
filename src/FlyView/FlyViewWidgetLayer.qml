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

// This is the ui overlay layer for the widgets/tools for Fly View
Item {
    id: _root

    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property rect _centerViewport: Qt.rect(0, 0, width, height)
    property var _geoFenceController: _planMasterController.geoFenceController
    property var _guidedController: globals.guidedControllerFlyView
    property real _layoutMargin: ScreenTools.defaultFontPixelWidth * 0.75
    property bool _layoutSpacing: ScreenTools.defaultFontPixelWidth
    property real _margins: ScreenTools.defaultFontPixelWidth / 2
    property var _missionController: _planMasterController.missionController
    property var _planMasterController: globals.planMasterControllerFlyView
    property var _rallyPointController: _planMasterController.rallyPointController
    property real _rightPanelWidth: ScreenTools.defaultFontPixelWidth * 30
    property alias actionButtonsPanel: actionButtonsPanel
    property alias bottomBar: bottomBar

    // ... (rest of properties)

    // ... (rest of code)

    property bool _showSingleVehicleUI: true
    property real _toolsMargin: ScreenTools.defaultFontPixelWidth * 0.75
    property real _topBottomMargin: ScreenTools.defaultFontPixelWidth * 0.5
    property real _widgetsMargin: ScreenTools.defaultFontPixelWidth
    property bool isViewer3DOpen: false
    property bool planEditMode: false
    property var mapControl
    property var parentToolInsets
    property var totalToolInsets: _totalToolInsets
    property real rightPanelTopMargin: 0

    QGCToolInsets {
        id: _totalToolInsets

        bottomEdgeCenterInset: bottomRightRowLayout.bottomEdgeCenterInset
        bottomEdgeLeftInset: virtualJoystickMultiTouch.visible ? virtualJoystickMultiTouch.bottomEdgeLeftInset : parentToolInsets.bottomEdgeLeftInset
        bottomEdgeRightInset: virtualJoystickMultiTouch.visible ? virtualJoystickMultiTouch.bottomEdgeRightInset : bottomRightRowLayout.bottomEdgeRightInset
        leftEdgeBottomInset: virtualJoystickMultiTouch.visible ? virtualJoystickMultiTouch.leftEdgeBottomInset : parentToolInsets.leftEdgeBottomInset
        leftEdgeCenterInset: toolStrip.leftEdgeCenterInset
        leftEdgeTopInset: toolStrip.leftEdgeTopInset
        rightEdgeBottomInset: bottomRightRowLayout.rightEdgeBottomInset
        rightEdgeCenterInset: topRightPanel.rightEdgeCenterInset
        rightEdgeTopInset: topRightPanel.rightEdgeTopInset
        topEdgeCenterInset: mapScale.topEdgeCenterInset
        topEdgeLeftInset: toolStrip.topEdgeLeftInset
        topEdgeRightInset: topRightPanel.topEdgeRightInset
    }
    FlyViewTopRightPanel {
        id: topRightPanel

        property real rightEdgeCenterInset: rightEdgeTopInset
        property real rightEdgeTopInset: width + _layoutMargin
        property real topEdgeRightInset: height + _layoutMargin

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: rightPanelTopMargin
        maximumHeight: parent.height - (bottomRightRowLayout.height + _margins * 4)
    }
    FlyViewTopRightColumnLayout {
        id: topRightColumnLayout

        property real rightEdgeCenterInset: rightEdgeTopInset
        property real rightEdgeTopInset: width + _layoutMargin
        property real topEdgeRightInset: childrenRect.height + _layoutMargin

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: rightPanelTopMargin
        spacing: _layoutSpacing
        visible: !topRightPanel.visible
    }
    FlyViewBottomRightRowLayout {
        id: bottomRightRowLayout

        property real bottomEdgeCenterInset: bottomEdgeRightInset
        property real bottomEdgeRightInset: height + _layoutMargin
        property real rightEdgeBottomInset: width + _layoutMargin

        anchors.bottom: parent.bottom
        anchors.right: parent.right
        spacing: _layoutSpacing
    }
    // New unified bottom bar with compass, toggles, tank indicator, and telemetry
    FlyViewBottomBar {
        id: bottomBar

        actionButtonsModel: flyViewToolStripActionList.model
        blurSourceItem: mapControl
        anchors.bottom: parent.bottom
        anchors.bottomMargin: _toolsMargin * 0.4
        anchors.right: parent.right
        anchors.rightMargin: _toolsMargin
        visible: !QGroundControl.videoManager.fullScreen && !mainWindow.modeSelectionVisible

        // Slide down off-screen when plan edit mode is active
        transform: Translate {
            y: _root.planEditMode ? bottomBar.height + _toolsMargin * 4 : 0
            Behavior on y { NumberAnimation { duration: 350; easing.type: Easing.InOutQuad } }
        }
    }

    // Individual action button islands - positioned directly above telemetry metrics
    FlyViewActionButtonsPanel {
        id: actionButtonsPanel

        actionModel: flyViewToolStripActionList.model

        // Floating centering (Physically separated from metrics line)
        anchors.bottom: bottomBar.bottom
        anchors.bottomMargin: (bottomBar.height - bottomBar.telemetryTopY) + ((bottomBar.telemetryTopY - actionButtonsPanel.height) / 2) + 8
        anchors.right: bottomBar.left
        anchors.rightMargin: -(bottomBar.telemetryRightEdge + bottomBar._margins * 1.8)

        // Width strictly matches the telemetry section width
        maxVisibleWidth: bottomBar.telemetryItem ? bottomBar.telemetryItem.width : parent.width * 0.4

        visible: !_root.isViewer3DOpen && _root._activeVehicle && bottomBar.telemetryItem
        z: QGroundControl.zOrderWidgets + 1

        // Keep flight-critical guided actions available while editing the mission.
        // The telemetry bottom bar slides away in plan edit mode, but actions such
        // as Start Mission and Land must remain reachable.
        transform: Translate {
            y: 0
        }
    }

    // Reference to the action list for the panel
    FlyViewToolStripActionList {
        id: flyViewToolStripActionList

        onDisplayPreFlightChecklist: {
            if (!preFlightChecklistLoader.active) {
                preFlightChecklistLoader.active = true;
            }
            preFlightChecklistLoader.item.open();
        }
    }
    FlyViewMissionCompleteDialog {
        geoFenceController: _geoFenceController
        missionController: _missionController
        rallyPointController: _rallyPointController
    }

    //-- Virtual Joystick
    Loader {
        id: virtualJoystickMultiTouch

        property var _pipViewMargin: _pipView.visible ? parentToolInsets.bottomEdgeLeftInset + ScreenTools.defaultFontPixelHeight * 2 : bottomRightRowLayout.height + ScreenTools.defaultFontPixelHeight * 1.5
        property bool _virtualJoystickEnabled: QGroundControl.settingsManager.appSettings.virtualJoystick.rawValue
        property bool autoCenterThrottle: QGroundControl.settingsManager.appSettings.virtualJoystickAutoCenterThrottle.rawValue
        property real bottomEdgeLeftInset: parent.height - y
        property real bottomEdgeRightInset: parent.height - y
        property var bottomLoaderMargin: _pipViewMargin >= parent.height / 2 ? parent.height / 2 : _pipViewMargin
        property var itemX: virtualJoystickMultiTouch.x   // real X on screen

        // Width is difficult to access directly hence this hack which may not work in all circumstances
        property real leftEdgeBottomInset: visible ? bottomEdgeLeftInset + width / 18 - ScreenTools.defaultFontPixelHeight * 2 : 0
        property bool leftHandedMode: QGroundControl.settingsManager.appSettings.virtualJoystickLeftHandedMode.rawValue
        property real rightEdgeBottomInset: visible ? bottomEdgeRightInset + width / 18 - ScreenTools.defaultFontPixelHeight * 2 : 0
        property real rootWidth: _root.width

        active: _virtualJoystickEnabled && !(_activeVehicle ? _activeVehicle.usingHighLatencyLink : false)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: bottomLoaderMargin
        anchors.left: parent.left
        anchors.leftMargin: (y > toolStrip.y + toolStrip.height ? toolStrip.width / 2 : toolStrip.width * 1.05 + toolStrip.x)
        anchors.right: parent.right
        anchors.rightMargin: anchors.leftMargin
        height: Math.min(parent.height * 0.25, ScreenTools.defaultFontPixelWidth * 16)
        source: "qrc:/qml/QGroundControl/FlyView/VirtualJoystick.qml"
        visible: _virtualJoystickEnabled && !QGroundControl.videoManager.fullScreen && !(_activeVehicle ? _activeVehicle.usingHighLatencyLink : false)
        z: QGroundControl.zOrderTopMost + 1

        onItemXChanged: virtualJoystickMultiTouch.status == Loader.Ready && visible ? virtualJoystickMultiTouch.item.uiRealX = itemX : undefined

        //Loader status logic
        onLoaded: {
            if (virtualJoystickMultiTouch.visible) {
                virtualJoystickMultiTouch.item.calibration = true;
                virtualJoystickMultiTouch.item.uiTotalWidth = rootWidth;
                virtualJoystickMultiTouch.item.uiRealX = itemX;
            } else {
                virtualJoystickMultiTouch.item.calibration = false;
            }
        }
        onRootWidthChanged: virtualJoystickMultiTouch.status == Loader.Ready && visible ? virtualJoystickMultiTouch.item.uiTotalWidth = rootWidth : undefined
    }
    FlyViewToolStrip {
        id: toolStrip

        property real leftEdgeCenterInset: leftEdgeTopInset
        property real leftEdgeTopInset: visible ? x + width : 0
        property real topEdgeLeftInset: visible ? y + height : 0

        anchors.left: parent.left
        anchors.top: parent.top
        maxHeight: parent.height - y - parentToolInsets.bottomEdgeLeftInset - _toolsMargin
        visible: false  // Hidden since actions are now in horizontal panel above bottom bar
        z: QGroundControl.zOrderWidgets

        onDisplayPreFlightChecklist: {
            if (!preFlightChecklistLoader.active) {
                preFlightChecklistLoader.active = true;
            }
            preFlightChecklistLoader.item.open();
        }
    }

    // Camera/Video Control - Moved to Left Side
    Loader {
        id:                 photoVideoControlLoader
        anchors.left:       parent.left
        anchors.leftMargin: _toolsMargin
        anchors.top:        parent.top
        anchors.topMargin:  _toolsMargin + ScreenTools.defaultFontPixelHeight * 2 // Clear status text if needed
        z:                  QGroundControl.zOrderWidgets
        visible:            mapControl.pipState.state !== mapControl.pipState.fullState
        
        sourceComponent:    _activeVehicle && _activeVehicle.cameraManager ? photoVideoControlComponent : undefined

        Component {
            id: photoVideoControlComponent

            PhotoVideoControl {
            }
        }
    }
    VehicleWarnings {
        anchors.centerIn: parent
        z: QGroundControl.zOrderTopMost
    }
    MapScale {
        id: mapScale

        property real topEdgeCenterInset: visible ? y + height : 0

        anchors.left: toolStrip.right
        anchors.top: parent.top
        autoHide: true
        mapControl: _mapControl
        visible: !ScreenTools.isTinyScreen && QGroundControl.corePlugin.options.flyView.showMapScale && !isViewer3DOpen && mapControl.pipState.state === mapControl.pipState.fullState
    }
    Loader {
        id: preFlightChecklistLoader

        active: false
        sourceComponent: preFlightChecklistPopup
    }
    Component {
        id: preFlightChecklistPopup

        FlyViewPreFlightChecklistPopup {
        }
    }

    // === TERRAIN FLOW OVERLAY (System Module Card Style) ===
    Rectangle {
        id: terrainFlowOverlay

        property bool active: false
        property real animPhase: 0
        property real timeoutMs: 3000
        // Centered on screen, shifted up to clear action buttons
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -parent.height * 0.15
        border.color: Qt.rgba(1, 1, 1, 0.1)
        border.width: 1
        clip: false

        color: "#0B140B" // Deep dark green background
        height: ScreenTools.defaultFontPixelHeight * 13

        // Shadow effect
        layer.enabled: true
        radius: ScreenTools.defaultFontPixelWidth
        visible: false
        width: ScreenTools.defaultFontPixelHeight * 26
        z: QGroundControl.zOrderTopMost + 100

        layer.effect: DropShadow {
            color: "#80000000"
            horizontalOffset: 0
            radius: 20
            samples: 17
            verticalOffset: 0
        }

        // Closing Timeout Progress Bar (at the very top)
        Rectangle {
            id: progressBar

            anchors.left: parent.left
            anchors.top: parent.top
            color: "#00ff00"
            height: 3
            radius: parent.radius
            width: parent.width
            z: 10

            PropertyAnimation on width {
                id: progressAnim

                duration: terrainFlowOverlay.timeoutMs
                from: terrainFlowOverlay.width
                running: false
                to: 0
            }
        }
        Timer {
            id: overlayTimer

            interval: terrainFlowOverlay.timeoutMs
            repeat: false

            onTriggered: {
                terrainFlowOverlay.visible = false;
                animLoop.stop();
            }
        }

        // Animation Loop
        Timer {
            id: animLoop

            interval: 16
            repeat: true
            running: false

            onTriggered: {
                terrainFlowOverlay.animPhase += 2;
            }
        }
        Connections {
            function onTerrainFlowActiveChanged() {
                if (bottomBar.terrainFlowActive) {
                    terrainFlowOverlay.visible = true;
                    terrainFlowOverlay.animPhase = 0;
                    animLoop.start();
                    overlayTimer.restart();
                    progressAnim.restart();
                } else {
                    terrainFlowOverlay.visible = false;
                    overlayTimer.stop();
                    animLoop.stop();
                    progressAnim.stop();
                }
            }

            target: bottomBar
        }

        // === SEAMLESS BACKGROUND VISUALIZER ===
        Canvas {
            id: terrainSeamlessCanvas

            property real amp: height * 0.08
            property real freq: 0.02
            property real offset: terrainFlowOverlay.animPhase

            anchors.fill: parent

            onOffsetChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.clearRect(0, 0, width, height);

                // Helper for rounded rects
                function roundedRect(ctx, x, y, width, height, radius) {
                    ctx.beginPath();
                    ctx.moveTo(x + radius, y);
                    ctx.lineTo(x + width - radius, y);
                    ctx.quadraticCurveTo(x + width, y, x + width, y + radius);
                    ctx.lineTo(x + width, y + height - radius);
                    ctx.quadraticCurveTo(x + width, y + height, x + width - radius, y + height);
                    ctx.lineTo(x + radius, y + height);
                    ctx.quadraticCurveTo(x, y + height, x, y + height - radius);
                    ctx.lineTo(x, y + radius);
                    ctx.quadraticCurveTo(x, y, x + radius, y);
                    ctx.closePath();
                }

                // 1. Grid Background
                ctx.strokeStyle = "#006633";
                ctx.lineWidth = 1;
                ctx.globalAlpha = 0.1;

                var gridSize = ScreenTools.defaultFontPixelHeight * 1.5;

                for (var x = 0; x < width; x += gridSize) {
                    ctx.beginPath();
                    ctx.moveTo(x, 0);
                    ctx.lineTo(x, height);
                    ctx.stroke();
                }
                for (var y = 0; y < height; y += gridSize) {
                    ctx.beginPath();
                    ctx.moveTo(0, y);
                    ctx.lineTo(width, y);
                    ctx.stroke();
                }

                ctx.globalAlpha = 1.0;

                // Constants for Wave/Drone
                var waveCenterY = height * 0.65; // Lowered from 0.55

                // 2. Wave
                ctx.strokeStyle = "#88AA88";
                ctx.lineWidth = 1.5;
                ctx.beginPath();
                ctx.moveTo(0, waveCenterY);
                for (var wx = 0; wx <= width; wx += 2) {
                    var wy = waveCenterY + Math.sin((wx + offset) * freq) * amp;
                    ctx.lineTo(wx, wy);
                }
                ctx.stroke();
                ctx.lineTo(width, height);
                ctx.lineTo(0, height);
                ctx.closePath();

                var grad = ctx.createLinearGradient(0, 0, 0, height);
                grad.addColorStop(0, "rgba(0, 80, 0, 0.1)");
                grad.addColorStop(1, "rgba(0, 120, 0, 0.4)");
                ctx.fillStyle = grad;
                ctx.fill();

                // 3. Drone Logic
                var droneX = width / 2;
                var waveYAtDrone = waveCenterY + Math.sin((droneX + offset) * freq) * amp;

                // Increased distance from terrain (was 2.2, now 3.5)
                var droneY = waveYAtDrone - (ScreenTools.defaultFontPixelHeight * 3.5);

                // Height Line
                ctx.strokeStyle = "#00ff00";
                ctx.globalAlpha = 0.3;
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.moveTo(droneX, droneY + ScreenTools.defaultFontPixelHeight * 0.5); // Bottom of drone approx
                ctx.lineTo(droneX, waveYAtDrone);
                ctx.stroke();
                ctx.globalAlpha = 1.0;

                // Wave Point Marker
                ctx.fillStyle = "#00ff00";
                ctx.beginPath();
                ctx.arc(droneX, waveYAtDrone, 2, 0, 2 * Math.PI);
                ctx.fill();

                // Drone Draw
                var dH = ScreenTools.defaultFontPixelHeight;
                var dW = dH * 4;
                var dX = droneX - dW / 2;
                var dY = droneY;

                // Arm (White)
                ctx.fillStyle = "white";
                ctx.fillRect(dX, dY + dH / 2 - 1, dW, 2);

                // Animated Rotor Logic
                // Draw 3 dots per rotor side, cycling opacity
                var rotorW = dW * 0.35;
                var dotCount = 3;
                var dotW = rotorW / dotCount - 2;
                var dotH = 3;
                var animIdx = Math.floor(offset / 3);

                function drawRotorDots(startX, startY) {
                    for (var i = 0; i < dotCount; i++) {
                        var active = (animIdx + i) % dotCount === 0;
                        ctx.globalAlpha = active ? 1.0 : 0.3;
                        ctx.fillStyle = "#00ff00";
                        roundedRect(ctx, startX + i * (dotW + 2), startY, dotW, dotH, 1);
                        ctx.fill();
                    }
                    ctx.globalAlpha = 1.0;
                }

                // Top-Left (Outside by 4px)
                drawRotorDots(dX - 4, dY + dH / 2 - 6);
                // Bottom-Left (Outside by 4px)
                drawRotorDots(dX - 4, dY + dH / 2 + 3);
                // Top-Right (Outside by 4px)
                drawRotorDots(dX + dW - rotorW + 4, dY + dH / 2 - 6);
                // Bottom-Right (Outside by 4px)
                drawRotorDots(dX + dW - rotorW + 4, dY + dH / 2 + 3);

                // Body (Green)
                ctx.fillStyle = "#00ff00";
                var bW = dW * 0.6;
                var bH = dH * 0.4;
                roundedRect(ctx, dX + (dW - bW) / 2, dY + (dH - bH) / 2, bW, bH, 4);
                ctx.fill();

                // 4. Label "2.5m"
                var lX = dX + dW + 8;
                var lY = dY + dH / 2 - 7;
                var lW = 35;
                var lH = 14;

                ctx.fillStyle = "#00cc00";
                roundedRect(ctx, lX, lY, lW, lH, 3);
                ctx.fill();

                // Text
                ctx.fillStyle = "black";
                ctx.font = "bold 9px " + ScreenTools.normalFontFamily;
                ctx.textAlign = "center";
                ctx.textBaseline = "middle";
                ctx.fillText("2.5m", lX + lW / 2, lY + lH / 2);
            }
        }

        // --- CONTENT LAYOUT ---
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: ScreenTools.defaultFontPixelWidth * 1.5
            anchors.topMargin: ScreenTools.defaultFontPixelHeight * 1.2
            spacing: ScreenTools.defaultFontPixelHeight * 0.5

            // Header Section
            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    color: "white"
                    font.bold: true
                    font.family: ScreenTools.normalFontFamily
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 1.3
                    text: "TERRAIN FLOW"
                }

                // Active Badge
                Rectangle {
                    border.color: "#00cc00"
                    border.width: 1
                    color: "#1a4d1a"
                    height: ScreenTools.defaultFontPixelHeight * 1.5
                    radius: height / 2
                    width: ScreenTools.defaultFontPixelHeight * 5

                    Item {
                        anchors.centerIn: parent
                        height: parent.height
                        width: statusDot.width + 6 + statusText.width

                        Rectangle {
                            id: statusDot

                            anchors.verticalCenter: parent.verticalCenter
                            color: "#00ff00"
                            height: 8
                            radius: 4
                            width: 8

                            SequentialAnimation on opacity {
                                loops: Animation.Infinite

                                NumberAnimation {
                                    duration: 800
                                    from: 1
                                    to: 0.4
                                }
                                NumberAnimation {
                                    duration: 800
                                    from: 0.4
                                    to: 1
                                }
                            }
                        }
                        Text {
                            id: statusText

                            anchors.left: statusDot.right
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            color: "#00ff00"
                            font.bold: true
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.75
                            text: "ACTIVE"
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }

            // Visualizer Section (Now handled by background Canvas)
            Item {
                Layout.fillHeight: true
                Layout.fillWidth: true
            }

            // Footer Section
            RowLayout {
                Layout.fillWidth: true
                spacing: 20

                Text {
                    Layout.fillWidth: true
                    color: "#aaaaaa"
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.8
                    text: "Terrain flow adjust the height of the drone relative to the ground using LiDaR."
                    wrapMode: Text.WordWrap
                }

                // Max Speed Badge
                Rectangle {
                    border.color: "#00cc00"
                    border.width: 1
                    color: "#334433"
                    height: ScreenTools.defaultFontPixelHeight * 1.5
                    radius: 4
                    width: ScreenTools.defaultFontPixelHeight * 8

                    Text {
                        anchors.centerIn: parent
                        color: "#00ff00"
                        font.bold: true
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.75
                        text: "MAX SPEED: 3m/s"
                    }
                }
            }
        }
    }

    // === OBSTACLE AVOIDANCE OVERLAY ===
    Rectangle {
        id: obstacleAvoidanceOverlay

        property real animPhase: 0
        property real timeoutMs: 3000
        // Centered on screen, shifted up to clear action buttons
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -parent.height * 0.15
        border.color: Qt.rgba(1, 1, 1, 0.1)
        border.width: 1
        clip: false
        color: "#140B0B" // Deep dark red background
        height: ScreenTools.defaultFontPixelHeight * 13
        layer.enabled: true
        radius: ScreenTools.defaultFontPixelWidth
        visible: false
        width: ScreenTools.defaultFontPixelHeight * 26
        z: QGroundControl.zOrderTopMost + 100

        layer.effect: DropShadow {
            color: "#80000000"
            radius: 20
            samples: 17
        }

        // Timeout Progress Bar
        Rectangle {
            id: oaProgressBar

            anchors.left: parent.left
            anchors.top: parent.top
            color: "#ff4444"
            height: 2
            width: 0

            PropertyAnimation {
                id: oaProgressAnim

                duration: obstacleAvoidanceOverlay.timeoutMs
                from: obstacleAvoidanceOverlay.width
                property: "width"
                target: oaProgressBar
                to: 0
            }
        }
        Timer {
            id: oaOverlayTimer

            interval: obstacleAvoidanceOverlay.timeoutMs

            onTriggered: {
                obstacleAvoidanceOverlay.visible = false;
                oaAnimLoop.stop();
                oaProgressAnim.stop();
            }
        }
        NumberAnimation {
            id: oaAnimLoop

            duration: 2000
            from: 0
            loops: Animation.Infinite
            property: "animPhase"
            target: obstacleAvoidanceOverlay
            to: 100
        }
        Connections {
            function onObstacleAvoidanceActiveChanged() {
                if (bottomBar.obstacleAvoidanceActive) {
                    obstacleAvoidanceOverlay.visible = true;
                    obstacleAvoidanceOverlay.animPhase = 0;
                    oaAnimLoop.start();
                    oaOverlayTimer.restart();
                    oaProgressAnim.restart();
                } else {
                    obstacleAvoidanceOverlay.visible = false;
                    oaOverlayTimer.stop();
                    oaAnimLoop.stop();
                    oaProgressAnim.stop();
                }
            }

            target: bottomBar
        }

        // === SEAMLESS BACKGROUND VISUALIZER ===
        Canvas {
            id: radarCanvas

            property real phase: obstacleAvoidanceOverlay.animPhase

            anchors.fill: parent

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.clearRect(0, 0, width, height);

                var t = phase / 100.0;

                // Centering logic for full-modal canvas
                var centerY = height / 2 + 10; // Slightly lower than true center to clear header
                var startX = 50;
                var endX = width - 50;

                // Bezier path control points (Adjusted for full modal width)
                var p0 = {
                    x: startX,
                    y: centerY
                };
                var p1 = {
                    x: width * 0.35,
                    y: centerY - 55
                };
                var p2 = {
                    x: width * 0.65,
                    y: centerY + 55
                };
                var p3 = {
                    x: endX,
                    y: centerY
                };

                function getBezier(t) {
                    var cx = 3 * (p1.x - p0.x);
                    var bx = 3 * (p2.x - p1.x) - cx;
                    var ax = p3.x - p0.x - cx - bx;
                    var cy = 3 * (p1.y - p0.y);
                    var by = 3 * (p2.y - p1.y) - cy;
                    var ay = p3.y - p0.y - cy - by;
                    var x = ax * Math.pow(t, 3) + bx * Math.pow(t, 2) + cx * t + p0.x;
                    var y = ay * Math.pow(t, 3) + by * Math.pow(t, 2) + cy * t + p0.y;
                    return {
                        x: x,
                        y: y
                    };
                }

                function getTangent(t) {
                    var cx = 3 * (p1.x - p0.x);
                    var bx = 3 * (p2.x - p1.x) - cx;
                    var ax = p3.x - p0.x - cx - bx;
                    var cy = 3 * (p1.y - p0.y);
                    var by = 3 * (p2.y - p1.y) - cy;
                    var ay = p3.y - p0.y - cy - by;
                    var dx = 3 * ax * Math.pow(t, 2) + 2 * bx * t + cx;
                    var dy = 3 * ay * Math.pow(t, 2) + 2 * by * t + cy;
                    return Math.atan2(dy, dx);
                }

                var curPos = getBezier(t);
                var curAngle = getTangent(t);

                // 1. Draw Static Path (Faded background path)
                ctx.strokeStyle = "rgba(255, 68, 68, 0.15)";
                ctx.lineWidth = 1.5;
                ctx.beginPath();
                ctx.moveTo(p0.x, p0.y);
                ctx.bezierCurveTo(p1.x, p1.y, p2.x, p2.y, p3.x, p3.y);
                ctx.stroke();

                // 2. FOV Shaded area (attached to moving drone)
                ctx.save();
                ctx.translate(curPos.x, curPos.y);
                ctx.rotate(curAngle);

                var fovSize = 90 * Math.PI / 180;
                ctx.beginPath();
                ctx.moveTo(0, 0);
                ctx.arc(0, 0, width * 0.45, -fovSize / 2, fovSize / 2);
                ctx.closePath();
                var fovGrad = ctx.createRadialGradient(0, 0, 0, 0, 0, width * 0.45);
                fovGrad.addColorStop(0, "rgba(255, 0, 0, 0.05)");
                fovGrad.addColorStop(1, "rgba(255, 0, 0, 0.18)");
                ctx.fillStyle = fovGrad;
                ctx.fill();
                ctx.restore();

                // 3. Grid Background (Drawing in Canvas for seamless look)
                ctx.strokeStyle = "rgba(102, 0, 0, 0.15)";
                ctx.lineWidth = 1;
                var gridSize = ScreenTools.defaultFontPixelHeight * 1.5;
                for (var x = 0; x < width; x += gridSize) {
                    ctx.beginPath();
                    ctx.moveTo(x, 0);
                    ctx.lineTo(x, height);
                    ctx.stroke();
                }
                for (var y = 0; y < height; y += gridSize) {
                    ctx.beginPath();
                    ctx.moveTo(0, y);
                    ctx.lineTo(width, y);
                    ctx.stroke();
                }

                // 4. Multiple Obstacles (Static Positions - Bleeding into edges)
                var obstacles = [
                    {
                        x: width * 0.38,
                        y: centerY - 52,
                        label: "OBJ-01"
                    },
                    {
                        x: width * 0.62,
                        y: centerY + 58,
                        label: "OBJ-02"
                    }
                ];

                obstacles.forEach(function (obj, i) {
                    var pulse = Math.sin(phase * 0.2 + i) * 2;
                    var distToDrone = Math.sqrt(Math.pow(obj.x - curPos.x, 2) + Math.pow(obj.y - curPos.y, 2));

                    if (distToDrone < width * 0.4) {
                        ctx.beginPath();
                        ctx.moveTo(curPos.x, curPos.y);
                        ctx.lineTo(obj.x, obj.y);
                        ctx.strokeStyle = "rgba(255, 0, 0, " + (0.25 * (1 - distToDrone / (width * 0.4))) + ")";
                        ctx.lineWidth = 1;
                        ctx.stroke();
                    }

                    // Obstacle Dot
                    ctx.fillStyle = "#ff4444";
                    ctx.beginPath();
                    ctx.arc(obj.x, obj.y, 6 + pulse, 0, Math.PI * 2);
                    ctx.fill();

                    // Obstacle Label
                    ctx.fillStyle = "#ff4444";
                    ctx.font = "bold 9px " + ScreenTools.fixedFontFamily;
                    ctx.textAlign = "center";
                    ctx.fillText(obj.label, obj.x, obj.y - 12);
                });

                // 5. Moving Drone Icon
                ctx.save();
                ctx.translate(curPos.x, curPos.y);
                ctx.rotate(curAngle + Math.PI / 2);

                ctx.fillStyle = "#ffffff";
                ctx.beginPath();
                ctx.moveTo(0, -10);
                ctx.lineTo(-8, 8);
                ctx.lineTo(0, 4);
                ctx.lineTo(8, 8);
                ctx.closePath();
                ctx.fill();

                ctx.strokeStyle = "#aaaaaa";
                ctx.lineWidth = 1;
                for (var i = 0; i < 4; i++) {
                    var angle = Math.PI / 4 + (i * Math.PI / 2);
                    var rx = Math.cos(angle) * 12;
                    var ry = Math.sin(angle) * 12;
                    ctx.beginPath();
                    ctx.moveTo(0, 0);
                    ctx.lineTo(rx, ry);
                    ctx.stroke();
                    ctx.beginPath();
                    ctx.arc(rx, ry, 4, 0, Math.PI * 2);
                    ctx.stroke();
                }
                ctx.restore();

                // FOV Indicator
                ctx.strokeStyle = "rgba(255, 255, 255, 0.3)";
                ctx.strokeRect(width - 55, 35, 45, 18);
                ctx.fillStyle = "white";
                ctx.font = "9px " + ScreenTools.normalFontFamily;
                ctx.fillText("FOV: 90°", width - 52, 47);
            }
            onPhaseChanged: requestPaint()
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: ScreenTools.defaultFontPixelWidth * 1.5
            anchors.topMargin: ScreenTools.defaultFontPixelHeight * 1.2
            spacing: ScreenTools.defaultFontPixelHeight * 0.5

            // Header Section
            RowLayout {
                Layout.fillWidth: true

                Text {
                    color: "white"
                    font.bold: true
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 1.3
                    text: "OBSTACLE AVOIDANCE"
                }
                Item {
                    Layout.fillWidth: true
                }

                // Active Badge
                Rectangle {
                    border.color: "#cc0000"
                    border.width: 1
                    color: "#4a1a1a"
                    height: ScreenTools.defaultFontPixelHeight * 1.5
                    radius: height / 2
                    width: ScreenTools.defaultFontPixelHeight * 5

                    Item {
                        anchors.centerIn: parent
                        height: parent.height
                        width: oaStatusDot.width + 6 + oaStatusText.width

                        Rectangle {
                            id: oaStatusDot

                            anchors.verticalCenter: parent.verticalCenter
                            color: "#ff4444"
                            height: 8
                            radius: 4
                            width: 8

                            SequentialAnimation on opacity {
                                loops: Animation.Infinite

                                NumberAnimation {
                                    duration: 800
                                    from: 1
                                    to: 0.4
                                }
                                NumberAnimation {
                                    duration: 800
                                    from: 0.4
                                    to: 1
                                }
                            }
                        }
                        Text {
                            id: oaStatusText

                            anchors.left: oaStatusDot.right
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            color: "#ff4444"
                            font.bold: true
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.75
                            text: bottomBar.obstacleAvoidanceActive ? "ACTIVE" : "OFF"
                        }
                    }
                }
            }

            // Middle Spacing (Canvas draws behind this)
            Item {
                Layout.fillHeight: true
                Layout.fillWidth: true
            }

            // Footer Section
            RowLayout {
                Layout.fillWidth: true
                spacing: 20

                Text {
                    Layout.fillWidth: true
                    color: "#aaaaaa"
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.8
                    text: "Obstacle Avoidance system detects near field objects and adjusts path automatically."
                    wrapMode: Text.WordWrap
                }

                // Mode Badge
                Rectangle {
                    border.color: "#cc4444"
                    border.width: 1
                    color: "#443333"
                    height: ScreenTools.defaultFontPixelHeight * 1.5
                    radius: 4
                    width: ScreenTools.defaultFontPixelHeight * 8

                    Text {
                        anchors.centerIn: parent
                        color: "#ff4444"
                        font.bold: true
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.75
                        text: "MODE: BRAKE"
                    }
                }
            }
        }
    }
}
