import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import QGroundControl
import QGroundControl.Controls
import QGroundControl.ScreenTools
import QGroundControl.FactControls

Item {
    id: control

    // Properties required from parent
    required property var mapToolsRoot
    required property var scalableContainer
    required property var mapEngineManager
    required property var mapProviderFact
    required property var mapTypeFact
    
    // Internal shortcuts
    property bool _mapSettingsVisible: mapToolsRoot._mapSettingsVisible

    anchors.fill: parent

    // ============ ACTIVE TOOL OVERLAY ============
    // This sits ABOVE the scalable container and holds the "Active" Map Button
    // It does NOT scale (Scale 1.0), enhancing the focus effect.
    Item {
        id: activeToolOverlay
        
        // Anchor to the right side of the root, mimicking the layout.
        anchors.right: parent.right
        anchors.rightMargin: ScreenTools.defaultFontPixelWidth // The padding
        
        // Vertical Position:
        // Since we scale from TopRight, the Top edge is fixed at 0.
        // The center of the button in the scaled container moves up.
        // CenterY (Unscaled) = parent.height / 2
        // CenterY (Scaled) = (parent.height / 2) * scale
        // So we position the overlay centroid at that Y_Scaled
        y: (parent.height * scalableContainer.scale * 0.5) - (height * 0.5)
        
        width:  ScreenTools.defaultFontPixelHeight * 1.8 // Same as IconButton
        height: width

        visible: _mapSettingsVisible || opacity > 0
        opacity: _mapSettingsVisible ? 1.0 : 0.0
        
        // Instant ON to prevent rounded corners showing. Smooth OFF.
        Behavior on opacity { 
            enabled: !_mapSettingsVisible 
            NumberAnimation { duration: 200 } 
        }
        
        z: 1006 // Above everything else (Overlay is 1005)

        // The White Connector Background
        // It needs to look like it continues into the popup.
        Rectangle {
            id: connectorBg
            anchors.verticalCenter: parent.verticalCenter
            
            // Extend to the right edge of the container (covering the padding)
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.rightMargin: -ScreenTools.defaultFontPixelWidth
            
            // The connector height should seamlessly match the scaled strip height
            height: mapToolsRoot.height * scalableContainer.scale
            
            radius: height * 0.25 // Match root radius (scaled)
            color: "white"
            
            // To ensuring seamless connection, we need to extend the bottom if the popup is below.
            // The popup is below. Layout in `mapSettingsOverlay`.
            
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.radius
                color: "white"                
            }
            // Overlap filler
            Rectangle {
                anchors.top: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: ScreenTools.defaultFontPixelWidth * 0.5 // Overlap
                color: "white"
            }
        }

        // The Active Icon (Black)
        QGCColoredImage {
            // Center within the WHITE BACKGROUND (connectorBg) to appear visually centered in the tab
            anchors.centerIn: connectorBg
            
            width: parent.width * 0.75
            height: width
            source: "/res/modern-icons/MaterialSymbolsStacksRounded.svg"
            color: "black" // High contrast active state
            smooth: true
        }
        
        // Allow clicking the active overlay to dismiss
        MouseArea {
            anchors.fill: parent
            onClicked: mapToolsRoot._mapSettingsVisible = false
            cursorShape: Qt.PointingHandCursor
        }
    }

    // ============ MAP SETTINGS OVERLAY ============

    // Dismiss area — reparented to FlyView, Z below Overlay
    Item {
        visible:        _mapSettingsVisible
        parent:         mapToolsRoot.parent
        anchors.fill:   parent
        z:              1004 // Below overlay (1005)

        MouseArea {
            anchors.fill: parent
            onClicked:  mapToolsRoot._mapSettingsVisible = false
        }
    }

    // Overlay panel
    Rectangle {
        id: mapSettingsOverlay
        // Keep visible while animating out
        visible:    _mapSettingsVisible || opacity > 0
        parent:     mapToolsRoot.parent
        width:      ScreenTools.defaultFontPixelWidth * 42
        
        // Animations for Entry/Exit
        opacity:    _mapSettingsVisible ? 1.0 : 0.0
        scale:      _mapSettingsVisible ? 1.0 : 0.95
        
        transformOrigin: Item.TopRight

        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
        Behavior on scale   { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        // Position relative to the toolbar bottom (Modified for Top-Right Scaling)
        // Visual Bottom of Toolbar = root.y + (root.height * scale)
        x:          mapToolsRoot.x + mapToolsRoot.width - width
        y:          mapToolsRoot.y + (mapToolsRoot.height * scalableContainer.scale)
        height:     overlayContent.height + ScreenTools.defaultFontPixelHeight * 1.6

        color:      "white"
        radius:     ScreenTools.defaultFontPixelWidth * 0.8
        z:          1005 // Fixed high Z, above dismiss area

        // Shadow
        layer.enabled: true
        layer.effect: DropShadow {
            horizontalOffset: 0
            verticalOffset: 4
            radius: 16.0
            samples: 33
            color: "#35000000"
        }

        Column {
            id: overlayContent
            anchors.left:       parent.left
            anchors.right:      parent.right
            anchors.top:        parent.top
            anchors.margins:    ScreenTools.defaultFontPixelHeight * 0.8
            spacing:            ScreenTools.defaultFontPixelHeight * 0.5

            // ---- Provider Section ----
            Text {
                text:           qsTr("Provider")
                color:          "#333333"
                font.pixelSize: ScreenTools.defaultFontPixelSize * 0.85
                font.weight:    Font.DemiBold
                leftPadding:    ScreenTools.defaultFontPixelWidth * 0.2
            }

            // Segmented control for provider
            Rectangle {
                width:  parent.width
                height: ScreenTools.defaultFontPixelHeight * 2.4
                radius: height * 0.2
                color:  "#F0F0F0"

                Row {
                    anchors.fill:    parent
                    anchors.margins: 2

                    Repeater {
                        model: ["Google", "Bing"]

                        Rectangle {
                            width:  parent.width / 2
                            height: parent.height
                            radius: (parent.height) * 0.18
                            color:  mapProviderFact.rawValue === modelData
                                    ? "#2E9B54"
                                    : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text:           modelData
                                color:          mapProviderFact.rawValue === modelData ? "white" : "#555555"
                                font.pixelSize: ScreenTools.defaultFontPixelSize * 0.9
                                font.weight:    mapProviderFact.rawValue === modelData ? Font.DemiBold : Font.Normal
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape:  Qt.PointingHandCursor
                                onClicked: {
                                    mapProviderFact.rawValue = modelData
                                    var types = mapEngineManager.mapTypeList(modelData)
                                    if (types.length > 0) {
                                        mapTypeFact.rawValue = types[0]
                                    }
                                }
                            }

                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                    }
                }
            }

            // Separator
            Rectangle {
                width:  parent.width
                height: 1
                color:  "#E8E8E8"
            }

            // ---- Type Section ----
            Text {
                text:           qsTr("Type")
                color:          "#333333"
                font.pixelSize: ScreenTools.defaultFontPixelSize * 0.85
                font.weight:    Font.DemiBold
                leftPadding:    ScreenTools.defaultFontPixelWidth * 0.2
            }

            // Type grid — preview image cards
            Grid {
                columns:    2
                spacing:    ScreenTools.defaultFontPixelWidth * 0.8
                width:      parent.width

                property real cellWidth: (width - spacing) / 2

                Repeater {
                    model: {
                        var list = mapEngineManager.mapTypeList(mapProviderFact.rawValue)
                        var filtered = []
                        for (var i = 0; i < list.length; i++) {
                            if (list[i] !== "Labels") {
                                filtered.push(list[i])
                            }
                        }
                        return filtered
                    }

                    Rectangle {
                        id: typeCard
                        width:  parent.cellWidth
                        height: ScreenTools.defaultFontPixelHeight * 6.5
                        radius: ScreenTools.defaultFontPixelWidth * 0.6
                        color:  "transparent"
                        border.color: mapTypeFact.rawValue === modelData ? "#2E9B54" : "#E0E0E0"
                        border.width: mapTypeFact.rawValue === modelData ? 2.5 : 1

                        Column {
                            anchors.fill: parent
                            anchors.margins: 2

                            // Preview image
                            Image {
                                width:      parent.width
                                height:     parent.height - typeLabel.height - 2
                                source:     "/res/map-type-previews/" + modelData.toLowerCase().replace(/ /g, "-") + ".png"
                                fillMode:   Image.PreserveAspectCrop
                                smooth:     true
                                mipmap:     true

                                // Rounded top corners via layer
                                layer.enabled: true
                                layer.effect: OpacityMask {
                                    maskSource: Rectangle {
                                        width:  typeCard.width - 4
                                        height: typeCard.height - typeLabel.height - 4
                                        radius: Math.max(0, typeCard.radius - 2)
                                    }
                                }

                                // Checkmark badge
                                Rectangle {
                                    anchors.right:      parent.right
                                    anchors.top:        parent.top
                                    anchors.margins:    4
                                    width:              ScreenTools.defaultFontPixelHeight * 1.3
                                    height:             width
                                    radius:             width / 2
                                    color:              "#2E9B54"
                                    visible:            mapTypeFact.rawValue === modelData

                                    Text {
                                        anchors.centerIn: parent
                                        text:           "✓"
                                        color:          "white"
                                        font.pixelSize: ScreenTools.defaultFontPixelSize * 0.8
                                        font.weight:    Font.Bold
                                    }
                                }
                            }

                            // Label
                            Text {
                                id:                 typeLabel
                                width:              parent.width
                                height:             ScreenTools.defaultFontPixelHeight * 1.6
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment:  Text.AlignVCenter
                                text:               modelData
                                color:              mapTypeFact.rawValue === modelData ? "#2E9B54" : "#555555"
                                font.pixelSize:     ScreenTools.defaultFontPixelSize * 0.85
                                font.weight:        mapTypeFact.rawValue === modelData ? Font.DemiBold : Font.Normal
                            }
                        }

                        MouseArea {
                            anchors.fill:   parent
                            cursorShape:    Qt.PointingHandCursor
                            onClicked:      mapTypeFact.rawValue = modelData
                            onPressed:      parent.scale = 0.96
                            onReleased:     parent.scale = 1.0
                        }

                        Behavior on scale       { NumberAnimation { duration: 80 } }
                        Behavior on border.color { ColorAnimation  { duration: 120 } }
                    }
                }
            }
        }
    }
}
