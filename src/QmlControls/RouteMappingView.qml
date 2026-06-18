import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtLocation
import QtPositioning
import QtQuick.Layouts
import QtQuick.Window

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap
import QGroundControl.FlyView

Item {
    id: _root

    readonly property int  _decimalPlaces: 8
    readonly property real _margin: ScreenTools.defaultFontPixelHeight * 0.5
    readonly property real _toolsMargin: ScreenTools.defaultFontPixelWidth * 0.75

    property var  _planMasterController: planMasterController
    property var  _missionController: _planMasterController.missionController
    property var  _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property int  _fieldPointCount: 0

    function mapCenter() {
        var coordinate = routeMap.center
        coordinate.latitude  = coordinate.latitude.toFixed(_decimalPlaces)
        coordinate.longitude = coordinate.longitude.toFixed(_decimalPlaces)
        coordinate.altitude  = coordinate.altitude.toFixed(_decimalPlaces)
        return coordinate
    }

    function addRouteMappingPoint() {
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertSimpleMissionItem(mapCenter(), nextIndex, true)
        _fieldPointCount++
    }

    function _formatTelemetryValue(value) {
        if (isNaN(value)) {
            value = 0
        }
        return value.toFixed(1)
    }

    PlanMasterController {
        id: planMasterController
        flyView: false

        Component.onCompleted: {
            _planMasterController.start()
            _missionController.setCurrentPlanViewSeqNum(0, true)
        }

        function saveToSelectedFile() {
            fileDialog.title = qsTr("Save Route Mapping Plan")
            fileDialog.planFiles = true
            fileDialog.nameFilters = _planMasterController.saveNameFilters
            fileDialog.openForSave()
        }
    }

    QGCFileDialog {
        id: fileDialog
        folder: _appSettings ? _appSettings.missionSavePath : ""

        property bool planFiles: true
        property var _appSettings: QGroundControl.settingsManager.appSettings

        onAcceptedForSave: (file) => {
            _planMasterController.saveToFile(file)
            close()
        }
    }

    PlanViewToolBar {
        id: planToolBar
        planMasterController: _planMasterController
        visible: !mainWindow.modeSelectionVisible
        onExitPlanEditMode: mainWindow.showFlyView()
    }

    Item {
        id: routeContent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: planToolBar.bottom
        anchors.bottom: parent.bottom

        FlightMap {
            id: routeMap
            anchors.fill: parent
            mapName: "RouteMapping"
            allowGCSLocationCenter: true
            allowVehicleLocationCenter: true
            planView: true
            zoomLevel: QGroundControl.flightMapZoom
            center: QGroundControl.flightMapPosition

            onZoomLevelChanged: QGroundControl.flightMapZoom = routeMap.zoomLevel
            onCenterChanged: QGroundControl.flightMapPosition = routeMap.center

            Repeater {
                model: _missionController.visualItems
                delegate: MissionItemMapVisual {
                    map: routeMap
                    opacity: 1
                    interactive: true
                    vehicle: _planMasterController.controllerVehicle
                    onClicked: (sequenceNumber) => _missionController.setCurrentPlanViewSeqNum(sequenceNumber, false)
                }
            }

            MissionLineView {
                showSpecialVisual: _missionController.isROIBeginCurrentItem
                model: _missionController.simpleFlightPathSegments
            }

            MapItemView {
                model: QGroundControl.multiVehicleManager.vehicles
                delegate: VehicleMapItem {
                    vehicle: object
                    coordinate: object.coordinate
                    map: routeMap
                    size: ScreenTools.defaultFontPixelHeight * 3
                    z: QGroundControl.zOrderMapItems - 1
                }
            }

            Item {
                id: centerTarget
                anchors.centerIn: parent
                width: ScreenTools.defaultFontPixelHeight * 2.5
                height: width
                z: QGroundControl.zOrderWidgets + 10

                property real lineLength: width * 0.45
                property real centerGap: ScreenTools.defaultFontPixelHeight * 0.5

                Repeater {
                    model: [
                        { x: parent.width / 2 - 1, y: 0, w: 2, h: centerTarget.lineLength },
                        { x: parent.width / 2 - 1, y: parent.height - centerTarget.lineLength, w: 2, h: centerTarget.lineLength },
                        { x: 0, y: parent.height / 2 - 1, w: centerTarget.lineLength, h: 2 },
                        { x: parent.width - centerTarget.lineLength, y: parent.height / 2 - 1, w: centerTarget.lineLength, h: 2 }
                    ]

                    Rectangle {
                        x: modelData.x
                        y: modelData.y
                        width: modelData.w
                        height: modelData.h
                        color: "white"
                    }
                }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.3
            anchors.verticalCenter: parent.verticalCenter
            width: ScreenTools.defaultFontPixelHeight * 2.2
            height: ScreenTools.defaultFontPixelHeight * 4.4
            radius: ScreenTools.defaultFontPixelWidth * 0.35
            color: Qt.rgba(1, 1, 1, 0.23)
            z: QGroundControl.zOrderWidgets + 10

            QGCLabel {
                anchors.centerIn: parent
                text: ">"
                color: "white"
                font.bold: true
                font.pointSize: ScreenTools.largeFontPointSize
            }
        }

        Row {
            id: mapTools
            anchors.top: parent.top
            anchors.topMargin: ScreenTools.defaultFontPixelHeight * 1.2
            anchors.right: parent.right
            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 1.2
            spacing: ScreenTools.defaultFontPixelWidth * 1.5
            z: QGroundControl.zOrderWidgets + 10

            Repeater {
                model: ["/res/pencil.svg", "/res/target-crosshair.svg", "/res/FlyingPaperPlane.svg", "/InstrumentValueIcons/layers.svg"]

                Rectangle {
                    width: ScreenTools.defaultFontPixelHeight * 2.1
                    height: width
                    radius: width * 0.2
                    color: toolMouse.pressed ? Qt.rgba(0, 0, 0, 0.32) : "transparent"

                    QGCColoredImage {
                        anchors.margins: parent.width * 0.16
                        anchors.fill: parent
                        source: modelData
                        color: "white"
                    }

                    QGCMouseArea {
                        id: toolMouse
                        anchors.fill: parent
                    }
                }
            }
        }

        Rectangle {
            id: mappingStats
            anchors.top: mapTools.bottom
            anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.5
            anchors.right: parent.right
            anchors.rightMargin: ScreenTools.defaultFontPixelWidth
            width: ScreenTools.defaultFontPixelWidth * 18
            height: statsGrid.implicitHeight + ScreenTools.defaultFontPixelHeight
            radius: ScreenTools.defaultFontPixelWidth * 0.35
            color: Qt.rgba(0.03, 0.03, 0.03, 0.52)
            z: QGroundControl.zOrderWidgets + 10

            GridLayout {
                id: statsGrid
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                anchors.rightMargin: ScreenTools.defaultFontPixelWidth
                columns: 2
                rowSpacing: ScreenTools.defaultFontPixelHeight * 0.35
                columnSpacing: ScreenTools.defaultFontPixelWidth

                QGCLabel { text: qsTr("Mapping Area"); color: "white"; opacity: 0.92; Layout.fillWidth: true }
                QGCLabel { text: "0.0 Ha"; color: "white"; font.bold: true; horizontalAlignment: Text.AlignRight; Layout.fillWidth: true }
                QGCLabel { text: qsTr("Est. Photo Count"); color: "white"; opacity: 0.92; Layout.fillWidth: true }
                QGCLabel { text: _fieldPointCount; color: "white"; font.bold: true; horizontalAlignment: Text.AlignRight; Layout.fillWidth: true }
                QGCLabel { text: qsTr("Est. Flight Time"); color: "white"; opacity: 0.92; Layout.fillWidth: true }
                QGCLabel { text: "0 min"; color: "white"; font.bold: true; horizontalAlignment: Text.AlignRight; Layout.fillWidth: true }
            }
        }

        Rectangle {
            id: fieldsPanel
            anchors.right: parent.right
            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.8
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -ScreenTools.defaultFontPixelHeight * 2.6
            width: ScreenTools.defaultFontPixelWidth * 18.5
            height: ScreenTools.defaultFontPixelHeight * 8.6
            radius: ScreenTools.defaultFontPixelWidth * 0.55
            color: Qt.rgba(0, 0, 0, 0.34)
            z: QGroundControl.zOrderWidgets + 9

            Rectangle {
                width: ScreenTools.defaultFontPixelHeight * 0.65
                height: width
                radius: width / 2
                color: "magenta"
                anchors.left: parent.left
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 1.7
                anchors.top: parent.top
                anchors.topMargin: ScreenTools.defaultFontPixelHeight * 1.2
            }

            QGCLabel {
                anchors.left: parent.left
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 5
                anchors.top: parent.top
                anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.9
                text: qsTr("Fields")
                color: "white"
                font.bold: true
                font.pointSize: ScreenTools.largeFontPointSize
            }

            Rectangle {
                id: plusButton
                anchors.left: parent.left
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 1.1
                anchors.bottom: parent.bottom
                anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.65
                width: ScreenTools.defaultFontPixelHeight * 3.25
                height: width
                radius: ScreenTools.defaultFontPixelWidth * 0.45
                color: "white"
                border.color: "#78d957"
                border.width: 2

                QGCLabel {
                    anchors.centerIn: parent
                    text: "+"
                    color: "#303030"
                    font.bold: true
                    font.pointSize: ScreenTools.largeFontPointSize
                }

                QGCMouseArea {
                    anchors.fill: parent
                    onClicked: addRouteMappingPoint()
                }
            }

            Rectangle {
                anchors.left: plusButton.right
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.65
                anchors.right: parent.right
                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.75
                anchors.verticalCenter: plusButton.verticalCenter
                height: plusButton.height
                radius: ScreenTools.defaultFontPixelWidth * 0.45
                color: "white"

                QGCLabel {
                    anchors.centerIn: parent
                    text: qsTr("Add")
                    color: "#303030"
                    font.bold: true
                    font.pointSize: ScreenTools.mediumFontPointSize
                }

                QGCMouseArea {
                    anchors.fill: parent
                    onClicked: addRouteMappingPoint()
                }
            }
        }

        Rectangle {
            id: videoPreview
            anchors.left: parent.left
            anchors.leftMargin: ScreenTools.defaultFontPixelWidth
            anchors.bottom: parent.bottom
            anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.8
            width: Math.min(parent.width * 0.23, ScreenTools.defaultFontPixelWidth * 24)
            height: width * 0.58
            radius: ScreenTools.defaultFontPixelWidth * 0.45
            clip: true
            color: "#1e2b34"
            border.color: Qt.rgba(1, 1, 1, 0.45)
            border.width: 1
            z: QGroundControl.zOrderWidgets + 10

            FlyViewVideo {
                anchors.fill: parent
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0.2, 0.62, 0.82, 0.28)
                visible: !QGroundControl.videoManager.hasVideo
            }

            QGCLabel {
                anchors.centerIn: parent
                text: qsTr("Camera")
                color: "white"
                font.bold: true
                visible: !QGroundControl.videoManager.hasVideo
            }
        }

        Rectangle {
            anchors.centerIn: routeTelemetry
            width: routeTelemetry.width + ScreenTools.defaultFontPixelWidth * 3
            height: routeTelemetry.height + ScreenTools.defaultFontPixelHeight * 1.1
            radius: ScreenTools.defaultFontPixelWidth * 0.55
            color: Qt.rgba(0, 0, 0, 0.30)
            z: QGroundControl.zOrderWidgets + 9
        }

        Row {
            id: routeTelemetry
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 1.3
            spacing: ScreenTools.defaultFontPixelWidth * 3.2
            z: QGroundControl.zOrderWidgets + 10

            Repeater {
                model: [
                    { label: qsTr("Relative to\nHome"), value: _formatTelemetryValue(_activeVehicle && _activeVehicle.altitudeRelative ? _activeVehicle.altitudeRelative.rawValue : 0), units: " m" },
                    { label: qsTr("Speed"), value: _formatTelemetryValue(_activeVehicle && _activeVehicle.groundSpeed ? _activeVehicle.groundSpeed.rawValue : 0), units: " km/h" },
                    { label: qsTr("Distance"), value: _formatTelemetryValue(_activeVehicle && _activeVehicle.distanceToHome ? _activeVehicle.distanceToHome.rawValue : 0), units: " m" },
                    { label: qsTr("Flow"), value: "0.0", units: " L/min" }
                ]

                Column {
                    spacing: 0
                    QGCLabel { text: modelData.label; color: "white"; horizontalAlignment: Text.AlignHCenter }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        QGCLabel { text: modelData.value; color: "white"; font.bold: true; font.pointSize: ScreenTools.largeFontPointSize }
                        QGCLabel { text: modelData.units; color: "white"; anchors.bottom: parent.bottom }
                    }
                }
            }
        }

        Column {
            anchors.right: parent.right
            anchors.rightMargin: ScreenTools.defaultFontPixelWidth
            anchors.bottom: parent.bottom
            anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.6
            spacing: ScreenTools.defaultFontPixelHeight * 0.6
            z: QGroundControl.zOrderWidgets + 10

            Rectangle {
                width: ScreenTools.defaultFontPixelWidth * 9
                height: ScreenTools.defaultFontPixelHeight * 2.7
                radius: ScreenTools.defaultFontPixelWidth * 0.45
                color: "white"

                QGCLabel { anchors.centerIn: parent; text: qsTr("Exit"); color: "#303030"; font.bold: true }
                QGCMouseArea { anchors.fill: parent; onClicked: mainWindow.showFlyView() }
            }

            Rectangle {
                width: ScreenTools.defaultFontPixelWidth * 9
                height: ScreenTools.defaultFontPixelHeight * 2.7
                radius: ScreenTools.defaultFontPixelWidth * 0.45
                color: "white"

                QGCLabel { anchors.centerIn: parent; text: qsTr("Save"); color: "#303030"; font.bold: true }
                QGCMouseArea { anchors.fill: parent; onClicked: planMasterController.saveToSelectedFile() }
            }
        }
    }
}
