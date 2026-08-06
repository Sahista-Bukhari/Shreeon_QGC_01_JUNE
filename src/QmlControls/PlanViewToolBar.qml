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

            QGCMouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var point = brandLogo.mapToItem(mainWindow.contentItem, brandLogo.width / 2, brandLogo.height / 2)
                    mainWindow.showModeSelection(point)
                }
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

        QGCToolBarButton {
            id: backButton
            Layout.alignment: Qt.AlignVCenter
            height: ScreenTools.defaultFontPixelHeight * 2.55
            implicitWidth: height * 1.55
            icon.source: "/res/chevron-double-left.svg"
            iconSize: ScreenTools.defaultFontPixelHeight * 1.45
            onClicked: _root.exitPlanEditMode()
        }

        PlanToolBarIndicators {
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
