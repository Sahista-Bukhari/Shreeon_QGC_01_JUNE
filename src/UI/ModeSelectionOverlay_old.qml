import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects

import QGroundControl
import QGroundControl.Controls

Item {
    id:         control
    anchors.fill: parent
    visible:    false
    z:          1000

    property point  startPoint: Qt.point(0, 0)
    property bool   isOpen:     false

    onIsOpenChanged: {
        if (control.isOpen) {
            control.visible = true
            moreMenu.visible = false  // Reset dropdown when modal opens
            openAnim.start()
        } else {
            closeAnim.start()
        }
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    // Dark overlay background
    Rectangle {
        id:             dimBackground
        anchors.fill:   parent
        color:          "black"
        opacity:        0
    }

    // Circular expansion background
    Rectangle {
        id:             circleOverlay
        x:              control.startPoint.x - width / 2
        y:              control.startPoint.y - height / 2
        width:          0
        height:         0
        radius:         width / 2
        color:          qgcPal.window
    }

    // Content Container (Fixed position, not inside circle)
    Item {
        id:             contentContainer
        anchors.fill:   parent
        opacity:        0
        visible:        opacity > 0

            // Close Button (Top Right) - Clean icon
            Item {
                id:                     closeButton
                anchors.top:            parent.top
                anchors.right:          parent.right
                anchors.margins:        ScreenTools.defaultFontPixelHeight * 1.5
                width:                  ScreenTools.defaultFontPixelHeight * 2.5
                height:                 width

                QGCColoredImage {
                    anchors.centerIn:   parent
                    width:              parent.width * 0.6
                    height:             width
                    source:             "/res/XDeleteBlack.svg"
                    color:              qgcPal.text
                    opacity:            closeMouseArea.containsMouse ? 1.0 : 0.7
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
                
                MouseArea {
                    id:                 closeMouseArea
                    anchors.fill:       parent
                    hoverEnabled:       true
                    cursorShape:        Qt.PointingHandCursor
                    onClicked:          control.isOpen = false
                }
            }

            // Top Left Branding
            RowLayout {
                id:                     brandingLayout
                anchors.top:            parent.top
                anchors.left:           parent.left
                anchors.margins:        ScreenTools.defaultFontPixelHeight * 1.5
                spacing:                ScreenTools.defaultFontPixelWidth * 1.5

                Image {
                    source:             "qrc:/ModeSelection/shreeon_logo.png"
                    Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 3
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3
                    fillMode:           Image.PreserveAspectFit
                }

                QGCLabel {
                    text:               "Shreeon Technologies"
                    font.pointSize:     ScreenTools.mediumFontPointSize
                    font.weight:        Font.Medium
                    color:              qgcPal.text
                }
            }

            // Center Content
            Item {
                anchors.centerIn:       parent
                width:                  parent.width * 0.92
                height:                 parent.height * 0.92

                // Title
                QGCLabel {
                    id:                 titleLabel
                    anchors.top:        parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:               qsTr("Select task mode")
                    font.pointSize:     ScreenTools.largeFontPointSize * 1.3
                    font.weight:        Font.DemiBold
                    color:              qgcPal.text
                }

                // Dynamic Grid Container (2x3 grid with selected spanning 2 columns)
                Item {
                    id:                 gridContainer
                    anchors.top:        titleLabel.bottom
                    anchors.topMargin:  ScreenTools.defaultFontPixelHeight * 2
                    anchors.bottom:     bottomControls.top
                    anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    width:              parent.width

                    property int selectedIndex: 0
                    property real cardSpacing: ScreenTools.defaultFontPixelWidth * 2
                    property real rowHeight: (height - cardSpacing) / 2
                    property real singleColWidth: (width - cardSpacing * 2) / 3
                    property real doubleColWidth: singleColWidth * 2 + cardSpacing

                    // Row 1
                    Item {
                        id:             row1
                        anchors.top:    parent.top
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        height:         gridContainer.rowHeight

                        // Card 0 - Agriculture Spraying
                        ModeCard {
                            id:         card0
                            anchors.left: parent.left
                            anchors.top: parent.top
                            width:      gridContainer.selectedIndex === 0 ? gridContainer.doubleColWidth : gridContainer.singleColWidth
                            height:     parent.height
                            title:      qsTr("Agriculture Spraying")
                            imageSource: "qrc:/ModeSelection/agriculture_spraying.png"
                            isSelected: gridContainer.selectedIndex === 0
                            onClicked: {
                                gridContainer.selectedIndex = 0
                                mainWindow.showPlanView()
                                control.isOpen = false
                            }
                            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        }

                        // Card 1 - Route Mapping
                        ModeCard {
                            id:         card1
                            anchors.left: card0.right
                            anchors.leftMargin: gridContainer.cardSpacing
                            anchors.top: parent.top
                            width:      gridContainer.selectedIndex === 1 ? gridContainer.doubleColWidth : gridContainer.singleColWidth
                            height:     parent.height
                            title:      qsTr("Route Mapping")
                            imageSource: "qrc:/ModeSelection/route_mapping.png"
                            isSelected: gridContainer.selectedIndex === 1
                            visible:    gridContainer.selectedIndex !== 0
                            onClicked: {
                                gridContainer.selectedIndex = 1
                                mainWindow.showPlanView()
                                control.isOpen = false
                            }
                            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        }

                        // Card 2 - Seed Spreader
                        ModeCard {
                            id:         card2
                            anchors.right: parent.right
                            anchors.top: parent.top
                            width:      gridContainer.singleColWidth
                            height:     parent.height
                            title:      qsTr("Seed Spreader")
                            imageSource: "qrc:/ModeSelection/seed_spreader.png"
                            isSelected: gridContainer.selectedIndex === 2
                            visible:    gridContainer.selectedIndex !== 0 && gridContainer.selectedIndex !== 1
                            onClicked: {
                                gridContainer.selectedIndex = 2
                                mainWindow.showPlanView()
                                control.isOpen = false
                            }
                        }
                    }

                    // Row 2
                    Item {
                        id:             row2
                        anchors.bottom: parent.bottom
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        height:         gridContainer.rowHeight

                        // Card 2 - Seed Spreader (when selected, moves to row 2)
                        ModeCard {
                            id:         card2Row2
                            anchors.left: parent.left
                            anchors.top: parent.top
                            width:      gridContainer.selectedIndex === 2 ? gridContainer.doubleColWidth : gridContainer.singleColWidth
                            height:     parent.height
                            title:      qsTr("Seed Spreader")
                            imageSource: "qrc:/ModeSelection/seed_spreader.png"
                            isSelected: gridContainer.selectedIndex === 2
                            visible:    gridContainer.selectedIndex === 0 || gridContainer.selectedIndex === 1 || gridContainer.selectedIndex === 2
                            onClicked: {
                                gridContainer.selectedIndex = 2
                                mainWindow.showPlanView()
                                control.isOpen = false
                            }
                            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        }

                        // Card 3 - Custom Mission
                        ModeCard {
                            id:         card3
                            anchors.left: card2Row2.right
                            anchors.leftMargin: gridContainer.cardSpacing
                            anchors.top: parent.top
                            width:      gridContainer.selectedIndex === 3 ? gridContainer.doubleColWidth : gridContainer.singleColWidth
                            height:     parent.height
                            title:      qsTr("Custom Mission")
                            imageSource: "qrc:/ModeSelection/custom_mission.png"
                            isSelected: gridContainer.selectedIndex === 3
                            visible:    gridContainer.selectedIndex !== 2
                            onClicked: {
                                gridContainer.selectedIndex = 3
                                mainWindow.showPlanView()
                                control.isOpen = false
                            }
                            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        }

                        // Card 4 - Manual
                        ModeCard {
                            id:         card4
                            anchors.right: parent.right
                            anchors.top: parent.top
                            width:      gridContainer.selectedIndex === 4 ? gridContainer.doubleColWidth : gridContainer.singleColWidth
                            height:     parent.height
                            title:      qsTr("Manual")
                            imageSource: "qrc:/ModeSelection/manual_mode.png"
                            isSelected: gridContainer.selectedIndex === 4
                            visible:    gridContainer.selectedIndex !== 2 && gridContainer.selectedIndex !== 3
                            onClicked: {
                                gridContainer.selectedIndex = 4
                                mainWindow.showFlyView()
                                control.isOpen = false
                            }
                            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        }
                    }
                }

                // Bottom Controls
                Item {
                    id:                     bottomControls
                    anchors.bottom:         parent.bottom
                    anchors.left:           parent.left
                    anchors.right:          parent.right
                    height:                 ScreenTools.defaultFontPixelHeight * 3

                    // Settings Button (Bottom Left - Flat)
                    Item {
                        id:                     settingsButton
                        anchors.left:           parent.left
                        anchors.bottom:         parent.bottom
                        anchors.leftMargin:     ScreenTools.defaultFontPixelWidth
                        width:                  settingsRow.width
                        height:                 settingsRow.height

                        Row {
                            id:         settingsRow
                            spacing:    ScreenTools.defaultFontPixelWidth * 0.5

                            QGCColoredImage {
                                source:         "/res/gear-black.svg"
                                width:          ScreenTools.defaultFontPixelHeight * 1.5
                                height:         width
                                color:          qgcPal.text
                                fillMode:       Image.PreserveAspectFit
                                opacity:        settingsMouseArea.containsMouse ? 1.0 : 0.6
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            QGCLabel {
                                text:                   qsTr("Settings")
                                font.pointSize:         ScreenTools.mediumFontPointSize
                                color:                  qgcPal.text
                                opacity:                settingsMouseArea.containsMouse ? 1.0 : 0.6
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                        }

                        MouseArea {
                            id:                 settingsMouseArea
                            anchors.fill:       parent
                            anchors.margins:    -ScreenTools.defaultFontPixelHeight * 0.5
                            hoverEnabled:       true
                            cursorShape:        Qt.PointingHandCursor
                            onClicked: {
                                mainWindow.showSettingsTool()
                                control.isOpen = false
                            }
                        }
                    }

                    // More Options Button (Bottom Right - Up Arrow with Dropdown)
                    Item {
                        id:                     moreButton
                        anchors.right:          parent.right
                        anchors.bottom:         parent.bottom
                        anchors.rightMargin:    ScreenTools.defaultFontPixelWidth
                        width:                  moreContent.width
                        height:                 moreContent.height

                        Row {
                            id:         moreContent
                            spacing:    ScreenTools.defaultFontPixelWidth * 0.5

                            QGCLabel {
                                text:                   qsTr("More")
                                font.pointSize:         ScreenTools.mediumFontPointSize
                                color:                  qgcPal.text
                                opacity:                moreMouseArea.containsMouse ? 1.0 : 0.6
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            QGCColoredImage {
                                source:         "/res/chevron-up.svg"
                                width:          ScreenTools.defaultFontPixelHeight * 1.2
                                height:         width
                                color:          qgcPal.text
                                fillMode:       Image.PreserveAspectFit
                                opacity:        moreMouseArea.containsMouse ? 1.0 : 0.6
                                anchors.verticalCenter: parent.verticalCenter
                                rotation:       moreMenu.visible ? 180 : 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                                Behavior on rotation { NumberAnimation { duration: 200 } }
                            }
                        }

                        MouseArea {
                            id:                 moreMouseArea
                            anchors.fill:       parent
                            anchors.margins:    -ScreenTools.defaultFontPixelHeight * 0.5
                            hoverEnabled:       true
                            cursorShape:        Qt.PointingHandCursor
                            onClicked:          moreMenu.visible = !moreMenu.visible
                        }

                        // Dropdown Menu
                        Rectangle {
                            id:                 moreMenu
                            visible:            false
                            anchors.bottom:     parent.top
                            anchors.right:      parent.right
                            anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.5
                            width:              ScreenTools.defaultFontPixelWidth * 18
                            height:             menuColumn.height + ScreenTools.defaultFontPixelHeight
                            color:              qgcPal.window
                            radius:             ScreenTools.defaultFontPixelHeight * 0.5
                            border.color:       qgcPal.text
                            border.width:       1

                            Column {
                                id:                 menuColumn
                                anchors.centerIn:   parent
                                width:              parent.width - ScreenTools.defaultFontPixelWidth
                                spacing:            ScreenTools.defaultFontPixelHeight * 0.5

                                // Analyze Option
                                Item {
                                    width:  parent.width
                                    height: analyzeRow.height

                                    Row {
                                        id:         analyzeRow
                                        spacing:    ScreenTools.defaultFontPixelWidth * 0.8
                                        anchors.centerIn: parent

                                        QGCColoredImage {
                                            source:         "/res/analyze-icon.svg"
                                            width:          ScreenTools.defaultFontPixelHeight * 1.5
                                            height:         width
                                            color:          qgcPal.text
                                            fillMode:       Image.PreserveAspectFit
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        QGCLabel {
                                            text:                   qsTr("Analyze")
                                            font.pointSize:         ScreenTools.mediumFontPointSize
                                            color:                  qgcPal.text
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill:   parent
                                        hoverEnabled:   true
                                        cursorShape:    Qt.PointingHandCursor
                                        onClicked: {
                                            moreMenu.visible = false
                                            mainWindow.showAnalyzeTool()
                                            control.isOpen = false
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill:   parent
                                        color:          qgcPal.text
                                        opacity:        0.1
                                        visible:        parent.children[1].containsMouse
                                        radius:         ScreenTools.defaultFontPixelHeight * 0.3
                                    }
                                }

                                // Vehicle Config Option
                                Item {
                                    width:  parent.width
                                    height: vehicleConfigRow.height

                                    Row {
                                        id:         vehicleConfigRow
                                        spacing:    ScreenTools.defaultFontPixelWidth * 0.8
                                        anchors.centerIn: parent

                                        QGCColoredImage {
                                            source:         "/res/vehicle-config-icon.svg"
                                            width:          ScreenTools.defaultFontPixelHeight * 1.5
                                            height:         width
                                            color:          qgcPal.text
                                            fillMode:       Image.PreserveAspectFit
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        QGCLabel {
                                            text:                   qsTr("Vehicle Config")
                                            font.pointSize:         ScreenTools.mediumFontPointSize
                                            color:                  qgcPal.text
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill:   parent
                                        hoverEnabled:   true
                                        cursorShape:    Qt.PointingHandCursor
                                        onClicked: {
                                            moreMenu.visible = false
                                            mainWindow.showVehicleConfig()
                                            control.isOpen = false
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill:   parent
                                        color:          qgcPal.text
                                        opacity:        0.1
                                        visible:        parent.children[1].containsMouse
                                        radius:         ScreenTools.defaultFontPixelHeight * 0.3
                                    }
                                }
                            }
                        }
                    }
                }
            }
    }

    // Animations
    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: circleOverlay; property: "width"; from: 0; to: control.width * 2.5; duration: 500; easing.type: Easing.OutCubic }
        NumberAnimation { target: circleOverlay; property: "height"; from: 0; to: control.width * 2.5; duration: 500; easing.type: Easing.OutCubic }
        NumberAnimation { target: dimBackground; property: "opacity"; from: 0; to: 0.5; duration: 400 }
        NumberAnimation { target: contentContainer; property: "opacity"; from: 0; to: 1.0; duration: 400; easing.type: Easing.InQuad }
    }

    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation { target: contentContainer; property: "opacity"; from: 1.0; to: 0; duration: 200 }
            NumberAnimation { target: dimBackground; property: "opacity"; to: 0; duration: 300 }
            NumberAnimation { target: circleOverlay; property: "width"; to: 0; duration: 400; easing.type: Easing.InCubic }
            NumberAnimation { target: circleOverlay; property: "height"; to: 0; duration: 400; easing.type: Easing.InCubic }
        }
        PropertyAction { target: control; property: "visible"; value: false }
    }

    // Internal Component: Mode Card (Squircle style with smooth edges)
    component ModeCard : Item {
        id:             cardRoot
        property string title
        property string imageSource
        property bool   isSelected: false
        signal clicked()

        // Shadow layer
        Rectangle {
            id:             shadowRect
            anchors.fill:   parent
            radius:         ScreenTools.defaultFontPixelHeight * 0.8
            color:          "transparent"
            antialiasing:   true
            
            layer.enabled:  true
            layer.effect:   MultiEffect {
                shadowEnabled:          true
                shadowColor:            isSelected ? "#50219C59" : "#40000000"
                shadowBlur:             isSelected ? 1.0 : 0.8
                shadowHorizontalOffset: 0
                shadowVerticalOffset:   isSelected ? 5 : 4
            }
        }

        // Card content with rounded corners
        Rectangle {
            id:             cardBackground
            anchors.fill:   parent
            radius:         ScreenTools.defaultFontPixelHeight * 0.8
            color:          "#e0e0e0"
            antialiasing:   true
            smooth:         true
            border.width:   isSelected ? 2 : 0
            border.color:   "#219C59"
            
            layer.enabled:  true
            layer.smooth:   true
            layer.effect:   MultiEffect {
                maskEnabled:    true
                maskSource:     ShaderEffectSource {
                    sourceItem: Rectangle {
                        width:          cardBackground.width
                        height:         cardBackground.height
                        radius:         cardBackground.radius
                        antialiasing:   true
                        smooth:         true
                    }
                }
            }

            // Background Image
            Image {
                id:             bgImage
                anchors.fill:   parent
                source:         cardRoot.imageSource
                fillMode:       Image.PreserveAspectCrop
                asynchronous:   true
                smooth:         true
                antialiasing:   true
            }

            // Gradient Overlay
            Rectangle {
                anchors.fill:   parent
                color:          "transparent"
                antialiasing:   true
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.5) }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.2) }
                }
            }

            // Title (Top Left)
            QGCLabel {
                anchors.top:            parent.top
                anchors.left:           parent.left
                anchors.topMargin:      ScreenTools.defaultFontPixelHeight * 1.5
                anchors.leftMargin:     ScreenTools.defaultFontPixelHeight * 1.5
                anchors.rightMargin:    ScreenTools.defaultFontPixelHeight * 1.5
                text:                   cardRoot.title
                color:                  "white"
                font.pointSize:         ScreenTools.mediumFontPointSize * 1.2
                font.weight:            Font.DemiBold
                wrapMode:               Text.WordWrap
            }

            // Hover effect (subtle brightness)
            Rectangle {
                anchors.fill:   parent
                color:          "white"
                opacity:        mouseArea.containsMouse ? 0.1 : 0
                antialiasing:   true
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }

            MouseArea {
                id:             mouseArea
                anchors.fill:   parent
                hoverEnabled:   true
                cursorShape:    Qt.PointingHandCursor
                onClicked:      cardRoot.clicked()
            }
        }
    }
}
