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
        // Flush to the right edge of the window
        moreMenu.x = mainWindow.contentItem.width - moreMenu.width
        // Indicators sit inside toolbar margins; add that bottom margin so the
        // menu touches the toolbar edge instead of floating over the map.
        moreMenu.y = pos.y + control.height + ScreenTools.defaultFontPixelHeight * 0.66
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
        // source:                 "qrc:/qmlimages/HamburgerThin.svg"
        source:  "/res/gear-black.svg"
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
        width:              ScreenTools.defaultFontPixelWidth * 32
        height:             menuColumn.height + ScreenTools.defaultFontPixelHeight
        color:              qgcPal.textField
        radius:             ScreenTools.defaultFontPixelHeight * 0.5
        border.color:       qgcPal.colorGreen
        border.width:       1
        z:                  1001

        readonly property real _rowPad:     ScreenTools.defaultFontPixelWidth * 1.5
        readonly property real _iconSize:   ScreenTools.defaultFontPixelHeight * 1.1
        readonly property real _iconGap:    ScreenTools.defaultFontPixelWidth * 0.8

        Column {
            id:                 menuColumn
            anchors.centerIn:   parent
            width:              parent.width - moreMenu._rowPad * 2
            spacing:            ScreenTools.defaultFontPixelHeight * 0.2

            // Analyze
            Item {
                width:  parent.width
                height: ScreenTools.defaultFontPixelHeight * 2.0

                Rectangle {
                    anchors.fill:   parent
                    color:          qgcPal.colorGreen
                    opacity:        analyzeMouseArea.containsMouse ? 0.12 : 0
                    visible:        analyzeMouseArea.containsMouse
                }

                Row {
                    spacing:                moreMenu._iconGap
                    anchors.left:           parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    Item {
                        width:  moreMenu._iconSize
                        height: moreMenu._iconSize
                        anchors.verticalCenter: parent.verticalCenter

                        QGCColoredImage {
                            anchors.fill:           parent
                            source:                 "/res/analyze-icon.svg"
                            color:                  qgcPal.textFieldText
                            fillMode:               Image.PreserveAspectFit
                        }
                    }

                    QGCLabel {
                        text:                   qsTr("Analyze")
                        font.pointSize:         ScreenTools.defaultFontPointSize
                        color:                  qgcPal.textFieldText
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
                    color:          qgcPal.colorGreen
                    opacity:        vehicleConfigMouseArea.containsMouse ? 0.12 : 0
                    visible:        vehicleConfigMouseArea.containsMouse
                }

                Row {
                    spacing:                moreMenu._iconGap
                    anchors.left:           parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    Item {
                        width:  moreMenu._iconSize
                        height: moreMenu._iconSize
                        anchors.verticalCenter: parent.verticalCenter

                        QGCColoredImage {
                            anchors.fill:           parent
                            source:                 "/res/vehicle-config-icon.svg"
                            color:                  qgcPal.textFieldText
                            fillMode:               Image.PreserveAspectFit
                        }
                    }

                    QGCLabel {
                        text:                   qsTr("Vehicle  Config")
                        font.pointSize:         ScreenTools.defaultFontPointSize
                        color:                  qgcPal.textFieldText
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

            // Advanced
            Item {
                width:  parent.width
                height: ScreenTools.defaultFontPixelHeight * 2.0

                Rectangle {
                    anchors.fill:   parent
                    color:          qgcPal.colorGreen
                    opacity:        advancedMouseArea.containsMouse ? 0.12 : 0
                    visible:        advancedMouseArea.containsMouse
                }

                Row {
                    spacing:                moreMenu._iconGap
                    anchors.left:           parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    Item {
                        width:  moreMenu._iconSize
                        height: moreMenu._iconSize
                        anchors.verticalCenter: parent.verticalCenter

                        QGCColoredImage {
                            anchors.fill:           parent
                            source:                 "/qmlimages/CogWheel.svg"
                            color:                  qgcPal.textFieldText
                            fillMode:               Image.PreserveAspectFit
                        }
                    }

                    QGCLabel {
                        text:                   qsTr("Advanced")
                        font.pointSize:         ScreenTools.defaultFontPointSize
                        color:                  qgcPal.textFieldText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id:             advancedMouseArea
                    anchors.fill:   parent
                    hoverEnabled:   true
                    cursorShape:    Qt.PointingHandCursor
                    onClicked: {
                        control.closeMenu()
                        mainWindow.showAdvancedTool(true)
                    }
                }
            }
        }
    }
}
