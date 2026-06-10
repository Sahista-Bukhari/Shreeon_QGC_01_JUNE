import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

Item {
    id:     control
    width:  ScreenTools.defaultFontPixelHeight * 2 + ScreenTools.defaultFontPixelWidth
    z:      moreMenu.visible ? 1000 : 0

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    function closeMenu() {
        moreMenu.visible = false
        if (outsideClickArea) {
            outsideClickArea.destroy()
            outsideClickArea = null
        }
    }

    function openMenu() {
        var pos = control.mapToItem(mainWindow.contentItem, 0, 0)
        moreMenu.x = pos.x + control.width - moreMenu.width
        moreMenu.y = pos.y + control.height + ScreenTools.defaultFontPixelHeight * 0.3
        moreMenu.visible = true
        outsideClickArea = outsideClickComponent.createObject(mainWindow.contentItem)
    }

    property var outsideClickArea: null

    QGCColoredImage {
        id:                     hamburgerIcon
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        width:                  ScreenTools.defaultFontPixelHeight * 1.5
        height:                 width
        source:                 "qrc:/qmlimages/HamburgerThin.svg"
        color:                  qgcPal.text
        fillMode:               Image.PreserveAspectFit
        opacity:                hamburgerMouseArea.containsMouse || moreMenu.visible ? 1.0 : 0.7
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    MouseArea {
        id:                 hamburgerMouseArea
        anchors.fill:       parent
        hoverEnabled:       true
        cursorShape:        Qt.PointingHandCursor
        onClicked:          moreMenu.visible ? closeMenu() : openMenu()
    }

    Component {
        id: outsideClickComponent

        MouseArea {
            anchors.fill:   parent
            z:              999
            onClicked:      control.closeMenu()
        }
    }

    Rectangle {
        id:                 moreMenu
        parent:             mainWindow.contentItem
        visible:            false
        width:              ScreenTools.defaultFontPixelWidth * 22
        height:             menuColumn.height + ScreenTools.defaultFontPixelHeight
        color:              qgcPal.window
        radius:             ScreenTools.defaultFontPixelHeight * 0.5
        border.color:       qgcPal.text
        border.width:       1
        z:                  1001

        Column {
            id:                 menuColumn
            anchors.centerIn:   parent
            width:              parent.width - ScreenTools.defaultFontPixelWidth
            spacing:            ScreenTools.defaultFontPixelHeight * 0.3

            // Analyze
            Item {
                width:  parent.width
                height: ScreenTools.defaultFontPixelHeight * 2.0

                Rectangle {
                    anchors.fill:   parent
                    color:          qgcPal.text
                    opacity:        analyzeMouseArea.containsMouse ? 0.1 : 0
                    radius:         ScreenTools.defaultFontPixelHeight * 0.3
                    visible:        analyzeMouseArea.containsMouse
                }

                Row {
                    spacing:                ScreenTools.defaultFontPixelWidth * 0.8
                    anchors.left:           parent.left
                    anchors.leftMargin:     ScreenTools.defaultFontPixelWidth
                    anchors.verticalCenter: parent.verticalCenter

                    QGCColoredImage {
                        source:                 "/res/analyze-icon.svg"
                        width:                  ScreenTools.defaultFontPixelHeight * 1.1
                        height:                 width
                        color:                  qgcPal.text
                        fillMode:               Image.PreserveAspectFit
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    QGCLabel {
                        text:                   qsTr("Analyze")
                        font.pointSize:         ScreenTools.defaultFontPointSize
                        color:                  qgcPal.text
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id:             analyzeMouseArea
                    anchors.fill:   parent
                    hoverEnabled:   true
                    cursorShape:    Qt.PointingHandCursor
                    onClicked: {
                        control.closeMenu()
                        mainWindow.showAnalyzeTool(true)
                    }
                }
            }

            // Vehicle Config
            Item {
                width:  parent.width
                height: ScreenTools.defaultFontPixelHeight * 2.0

                Rectangle {
                    anchors.fill:   parent
                    color:          qgcPal.text
                    opacity:        vehicleConfigMouseArea.containsMouse ? 0.1 : 0
                    radius:         ScreenTools.defaultFontPixelHeight * 0.3
                    visible:        vehicleConfigMouseArea.containsMouse
                }

                Row {
                    spacing:                ScreenTools.defaultFontPixelWidth * 0.8
                    anchors.left:           parent.left
                    anchors.leftMargin:     ScreenTools.defaultFontPixelWidth
                    anchors.verticalCenter: parent.verticalCenter

                    QGCColoredImage {
                        source:                 "/res/vehicle-config-icon.svg"
                        width:                  ScreenTools.defaultFontPixelHeight * 1.1
                        height:                 width
                        color:                  qgcPal.text
                        fillMode:               Image.PreserveAspectFit
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    QGCLabel {
                        text:                   qsTr("Vehicle Config")
                        font.pointSize:         ScreenTools.defaultFontPointSize
                        color:                  qgcPal.text
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id:             vehicleConfigMouseArea
                    anchors.fill:   parent
                    hoverEnabled:   true
                    cursorShape:    Qt.PointingHandCursor
                    onClicked: {
                        control.closeMenu()
                        mainWindow.showVehicleConfig(true)
                    }
                }
            }
        }
    }
}
