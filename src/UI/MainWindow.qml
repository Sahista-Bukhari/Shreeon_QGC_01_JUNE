import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Window
import QtCore

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.FlyView
import QGroundControl.FlightMap
import QGroundControl.Toolbar

/// @brief Native QML top level window
/// All properties defined here are visible to all QML pages.
ApplicationWindow {
    id:         mainWindow
    height: 350
    width: 800
    visible:    true
    // The special casing for android prevents white bars from showing up on the edges of the screen with newer android versions
    flags:      Qt.Window | (ScreenTools.isAndroid ? Qt.ExpandedClientAreaHint | Qt.NoTitleBarBackgroundHint : 0)

    property bool   _utmspSendActTrigger

    // Set true to preview only CustomHomePage (no Fly View / mode selection).
    readonly property bool homePageOnly: true

    // UI theme: Default = current product look, Black = QGC Indoor/Dark, White = QGC Outdoor/Light
    readonly property int themeDefault: 0
    readonly property int themeBlack:   1
    readonly property int themeWhite:   2
    property int uiThemeMode: themeSettings.uiThemeMode

    Settings {
        id: themeSettings
        category: "UiTheme"
        property int uiThemeMode: 0
    }

    function isThemeExemptView() {
        // Fly View + mission editors always keep the Black (Indoor/Dark) look
        return flyView.visible
                || agricultureSprayingMissionView.visible
                || routeMappingView.visible
                || seedSpraderMision.visible
                || customMissionView.visible
    }

    function _forceBlackTheme() {
        var appSettings = QGroundControl.settingsManager.appSettings
        if (!appSettings || !appSettings.indoorPalette)
            return
        if (appSettings.indoorPalette.rawValue !== 1)
            appSettings.indoorPalette.rawValue = 1
        // Also lock the live palette in case globalTheme was changed directly
        if (QGroundControl.globalPalette.globalTheme !== QGCPalette.Dark)
            QGroundControl.globalPalette.globalTheme = QGCPalette.Dark
    }

    function _applySelectedTheme() {
        var appSettings = QGroundControl.settingsManager.appSettings
        if (!appSettings || !appSettings.indoorPalette)
            return
        // Black → Indoor/Dark. Default & White → Outdoor/Light
        var wantIndoor = (uiThemeMode === themeBlack) ? 1 : 0
        if (appSettings.indoorPalette.rawValue !== wantIndoor)
            appSettings.indoorPalette.rawValue = wantIndoor
    }

    function applyUiTheme() {
        // Application Settings / tools follow the selected theme
        if (toolDrawer.visible) {
            _applySelectedTheme()
            return
        }

        // Fly View (and mission editors) always stay on Black theme — never Default/White
        if (isThemeExemptView()) {
            _forceBlackTheme()
            return
        }

        // Mode selection / home (and anywhere else) follow the selected theme
        _applySelectedTheme()
    }

    function setUiThemeMode(mode) {
        if (mode !== themeDefault && mode !== themeBlack && mode !== themeWhite)
            return
        themeSettings.uiThemeMode = mode
        uiThemeMode = mode
        applyUiTheme()
    }

    Component.onCompleted: {
        console.log("the application begins")
        applyUiTheme()

        if (homePageOnly) {
            customHomePage.visible = true
            return
        }

        loadLastExecutedMissionMetadata()
        restoreLastExecutedMissionOnStartup()

        // Start the sequence of first run prompt(s)
        // This is available in all editors.
        customHomePage.visible = true
        firstRunPromptManager.nextPrompt()
    }

    // Persists which editor last uploaded the active vehicle mission.
    Settings {
        id: missionExecutionSettings
        category: "MissionExecution"
        property string lastUploadedMissionEditor: ""
    }

    /// Saves main window position and size and re-opens it in the same position and size next time
    MainWindowSavedState {
        window: mainWindow

    }
    QtObject {
        id: firstRunPromptManager

        property var currentDialog:     null
        property var rgPromptIds:       QGroundControl.corePlugin.firstRunPromptsToShow()
        property int nextPromptIdIndex: 0

        function clearNextPromptSignal() {
            if (currentDialog) {
                currentDialog.closed.disconnect(nextPrompt)
            }
        }

        function nextPrompt() {
            if (nextPromptIdIndex < rgPromptIds.length) {
                var component = Qt.createComponent(QGroundControl.corePlugin.firstRunPromptResource(rgPromptIds[nextPromptIdIndex]));
                currentDialog = component.createObject(mainWindow)
                currentDialog.closed.connect(nextPrompt)
                currentDialog.open()
                nextPromptIdIndex++
            } else {
                currentDialog = null
                showPreFlightChecklistIfNeeded()
            }
        }
    }

    readonly property real      _topBottomMargins:          ScreenTools.defaultFontPixelHeight * 0.5

    //-------------------------------------------------------------------------
    //-- Global Scope Variables

    QtObject {
        id: globals

        readonly property var       activeVehicle:                  QGroundControl.multiVehicleManager.activeVehicle
        readonly property real      defaultTextHeight:              ScreenTools.defaultFontPixelHeight
        readonly property real      defaultTextWidth:               ScreenTools.defaultFontPixelWidth
        readonly property var       planMasterControllerFlyView:    flyView.planController
        readonly property var       guidedControllerFlyView:        flyView.guidedController

        // Number of QGCTextField's with validation errors. Used to prevent closing panels with validation errors.
        property int                validationErrorCount:           0

        // Property to manage RemoteID quick access to settings page
        property bool               commingFromRIDIndicator:        false
    }

    /// Default color palette used throughout the UI
    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    //-------------------------------------------------------------------------
    //-- Actions

    signal armVehicleRequest
    signal forceArmVehicleRequest
    signal disarmVehicleRequest
    signal vtolTransitionToFwdFlightRequest
    signal vtolTransitionToMRFlightRequest
    signal showPreFlightChecklistIfNeeded

    //-------------------------------------------------------------------------
    //-- Global Scope Functions

    // Tracks which mission editor owns the active Fly View plan.
    // Values: routeMapping | agricultureSpraying | seedSpreader | customMission | planView
    property string activeMissionEditor: "routeMapping"

    // Editor that last successfully uploaded a plan to Fly View / vehicle.
    // Empty means no mode has an uploaded plan currently owned on Fly View.
    property string uploadedMissionEditor: ""

    function setActiveMissionEditor(editorType) {
        if (editorType && editorType !== "") {
            activeMissionEditor = editorType
        }
    }

    function missionEditorDisplayName(editorType) {
        switch (editorType) {
        case "agricultureSpraying":
            return qsTr("Agriculture Spraying")
        case "seedSpreader":
            return qsTr("Seed Spreader")
        case "customMission":
            return qsTr("Custom Mission")
        case "planView":
            return qsTr("Plan View")
        case "routeMapping":
        default:
            return qsTr("Route Mapping")
        }
    }

    function hasFlyViewPlanFromOtherEditor(editorType) {
        if (uploadedMissionEditor === "" || uploadedMissionEditor === editorType) {
            return false
        }

        var flyHasPlan = flyView._hasFlyViewPlanContent
                || (flyView.planController && flyView.planController.containsItems)
                || (flyView.routeMappingTransectPath && flyView.routeMappingTransectPath.length >= 2)
        return flyHasPlan
    }

    // Clears upload ownership flags on every editor except keepEditorType so
    // Exit / restore cannot bring back a replaced Fly View plan.
    function clearOtherEditorsUploadOwnership(keepEditorType) {
        if (keepEditorType !== "routeMapping") {
            routeMappingView._routeMappingPlanUploaded = false
            routeMappingView._uploadedRouteMappingOverlayData = null
            routeMappingView._editingUploadedPlan = false
            routeMappingView._routeMappingUploadPending = false
        }
        if (keepEditorType !== "agricultureSpraying") {
            agricultureSprayingMissionView._routeMappingPlanUploaded = false
            agricultureSprayingMissionView._uploadedRouteMappingOverlayData = null
            agricultureSprayingMissionView._editingUploadedPlan = false
            agricultureSprayingMissionView._routeMappingUploadPending = false
        }
        if (keepEditorType !== "seedSpreader") {
            seedSpraderMision._routeMappingPlanUploaded = false
            seedSpraderMision._uploadedRouteMappingOverlayData = null
            seedSpraderMision._editingUploadedPlan = false
            seedSpraderMision._routeMappingUploadPending = false
        }
    }

    function markMissionPlanUploaded(editorType) {
        if (!editorType || editorType === "") {
            return
        }
        clearOtherEditorsUploadOwnership(editorType)
        uploadedMissionEditor = editorType
        missionExecutionSettings.lastUploadedMissionEditor = editorType
        setActiveMissionEditor(editorType)
        persistLastExecutedMission(editorType)
    }

    function clearUploadedMissionEditor() {
        uploadedMissionEditor = ""
        missionExecutionSettings.lastUploadedMissionEditor = ""
    }

    function missionSaveDirectory() {
        var savePath = QGroundControl.settingsManager.appSettings.missionSavePath
        return savePath ? savePath : ""
    }

    function lastExecutedPlanFilePath() {
        var savePath = missionSaveDirectory()
        if (savePath === "") {
            return ""
        }
        var separator = savePath.endsWith("/") ? "" : "/"
        return savePath + separator + "last_executed_mission.plan"
    }

    function missionEditorView(editorType) {
        switch (editorType) {
        case "agricultureSpraying":
            return agricultureSprayingMissionView
        case "seedSpreader":
            return seedSpraderMision
        case "customMission":
            return customMissionView
        case "routeMapping":
            return routeMappingView
        default:
            return null
        }
    }

    function loadLastExecutedMissionMetadata() {
        if (missionExecutionSettings.lastUploadedMissionEditor !== "") {
            uploadedMissionEditor = missionExecutionSettings.lastUploadedMissionEditor
        }
    }

    // Saves the last uploaded plan to a single shared file so reconnect can
    // restore the same mission regardless of which mode uploaded it.
    function persistLastExecutedMission(editorType) {
        var editorView = missionEditorView(editorType)
        var planFile = lastExecutedPlanFilePath()
        if (!editorView || planFile === "") {
            return false
        }

        if (editorView._persistUploadedRouteMappingPlan) {
            editorView._persistUploadedRouteMappingPlan()
        }

        if (editorView._planMasterController && editorView._planMasterController.containsItems) {
            editorView._planMasterController.saveToFile(planFile)
            return true
        }

        if (editorType === "customMission" && customMissionView._planMasterController.containsItems) {
            customMissionView._planMasterController.saveToFile(planFile)
            return true
        }

        return false
    }

    function clearLastExecutedMissionPersistence() {
        clearUploadedMissionEditor()

        var planFile = lastExecutedPlanFilePath()
        if (planFile !== "" && QGCFileDialogController.fileExists(planFile)) {
            QGCFileDialogController.deleteFile(planFile)
        }
    }

    // After reconnect, reload the last executed plan into its owning editor and
    // push it back to the vehicle when the autopilot has no mission.
    function tryReuploadLastExecutedPlanAfterReconnect() {
        loadLastExecutedMissionMetadata()
        if (uploadedMissionEditor === "") {
            return false
        }

        var editorView = missionEditorView(uploadedMissionEditor)
        if (!editorView) {
            return false
        }

        if (editorView.tryReuploadRouteMappingPlanAfterReconnect) {
            return editorView.tryReuploadRouteMappingPlanAfterReconnect()
        }

        var planFile = lastExecutedPlanFilePath()
        if (planFile === "" || !QGCFileDialogController.fileExists(planFile)) {
            return false
        }

        if (uploadedMissionEditor === "customMission") {
            customMissionView._planMasterController.loadFromFile(planFile)
            flyView.planController.loadFromFile(planFile)
            if (flyView.planController.containsItems) {
                return flyView.planController.upload()
            }
        }

        return false
    }

    function restoreLastExecutedMissionOnStartup() {
        loadLastExecutedMissionMetadata()
        if (uploadedMissionEditor === "") {
            return
        }

        var editorView = missionEditorView(uploadedMissionEditor)
        if (!editorView) {
            return
        }

        var planFile = lastExecutedPlanFilePath()
        if (planFile === "" || !QGCFileDialogController.fileExists(planFile)) {
            if (editorView.loadPersistedUploadedPlan) {
                editorView.loadPersistedUploadedPlan()
            }
            return
        }

        if (editorView.loadPersistedUploadedPlan) {
            if (!editorView.loadPersistedUploadedPlan() && editorView.loadRouteMappingPlan) {
                editorView.loadRouteMappingPlan(planFile)
                editorView._routeMappingPlanUploaded = true
                editorView._editingUploadedPlan = true
            }
        } else if (uploadedMissionEditor === "customMission") {
            customMissionView._planMasterController.loadFromFile(planFile)
        }

        if (editorView.onFlyViewMissionResyncedFromVehicle) {
            editorView.onFlyViewMissionResyncedFromVehicle()
        }
    }

    // Shared Upload gate: if another mode already pushed a plan to Fly View,
    // ask the user before replacing it.
    function confirmUploadToFlyView(editorType, acceptFunction) {
        if (!hasFlyViewPlanFromOtherEditor(editorType)) {
            if (acceptFunction) {
                acceptFunction()
            }
            return
        }

        var existingName = missionEditorDisplayName(uploadedMissionEditor)
        showMessageDialog(
                    qsTr("Plan Already On Fly View"),
                    qsTr("A plan from %1 is already loaded on Fly View. If you upload now, it will replace the existing plan. Do you want to continue?").arg(existingName),
                    Dialog.Yes | Dialog.Cancel,
                    function() {
                        clearOtherEditorsUploadOwnership(editorType)
                        if (acceptFunction) {
                            acceptFunction()
                        }
                    })
    }

    function showActiveMissionEditor(forEdit) {
        switch (activeMissionEditor) {
        case "agricultureSpraying":
            showAgricultureSprayingMissionView(forEdit)
            break

        case "seedSpreader":
            showSeedSpraderMissionView(forEdit)
            break
        case "customMission":
            showCustomMissionView(forEdit)
            break
        case "planView":
            showPlanView()
            break
        case "routeMapping":
        default:
            showRouteMappingView(forEdit)
            break
        }
    }


    // This function is used to prevent view switching if there are validation errors
    function allowViewSwitch(previousValidationErrorCount = 0) {
        // Run validation on active focus control to ensure it is valid before switching views
        if (mainWindow.activeFocusControl instanceof FactTextField) {
            mainWindow.activeFocusControl._onEditingFinished()
        }
        return globals.validationErrorCount <= previousValidationErrorCount
    }
    // Plan view file
    function showPlanView() {
        activeMissionEditor = "planView"
        flyView.visible = false
        routeMappingView.visible = false
        customMissionView.visible = false
        agricultureSprayingMissionView.visible = false
        seedSpraderMision.visible = false
        planView.visible = true
        toolDrawer.visible = false
        applyUiTheme()
    }
    // custom mission file
    function showCustomMissionView(forEdit) {
        activeMissionEditor = "customMission"
        flyView.visible = false
        planView.visible = false
        routeMappingView.visible = false
        agricultureSprayingMissionView.visible = false
        seedSpraderMision.visible = false
        customMissionView.visible = true
        toolDrawer.visible = false

        // Only pull Fly View plan when Edit was requested, or this editor owns the upload.
        // Do not copy the uploaded plan into other modes — each page keeps its own draft.
        if (forEdit === true || (forEdit !== false && uploadedMissionEditor === "customMission")) {
            customMissionView.resumePlanForEdit()
        }
        applyUiTheme()
    }
    // Agriculture mission file
    function showAgricultureSprayingMissionView(forEdit) {
        activeMissionEditor = "agricultureSpraying"
        flyView.visible = false
        planView.visible = false
        customMissionView.visible = false
        routeMappingView.visible = false
        seedSpraderMision.visible = false
        agricultureSprayingMissionView.visible = true
        toolDrawer.visible = false

        if (forEdit === true || (forEdit !== false && uploadedMissionEditor === "agricultureSpraying")) {
            agricultureSprayingMissionView.resumeRouteMappingForEdit()
        }
        applyUiTheme()
    }
    // Route mapping mission file
    function showRouteMappingView(forEdit) {
        activeMissionEditor = "routeMapping"
        flyView.visible = false
        planView.visible = false
        customMissionView.visible = false
        agricultureSprayingMissionView.visible = false
        seedSpraderMision.visible = false
        routeMappingView.visible = true
        toolDrawer.visible = false

        if (forEdit === true || (forEdit !== false && uploadedMissionEditor === "routeMapping")) {
            routeMappingView.resumeRouteMappingForEdit()
        }
        applyUiTheme()
    }

    function showSeedSpraderMissionView(forEdit) {
        activeMissionEditor = "seedSpreader"
        flyView.visible = false
        planView.visible = false
        customMissionView.visible = false
        routeMappingView.visible = false
        agricultureSprayingMissionView.visible = false
        seedSpraderMision.visible = true
        toolDrawer.visible = false

        if (forEdit === true || (forEdit !== false && uploadedMissionEditor === "seedSpreader")) {
            seedSpraderMision.resumeRouteMappingForEdit()
        }
        applyUiTheme()
    }

    function showFlyView() {
        flyView.visible = true
        planView.visible = false
        customMissionView.visible = false
        agricultureSprayingMissionView.visible = false
        routeMappingView.visible = false
        seedSpraderMision.visible = false
        toolDrawer.visible = false
        applyUiTheme()
    }

    function resetRouteMappingPlanState(removeFromVehicle) {
        routeMappingView.resetRouteMappingPlanState()
        agricultureSprayingMissionView.resetRouteMappingPlanState()
        seedSpraderMision.resetRouteMappingPlanState()
        clearLastExecutedMissionPersistence()

        if (planView._planMasterController.containsItems) {
            planView._planMasterController.removeAll()
            planView._planMasterController.dirty = false
        }

        if (customMissionView._planMasterController.containsItems) {
            customMissionView._planMasterController.removeAll()
            customMissionView._planMasterController.dirty = false
        }

        flyView.clearRouteMappingOverlay(true)
        flyView.hideVehicleMissionForUnuploadedRoute = false
        flyView.clearFlyViewFlightTraces()
        flyView.planEditMode = false

        var flyPlanController = flyView.planController
        if (flyPlanController) {
            if (flyPlanController.containsItems) {
                flyPlanController.removeAll()
            }
            if (removeFromVehicle && !flyPlanController.offline) {
                flyPlanController.removeAllFromVehicle()
            }
            flyPlanController.dirty = false
            flyPlanController.missionController.setCurrentPlanViewSeqNum(0, true)
        }

        if (removeFromVehicle && QGroundControl.utmspSupported) {
            QGroundControl.utmspManager.utmspVehicle.triggerActivationStatusBar(false)
            UTMSPStateStorage.startTimeStamp = ""
            UTMSPStateStorage.showActivationTab = false
            UTMSPStateStorage.flightID = ""
            UTMSPStateStorage.enableMissionUploadButton = false
            UTMSPStateStorage.indicatorPendingStatus = true
            UTMSPStateStorage.indicatorApprovedStatus = false
            UTMSPStateStorage.indicatorActivatedStatus = false
            UTMSPStateStorage.currentStateIndex = 0
        }
    }

    // Clears every plan and overlay when the vehicle fully disconnects. Do not
    // clear on temporary communicationLost; the user can still recover that
    // connection or explicitly click Disconnect.
    function clearPlansOnVehicleLost() {
        routeMappingView.resetRouteMappingPlanState()
        agricultureSprayingMissionView.resetRouteMappingPlanState()
        seedSpraderMision.resetRouteMappingPlanState()
        clearLastExecutedMissionPersistence()

        if (planView._planMasterController.containsItems) {
            planView._planMasterController.removeAll()
            planView._planMasterController.dirty = false
        }

        if (customMissionView._planMasterController.containsItems) {
            customMissionView._planMasterController.removeAll()
            customMissionView._planMasterController.dirty = false
        }

        flyView.hideVehicleMissionForUnuploadedRoute = false
        flyView.planEditMode = false

        var flyPlanController = flyView.planController
        if (flyPlanController) {
            if (flyPlanController.containsItems) {
                flyPlanController.removeAll()
            }
            flyPlanController.dirty = false
            flyPlanController.missionController.setCurrentPlanViewSeqNum(0, true)
        }

        flyView.clearRouteMappingOverlay(true)
        flyView.clearFlyViewFlightTraces()
    }

    Connections {
        target: QGroundControl.multiVehicleManager

        function onActiveVehicleChanged(activeVehicle) {
            if (!activeVehicle) {
                mainWindow.clearPlansOnVehicleLost()
            }
        }

        function onVehicleRemoved(vehicle) {
            mainWindow.clearPlansOnVehicleLost()
        }
    }

    function hasRouteMappingPlanToClear() {
        if (routeMappingView._hasRouteMappingContent
                || agricultureSprayingMissionView._hasRouteMappingContent
                || seedSpraderMision._hasRouteMappingContent
                || customMissionView._planMasterController.containsItems
                || planView._planMasterController.containsItems
                || flyView._hasFlyViewPlanContent) {
            return true
        }

        var activeVehicle = QGroundControl.multiVehicleManager.activeVehicle
        if (activeVehicle && activeVehicle.trajectoryPoints) {
            var tracePoints = activeVehicle.trajectoryPoints.list()
            if (tracePoints.length > 0) {
                return true
            }
        }

        return false
    }

    function confirmClearRouteMappingPlan() {
        if (!hasRouteMappingPlanToClear()) {
            showMessageDialog(
                        qsTr("Clear"),
                        qsTr("There is no plan to clear."),
                        Dialog.Ok,
                        null,
                        null,
                        true,
                        true)
            return
        }

        showMessageDialog(
                    qsTr("Clear"),
                    qsTr("Are you sure you want to remove all items from the current plan?"),
                    Dialog.Yes | Dialog.Cancel,
                    function() {
                        var activeVehicle = QGroundControl.multiVehicleManager.activeVehicle
                        var removeFromVehicle = activeVehicle !== null
                        resetRouteMappingPlanState(removeFromVehicle)
                    })
    }

    function showTool(toolTitle, toolSource, toolIcon, fromFlyViewBackNav, hideToolbar) {
        toolDrawer.backIcon         = flyView.visible ? "/qmlimages/PaperPlane.svg" : "/qmlimages/Plan.svg"
        toolDrawer.toolTitle        = toolTitle
        toolDrawer.toolSource       = toolSource
        toolDrawer.toolIcon         = toolIcon
        toolDrawer.showBackButton   = fromFlyViewBackNav === true
        toolDrawer.centeredTitle    = fromFlyViewBackNav === true
        toolDrawer.returnToFlyView  = fromFlyViewBackNav === true && flyView.visible
        toolDrawer.hideToolbar      = hideToolbar === true
        toolDrawer.visible          = true
        applyUiTheme()
    }

    function showAnalyzeTool(fromFlyViewBackNav) {
        showTool(qsTr("Analyze Tools"), "qrc:/qml/QGroundControl/AnalyzeView/AnalyzeView.qml", "/qmlimages/Analyze.svg", fromFlyViewBackNav)
    }

    function showVehicleConfig(fromFlyViewBackNav) {
        // Vehicle Config provides its own header + close control (same as Application Settings)
        showTool(qsTr("Vehicle Configuration"), "qrc:/qml/QGroundControl/VehicleSetup/SetupView.qml", "/qmlimages/Gears.svg", false, true)
    }

    function showVehicleConfigParametersPage() {
        showVehicleConfig()
        toolDrawerLoader.item.showParametersPanel()
    }

    function showKnownVehicleComponentConfigPage(knownVehicleComponent) {
        showVehicleConfig()
        let vehicleComponent = globals.activeVehicle.autopilotPlugin.findKnownVehicleComponent(knownVehicleComponent)
        if (vehicleComponent) {
            toolDrawerLoader.item.showVehicleComponentPanel(vehicleComponent)
        }
    }

    function showSettingsTool(settingsPage = "") {
        // Settings provides its own Application Settings header + close control
        showTool(qsTr("Application Settings"), "qrc:/qml/QGroundControl/Controls/AppSettings.qml", "/res/QGCLogoWhite", false, true)
        if (settingsPage !== "") {
            toolDrawerLoader.item.showSettingsPage(settingsPage)
        }
    }

    //-------------------------------------------------------------------------
    //-- Global simple message dialog

    function showMessageDialog(dialogTitle, dialogText, buttons = Dialog.Ok, acceptFunction = null, closeFunction = null, compact = false, largeTitleText = false) {
        simpleMessageDialogComponent.createObject(mainWindow, {
                                                      title: dialogTitle,
                                                      text: dialogText,
                                                      buttons: buttons,
                                                      acceptFunction: acceptFunction,
                                                      closeFunction: closeFunction,
                                                      compact: compact,
                                                      largeTitleText: largeTitleText
                                                  }).open()
    }

    // This variant is only meant to be called by QGCApplication
    function _showMessageDialog(dialogTitle, dialogText) {
        showMessageDialog(dialogTitle, dialogText)
    }

    Component {
        id: simpleMessageDialogComponent
        QGCSimpleMessageDialog {

        }
    }

    property bool _forceClose: false

    function finishCloseProcess() {
        _forceClose = true
        // For some reason on the Qml side Qt doesn't automatically disconnect a signal when an object is destroyed.
        // So we have to do it ourselves otherwise the signal flows through on app shutdown to an object which no longer exists.
        firstRunPromptManager.clearNextPromptSignal()
        QGroundControl.linkManager.shutdown()
        QGroundControl.videoManager.stopVideo();
        mainWindow.close()
    }

    // Check for things which should prevent the app from closing
    //  Returns true if it is OK to close
    readonly property int _skipUnsavedMissionCheckMask: 0x01
    readonly property int _skipPendingParameterWritesCheckMask: 0x02
    readonly property int _skipActiveConnectionsCheckMask: 0x04
    property int _closeChecksToSkip: 0
    function performCloseChecks() {
        if (!(_closeChecksToSkip & _skipUnsavedMissionCheckMask) && !checkForUnsavedMission()) {
            return false
        }
        if (!(_closeChecksToSkip & _skipPendingParameterWritesCheckMask) && !checkForPendingParameterWrites()) {
            return false
        }
        if (!(_closeChecksToSkip & _skipActiveConnectionsCheckMask) && !checkForActiveConnections()) {
            return false
        }
        finishCloseProcess()
        return true
    }

    property string closeDialogTitle: qsTr("Close %1").arg(QGroundControl.appName)

    function checkForUnsavedMission() {
        if (planView._planMasterController.dirty) {
            showMessageDialog(closeDialogTitle,
                              qsTr("You have a mission edit in progress which has not been saved/sent. If you close you will lose changes. Are you sure you want to close?"),
                              Dialog.Yes | Dialog.No,
                              function() { _closeChecksToSkip |= _skipUnsavedMissionCheckMask; performCloseChecks() })
            return false
        } else {
            return true
        }
    }

    function checkForPendingParameterWrites() {
        for (var index=0; index<QGroundControl.multiVehicleManager.vehicles.count; index++) {
            if (QGroundControl.multiVehicleManager.vehicles.get(index).parameterManager.pendingWrites) {
                mainWindow.showMessageDialog(closeDialogTitle,
                                             qsTr("You have pending parameter updates to a vehicle. If you close you will lose changes. Are you sure you want to close?"),
                                             Dialog.Yes | Dialog.No,
                                             function() { _closeChecksToSkip |= _skipPendingParameterWritesCheckMask; performCloseChecks() })
                return false
            }
        }
        return true
    }

    function checkForActiveConnections() {
        if (QGroundControl.multiVehicleManager.activeVehicle) {
            mainWindow.showMessageDialog(closeDialogTitle,
                                         qsTr("There are still active connections to vehicles. Are you sure you want to exit?"),
                                         Dialog.Yes | Dialog.No,
                                         function() { _closeChecksToSkip |= _skipActiveConnectionsCheckMask; performCloseChecks() })
            return false
        } else {
            return true
        }
    }

    onClosing: (close) => {
                   if (!_forceClose) {
                       _closeChecksToSkip = 0
                       close.accepted = performCloseChecks()
                   }
               }

    background: Rectangle {
        anchors.fill:   parent
        color:          QGroundControl.globalPalette.window
    }

    FlyView {
        id:                     flyView
        anchors.fill:           parent
        visible:                !mainWindow.homePageOnly
    }

    PlanView {
        id:             planView
        anchors.fill:   parent
        visible:        false
    }
    SeedSpraderMissionView{
        id:  seedSpraderMision
        anchors.fill: parent
        visible:  false
    }

    CustomMissionView {
        id:             customMissionView
        anchors.fill:   parent
        visible:        false
    }

    AgricultureSprayingMissionView {
        id:             agricultureSprayingMissionView
        anchors.fill:   parent
        visible:        false
    }

    // This is the route mapping redirect file
    RouteMappingView {
        id:             routeMappingView
        anchors.fill:   parent
        visible:        false
    }


    footer: LogReplayStatusBar {
        visible: QGroundControl.settingsManager.flyViewSettings.showLogReplayStatusBar.rawValue
    }

    MessageDialog {
        id:                 showTouchAreasNotification
        title:              qsTr("Debug Touch Areas")
        text:               qsTr("Touch Area display toggled")
        buttons:            MessageDialog.Ok
    }

    MessageDialog {
        id:                 advancedModeOnConfirmation
        title:              qsTr("Advanced Mode")
        text:               QGroundControl.corePlugin.showAdvancedUIMessage
        buttons:            MessageDialog.Yes | MessageDialog.No
        onButtonClicked: function (button, role) {
            if (button === MessageDialog.Yes) {
                QGroundControl.corePlugin.showAdvancedUI = true
            }
        }
    }

    MessageDialog {
        id:                 advancedModeOffConfirmation
        title:              qsTr("Advanced Mode")
        text:               qsTr("Turn off Advanced Mode?")
        buttons:            MessageDialog.Yes | MessageDialog.No
        onButtonClicked: function (button, role) {
            if (button === MessageDialog.Yes) {
                QGroundControl.corePlugin.showAdvancedUI = false
            }
        }
    }

    function showToolSelectDialog() {
        if (mainWindow.allowViewSwitch()) {
            mainWindow.showIndicatorDrawer(toolSelectComponent, null)
        }
    }

    Component {
        id: toolSelectComponent

        SelectViewDropdown {
        }
    }

    Rectangle {
        id:             toolDrawer
        anchors.fill:   parent
        visible:        false
        color:          hideToolbar
                        ? (mainWindow.uiThemeMode === mainWindow.themeBlack ? qgcPal.window : "white")
                        : qgcPal.window

        property var backIcon
        property string toolTitle
        property alias toolSource:  toolDrawerLoader.source
        property var toolIcon
        property bool showBackButton:   false
        property bool centeredTitle:    false
        property bool returnToFlyView:  false
        property bool hideToolbar:      false

        onVisibleChanged: {
            if (!toolDrawer.visible) {
                toolDrawerLoader.source = ""
                showBackButton = false
                centeredTitle = false
                returnToFlyView = false
                hideToolbar = false
                mainWindow.applyUiTheme()
            }
        }

        // This need to block click event leakage to underlying map.
        DeadMouseArea {
            anchors.fill: parent
        }

        Rectangle {
            id:             toolDrawerToolbar
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.top:    parent.top
            height:         toolDrawer.hideToolbar ? 0 : ScreenTools.toolbarHeight
            visible:        !toolDrawer.hideToolbar
            color: Qt.rgba(0, 0, 0, 0.35)

            QGCToolBarButton {
                id:                 backButton
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                anchors.left:       parent.left
                anchors.top:        parent.top
                anchors.bottom:     parent.bottom
                visible:            toolDrawer.showBackButton
                icon.source:        "/res/chevron-double-left.svg"
                iconSize:           ScreenTools.smallFontPixelHeight * 1.6
                onClicked: {
                    if (toolDrawer.returnToFlyView) {
                        mainWindow.showFlyView()
                    } else if (toolDrawer.showBackButton) {
                        // Return to the mission editor page that opened Vehicle Config / Analyze
                        mainWindow.showActiveMissionEditor(false)
                    } else {
                        mainWindow.showPlanView()
                    }
                }
            }

            QGCLabel {
                id:                     toolbarDrawerCenteredText
                anchors.centerIn:       parent
                visible:                toolDrawer.centeredTitle
                text:                   toolDrawer.toolTitle
                font.pointSize:         ScreenTools.largeFontPointSize
            }

            RowLayout {
                id:                 toolDrawerToolbarLayout
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                anchors.left:       parent.left
                anchors.top:        parent.top
                anchors.bottom:     parent.bottom
                spacing:            ScreenTools.defaultFontPixelWidth
                visible:            !toolDrawer.centeredTitle

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

                QGCLabel {
                    id:             toolbarDrawerText
                    text:           toolDrawer.toolTitle
                    font.pointSize: ScreenTools.largeFontPointSize
                }
            }
        }

        Loader {
            id:             toolDrawerLoader
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.top:    toolDrawerToolbar.bottom
            anchors.bottom: parent.bottom

            Connections {
                target:                 toolDrawerLoader.item
                ignoreUnknownSignals:   true
                function onPopout() { toolDrawer.visible = false }
            }
        }
    }

    //-------------------------------------------------------------------------
    //-- Critical Vehicle Message Popup

    function showCriticalVehicleMessage(message) {
        closeIndicatorDrawer()
        if (criticalVehicleMessagePopup.visible || QGroundControl.videoManager.fullScreen) {
            // We received additional warning message while an older warning message was still displayed.
            // When the user close the older one drop the message indicator tool so they can see the rest of them.
            criticalVehicleMessagePopup.additionalCriticalMessagesReceived = true
        } else {
            criticalVehicleMessagePopup.criticalVehicleMessage      = message
            criticalVehicleMessagePopup.additionalCriticalMessagesReceived = false
            criticalVehicleMessagePopup.open()
        }
    }

    Popup {
        id:                 criticalVehicleMessagePopup
        y:                  ScreenTools.toolbarHeight + ScreenTools.defaultFontPixelHeight
        x:                  Math.round((mainWindow.width - width) * 0.5)
        width:              mainWindow.width  * 0.55
        height:             criticalVehicleMessageText.contentHeight + ScreenTools.defaultFontPixelHeight * 2
        modal:              false
        focus:              true

        property alias  criticalVehicleMessage:             criticalVehicleMessageText.text
        property bool   additionalCriticalMessagesReceived: false

        background: Rectangle {
            anchors.fill:   parent
            color:          qgcPal.alertBackground
            radius:         ScreenTools.defaultFontPixelHeight * 0.5
            border.color:   qgcPal.alertBorder
            border.width:   2

            Rectangle {
                anchors.horizontalCenter:   parent.horizontalCenter
                anchors.top:                parent.top
                anchors.topMargin:          -(height / 2)
                color:                      qgcPal.alertBackground
                radius:                     ScreenTools.defaultFontPixelHeight * 0.25
                border.color:               qgcPal.alertBorder
                border.width:               1
                width:                      vehicleWarningLabel.contentWidth + _margins
                height:                     vehicleWarningLabel.contentHeight + _margins

                property real _margins: ScreenTools.defaultFontPixelHeight * 0.25

                QGCLabel {
                    id:                 vehicleWarningLabel
                    anchors.centerIn:   parent
                    text:               qsTr("Vehicle Error")
                    font.pointSize:     ScreenTools.smallFontPointSize
                    color:              qgcPal.alertText
                }
            }

            Rectangle {
                id:                         additionalErrorsIndicator
                anchors.horizontalCenter:   parent.horizontalCenter
                anchors.bottom:             parent.bottom
                anchors.bottomMargin:       -(height / 2)
                color:                      qgcPal.alertBackground
                radius:                     ScreenTools.defaultFontPixelHeight * 0.25
                border.color:               qgcPal.alertBorder
                border.width:               1
                width:                      additionalErrorsLabel.contentWidth + _margins
                height:                     additionalErrorsLabel.contentHeight + _margins
                visible:                    criticalVehicleMessagePopup.additionalCriticalMessagesReceived

                property real _margins: ScreenTools.defaultFontPixelHeight * 0.25

                QGCLabel {
                    id:                 additionalErrorsLabel
                    anchors.centerIn:   parent
                    text:               qsTr("Additional errors received")
                    font.pointSize:     ScreenTools.smallFontPointSize
                    color:              qgcPal.alertText
                }
            }
        }

        QGCLabel {
            id:                 criticalVehicleMessageText
            width:              criticalVehicleMessagePopup.width - ScreenTools.defaultFontPixelHeight
            anchors.centerIn:   parent
            wrapMode:           Text.WordWrap
            color:              qgcPal.alertText
            textFormat:         TextEdit.RichText
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                criticalVehicleMessagePopup.close()
                if (criticalVehicleMessagePopup.additionalCriticalMessagesReceived) {
                    criticalVehicleMessagePopup.additionalCriticalMessagesReceived = false;
                    flyView.dropMainStatusIndicatorTool();
                } else {
                    QGroundControl.multiVehicleManager.activeVehicle.resetErrorLevelMessages();
                }
            }
        }
    }

    //-------------------------------------------------------------------------
    //-- Indicator Drawer

    function showIndicatorDrawer(drawerComponent, indicatorItem) {
        indicatorDrawer.sourceComponent = drawerComponent
        indicatorDrawer.indicatorItem = indicatorItem
        indicatorDrawer.open()
    }

    function closeIndicatorDrawer() {
        indicatorDrawer.close()
    }

    Popup {
        id:             indicatorDrawer
        x:              calcXPosition()
        y:              ScreenTools.toolbarHeight + _margins
        leftInset:      0
        rightInset:     0
        topInset:       0
        bottomInset:    0
        padding:        _margins * 2
        visible:        false
        modal:          true
        focus:          true
        closePolicy:    Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property var sourceComponent
        property var indicatorItem

        property bool _expanded:    false
        property real _margins:     ScreenTools.defaultFontPixelHeight / 4

        function calcXPosition() {
            if (indicatorItem) {
                var xCenter = indicatorItem.mapToItem(mainWindow.contentItem, indicatorItem.width / 2, 0).x
                return Math.max(_margins, Math.min(xCenter - (contentItem.implicitWidth / 2), mainWindow.contentItem.width - contentItem.implicitWidth - _margins - (indicatorDrawer.padding * 2) - (ScreenTools.defaultFontPixelHeight / 2)))
            } else {
                return _margins
            }
        }

        onOpened: {
            _expanded                               = false;
            indicatorDrawerLoader.sourceComponent   = indicatorDrawer.sourceComponent
        }
        onClosed: {
            _expanded                               = false
            indicatorItem                           = undefined
            indicatorDrawerLoader.sourceComponent   = undefined
        }

        background: Item {
            Rectangle {
                id:             backgroundRect
                anchors.fill:   parent
                color:          QGroundControl.globalPalette.window
                radius:         indicatorDrawer._margins
                opacity:        0.85
            }

            Rectangle {
                anchors.horizontalCenter:   backgroundRect.right
                anchors.verticalCenter:     backgroundRect.top
                width:                      ScreenTools.largeFontPixelHeight
                height:                     width
                radius:                     width / 2
                color:                      QGroundControl.globalPalette.button
                border.color:               QGroundControl.globalPalette.buttonText
                visible:                    indicatorDrawerLoader.item && indicatorDrawerLoader.item.showExpand && !indicatorDrawer._expanded

                QGCLabel {
                    anchors.centerIn:   parent
                    text:               ">"
                    color:              QGroundControl.globalPalette.buttonText
                }

                QGCMouseArea {
                    fillItem: parent
                    onClicked: indicatorDrawer._expanded = true
                }
            }
        }

        contentItem: QGCFlickable {
            id:             indicatorDrawerLoaderFlickable
            implicitWidth:  Math.min(mainWindow.contentItem.width - (2 * indicatorDrawer._margins) - (indicatorDrawer.padding * 2), indicatorDrawerLoader.width)
            implicitHeight: Math.min(mainWindow.contentItem.height - ScreenTools.toolbarHeight - (2 * indicatorDrawer._margins) - (indicatorDrawer.padding * 2), indicatorDrawerLoader.height)
            contentWidth:   indicatorDrawerLoader.width
            contentHeight:  indicatorDrawerLoader.height

            Loader {
                id: indicatorDrawerLoader

                Binding {
                    target:     indicatorDrawerLoader.item
                    property:   "expanded"
                    value:      indicatorDrawer._expanded
                }

                Binding {
                    target:     indicatorDrawerLoader.item
                    property:   "drawer"
                    value:      indicatorDrawer
                }
            }
        }
    }

    // We have to create the popup windows for the Analyze pages here so that the creation context is rooted
    // to mainWindow. Otherwise if they are rooted to the AnalyzeView itself they will die when the analyze viewSwitch
    // closes.

    function createrWindowedAnalyzePage(title, source) {
        var windowedPage = windowedAnalyzePage.createObject(mainWindow)
        windowedPage.title = title
        windowedPage.source = source
    }

    Component {
        id: windowedAnalyzePage

        Window {
            width:      ScreenTools.defaultFontPixelWidth  * 100
            height:     ScreenTools.defaultFontPixelHeight * 40
            visible:    true

            property alias source: loader.source

            Rectangle {
                color:          QGroundControl.globalPalette.window
                anchors.fill:   parent

                Loader {
                    id:             loader
                    anchors.fill:   parent
                    onLoaded:       item.popped = true
                }
            }
            onClosing: {
                visible = false
                source = ""
            }
        }
    }
    // Bottom Floating Navbar - Hidden
    BottomFloatingNavbar {
        id:                 bottomNavbar
        mainWindow:         mainWindow
        visible:            false
        onShowFlyView:      mainWindow.showFlyView()
        onShowPlanView:     mainWindow.showPlanView()
        onShowAnalyzeTool:  mainWindow.showAnalyzeTool()
        onShowSettings:     mainWindow.showSettingsTool()
        onShowConfigure:    mainWindow.showVehicleConfig()
    }

    readonly property bool modeSelectionVisible: modeSelectionOverlay.isOpen

    CustomHomePage {
        id: customHomePage
        anchors.fill: parent
    visible: false
        z: QGroundControl.zOrderTopMost + 50

        onStartClicked: {
            customHomePage.visible = false
            modeSelectionOverlay.isOpen = true
        }
        onUserManualClicked: {
            mainWindow.openUserManual()
        }
        onDeviceConnectorClicked: {
            if (mainWindow.homePageOnly)
                return
            mainWindow.showVehicleConfig()
        }
    }

    UserManualViewer {
        id: userManualViewer
        anchors.fill: parent

        onGoHomeRequested: {
            mainWindow.showCustomHomePage()
        }
    }

    ModeSelectionOverlay {
        id: modeSelectionOverlay
    }

    function showModeSelection(startPoint) {
        modeSelectionOverlay.startPoint = startPoint
        modeSelectionOverlay.isOpen = true
        applyUiTheme()
    }

    function openUserManual() {
        customHomePage.visible = false
        userManualViewer.open()
    }

    function showCustomHomePage() {
        // Show home first so it is ready under the mode-selection close animation
        userManualViewer.visible = false
        customHomePage.resetStartControl()
        customHomePage.visible = true
        modeSelectionOverlay.isOpen = false
        applyUiTheme()
    }
}
