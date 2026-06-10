import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects

import QGroundControl
import QGroundControl.Controls

Item {
    id: control

    property bool isOpen: false
    property point startPoint: Qt.point(0, 0)

    anchors.fill: parent
    visible: false
    z: 1000

    onIsOpenChanged: {
        if (control.isOpen) {
            control.visible = true;
            openAnim.start();
        } else {
            closeAnim.start();
        }
    }

    QGCPalette {
        id: qgcPal

        colorGroupEnabled: true
    }

    // Dark overlay background
    Rectangle {
        id: dimBackground

        anchors.fill: parent
        color: "black"
        opacity: 0
    }

    // Circular expansion background
    Rectangle {
        id: circleOverlay

        color: qgcPal.window
        height: 0
        radius: width / 2
        width: 0
        x: control.startPoint.x - width / 2
        y: control.startPoint.y - height / 2
    }

    // Content Container
    Item {
        id: contentContainer

        anchors.fill: parent
        opacity: 0
        visible: opacity > 0

        // Top Header Row (Logo and Close)
        Item {
            id: topHeader

            anchors.left: parent.left
            anchors.leftMargin: ScreenTools.defaultFontPixelHeight * 0.5
            anchors.right: parent.right
            anchors.rightMargin: ScreenTools.defaultFontPixelHeight * 0.5
            anchors.top: parent.top
            anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.5
            height: ScreenTools.defaultFontPixelHeight * 2.5

            // Logo and Company Name
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: ScreenTools.defaultFontPixelWidth * 1.5

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    fillMode: Image.PreserveAspectFit
                    height: ScreenTools.defaultFontPixelHeight * 2.5
                    source: "qrc:/ModeSelection/shreeon_logo.png"
                    width: ScreenTools.defaultFontPixelHeight * 2.5
                }
                QGCLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    color: qgcPal.text
                    font.pointSize: ScreenTools.mediumFontPointSize * 1.15
                    font.weight: Font.Medium
                    text: "Shreeon Technologies"
                }
            }

            // Close Button
            Item {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: width
                width: ScreenTools.defaultFontPixelHeight * 2

                QGCColoredImage {
                    anchors.centerIn: parent
                    color: qgcPal.text
                    height: width
                    opacity: closeMouseArea.containsMouse ? 1.0 : 0.7
                    source: "/res/XDeleteBlack.svg"
                    width: parent.width * 0.6

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }
                }
                MouseArea {
                    id: closeMouseArea

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: control.isOpen = false
                }
            }
        }

        // Center Content Area
        Item {
            id: centerContent

            anchors.bottom: bottomFooter.top
            anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.5
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: topHeader.bottom
            anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.5

            // Title
            Rectangle {
                id: titleBackground
                radius: 10
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: -ScreenTools.defaultFontPixelHeight * 0.4
                height: titleLabel.contentHeight * 1.6
                width: gridContainer.width

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    // GradientStop {
                    //     color: "transparent"
                    //     position: 0.0
                    // }
                    GradientStop {
                        color: Qt.rgba(0.004, 0.486, 0.365, 0.62)
                        position: 0.3
                    }
                    GradientStop {
                        color: Qt.rgba(0.004, 0.486, 0.365, 0.62)
                        position: 0.7
                    }
                    // GradientStop {
                    //     color: "transparent"
                    //     position: 1.0
                    // }
                }

                QGCLabel {
                    id: titleLabel
                    anchors.centerIn: parent
                    color: "#A9A9A9"
                    font.pointSize: ScreenTools.largeFontPointSize * 1.0
                    font.weight: Font.DemiBold
                    text: qsTr("Select Task Mode")
                }
            }

            // Grid Container
            Rectangle {
                id: gridContainer

                property real cardSpacing: ScreenTools.defaultFontPixelWidth * 3
                property real doubleColWidth: singleColWidth * 2 + cardSpacing
                property real rowHeight: (height - cardSpacing) / 2
                property int selectedIndex: 4
                property real singleColWidth: (width - cardSpacing * 2) / 3
                property real cardBorderRadius: 12

                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: titleBackground.bottom
                anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.5
                width: parent.width * 0.85


                // Row 1
                Row {
                    id: row1
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: gridContainer.rowHeight
                    spacing: gridContainer.cardSpacing


                    ModeCard {
                        height: parent.height
                        imageSource: "qrc:/ModeSelection/agriculture_spraying.png"
                        isSelected: gridContainer.selectedIndex === 0
                        title: qsTr("Agriculture Spraying")
                        visible: true
                        width: gridContainer.selectedIndex === 0 ? gridContainer.doubleColWidth : gridContainer.singleColWidth

                        Behavior on width {
                            NumberAnimation {
                                duration: 300
                                easing.type: Easing.OutCubic
                            }
                        }

                        onClicked: {
                            gridContainer.selectedIndex = 0;
                            mainWindow.showPlanView();
                            control.isOpen = false;
                        }
                    }
                    ModeCard {
                        height: parent.height
                        imageSource: "qrc:/ModeSelection/route_mapping.png"
                        isSelected: gridContainer.selectedIndex === 1
                        title: qsTr("Route Mapping")
                        visible: true
                        width: gridContainer.selectedIndex === 1 ? gridContainer.doubleColWidth : gridContainer.singleColWidth

                        Behavior on width {
                            NumberAnimation {
                                duration: 300
                                easing.type: Easing.OutCubic
                            }
                        }

                        onClicked: {
                            gridContainer.selectedIndex = 1;
                            mainWindow.showPlanView();
                            control.isOpen = false;
                        }
                    }
                    ModeCard {
                        height: parent.height
                        imageSource: "qrc:/ModeSelection/seed_spreader.png"
                        isSelected: gridContainer.selectedIndex === 2
                        title: qsTr("Seed Spreader")
                        visible: gridContainer.selectedIndex === 3 || gridContainer.selectedIndex === 4
                        width: gridContainer.singleColWidth

                        onClicked: {
                            gridContainer.selectedIndex = 2;
                            mainWindow.showPlanView();
                            control.isOpen = false;
                        }
                    }
                    ModeCard {
                        height: parent.height
                        imageSource: "qrc:/ModeSelection/custom_mission.png"
                        isSelected: gridContainer.selectedIndex === 3
                        title: qsTr("Custom Mission")
                        visible: gridContainer.selectedIndex === 2
                        width: gridContainer.singleColWidth

                        onClicked: {
                            gridContainer.selectedIndex = 3;
                            mainWindow.showPlanView();
                            control.isOpen = false;
                        }
                    }
                }

                // Row 2
                Row {
                    id: row2

                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: gridContainer.rowHeight
                    spacing: gridContainer.cardSpacing

                    ModeCard {
                        height: parent.height
                        imageSource: "qrc:/ModeSelection/seed_spreader.png"
                        isSelected: gridContainer.selectedIndex === 2
                        title: qsTr("Seed Spreader")
                        visible: gridContainer.selectedIndex === 0 || gridContainer.selectedIndex === 1 || gridContainer.selectedIndex === 2
                        width: gridContainer.selectedIndex === 2 ? gridContainer.doubleColWidth : gridContainer.singleColWidth

                        Behavior on width {
                            NumberAnimation {
                                duration: 300
                                easing.type: Easing.OutCubic
                            }
                        }

                        onClicked: {
                            gridContainer.selectedIndex = 2;
                            mainWindow.showPlanView();
                            control.isOpen = false;
                        }
                    }
                    ModeCard {
                        height: parent.height
                        imageSource: "qrc:/ModeSelection/custom_mission.png"
                        isSelected: gridContainer.selectedIndex === 3
                        title: qsTr("Custom Mission")
                        visible: gridContainer.selectedIndex !== 2
                        width: gridContainer.selectedIndex === 3 ? gridContainer.doubleColWidth : gridContainer.singleColWidth

                        Behavior on width {
                            NumberAnimation {
                                duration: 300
                                easing.type: Easing.OutCubic
                            }
                        }

                        onClicked: {
                            gridContainer.selectedIndex = 3;
                            mainWindow.showPlanView();
                            control.isOpen = false;
                        }
                    }
                    ModeCard {
                        height: parent.height
                        imageSource: "qrc:/ModeSelection/manual_mode.png"
                        isSelected: gridContainer.selectedIndex === 4
                        title: qsTr("Manual")
                        visible: true
                        width: gridContainer.selectedIndex === 4 ? gridContainer.doubleColWidth : gridContainer.singleColWidth

                        Behavior on width {
                            NumberAnimation {
                                duration: 300
                                easing.type: Easing.OutCubic
                            }
                        }

                        onClicked: {
                            gridContainer.selectedIndex = 4;
                            mainWindow.showFlyView();
                            control.isOpen = false;
                        }
                    }
                }
            }
        }

        // Bottom Footer (Settings)
        Item {
            id: bottomFooter

            anchors.bottom: parent.bottom
            anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.5
            anchors.left: parent.left
            anchors.leftMargin: ScreenTools.defaultFontPixelHeight * 0.5
            anchors.right: parent.right
            anchors.rightMargin: ScreenTools.defaultFontPixelHeight * 0.5
            height: ScreenTools.defaultFontPixelHeight * 2

            // Settings Button
            Item {
                id: settingsButton

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: settingsRow.height
                width: settingsRow.width

                Row {
                    id: settingsRow

                    spacing: ScreenTools.defaultFontPixelWidth * 0.5

                    QGCColoredImage {
                        anchors.verticalCenter: parent.verticalCenter
                        color: qgcPal.text
                        fillMode: Image.PreserveAspectFit
                        height: width
                        opacity: settingsMouseArea.containsMouse ? 1.0 : 0.6
                        source: "/res/gear-black.svg"
                        width: ScreenTools.defaultFontPixelHeight * 1.5

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 150
                            }
                        }
                    }
                    QGCLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        color: qgcPal.text
                        font.pointSize: ScreenTools.mediumFontPointSize
                        opacity: settingsMouseArea.containsMouse ? 1.0 : 0.6
                        text: qsTr("Settings")

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 150
                            }
                        }
                    }
                }
                MouseArea {
                    id: settingsMouseArea

                    anchors.fill: parent
                    anchors.margins: -ScreenTools.defaultFontPixelHeight * 0.5
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: {
                        mainWindow.showSettingsTool();
                        control.isOpen = false;
                    }
                }
            }
        }
    }

    // Animations
    ParallelAnimation {
        id: openAnim

        NumberAnimation {
            duration: 500
            easing.type: Easing.OutCubic
            from: 0
            property: "width"
            target: circleOverlay
            to: control.width * 2.5
        }
        NumberAnimation {
            duration: 500
            easing.type: Easing.OutCubic
            from: 0
            property: "height"
            target: circleOverlay
            to: control.width * 2.5
        }
        NumberAnimation {
            duration: 400
            from: 0
            property: "opacity"
            target: dimBackground
            to: 0.5
        }
        NumberAnimation {
            duration: 400
            easing.type: Easing.InQuad
            from: 0
            property: "opacity"
            target: contentContainer
            to: 1.0
        }
    }
    SequentialAnimation {
        id: closeAnim

        ParallelAnimation {
            NumberAnimation {
                duration: 200
                from: 1.0
                property: "opacity"
                target: contentContainer
                to: 0
            }
            NumberAnimation {
                duration: 300
                property: "opacity"
                target: dimBackground
                to: 0
            }
            NumberAnimation {
                duration: 400
                easing.type: Easing.InCubic
                property: "width"
                target: circleOverlay
                to: 0
            }
            NumberAnimation {
                duration: 400
                easing.type: Easing.InCubic
                property: "height"
                target: circleOverlay
                to: 0
            }
        }
        PropertyAction {
            property: "visible"
            target: control
            value: false
        }
    }

    // Mode Card Component
    component ModeCard: Item {
        id: cardRoot

        property string imageSource
        property bool isSelected: false
        property string title

        signal clicked

        Rectangle {
            id: cardBackground

            anchors.fill: parent
            antialiasing: true
            border.color: "#219C59"
            border.width: cardRoot.isSelected ? 2 : 0
            clip: true
            color: "transparent"
            layer.enabled: true
            layer.smooth: true
            radius: ScreenTools.defaultFontPixelHeight * 0.4
            smooth: true

            layer.effect: MultiEffect {
                maskEnabled: true
                shadowBlur: 1.0
                shadowColor: cardRoot.isSelected ? "#80219C59" : "#80000000"
                shadowEnabled: true
                shadowHorizontalOffset: 0
                shadowVerticalOffset: cardRoot.isSelected ? 10 : 8

                maskSource: ShaderEffectSource {
                    sourceItem: Rectangle {
                        height: cardBackground.height
                        radius: cardBackground.radius
                        width: cardBackground.width
                    }
                }
            }

            Image {
                anchors.fill: parent
                antialiasing: true
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                smooth: true
                source: cardRoot.imageSource
            }
            Rectangle {
                anchors.fill: parent
                antialiasing: true
                color: "transparent"

                gradient: Gradient {
                    GradientStop {
                        color: Qt.rgba(0, 0, 0, 0.5)
                        position: 0.0
                    }
                    GradientStop {
                        color: Qt.rgba(0, 0, 0, 0.2)
                        position: 1.0
                    }
                }
            }
            QGCLabel {
                anchors.left: parent.left
                anchors.leftMargin: ScreenTools.defaultFontPixelHeight * 1.5
                anchors.rightMargin: ScreenTools.defaultFontPixelHeight * 1.5
                anchors.top: parent.top
                anchors.topMargin: ScreenTools.defaultFontPixelHeight * 1.5
                color: "white"
                font.pointSize: ScreenTools.mediumFontPointSize * 1.2
                font.weight: Font.DemiBold
                text: cardRoot.title
                wrapMode: Text.WordWrap
            }
            Rectangle {
                anchors.fill: parent
                antialiasing: true
                color: "white"
                opacity: mouseArea.containsMouse ? 0.1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                    }
                }
            }
            MouseArea {
                id: mouseArea

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                onClicked: cardRoot.clicked()
            }
        }
    }
}
