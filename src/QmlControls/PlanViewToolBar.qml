import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id: _root
    width: parent.width
    height: ScreenTools.toolbarHeight
    color: qgcPal.toolbarBackground

    property var planMasterController

    signal missionUploaded()

    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property real _controllerProgressPct: planMasterController.missionController.progressPct

    QGCPalette { id: qgcPal }

    /// Bottom single pixel divider
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: "black"
        visible: qgcPal.globalTheme === QGCPalette.Light
    }

    QGCToolBarButton {
        id: qgcButton
        height: parent.height
        icon.source: "/res/QGCLogoFull.svg"
        logo: true
        onClicked: {
            var point = qgcButton.mapToItem(mainWindow.contentItem, qgcButton.width / 2, qgcButton.height / 2)
            mainWindow.showModeSelection(point)
        }
    }

    // Back button to exit plan edit mode
    signal exitPlanEditMode()
    
    Rectangle {
        id: backButton
        anchors.left: qgcButton.right
        anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.5
        anchors.verticalCenter: parent.verticalCenter
        width: ScreenTools.defaultFontPixelWidth * 7
        height: parent.height * 0.7
        radius: ScreenTools.defaultFontPixelWidth * 0.3
        color: backMouseArea.pressed ? qgcPal.buttonHighlight : qgcPal.button
        
        Row {
            anchors.centerIn: parent
            spacing: ScreenTools.defaultFontPixelWidth * 0.3
            
            Text {
                text: "←"
                font.pixelSize: ScreenTools.defaultFontPixelHeight * 1.2
                color: backMouseArea.pressed ? qgcPal.buttonHighlightText : qgcPal.buttonText
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: qsTr("Back")
                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.9
                color: backMouseArea.pressed ? qgcPal.buttonHighlightText : qgcPal.buttonText
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        
        MouseArea {
            id: backMouseArea
            anchors.fill: parent
            onClicked: _root.exitPlanEditMode()
        }
    }



    // Small mission download progress bar
    Rectangle {
        id: progressBar
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        height: 4
        width: _controllerProgressPct * parent.width
        color: qgcPal.colorGreen
        visible: false

        onVisibleChanged: {
            if (visible) {
                largeProgressBar._userHide = false
            }
        }
    }

    // Large mission download progress bar
    Rectangle {
        id: largeProgressBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: parent.height
        color: qgcPal.window
        visible: _showLargeProgress

        property bool _userHide: false
        property bool _showLargeProgress: progressBar.visible && !_userHide && qgcPal.globalTheme === QGCPalette.Light

        Connections {
            target: QGroundControl.multiVehicleManager
            function onActiveVehicleChanged(activeVehicle) { largeProgressBar._userHide = false }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: _controllerProgressPct * parent.width
            color: qgcPal.colorGreen
        }

        QGCLabel {
            anchors.centerIn: parent
            text: qsTr("Syncing Mission")
            font.pointSize: ScreenTools.largeFontPointSize
            visible: _controllerProgressPct !== 1
        }

        QGCLabel {
            anchors.centerIn: parent
            text: qsTr("Done")
            font.pointSize: ScreenTools.largeFontPointSize
            visible: _controllerProgressPct === 1
        }

        QGCLabel {
            anchors.margins: _margin
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            text: qsTr("Click anywhere to hide")

            property real _margin: ScreenTools.defaultFontPixelWidth / 2
        }

        MouseArea {
            anchors.fill: parent
            onClicked: largeProgressBar._userHide = true
        }
    }

    // Progress bar
    Connections {
        target: planMasterController.missionController

        function onProgressPctChanged(progressPct) {
            if (progressPct === 1) {
                if (_root.visible) {
                    resetProgressTimer.start()
                } else {
                    progressBar.visible = false
                }
            } else if (progressPct > 0) {
                progressBar.visible = true
            }
        }
    }

    Timer {
        id: resetProgressTimer
        interval: 3000
        onTriggered: progressBar.visible = false
    }
}
