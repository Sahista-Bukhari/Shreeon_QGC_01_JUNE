pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtLocation
import QtPositioning

import QGroundControl
import QGroundControl.Controls

/// Gallery of user-saved mission plans. Selecting a card and pressing Upload
/// returns the fully qualified plan path and its originating mission mode.
Popup {
    id: root

    signal planSelected(string filePath, string missionMode)
    signal browseRequested()

    property string folder
    property var nameFilters: ["*.plan"]
    property var _planFiles: []
    property int _selectedIndex: -1

    readonly property color _accentGreen:     "#00a651"
    readonly property color _softGreen:       "#e2f4eb"
    readonly property color _titleColor:      "#202124"
    readonly property color _bodyColor:       "#5f6368"
    readonly property color _borderColor:     "#dfe3e1"
    readonly property color _surfaceGray:     "#f5f7f6"
    readonly property color _cardGray:        "#eef1ef"
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

    function missionModeDisplayName(missionMode) {
        switch (missionMode) {
        case "agricultureSpraying":
            return qsTr("Agriculture Spraying")
        case "seedSpreader":
            return qsTr("Seed Spreader")
        case "customMission":
            return qsTr("Custom Mission")
        case "routeMapping":
        default:
            return qsTr("Route Mapping")
        }
    }

    function missionModeLabel(fileInfo) {
        var modeName = missionModeDisplayName(fileInfo.missionMode)
        return fileInfo.missionModeInferred
                ? qsTr("%1 (legacy)").arg(modeName)
                : modeName
    }

    function uploadSelectedPlan() {
        if (_selectedIndex < 0 || _selectedIndex >= _planFiles.length) {
            return
        }
        var selectedPlan = _planFiles[_selectedIndex]
        close()
        planSelected(selectedPlan.filePath, selectedPlan.missionMode)
    }

    onOpened: refreshPlans()
    onClosed: {
        _planFiles = []
        _selectedIndex = -1
    }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation {
                target: drawerTranslate
                property: "x"
                from: drawerFrame.width
                to: 0
                duration: 340
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: drawerShade
                property: "opacity"
                from: 0
                to: 1
                duration: 240
                easing.type: Easing.OutCubic
            }
        }
    }

    exit: Transition {
        ParallelAnimation {
            NumberAnimation {
                target: drawerTranslate
                property: "x"
                from: 0
                to: drawerFrame.width
                duration: 260
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: drawerShade
                property: "opacity"
                from: 1
                to: 0
                duration: 220
                easing.type: Easing.InCubic
            }
        }
    }

    background: Item { }

    contentItem: Item {
        Rectangle {
            id: drawerShade
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.38)

            QGCMouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }
        }

        Rectangle {
            id: drawerFrame
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: ScreenTools.isMobile
                   ? parent.width
                   : Math.round(parent.width * 0.72)
            color: "white"
            clip: true
            border.width: 1
            border.color: root._borderColor

            transform: Translate { id: drawerTranslate }

            DeadMouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(ScreenTools.toolbarHeight,
                                                     ScreenTools.defaultFontPixelHeight * 3.2)

                    QGCLabel {
                        anchors.centerIn: parent
                        text: qsTr("Saved Plans")
                        color: root._titleColor
                        font.pointSize: ScreenTools.largeFontPointSize
                        font.weight: Font.DemiBold
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: ScreenTools.defaultFontPixelWidth
                        width: Math.max(30, ScreenTools.defaultFontPixelHeight * 1.8)
                        height: width
                        radius: width / 2
                        color: closeMouse.pressed
                               ? root._softGreen
                               : (closeMouse.containsMouse ? root._surfaceGray : "white")
                        border.width: 1
                        border.color: closeMouse.containsMouse ? root._accentGreen : root._borderColor

                        QGCLabel {
                            anchors.centerIn: parent
                            text: "×"
                            color: closeMouse.containsMouse ? root._accentGreen : root._bodyColor
                            font.pixelSize: parent.height * 0.66
                        }

                        QGCMouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.close()
                        }

                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: root._borderColor
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.7
                    color: root._surfaceGray

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 1.5
                        anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 1.5
                        spacing: ScreenTools.defaultFontPixelWidth * 0.8

                        Rectangle {
                            Layout.preferredWidth: 3
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.45
                            radius: width / 2
                            color: root._accentGreen
                        }

                        QGCLabel {
                            Layout.fillWidth: true
                            text: root._planFiles.length === 1
                                  ? qsTr("Select the saved plan to upload for this mission.")
                                  : qsTr("Select a saved plan to upload for this mission. %1 plans found.").arg(root._planFiles.length)
                            color: root._bodyColor
                            elide: Text.ElideRight
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: ScreenTools.defaultFontPixelWidth
                    Layout.rightMargin: ScreenTools.defaultFontPixelWidth
                    Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.65
                    Layout.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.65
                    color: root._surfaceGray
                    radius: ScreenTools.defaultFontPixelWidth * 0.65

                    GridView {
                        id: planGrid
                        anchors.fill: parent
                        anchors.margins: ScreenTools.defaultFontPixelWidth * 0.45
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: root._planFiles
                        readonly property real minimumCardWidth: ScreenTools.defaultFontPixelWidth * 25
                        readonly property int columnCount: Math.max(1, Math.min(3, Math.floor(width / minimumCardWidth)))
                        cellWidth: width / columnCount
                        cellHeight: ScreenTools.defaultFontPixelHeight * 12.2

                        ScrollBar.vertical: ScrollBar {
                            policy: planGrid.contentHeight > planGrid.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                            width: Math.max(3, ScreenTools.defaultFontPixelWidth * 0.35)

                            contentItem: Rectangle {
                                implicitWidth: 3
                                radius: width / 2
                                color: root._accentGreen
                            }
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
                                color: planDelegate.index === root._selectedIndex
                                       ? root._softGreen
                                       : (planCardMouse.containsMouse ? "#ffffff" : root._cardGray)
                                radius: ScreenTools.defaultFontPixelWidth * 0.7
                                border.width: planDelegate.index === root._selectedIndex ? 2 : 1
                                border.color: planDelegate.index === root._selectedIndex || planCardMouse.containsMouse
                                              ? root._accentGreen
                                              : root._borderColor

                                Behavior on color { ColorAnimation { duration: 140 } }
                                Behavior on border.color { ColorAnimation { duration: 140 } }

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

                                    Rectangle {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.preferredWidth: modeLabel.implicitWidth + ScreenTools.defaultFontPixelWidth * 1.7
                                        Layout.preferredHeight: modeLabel.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.32
                                        radius: height / 2
                                        color: planDelegate.modelData.missionModeInferred ? "#fff3cd" : root._softGreen

                                        QGCLabel {
                                            id: modeLabel
                                            anchors.centerIn: parent
                                            text: root.missionModeLabel(planDelegate.modelData)
                                            color: planDelegate.modelData.missionModeInferred ? "#765600" : root._accentGreen
                                            font.pointSize: ScreenTools.smallFontPointSize
                                            font.weight: Font.DemiBold
                                        }
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
                                    id: planCardMouse
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
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.2
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

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(ScreenTools.defaultFontPixelHeight * 3.4,
                                                     ScreenTools.implicitButtonHeight + ScreenTools.defaultFontPixelHeight)
                    color: "white"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 1.5
                        anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 1.5
                        anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.5
                        anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.5
                        spacing: ScreenTools.defaultFontPixelWidth

                        QGCButton {
                            text: qsTr("Browse Files")
                            primary: false
                            compact: true
                            backgroundColor: root._accentGreen
                            textColor: "white"
                            fontWeight: Font.Medium
                            onClicked: {
                                root.close()
                                root.browseRequested()
                            }
                        }

                        Item { Layout.fillWidth: true }

                        QGCButton {
                            text: qsTr("Cancel")
                            primary: false
                            compact: true
                            backgroundColor: root._accentGreen
                            textColor: "white"
                            fontWeight: Font.Medium
                            onClicked: root.close()
                        }

                        QGCButton {
                            text: qsTr("Upload Selected Plan")
                            primary: false
                            compact: true
                            backgroundColor: root._accentGreen
                            textColor: "white"
                            fontWeight: Font.Medium
                            enabled: root._selectedIndex >= 0
                            opacity: enabled ? 1 : 0.48
                            onClicked: root.uploadSelectedPlan()
                        }
                    }
                }
            }
        }
    }
}
