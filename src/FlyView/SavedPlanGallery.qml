pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtLocation
import QtPositioning

import QGroundControl
import QGroundControl.Controls

/// Gallery of user-saved mission plans. Selecting a card and pressing Upload
/// returns the fully qualified plan path to the caller.
Popup {
    id: root

    signal planSelected(string filePath)
    signal browseRequested()

    property string folder
    property var nameFilters: ["*.plan"]
    property var _planFiles: []
    property int _selectedIndex: -1

    readonly property color _accentGreen: "#00a04c"
    readonly property color _titleColor: "#202124"
    readonly property color _bodyColor: "#5f6368"
    readonly property color _borderColor: "#e1e4e8"
    readonly property var _internalPlanFiles: [
        "last_executed_mission.plan",
        "route_mapping_last_uploaded.plan",
        "agriculture_spraying_last_uploaded.plan",
        "seed_spreader_last_uploaded.plan",
        "route_mapping_transfer.plan"
    ]

    parent: Overlay.overlay
    x: 0
    y: 0
    width: mainWindow.width
    height: mainWindow.height
    padding: 0
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape

    function refreshPlans() {
        if (folder === "") {
            _planFiles = []
            _selectedIndex = -1
            return
        }
        var allFiles = QGCFileDialogController.getPlanFileInfoList(folder, nameFilters)
        var visibleFiles = []
        for (var i = 0; i < allFiles.length; i++) {
            var fileInfo = allFiles[i]
            if (_internalPlanFiles.indexOf(fileInfo.fileName.toLowerCase()) === -1) {
                visibleFiles.push(fileInfo)
            }
        }
        _planFiles = visibleFiles
        _selectedIndex = -1
    }

    function formatFileSize(byteCount) {
        var bytes = Number(byteCount)
        if (!isFinite(bytes) || bytes < 0) {
            return qsTr("0 B")
        }
        if (bytes < 1024) {
            return qsTr("%1 B").arg(Math.round(bytes))
        }
        if (bytes < 1024 * 1024) {
            return qsTr("%1 KB").arg((bytes / 1024).toFixed(1))
        }
        return qsTr("%1 MB").arg((bytes / (1024 * 1024)).toFixed(1))
    }

    function uploadSelectedPlan() {
        if (_selectedIndex < 0 || _selectedIndex >= _planFiles.length) {
            return
        }
        var selectedPath = _planFiles[_selectedIndex].filePath
        close()
        planSelected(selectedPath)
    }

    onOpened: refreshPlans()
    onClosed: {
        _planFiles = []
        _selectedIndex = -1
    }

    background: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.58)
    }

    contentItem: Item {
        Rectangle {
            id: dialogFrame
            anchors.centerIn: parent
            width: Math.min(parent.width - ScreenTools.defaultFontPixelWidth * 2,
                            ScreenTools.defaultFontPixelWidth * 88)
            height: Math.min(parent.height - ScreenTools.defaultFontPixelHeight,
                             ScreenTools.defaultFontPixelHeight * 36)
            color: "white"
            radius: ScreenTools.defaultFontPixelWidth * 0.9
            clip: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: ScreenTools.defaultFontPixelWidth * 2
                    Layout.rightMargin: ScreenTools.defaultFontPixelWidth * 2
                    Layout.topMargin: ScreenTools.defaultFontPixelHeight
                    Layout.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.75
                    spacing: ScreenTools.defaultFontPixelHeight * 0.2

                    QGCLabel {
                        Layout.fillWidth: true
                        text: qsTr("Saved Plans")
                        color: root._titleColor
                        font.pointSize: ScreenTools.mediumFontPointSize
                        font.weight: Font.DemiBold
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        text: root._planFiles.length === 1
                              ? qsTr("Select the saved plan to upload for this mission.")
                              : qsTr("Select a saved plan to upload for this mission. %1 plans found.").arg(root._planFiles.length)
                        color: root._bodyColor
                        wrapMode: Text.WordWrap
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: root._borderColor
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: ScreenTools.defaultFontPixelWidth
                    Layout.rightMargin: ScreenTools.defaultFontPixelWidth
                    Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.65
                    Layout.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.65

                    GridView {
                        id: planGrid
                        anchors.fill: parent
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: root._planFiles
                        readonly property real minimumCardWidth: ScreenTools.defaultFontPixelWidth * 21
                        readonly property int columnCount: Math.max(1, Math.min(4, Math.floor(width / minimumCardWidth)))
                        cellWidth: width / columnCount
                        cellHeight: ScreenTools.defaultFontPixelHeight * 10

                        ScrollBar.vertical: ScrollBar {
                            policy: planGrid.contentHeight > planGrid.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                        }

                        delegate: Item {
                            id: planDelegate

                            required property int index
                            required property var modelData

                            width: planGrid.cellWidth
                            height: planGrid.cellHeight

                            Rectangle {
                                id: planCard
                                anchors.fill: parent
                                anchors.margins: ScreenTools.defaultFontPixelWidth * 0.55
                                color: planDelegate.index === root._selectedIndex ? "#efffee" : "#fafbfc"
                                radius: ScreenTools.defaultFontPixelWidth * 0.7
                                border.width: planDelegate.index === root._selectedIndex ? 2 : 1
                                border.color: planDelegate.index === root._selectedIndex ? root._accentGreen : root._borderColor

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: ScreenTools.defaultFontPixelWidth
                                    spacing: ScreenTools.defaultFontPixelHeight * 0.25

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        Rectangle {
                                            id: mapPreviewFrame
                                            anchors.fill: parent
                                            radius: ScreenTools.defaultFontPixelWidth * 0.45
                                            color: "#e9ecef"
                                            clip: true

                                            Map {
                                                id: previewMap
                                                anchors.fill: parent
                                                plugin: Plugin { name: "QGroundControl" }
                                                opacity: 0.99
                                                copyrightsVisible: false
                                                visible: planDelegate.modelData.hasPreview

                                                function updateActiveMapType() {
                                                    var settings = QGroundControl.settingsManager.flightMapSettings
                                                    var fullMapName = settings.mapProvider.value + " " + settings.mapType.value
                                                    for (var i = 0; i < supportedMapTypes.length; i++) {
                                                        if (supportedMapTypes[i].name === fullMapName) {
                                                            activeMapType = supportedMapTypes[i]
                                                            return
                                                        }
                                                    }
                                                }

                                                function fitPlanPreview() {
                                                    if (!mapReady || !planDelegate.modelData.hasPreview) {
                                                        return
                                                    }

                                                    var latitudeSpan = Math.max(0.00012,
                                                                                planDelegate.modelData.north - planDelegate.modelData.south)
                                                    var longitudeSpan = Math.max(0.00012,
                                                                                 planDelegate.modelData.east - planDelegate.modelData.west)
                                                    var latitudePadding = latitudeSpan * 0.14
                                                    var longitudePadding = longitudeSpan * 0.14
                                                    visibleRegion = QtPositioning.rectangle(
                                                                QtPositioning.coordinate(planDelegate.modelData.north + latitudePadding,
                                                                                         planDelegate.modelData.west - longitudePadding),
                                                                QtPositioning.coordinate(planDelegate.modelData.south - latitudePadding,
                                                                                         planDelegate.modelData.east + longitudePadding))
                                                    if (zoomLevel > 20) {
                                                        zoomLevel = 20
                                                    }
                                                }

                                                onMapReadyChanged: {
                                                    if (mapReady) {
                                                        updateActiveMapType()
                                                        previewFitTimer.restart()
                                                    }
                                                }
                                                onWidthChanged: previewFitTimer.restart()
                                                onHeightChanged: previewFitTimer.restart()

                                                Timer {
                                                    id: previewFitTimer
                                                    interval: 0
                                                    repeat: false
                                                    onTriggered: previewMap.fitPlanPreview()
                                                }

                                                MapPolygon {
                                                    path: planDelegate.modelData.boundaryPath
                                                    color: Qt.rgba(1, 1, 1, 0.08)
                                                    border.color: Qt.rgba(1, 1, 1, 0.94)
                                                    border.width: 1.5
                                                }

                                                MapPolyline {
                                                    path: planDelegate.modelData.routePath
                                                    line.color: "#ffe11a"
                                                    line.width: 2
                                                }

                                                MapQuickItem {
                                                    coordinate: planDelegate.modelData.takeoffValid
                                                                ? planDelegate.modelData.takeoffCoordinate
                                                                : planDelegate.modelData.startCoordinate
                                                    anchorPoint.x: startMarker.width / 2
                                                    anchorPoint.y: startMarker.height / 2
                                                    visible: planDelegate.modelData.hasPreview

                                                    sourceItem: Rectangle {
                                                        id: startMarker
                                                        width: ScreenTools.defaultFontPixelHeight * 0.9
                                                        height: width
                                                        radius: width / 2
                                                        color: "#14b85a"
                                                        border.color: "white"
                                                        border.width: 1.5

                                                        QGCLabel {
                                                            anchors.centerIn: parent
                                                            text: planDelegate.modelData.takeoffValid ? "T" : ""
                                                            color: "white"
                                                            font.pixelSize: parent.height * 0.58
                                                            font.weight: Font.Bold
                                                        }
                                                    }
                                                }

                                                MapQuickItem {
                                                    coordinate: planDelegate.modelData.endCoordinate
                                                    anchorPoint.x: endMarker.width / 2
                                                    anchorPoint.y: endMarker.height / 2
                                                    visible: planDelegate.modelData.hasPreview

                                                    sourceItem: Rectangle {
                                                        id: endMarker
                                                        width: ScreenTools.defaultFontPixelHeight * 0.72
                                                        height: width
                                                        radius: width / 2
                                                        color: "#f9ab00"
                                                        border.color: "white"
                                                        border.width: 1.5
                                                    }
                                                }
                                            }

                                            QGCColoredImage {
                                                anchors.centerIn: parent
                                                width: Math.min(parent.width, parent.height) * 0.42
                                                height: width
                                                source: "/res/modern-icons/MaterialSymbolsStacksRounded.svg"
                                                color: "#687076"
                                                visible: !planDelegate.modelData.hasPreview
                                            }
                                        }

                                        Rectangle {
                                            anchors.top: parent.top
                                            anchors.right: parent.right
                                            width: ScreenTools.defaultFontPixelHeight * 1.35
                                            height: width
                                            radius: width / 2
                                            color: root._accentGreen
                                            visible: planDelegate.index === root._selectedIndex

                                            QGCLabel {
                                                anchors.centerIn: parent
                                                text: "\u2713"
                                                color: "white"
                                                font.weight: Font.Bold
                                            }
                                        }
                                    }

                                    QGCLabel {
                                        Layout.fillWidth: true
                                        text: planDelegate.modelData.baseName
                                        color: root._titleColor
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideMiddle
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    QGCLabel {
                                        Layout.fillWidth: true
                                        text: Qt.formatDateTime(planDelegate.modelData.lastModified, "dd MMM yyyy, hh:mm")
                                              + "  \u2022  " + root.formatFileSize(planDelegate.modelData.size)
                                        color: root._bodyColor
                                        font.pointSize: ScreenTools.smallFontPointSize
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }

                                QGCMouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root._selectedIndex = planDelegate.index
                                    onDoubleClicked: {
                                        root._selectedIndex = planDelegate.index
                                        root.uploadSelectedPlan()
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, ScreenTools.defaultFontPixelWidth * 42)
                        visible: root._planFiles.length === 0
                        spacing: ScreenTools.defaultFontPixelHeight * 0.55

                        QGCColoredImage {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 3.2
                            Layout.preferredHeight: Layout.preferredWidth
                            source: "/res/modern-icons/MaterialSymbolsStacksRounded.svg"
                            color: "#9aa0a6"
                        }

                        QGCLabel {
                            Layout.fillWidth: true
                            text: qsTr("No saved plans yet")
                            color: root._titleColor
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                        }

                        QGCLabel {
                            Layout.fillWidth: true
                            text: qsTr("Plans saved in the Missions folder will appear here. You can also browse for a plan in another folder.")
                            color: root._bodyColor
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: root._borderColor
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: ScreenTools.defaultFontPixelWidth * 1.5
                    Layout.rightMargin: ScreenTools.defaultFontPixelWidth * 1.5
                    Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.65
                    Layout.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.65
                    spacing: ScreenTools.defaultFontPixelWidth

                    QGCButton {
                        text: qsTr("Browse Files")
                        primary: false
                        onClicked: {
                            root.close()
                            root.browseRequested()
                        }
                    }

                    Item { Layout.fillWidth: true }

                    QGCButton {
                        text: qsTr("Cancel")
                        primary: false
                        onClicked: root.close()
                    }

                    QGCButton {
                        text: qsTr("Upload Selected Plan")
                        primary: true
                        enabled: root._selectedIndex >= 0
                        onClicked: root.uploadSelectedPlan()
                    }
                }
            }
        }
    }
}
