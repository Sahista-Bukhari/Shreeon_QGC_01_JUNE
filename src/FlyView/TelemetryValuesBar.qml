import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Item {
    id: control

    property real extraWidth: 0 ///< Extra width to add to the background rectangle

    property alias factValueGrid: factValueGrid
    property string settingsGroup: ""
    property var specificVehicleForCard: null

    // Height is taller than content to allow gradient to fade in smoothly
    height: mainLayout.height + (ScreenTools.defaultFontPixelHeight * 3.5)

    Rectangle {
        id: backgroundRect

        anchors.fill: parent
        radius: 0

        gradient: Gradient {
            GradientStop {
                color: "transparent"
                position: 0.0
            }
            GradientStop {
                color: "transparent"
                position: 0.2
            }
            GradientStop {
                color: Qt.rgba(0, 0, 0, 0.9)
                position: 1.0
            }
        }
    }
    ColumnLayout {
        id: mainLayout

        anchors.bottom: parent.bottom
        anchors.bottomMargin: _toolsMargin
        anchors.horizontalCenter: parent.horizontalCenter

        RowLayout {
            visible: factValueGrid.settingsUnlocked

            QGCColoredImage {
                color: qgcPal.text
                fillMode: Image.PreserveAspectFit
                height: width
                mipmap: true
                source: "qrc:/InstrumentValueIcons/lock-open.svg"
                sourceSize.width: width
                width: ScreenTools.minTouchPixels * 0.75

                QGCMouseArea {
                    anchors.fill: parent

                    onClicked: factValueGrid.settingsUnlocked = false
                }
            }
        }
        HorizontalFactValueGrid {
            id: factValueGrid
            settingsGroup: control.settingsGroup
            specificVehicleForCard: control.specificVehicleForCard

        }
    }
    QGCMouseArea {
        id: mouseArea

        acceptedButtons: Qt.LeftButton | Qt.RightButton
        height: mainLayout.height
        propagateComposedEvents: true
        visible: !factValueGrid.settingsUnlocked
        width: mainLayout.width
        x: mainLayout.x
        y: mainLayout.y

        onClicked: mouse => {
            if (!ScreenTools.isMobile && mouse.button === Qt.RightButton) {
                factValueGrid.settingsUnlocked = true;
                mouse.accepted = true;
            }
        }
        onPressAndHold: mouse => {
            factValueGrid.settingsUnlocked = true;
            mouse.accepted = true;
        }
    }
}
