import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Qt5Compat.GraphicalEffects

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.UTMSP

Item {
    id: root

    QGCPalette { id: qgcPal; colorGroupEnabled: true }
    
    // Properties
    required property var planMasterController
    required property var flyViewRoot
    
    // Internal shortcuts
    property var _planMasterController: planMasterController
    property var _missionController: _planMasterController.missionController
    property bool _controllerOffline: _planMasterController.offline
    property var _controllerDirty: _planMasterController.dirty
    property var _syncInProgress: _planMasterController.syncInProgress
    property var _visualItems: _missionController.visualItems
    property bool _hasPlanItems: _planMasterController.containsItems
    property bool _utmspEnabled: QGroundControl.utmspSupported
    property bool planEditMode: false
    property bool _missionRunning: flyViewRoot ? flyViewRoot.missionRunning : false

    // Map settings
    property var  _settingsManager:     QGroundControl.settingsManager
    property var  _mapEngineManager:    QGroundControl.mapEngineManager
    property var  _mapProviderFact:     _settingsManager.flightMapSettings.mapProvider
    property var  _mapTypeFact:         _settingsManager.flightMapSettings.mapType
    property bool _mapSettingsVisible:  false

    implicitWidth: buttonRow.width + (ScreenTools.defaultFontPixelWidth * 3.5)
    implicitHeight: Math.round(ScreenTools.defaultFontPixelHeight * 2.8)

    // Signal handlers (Copied from PlanToolBarIndicators logic)
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

    function _clearClicked() {
        if (_missionRunning) {
            return
        }

        if (flyViewRoot) {
            flyViewRoot.confirmAndClearPlan()
        }
    }

    // UI Implementation - Scalable Container for the Strip
    Item {
        id: scalableContainer
        anchors.fill: parent
        
        // Transform Origin set to Top Right so the bottom-left shrinks UP and Right
        transformOrigin: Item.TopRight

        scale: root._mapSettingsVisible ? 0.93 : 1.0
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        // No background — icons float directly over the map like the reference

        Row {
            id: buttonRow
            anchors.centerIn: parent
            spacing: ScreenTools.defaultFontPixelWidth * 1.6
            
            // Helper component for icon buttons — bare icons with drop shadow for visibility
            component IconButton: Item {
                property string iconSource
                signal clicked()
                property bool highlighted: false
                property bool isMapButton: false
                property bool buttonEnabled: true

                width: Math.round(ScreenTools.defaultFontPixelWidth * 5)
                height: width
                
                // Hide this button if it's the Map Button and we are in "Expanded Mode"
                opacity: (isMapButton && root._mapSettingsVisible) ? 0.0 : (buttonEnabled ? 1.0 : 0.35)
                visible: true
                
                Behavior on opacity { NumberAnimation { duration: 150 } }

                QGCColoredImage {
                    id: btnIcon
                    anchors.centerIn: parent
                    width: Math.round(parent.width * 0.85)
                    height: width
                    sourceSize.width:  width * Screen.devicePixelRatio
                    sourceSize.height: height * Screen.devicePixelRatio
                    source: iconSource
                    color: highlighted ? "#2E9B54" : "white"
                    smooth: true
                    mipmap: true

                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                // Drop shadow for crisp visibility over map
                DropShadow {
                    anchors.fill: btnIcon
                    source: btnIcon
                    horizontalOffset: 0
                    verticalOffset: 1
                    radius: 8
                    samples: 17
                    color: "#AA000000"
                }
                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: parent.buttonEnabled && parent.visible
                    cursorShape: parent.buttonEnabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                    onClicked: parent.clicked()
                    onEntered: if (parent.buttonEnabled) btnIcon.opacity = 0.7
                    onExited:  btnIcon.opacity = 1.0
                }
            }

            Item {
                width: flightModePill.implicitWidth + ScreenTools.defaultFontPixelWidth * 5.4
                height: buttonRow.height
                visible: QGroundControl.multiVehicleManager.activeVehicle

                FlightModeIndicator {
                    id: flightModePill
                    anchors.centerIn: parent
                    fontPointSize: ScreenTools.defaultFontPointSize
                    iconRotation: 90
                    showText: false
                    visible: parent.visible
                }
            }


            // Open / import plan (uploads to vehicle after load)
            IconButton {
                iconSource: "/res/modern-icons/MaterialSymbolsCreateNewFolder.svg"
                buttonEnabled: !root._missionRunning && !root._planMasterController.syncInProgress
                onClicked: {
                    if (root.flyViewRoot) {
                        root.flyViewRoot.openFlyViewPlanImportDialog()
                    }
                }
            }
            
            // Save
            IconButton {
                iconSource: "/res/modern-icons/MaterialSymbolsSave.svg"
                buttonEnabled: !root._syncInProgress && root._hasPlanItems
                onClicked: root._saveButtonClicked()
            }
            
            // Download
            IconButton {
                iconSource: "/res/modern-icons/MaterialSymbolsDownload2Rounded.svg"
                buttonEnabled: root._utmspEnabled ? (!root._syncInProgress && UTMSPStateStorage.enableMissionDownloadButton) : !root._syncInProgress
                onClicked: root._downloadClicked()
            }

            // Clear
            IconButton {
                iconSource: "/res/modern-icons/MaterialSymbolsLightDirectorySync.svg"
                buttonEnabled: !root._missionRunning && !root._syncInProgress
                onClicked: root._clearClicked()
            }
        }
    }

    /*
    // Refactored Map Settings Component (Hidden for now)
    FlyViewMapSettings {
        mapToolsRoot:       root
        scalableContainer:  scalableContainer
        mapEngineManager:   root._mapEngineManager
        mapProviderFact:    root._mapProviderFact
        mapTypeFact:        root._mapTypeFact
    }
    */

}
