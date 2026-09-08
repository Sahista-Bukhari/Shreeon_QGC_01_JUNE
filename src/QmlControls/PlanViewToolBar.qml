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
    color: Qt.rgba(0, 0, 0, 0.34)
    z: QGroundControl.zOrderWidgets + 20

    property var planMasterController

    signal missionUploaded()
    signal exitPlanEditMode()

    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property real _controllerProgressPct: planMasterController.missionController.progressPct

    QGCPalette { id: qgcPal }

    function _shouldReturnToModeSelection() {
        if (typeof mainWindow === "undefined" || !mainWindow) {
            return false
        }

        switch (mainWindow.activeMissionEditor) {
        case "customMission":
        case "routeMapping":
        case "agricultureSpraying":
        case "seedSpreader":
            return true
        default:
            return false
        }
    }

    function _returnToModeSelection(fromItem) {
        var point = fromItem.mapToItem(mainWindow.contentItem, fromItem.width / 2, fromItem.height / 2)
        mainWindow.showModeSelection(point)
    }

    RowLayout {
        anchors.bottomMargin: 1
        anchors.leftMargin: ScreenTools.defaultFontPixelWidth
        anchors.rightMargin: ScreenTools.defaultFontPixelWidth
        anchors.fill: parent
        spacing: ScreenTools.defaultFontPixelWidth * 0.75

        Item {
            id: brandLogo
            Layout.fillHeight: true
            Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 3.2

            Image {
                anchors.centerIn: parent
                source: "qrc:/ModeSelection/shreeon_logo.png"
                width: ScreenTools.defaultFontPixelHeight * 2.4
                height: width
                fillMode: Image.PreserveAspectFit
                mipmap: true
                smooth: true
            }
        }

        Item {
            Layout.fillHeight: true
            Layout.preferredWidth: toolbarTitle.implicitWidth
            Layout.leftMargin: ScreenTools.defaultFontPixelWidth * 0.5

            QGCLabel {
                id: toolbarTitle
                anchors.centerIn: parent
                text: typeof mainWindow !== "undefined" && mainWindow
                      ? mainWindow.missionEditorDisplayName(mainWindow.activeMissionEditor)
                      : qsTr("Custom Mission")
                color: "white"
                font.bold: true
                font.pointSize: ScreenTools.largeFontPointSize
            }

            Rectangle {
                anchors.left: toolbarTitle.left
                anchors.right: toolbarTitle.right
                anchors.top: toolbarTitle.bottom
                anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.12
                height: 1
                color: "#4af200"
                opacity: 0.55
            }
        }

        Item { Layout.fillWidth: true }

        Item {
            id: backButton
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 2.0
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.0

            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: width
                radius: width / 2
                color: backMouse.pressed
                       ? Qt.rgba(0.18, 0.18, 0.18, 0.72)
                       : Qt.rgba(0.12, 0.12, 0.14, 0.55)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.28)

                QGCColoredImage {
                    anchors.centerIn: parent
                    width: parent.width * 0.42
                    height: width
                    source: "/res/chevron-double-left.svg"
                    color: "white"
                    fillMode: Image.PreserveAspectFit
                }
            }

            MouseArea {
                id: backMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (_root._shouldReturnToModeSelection()) {
                        _root._returnToModeSelection(backButton)
                    } else {
                        _root.exitPlanEditMode()
                    }
                }
            }
        }

        PlanToolBarIndicators {
            // Custom Mission shows these just below the toolbar instead
            visible: typeof mainWindow === "undefined"
                     || !mainWindow
                     || mainWindow.activeMissionEditor !== "customMission"
            Layout.alignment: Qt.AlignVCenter
            planMasterController: _root.planMasterController
            compact: true
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
