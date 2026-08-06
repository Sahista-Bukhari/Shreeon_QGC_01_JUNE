import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.UTMSP

// Toolbar for Plan View
RowLayout {
    required property var planMasterController

    id: root
    spacing: compact ? ScreenTools.defaultFontPixelWidth * 0.55 : ScreenTools.defaultFontPixelWidth

    property bool compact: false
    property var _planMasterController: planMasterController
    property var _missionController: _planMasterController.missionController
    property var _geoFenceController: _planMasterController.geoFenceController
    property var _rallyPointController: _planMasterController.rallyPointController
    property bool _controllerOffline: _planMasterController.offline
    property var _controllerDirty: _planMasterController.dirty
    property var _syncInProgress: _planMasterController.syncInProgress
    property var _visualItems: _missionController.visualItems
    property bool _hasPlanItems: _planMasterController.containsItems

    readonly property real _margins: ScreenTools.defaultFontPixelWidth

    // Properties of UTM adapter
    property bool _utmspEnabled: QGroundControl.utmspSupported

    function _uploadClicked() {
        mainWindow.confirmUploadToFlyView(mainWindow.activeMissionEditor, function() {
            if (_utmspEnabled) {
                QGroundControl.utmspManager.utmspVehicle.triggerActivationStatusBar(true);
                UTMSPStateStorage.removeFlightPlanState = true
                UTMSPStateStorage.indicatorDisplayStatus = true
            }
            if (_planMasterController.upload()) {
                mainWindow.markMissionPlanUploaded(mainWindow.activeMissionEditor)
            }
        })
    }

    function _downloadClicked() {
        if (_planMasterController.dirty) {
            mainWindow.showMessageDialog(qsTr("Download"),
                                         qsTr("You have unsaved/unsent changes. Downloading from the Vehicle will lose these changes. Are you sure?"),
                                         Dialog.Yes | Dialog.Cancel,
                                         function() { _planMasterController.loadFromVehicle() })
        } else {
            _planMasterController.loadFromVehicle()
        }
    }

    function _openButtonClicked() {
        if (_planMasterController.dirty) {
            mainWindow.showMessageDialog(qsTr("Open Plan"),
                                        qsTr("You have unsaved/unsent changes. Loading a new Plan will lose these changes. Are you sure?"),
                                        Dialog.Yes | Dialog.Cancel,
                                        function() { _planMasterController.loadFromSelectedFile() } )
        } else {
            _planMasterController.loadFromSelectedFile()
        }
    }

    function _saveButtonClicked() {
        if(_planMasterController.currentPlanFile !== "") {
            _planMasterController.saveToCurrent()
            mainWindow.showMessageDialog(qsTr("Save"),
                                        qsTr("Plan saved to `%1`").arg(_planMasterController.currentPlanFile),
                                        Dialog.Ok)
        } else {
            _planMasterController.saveToSelectedFile()
        }
    }

    function _saveAsKMLClicked() {
        // Don't save if we only have Mission Settings item
        if (_visualItems.count > 1) {
            _planMasterController.saveKmlToSelectedFile()
        }
    }

    function _storageClearButtonClicked() {
        mainWindow.confirmClearRouteMappingPlan()
    }

    function _vehicleClearButtonClicked() {
        mainWindow.confirmClearRouteMappingPlan()
    }

    function _clearClicked() {
        mainWindow.confirmClearRouteMappingPlan()
    }

    QGCPalette { id: qgcPal }

    QGCButton {
        text: qsTr("Open")
        iconSource: "/res/modern-icons/MaterialSymbolsCreateNewFolder.svg"
        compact: root.compact
        pointSize: root.compact ? ScreenTools.defaultFontPointSize : ScreenTools.defaultFontPointSize
        heightFactor: root.compact ? 0.42 : 0.5
        enabled: !_planMasterController.syncInProgress
        onClicked: _openButtonClicked()
    }

    QGCButton {
        text: _planMasterController.currentPlanFile === "" ? qsTr("Save As") : qsTr("Save")
        iconSource: "/res/modern-icons/MaterialSymbolsSave.svg"
        compact: root.compact
        pointSize: ScreenTools.defaultFontPointSize
        heightFactor: root.compact ? 0.42 : 0.5
        enabled: !_syncInProgress && _hasPlanItems
        primary: _controllerDirty
        onClicked: _saveButtonClicked()
    }

    QGCButton {
        id: uploadButton
        text: qsTr("Upload")
        iconSource: "/res/modern-icons/MaterialSymbolsUpload2Rounded.svg"
        compact: root.compact
        pointSize: ScreenTools.defaultFontPointSize
        heightFactor: root.compact ? 0.42 : 0.5
        enabled: _utmspEnabled ? (!_syncInProgress && UTMSPStateStorage.enableMissionUploadButton) : (!_syncInProgress && _hasPlanItems)
        visible: !_syncInProgress
        primary: _controllerDirty
        onClicked: _uploadClicked()
    }

    QGCButton {
        text: qsTr("Clear")
        iconSource: "/res/modern-icons/MaterialSymbolsDeleteRounded.svg"
        compact: root.compact
        pointSize: ScreenTools.defaultFontPointSize
        heightFactor: root.compact ? 0.42 : 0.5
        enabled: !_syncInProgress
        onClicked: _clearClicked()
    }

    QGCButton {
        id: hamburgerButton
        iconSource: "qrc:/qmlimages/Hamburger.svg"
        compact: root.compact
        heightFactor: root.compact ? 0.42 : 0.5
        implicitWidth: root.compact ? ScreenTools.defaultFontPixelHeight * 3.15 : ScreenTools.implicitButtonWidth

        onClicked: {
            // For some strange reason using mainWindow in mapToItem doesn't work, so we use globals.parent instead which also gets us mainWindow
            var topLeft = mapToItem(globals.parent, 0, 0)
            var dropPanel = hamburgerDropPanelComponent.createObject(mainWindow, {
                clickRect: Qt.rect(topLeft.x, topLeft.y, width, height),
                dropBelow: true
            })
            dropPanel.open()
        }
    }

    Component {
        id: hamburgerDropPanelComponent

        DropPanel {
            id: dropPanel
            dropBelow: true

            sourceComponent: Component {
                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelHeight / 3

                    QGCButton {
                        Layout.fillWidth: true
                        Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 18
                        text: qsTr("Save as KML")
                        compact: true
                        heightFactor: 0.32
                        enabled: !_syncInProgress && _hasPlanItems

                        onClicked: {
                            dropPanel.close()
                            _saveAsKMLClicked()
                        }
                    }

                    QGCButton {
                        Layout.fillWidth: true
                        text: qsTr("Download")
                        iconSource: "/res/modern-icons/MaterialSymbolsDownload2Rounded.svg"
                        compact: true
                        heightFactor: 0.32
                        enabled: _utmspEnabled ? !_syncInProgress && UTMSPStateStorage.enableMissionDownloadButton : !_syncInProgress
                        visible: !_syncInProgress

                        onClicked: {
                            dropPanel.close()
                            _downloadClicked()
                        }
                    }
                }
            }
        }
    }
}
