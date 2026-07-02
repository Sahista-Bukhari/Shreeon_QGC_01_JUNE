import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

Item {
    required property var guidedValueSlider
    required property bool utmspSliderTrigger

    id:     control
    width:  parent.width
    height: ScreenTools.toolbarHeight

    property var    _activeVehicle:     QGroundControl.multiVehicleManager.activeVehicle
    property bool   _communicationLost: _activeVehicle ? _activeVehicle.vehicleLinkManager.communicationLost : false
    property real   _leftRightMargin:   ScreenTools.defaultFontPixelWidth * 0.75
    property var    _guidedController:  globals.guidedControllerFlyView

    function dropMainStatusIndicatorTool() {
        mainStatusIndicator.dropMainStatusIndicator();
    }

    QGCPalette { id: qgcPal }

    // Match FlyViewBottomBar HUD glass (no blur, light dark tint)
    readonly property color _glassFill:   Qt.rgba(0.10, 0.10, 0.12, 0.28)
    readonly property color _glassBorder: Qt.rgba(1.00, 1.00, 1.00, 0.28)
    readonly property real  _statusBandExtra: ScreenTools.defaultFontPixelWidth * 34

    Rectangle {
        anchors.fill:   parent
        z:              -1
        color:          control._glassFill
        border.color:   control._glassBorder
        border.width:   1
    }

    QGCFlickable {
        anchors.fill:       parent
        contentWidth:       toolBarLayout.width
        flickableDirection: Flickable.HorizontalFlick

        Row {
            id:         toolBarLayout
            height:     parent.height
            spacing:    0

            Item {
                id:     leftPanel
                width:  leftPanelLayout.implicitWidth + control._statusBandExtra
                height: parent.height

                // Status color band (Ready / Comms Lost / Armed, etc.)
                Rectangle {
                    id:         statusGradient
                    z:          0
                    x:          qgcButton.width
                    height:     parent.height
                    width:      mainStatusIndicator.width + control._statusBandExtra
                    opacity:    0.92

                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: mainStatusIndicator._mainStatusBGColor }
                        GradientStop {
                            position: 1
                            color:    Qt.rgba(control._glassFill.r, control._glassFill.g, control._glassFill.b, 0)
                        }
                    }
                }

                RowLayout {
                    z:          1
                    id:         leftPanelLayout
                    height:     parent.height
                    spacing:    ScreenTools.defaultFontPixelWidth * 2

                    RowLayout {
                        id:         mainStatusLayout
                        height:     parent.height
                        spacing:    0

                        QGCToolBarButton {
                            id:                 qgcButton
                            Layout.fillHeight:  true
                            icon.source:        "/res/QGCLogoFull.svg"
                            logo:               true
                            onClicked: {
                                var point = qgcButton.mapToItem(mainWindow.contentItem, qgcButton.width / 2, qgcButton.height / 2)
                                mainWindow.showModeSelection(point)
                            }
                        }
                        MainStatusIndicator {
                            id:                 mainStatusIndicator
                            Layout.fillHeight:  true
                        }
                    }

                    QGCButton {
                        id:         disconnectButton
                        text:       qsTr("Disconnect")
                        onClicked:  _activeVehicle.closeVehicle()
                        visible:    _activeVehicle && _communicationLost
                    }
                }
            }
            Item {
                id:     centerPanel
                // center panel takes up all remaining space in toolbar between left and right panels
                width:  control.width - (leftPanel.width + rightPanel.width)
                height: parent.height
            }

            Item {
                id:     rightPanel
                width:  flyViewIndicators.width
                height: parent.height

                FlyViewToolBarIndicators {
                    id:     flyViewIndicators
                    height: parent.height
                }
            }
        }
    }


    ParameterDownloadProgress {
        anchors.fill: parent
    }
}
