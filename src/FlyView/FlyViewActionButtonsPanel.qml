pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

// Individual action button islands positioned above telemetry section
Item {
    id: root

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    property var actionModel: null
    property real maxVisibleWidth: ScreenTools.defaultFontPixelWidth * 50
    property real _buttonHeight: ScreenTools.defaultFontPixelHeight * 1.85
    property real _buttonSpacing: ScreenTools.defaultFontPixelWidth

    implicitHeight: _buttonHeight
    width: needsScroll ? maxVisibleWidth : Math.min(maxVisibleWidth, buttonRow.width)
    implicitWidth: width

    // Calculate if scrolling is needed
    property bool needsScroll: buttonRow.width > maxVisibleWidth

    // Shared drop panel for actions like "Additional Actions"
    Popup {
        id: dropPanel

        property var sourceButton: null
        property bool showBelow: false
        property var _closeTime: 0

        onClosed: _closeTime = Date.now()

        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: ScreenTools.defaultFontPixelWidth * 0.8
        y: -height - ScreenTools.defaultFontPixelHeight * 0.5

        background: Rectangle {
            id: dropPanelBg
            border.color: qgcPal.globalTheme === QGCPalette.Light ? Qt.rgba(0.8, 0.85, 0.8, 0.8) : Qt.rgba(0.3, 0.5, 0.3, 0.6)
            border.width: 1
            color: qgcPal.globalTheme === QGCPalette.Light ? Qt.rgba(0.97, 0.97, 0.97, 0.97) : Qt.rgba(0.06, 0.08, 0.06, 0.97)
            radius: ScreenTools.defaultFontPixelHeight * 0.5

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: 0.7
                shadowVerticalOffset: 4
                shadowBlur: 0.8
            }

            // Pointer triangle pointing down/up
            Canvas {
                id: dropPanelPointer
                anchors.top: dropPanel.showBelow ? undefined : parent.bottom
                anchors.bottom: dropPanel.showBelow ? parent.top : undefined
                anchors.topMargin: dropPanel.showBelow ? 0 : -1
                anchors.bottomMargin: dropPanel.showBelow ? -1 : 0
                anchors.horizontalCenter: parent.horizontalCenter
                width: ScreenTools.defaultFontPixelHeight * 1.2
                height: ScreenTools.defaultFontPixelHeight * 0.6

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = dropPanelBg.color;
                    ctx.strokeStyle = dropPanelBg.border.color;
                    ctx.lineWidth = 1;
                    ctx.beginPath();
                    if (dropPanel.showBelow) {
                        ctx.moveTo(0, height);
                        ctx.lineTo(width / 2, 0);
                        ctx.lineTo(width, height);
                    } else {
                        ctx.moveTo(0, 0);
                        ctx.lineTo(width / 2, height);
                        ctx.lineTo(width, 0);
                    }
                    ctx.closePath();
                    ctx.fill();
                    ctx.stroke();
                }

                Connections {
                    target: dropPanel
                    function onShowBelowChanged() { dropPanelPointer.requestPaint(); }
                }
            }
        }

        contentItem: Loader {
            id: dropPanelLoader
            width: item ? Math.max(item.width, ScreenTools.defaultFontPixelWidth * 24) : ScreenTools.defaultFontPixelWidth * 24
            onLoaded: {
                if (item && ("popupRef" in item)) {
                    item.popupRef = dropPanel;
                }
            }
        }

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 150; easing.type: Easing.OutCubic }
            NumberAnimation { property: "y"; from: dropPanel.y + 10; to: dropPanel.y; duration: 150; easing.type: Easing.OutCubic }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 100; easing.type: Easing.InCubic }
        }
    }

    // --- SCROLL INDICATORS (Clean Floating Arrows) ---

    // Left Floating Arrow
    Item {
        id: leftScrollIndicator
        anchors.left: parent.left
        anchors.leftMargin: -ScreenTools.defaultFontPixelWidth * 0.5
        anchors.verticalCenter: parent.verticalCenter
        width: ScreenTools.defaultFontPixelWidth * 3
        height: root._buttonHeight
        z: 40
        visible: root.needsScroll && flickable.contentX > 10

        Text {
            anchors.centerIn: parent
            color: "#6beb17"
            font.weight: Font.Light
            font.pixelSize: ScreenTools.defaultFontPixelHeight * 1.65
            text: "‹"
            style: Text.Outline; styleColor: "black"
            
            SequentialAnimation on anchors.horizontalCenterOffset {
                loops: Animation.Infinite
                running: leftScrollIndicator.visible
                NumberAnimation { from: 1; to: -2; duration: 800; easing.type: Easing.OutQuad }
                NumberAnimation { from: -2; to: 1; duration: 800; easing.type: Easing.InQuad }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: flickable.flick(1200, 0)
        }
    }

    // Right Floating Arrow
    Item {
        id: rightScrollIndicator
        anchors.right: parent.right
        anchors.rightMargin: -ScreenTools.defaultFontPixelWidth * 0.5
        anchors.verticalCenter: parent.verticalCenter
        width: ScreenTools.defaultFontPixelWidth * 3
        height: root._buttonHeight
        z: 40
        visible: root.needsScroll && flickable.contentX < (flickable.contentWidth - flickable.width - 10)

        Text {
            anchors.centerIn: parent
            color: "#6beb17"
            font.weight: Font.Light
            font.pixelSize: ScreenTools.defaultFontPixelHeight * 1.65
            text: "›"
            style: Text.Outline; styleColor: "black"
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: flickable.flick(-1200, 0)
        }
    }

    // --- BUTTONS VIEW WITH FADE MASK ---
    Item {
        id: interactiveContainer
        anchors.fill: parent
        
        // Use layer-based mask to ensure the Flickable remains interactive
        layer.enabled: root.needsScroll
        layer.effect: OpacityMask {
            maskSource: maskEffectSource
        }

        Flickable {
            id: flickable
            anchors.fill: parent
            contentWidth: buttonRow.width
            contentHeight: height
            clip: true
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds

            // Start at the right for right-aligned feel
            onContentWidthChanged: {
                if (root.needsScroll && (!contentX || contentX === 0)) {
                    contentX = contentWidth - width;
                }
            }

            Row {
                id: buttonRow
                spacing: root._buttonSpacing
                // Anchor to right if not scrolling to ensure right-alignment
                anchors.right: !root.needsScroll ? parent.right : undefined
                leftPadding: root.needsScroll ? ScreenTools.defaultFontPixelWidth * 3 : 0
                rightPadding: root.needsScroll ? ScreenTools.defaultFontPixelWidth * 3 : 0

                Repeater {
                    id: actionRepeater

                    model: {
                        var actions = [];
                        if (root.actionModel) {
                            for (var i = 0; i < root.actionModel.length; i++) {
                                var item = root.actionModel[i];
                                if (!item) continue;
                                var txt = item.text ? item.text.toLowerCase() : "";
                                if (txt.includes("3d view") || txt.includes("checklist")) continue;

                                function getWeight(txt) {
                                    if (!txt) return 100;
                                    txt = txt.toLowerCase();
                                    if (txt.includes("actions") || txt.includes("gripper")) return 0;
                                    if (txt.includes("takeoff") || txt.includes("start")) return 10;
                                    if (txt.includes("rtl") || txt.includes("return")) return 15;
                                    if (txt.includes("pause") || txt.includes("resume")) return 18;
                                    if (txt.includes("land") || txt.includes("end")) return 20;
                                    return 22;
                                }
                                var weight = getWeight(txt);
                                actions.push({ obj: item, weight: weight, visible: item.visible });
                            }
                        }
                        actions.sort(function (a, b) { return a.weight - b.weight; });
                        return actions;
                    }

                    delegate: Item {
                        id: actionButton
                        required property int index
                        required property var modelData
                        readonly property var actionObject: modelData.obj
                        property bool isPrimary: modelData.weight <= 20
                        property bool isActionsButton: {
                            var txt = modelData.obj && modelData.obj.text ? modelData.obj.text.toLowerCase() : "";
                            return txt.includes("actions");
                        }
                        readonly property color contentColor: {
                            if (!actionObject || !actionObject.enabled) {
                                return "white"
                            }
                            var txt = actionObject.text ? actionObject.text.toLowerCase() : ""
                            return "white"
                        }

                        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                        height: root._buttonHeight
                        visible: modelData.obj.visible
                        width: Math.max(buttonContent.width + ScreenTools.defaultFontPixelWidth * 3.0, height * 2.1)

                        // Transparent overlay style to match the Fly View layout.
                        Rectangle {
                            anchors.fill: parent
                            radius: ScreenTools.defaultFontPixelWidth * 0.45
                            color: mouseArea.pressed ? Qt.rgba(0, 0, 0, 0.46) : Qt.rgba(0, 0, 0, 0.28)
                            border.color: Qt.rgba(1, 1, 1, 0.18)
                            border.width: 1
                        }

                        scale: mouseArea.pressed ? 0.97 : (mouseArea.containsMouse ? 1.03 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                        Row {
                            id: buttonContent
                            anchors.centerIn: parent
                            spacing: ScreenTools.defaultFontPixelWidth * 0.55

                            QGCColoredImage {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: source.toString() !== ""
                                source: actionButton.actionObject ? actionButton.actionObject.iconSource : ""
                                width: ScreenTools.defaultFontPixelHeight * 0.92
                                height: width
                                color: actionButton.contentColor
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }

                            Text {
                                id: labelText
                                anchors.verticalCenter: parent.verticalCenter
                                text: actionButton.actionObject ? actionButton.actionObject.text : ""
                                color: actionButton.contentColor
                                font.weight: Font.Black
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.56
                                font.capitalization: Font.MixedCase
                                font.family: "Noto Sans"
                                style: Text.Outline
                                styleColor: Qt.rgba(0, 0, 0, 0.45)
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: actionButton.isActionsButton
                                text: "▾"
                                color: labelText.color
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.52
                            }
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            cursorShape: (actionButton.actionObject && actionButton.actionObject.enabled) ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                            hoverEnabled: true
                            enabled: actionButton.actionObject ? actionButton.actionObject.enabled : false

                            onClicked: {
                                if (!actionButton.actionObject) return;
                                if (actionButton.actionObject.dropPanelComponent) {
                                    var now = Date.now();
                                    // If already open on THIS button, close it.
                                    if (dropPanel.opened && dropPanel.sourceButton === actionButton) {
                                        dropPanel.close();
                                        return;
                                    }
                                    
                                    // If it just closed (likely due to PressOutside on this same button), don't re-open.
                                    if (!dropPanel.opened && dropPanel.sourceButton === actionButton && (now - dropPanel._closeTime < 300)) {
                                        dropPanel.sourceButton = null;
                                        return;
                                    }

                                    dropPanelLoader.sourceComponent = actionButton.actionObject.dropPanelComponent;
                                    Qt.callLater(function() {
                                        var buttonLocalPos = actionButton.mapToItem(root, actionButton.width / 2, 0);
                                        var buttonGlobalPos = actionButton.mapToItem(null, 0, 0);
                                        var popupHeight = dropPanel.contentHeight > 0 ? dropPanel.contentHeight + dropPanel.padding * 2 : ScreenTools.defaultFontPixelHeight * 12;
                                        
                                        // Decide above or below
                                        // If there is less than popupHeight + margin space above the button, show below
                                        dropPanel.showBelow = (buttonGlobalPos.y < popupHeight + ScreenTools.defaultFontPixelHeight * 2);

                                        dropPanel.x = Math.max(-ScreenTools.defaultFontPixelWidth * 20,
                                                               Math.min(buttonLocalPos.x - dropPanel.width / 2,
                                                                        root.width - dropPanel.width + ScreenTools.defaultFontPixelWidth * 20));
                                        
                                        if (dropPanel.showBelow) {
                                            dropPanel.y = actionButton.height + ScreenTools.defaultFontPixelHeight * 0.5;
                                        } else {
                                            dropPanel.y = -popupHeight - ScreenTools.defaultFontPixelHeight * 0.5;
                                        }

                                        dropPanel.sourceButton = actionButton;
                                        dropPanel.open();
                                    });
                                } else {
                                    if (typeof actionButton.actionObject.triggered === "function") {
                                        actionButton.actionObject.triggered(actionButton);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: maskEffectSource
        anchors.fill: parent
        visible: false
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: root.needsScroll && flickable.contentX > 10 ? "transparent" : "white" }
            GradientStop { position: 0.15; color: "white" }
            GradientStop { position: 0.85; color: "white" }
            GradientStop { position: 1.0; color: root.needsScroll && flickable.contentX < (flickable.contentWidth - flickable.width - 10) ? "transparent" : "white" }
        }
    }
}
