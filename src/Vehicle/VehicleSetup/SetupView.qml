import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id:     setupView
    color:  _pageBackground
    z:      QGroundControl.zOrderTopMost

    signal popout()

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    readonly property bool _darkTheme: {
        if (typeof mainWindow !== "undefined" && mainWindow)
            return mainWindow.uiThemeMode === mainWindow.themeBlack
        return qgcPal.globalTheme === QGCPalette.Dark
    }

    readonly property color _pageBackground:    _darkTheme ? qgcPal.window : "white"
    readonly property color _titleColor:        _darkTheme ? "#AEAEB2" : "#1C1C1E"
    readonly property color _secondaryText:     "#8E8E93"
    readonly property color _headingColor:      _darkTheme ? "#AEAEB2" : "#1C1C1E"
    readonly property color _iconColor:         _darkTheme ? "#AEAEB2" : "#1C1C1E"
    readonly property color _dividerColor:      _darkTheme ? qgcPal.windowShade : "#f6f6f6"
    readonly property color _sidebarBg:         _darkTheme ? qgcPal.windowShade : "white"
    readonly property color _accentGreen:       "#00a04c"
    readonly property color _rowPressed:        _darkTheme ? qgcPal.windowShade : "#F2F2F2"
    readonly property real  _headerIconPad:     ScreenTools.defaultFontPixelWidth * 1.0
    readonly property real  _headerHeight:      ScreenTools.toolbarHeight
    readonly property real  _rowHeight:         ScreenTools.defaultFontPixelHeight * 3.2
    // Wide enough for labels like "Flight Modes" / "Flight Behavior"
    readonly property real  _sidebarWidth:      Math.max(ScreenTools.defaultFontPixelWidth * 20,
                                                         Math.min(width * 0.32, ScreenTools.defaultFontPixelWidth * 24))
    readonly property real  _sidebarPad:        ScreenTools.defaultFontPixelWidth * 1.4
    readonly property real  _sideIconSize:      ScreenTools.defaultFontPixelHeight * 2.2
    // Right content panel inset
    readonly property real  _contentPad:        ScreenTools.defaultFontPixelWidth * 0.75

    readonly property real      _defaultTextHeight: ScreenTools.defaultFontPixelHeight
    readonly property real      _defaultTextWidth:  ScreenTools.defaultFontPixelWidth
    readonly property string    _armedVehicleText:  qsTr("This operation cannot be performed while the vehicle is armed.")

    property var    _activeVehicle:                 QGroundControl.multiVehicleManager.activeVehicle
    property bool   _vehicleArmed:                  _activeVehicle ? _activeVehicle.armed : false
    property string _messagePanelText:              qsTr("missing message panel text")
    property bool   _fullParameterVehicleAvailable: QGroundControl.multiVehicleManager.parameterReadyVehicleAvailable && !_activeVehicle.parameterManager.missingParameters
    property var    _corePlugin:                    QGroundControl.corePlugin

    // In-page selection (no separate detail page)
    property string _selectedKey:       "summary"
    property string _selectedTitle:     qsTr("Summary")
    property string _selectedSource:    ""
    property bool   _selectedIsSummary: true
    property bool   _selectedIsMessage: false
    property var    _selectedComponent: null

    DeadMouseArea {
        anchors.fill: parent
    }

    function showSummaryPanel() {
        if (mainWindow.allowViewSwitch())
            _selectPage("summary", qsTr("Summary"), "", true, false, null)
    }

    function _showSummaryPanel() {
        showSummaryPanel()
    }

    function showPanel(button, qmlSource) {
        if (!mainWindow.allowViewSwitch())
            return
        var title = button && button.text ? button.text : qsTr("Configuration")
        _selectPage("panel:" + title, title, qmlSource ? qmlSource.toString() : "", false, false, null)
    }

    function showVehicleComponentPanel(vehicleComponent) {
        if (!mainWindow.allowViewSwitch())
            return
        var autopilotPlugin = _activeVehicle.autopilotPlugin
        var prereq = autopilotPlugin.prerequisiteSetup(vehicleComponent)
        var key = "component:" + vehicleComponent.name
        if (prereq !== "") {
            _messagePanelText = qsTr("%1 setup must be completed prior to %2 setup.").arg(prereq).arg(vehicleComponent.name)
            _selectPage(key, vehicleComponent.name, "", false, true, vehicleComponent)
        } else {
            _selectPage(key, vehicleComponent.name, vehicleComponent.setupSource.toString(), false, false, vehicleComponent)
        }
    }

    function showParametersPanel() {
        if (!mainWindow.allowViewSwitch())
            return
        _selectPage("parameters", qsTr("Parameters"),
                    "qrc:/qml/QGroundControl/VehicleSetup/SetupParameterEditor.qml",
                    false, false, null)
    }

    readonly property var _advancedOnlyMatchers: [
        "SensorsComponent",
        "AirframeComponent",
        "ActuatorComponent",
        "MotorComponent",
        "TuningComponent",
        "FlightBehavior"
    ]

    function _isAdvancedOnlyComponent(component) {
        if (!component)
            return false
        var source = component.setupSource ? component.setupSource.toString() : ""
        if (source === "")
            return false
        for (var i = 0; i < _advancedOnlyMatchers.length; i++) {
            if (source.indexOf(_advancedOnlyMatchers[i]) >= 0)
                return true
        }
        return false
    }

    function _isSafetyComponent(component) {
        if (!component)
            return false
        var source = component.setupSource ? component.setupSource.toString() : ""
        if (source.indexOf("SafetyComponent") >= 0)
            return true
        var name = component.name ? component.name.toString().toLowerCase() : ""
        return name === "safety"
    }

    function _safetyComponent() {
        if (!_fullParameterVehicleAvailable || !_activeVehicle || !_activeVehicle.autopilotPlugin)
            return null
        var components = _activeVehicle.autopilotPlugin.vehicleComponents
        for (var i = 0; i < components.length; i++) {
            if (_isSafetyComponent(components[i]))
                return components[i]
        }
        return null
    }

    function _closeSetup() {
        if (typeof mainWindow !== "undefined" && mainWindow &&
                mainWindow.closeToolAndReturnToSource()) {
            return
        }

        setupView.popout()
        if (typeof mainWindow !== "undefined" && mainWindow)
            mainWindow.showModeSelection(Qt.point(mainWindow.width / 2, ScreenTools.toolbarHeight / 2))
    }

    function _selectPage(key, title, pageSource, isSummary, isMessage, vehicleComponent) {
        _selectedKey = key
        _selectedTitle = title
        _selectedSource = pageSource ? pageSource.toString() : ""
        _selectedIsSummary = isSummary === true
        _selectedIsMessage = isMessage === true
        _selectedComponent = vehicleComponent ? vehicleComponent : null
        if (panelLoader.item && panelLoader.opacity > 0.05) {
            pageOutAnim.restart()
        } else {
            _reloadContent()
        }
    }

    function _reloadContent() {
        panelLoader.source = ""
        panelLoader.sourceComponent = undefined
        if (_selectedIsMessage) {
            panelLoader.sourceComponent = messagePanelComponent
        } else if (_selectedIsSummary) {
            panelLoader.sourceComponent = summaryLoaderComponent
        } else if (_selectedSource !== "") {
            panelLoader.source = _selectedSource
        }
        panelLoader.opacity = 0
        panelLoader.x = ScreenTools.defaultFontPixelWidth * 2.4
        pageInAnim.restart()
    }

    Component.onCompleted: {
        _reloadContent()
    }

    Connections {
        target: QGroundControl.corePlugin
        function onShowAdvancedUIChanged(showAdvancedUI) {
            if (!showAdvancedUI && _selectedKey === "parameters")
                showSummaryPanel()
        }
    }

    Connections {
        target: QGroundControl.multiVehicleManager
        function onParameterReadyVehicleAvailableChanged(parametersReady) {
            showSummaryPanel()
        }
    }

    // Same icon-row design as Application Settings (round green badge + label)
    component SetupSideButton: Item {
        id: sideBtn

        property string label
        property string iconSource: ""
        property string pageKey
        property bool   setupComplete: true
        property bool   buttonVisible: true
        property bool   selected: setupView._selectedKey === pageKey

        signal clicked()

        width:  parent ? parent.width : 0
        height: buttonVisible ? setupView._rowHeight : 0
        visible: buttonVisible

        Rectangle {
            anchors.fill: parent
            color: {
                if (sideMouse.pressed)
                    return setupView._rowPressed
                if (sideBtn.selected)
                    return Qt.rgba(0, 160 / 255, 76 / 255, 0.10)
                return "transparent"
            }
            Behavior on color { ColorAnimation { duration: 140 } }
        }

        Rectangle {
            anchors.left:   parent.left
            anchors.top:    parent.top
            anchors.bottom: parent.bottom
            width:          3
            color:          sideBtn.selected ? setupView._accentGreen : "transparent"
        }

        RowLayout {
            anchors.fill:           parent
            anchors.leftMargin:     setupView._sidebarPad
            anchors.rightMargin:    setupView._sidebarPad
            spacing:                ScreenTools.defaultFontPixelWidth * 1.25

            Item {
                Layout.preferredWidth:  setupView._sideIconSize
                Layout.preferredHeight: setupView._sideIconSize
                Layout.alignment:       Qt.AlignVCenter
                visible:                sideBtn.iconSource !== ""

                Rectangle {
                    anchors.fill: parent
                    radius:       width / 2
                    color:        sideBtn.setupComplete
                                  ? Qt.rgba(0, 160 / 255, 76 / 255, 0.12)
                                  : Qt.rgba(229 / 255, 57 / 255, 53 / 255, 0.12)
                }

                QGCColoredImage {
                    anchors.centerIn:   parent
                    width:              parent.width * 0.52
                    height:             width
                    source:             sideBtn.iconSource
                    color:              !sideBtn.setupComplete ? "#E53935" : setupView._titleColor
                    fillMode:           Image.PreserveAspectFit
                }
            }

            QGCLabel {
                Layout.fillWidth:   true
                Layout.alignment:   Qt.AlignVCenter
                Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 8
                text:               sideBtn.label
                color:              !sideBtn.setupComplete
                                    ? "#E53935"
                                    : (sideBtn.selected ? setupView._accentGreen : setupView._titleColor)
                font.pointSize:     ScreenTools.defaultFontPointSize
                font.bold:          sideBtn.selected
                elide:              Text.ElideRight
                wrapMode:           Text.NoWrap
            }

            Rectangle {
                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 0.5
                Layout.preferredHeight: Layout.preferredWidth
                Layout.alignment:       Qt.AlignVCenter
                radius:                 width / 2
                color:                  "#E53935"
                visible:                !sideBtn.setupComplete
            }
        }

        RippleEffect {
            id:          sideRipple
            rippleColor: setupView._darkTheme ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(0, 160 / 255, 76 / 255, 0.22)
            clipRadius:  0
        }

        MouseArea {
            id:             sideMouse
            anchors.fill:   parent
            cursorShape:    Qt.PointingHandCursor
            onClicked: function(mouse) {
                sideRipple.tap(mouse.x, mouse.y)
                sideBtn.clicked()
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing:      0

        // ---- Left icon sidebar ----
        Rectangle {
            Layout.preferredWidth:  setupView._sidebarWidth
            Layout.fillHeight:      true
            color:                  setupView._sidebarBg

            Rectangle {
                anchors.top:    parent.top
                anchors.bottom: parent.bottom
                anchors.right:  parent.right
                width:          1
                color:          setupView._dividerColor
            }

            QGCFlickable {
                anchors.fill:       parent
                contentWidth:       width
                contentHeight:      sideColumn.height
                clip:               true
                flickableDirection: Flickable.VerticalFlick

                Column {
                    id:     sideColumn
                    width:  parent.width
                    topPadding: ScreenTools.defaultFontPixelHeight * 0.35

                    SetupSideButton {
                        label:      qsTr("Summary")
                        iconSource: "/qmlimages/VehicleSummaryIcon.png"
                        pageKey:    "summary"
                        onClicked:  setupView.showSummaryPanel()
                    }

                    SetupSideButton {
                        property var _safetyComp: setupView._safetyComponent()
                        label:          _safetyComp ? _safetyComp.name : qsTr("Safety")
                        iconSource:     _safetyComp ? _safetyComp.iconResource : "/qmlimages/SafetyComponentIcon.png"
                        pageKey:        _safetyComp ? ("component:" + _safetyComp.name) : "safety"
                        setupComplete:  _safetyComp ? _safetyComp.setupComplete : true
                        buttonVisible:  _safetyComp !== null &&
                                        _safetyComp.setupSource.toString() !== ""
                        onClicked:      setupView.showVehicleComponentPanel(_safetyComp)
                    }

                    SetupSideButton {
                        label:      qsTr("Sprayer")
                        iconSource: "/qmlimages/Shower.svg"
                        pageKey:    "sprayer"
                        onClicked:  setupView._selectPage(
                                            "sprayer",
                                            qsTr("Spraying System Settings"),
                                            "qrc:/qml/QGroundControl/VehicleSetup/SprayerSetup.qml",
                                            false, false, null)
                    }

                    SetupSideButton {
                        label:          qsTr("Optical Flow")
                        iconSource:     ""
                        pageKey:        "opticalFlow"
                        buttonVisible:  _activeVehicle ? _activeVehicle.flowImageIndex > 0 : false
                        onClicked:      setupView._selectPage(
                                            "opticalFlow",
                                            qsTr("Optical Flow"),
                                            "qrc:/qml/QGroundControl/VehicleSetup/OpticalFlowSensor.qml",
                                            false, false, null)
                    }

                    SetupSideButton {
                        id:             joystickSideBtn
                        label:          _forcedToButtonsOnly ? qsTr("Buttons") : qsTr("Joystick")
                        iconSource:     "/qmlimages/Joystick.png"
                        pageKey:        "joystick"
                        setupComplete:  _activeJoystick ? _activeJoystick.calibrated || _buttonsOnly : false
                        buttonVisible:  _fullParameterVehicleAvailable && joystickManager.joysticks.length !== 0
                        onClicked:      setupView._selectPage(
                                            "joystick",
                                            joystickSideBtn.label,
                                            "qrc:/qml/QGroundControl/VehicleSetup/JoystickConfig.qml",
                                            false, false, null)

                        property Joystick _activeJoystick:      joystickManager.activeJoystick
                        property bool   _buttonsOnly:           _activeJoystick ? _activeJoystick.axisCount == 0 : false
                        property bool   _forcedToButtonsOnly:   !QGroundControl.corePlugin.options.allowJoystickSelection && _buttonsOnly
                    }

                    Repeater {
                        model: _fullParameterVehicleAvailable ? _activeVehicle.autopilotPlugin.vehicleComponents : 0

                        SetupSideButton {
                            label:          modelData.name
                            iconSource:     modelData.iconResource
                            pageKey:        "component:" + modelData.name
                            setupComplete:  modelData.setupComplete
                            buttonVisible:  modelData.setupSource.toString() !== "" &&
                                            !setupView._isAdvancedOnlyComponent(modelData) &&
                                            !setupView._isSafetyComponent(modelData)
                            onClicked:      setupView.showVehicleComponentPanel(modelData)
                        }
                    }
                }
            }
        }

        // ---- Right content pane ----
        Item {
            Layout.fillWidth:   true
            Layout.fillHeight:  true

            Rectangle {
                anchors.fill: parent
                color:        setupView._pageBackground
            }

            Rectangle {
                id:             contentHeader
                anchors.left:   parent.left
                anchors.right:  parent.right
                anchors.top:    parent.top
                height:         setupView._headerHeight
                color:          setupView._pageBackground
                z:              20

                QGCLabel {
                    anchors.centerIn:   parent
                    width:              parent.width - closeButton.width * 2
                                        - setupView._headerIconPad * 2
                    horizontalAlignment: Text.AlignHCenter
                    elide:              Text.ElideRight
                    text:               setupView._selectedTitle
                    color:              setupView._headingColor
                    font.pointSize:     ScreenTools.largeFontPointSize
                    font.weight:        Font.DemiBold
                }

                Item {
                    id:                     closeButton
                    anchors.right:          parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin:    setupView._headerIconPad
                    height:                 ScreenTools.defaultFontPixelHeight * 2.0
                    width:                  height

                    QGCColoredImage {
                        anchors.centerIn:   parent
                        width:              ScreenTools.defaultFontPixelHeight * 0.85
                        height:             width
                        source:             "/res/XDeleteBlack.svg"
                        color:              setupView._iconColor
                        opacity:            closeMouse.containsMouse ? 1.0 : 0.85
                    }

                    RippleEffect {
                        id:          closeRipple
                        rippleColor: setupView._darkTheme ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.16)
                        clipRadius:  parent.width / 2
                    }

                    MouseArea {
                        id:             closeMouse
                        anchors.fill:   parent
                        hoverEnabled:   true
                        cursorShape:    Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            closeRipple.tap(mouse.x, mouse.y)
                            closePageTimer.restart()
                        }
                    }

                    Timer {
                        id:         closePageTimer
                        interval:   140
                        repeat:     false
                        onTriggered: setupView._closeSetup()
                    }
                }

                Rectangle {
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    anchors.bottom: parent.bottom
                    height:         1
                    color:          setupView._dividerColor
                }
            }

            Item {
                id:                     contentHost
                anchors.left:           parent.left
                anchors.right:          parent.right
                anchors.top:            contentHeader.bottom
                anchors.bottom:         parent.bottom
                anchors.leftMargin:     setupView._contentPad
                anchors.rightMargin:    setupView._contentPad
                anchors.topMargin:      ScreenTools.defaultFontPixelHeight * 0.2
                anchors.bottomMargin:   ScreenTools.defaultFontPixelHeight * 0.2
                clip:                   true
                z:                      1

                Loader {
                    id:                     panelLoader
                    width:                  parent.width
                    height:                 parent.height
                    x:                      0
                    y:                      0
                    opacity:                0
                    z:                      1

                    property var vehicleComponent: setupView._selectedComponent

                    onWidthChanged: {
                        if (item && typeof item.computeSummaryBoxSize === "function")
                            item.computeSummaryBoxSize()
                    }
                }

                SequentialAnimation {
                    id: pageOutAnim
                    NumberAnimation {
                        target:     panelLoader
                        property:   "opacity"
                        to:         0
                        duration:   120
                        easing.type: Easing.InQuad
                    }
                    ScriptAction { script: setupView._reloadContent() }
                }

                ParallelAnimation {
                    id: pageInAnim
                    NumberAnimation {
                        target:         panelLoader
                        property:       "opacity"
                        to:             1
                        duration:       260
                        easing.type:    Easing.OutCubic
                    }
                    NumberAnimation {
                        target:         panelLoader
                        property:       "x"
                        to:             0
                        duration:       280
                        easing.type:    Easing.OutCubic
                    }
                }
            }
        }
    }

    Component {
        id: summaryLoaderComponent

        Loader {
            anchors.fill: parent

            Component.onCompleted: {
                if (_fullParameterVehicleAvailable) {
                    if (_activeVehicle.autopilotPlugin.vehicleComponents.length === 0)
                        sourceComponent = noComponentsVehicleSummaryComponent
                    else
                        source = "qrc:/qml/QGroundControl/VehicleSetup/VehicleSummary.qml"
                } else if (QGroundControl.multiVehicleManager.parameterReadyVehicleAvailable) {
                    sourceComponent = missingParametersVehicleSummaryComponent
                } else {
                    sourceComponent = disconnectedVehicleAndParamsSummaryComponent
                }
            }
        }
    }

    Component {
        id: noComponentsVehicleSummaryComponent
        Rectangle {
            color: setupView._pageBackground
            QGCLabel {
                anchors.margins:        _defaultTextWidth * 2
                anchors.fill:           parent
                verticalAlignment:      Text.AlignVCenter
                horizontalAlignment:    Text.AlignHCenter
                wrapMode:               Text.WordWrap
                font.pointSize:         ScreenTools.mediumFontPointSize
                color:                  setupView._titleColor
                text:                   qsTr("%1 does not currently support configuration of your vehicle. ").arg(QGroundControl.appName) +
                                        "If your vehicle is already configured you can still Fly."
            }
        }
    }

    Component {
        id: disconnectedVehicleAndParamsSummaryComponent
        Rectangle {
            color: setupView._pageBackground
            QGCLabel {
                anchors.margins:        _defaultTextWidth * 2
                anchors.fill:           parent
                verticalAlignment:      Text.AlignVCenter
                horizontalAlignment:    Text.AlignHCenter
                wrapMode:               Text.WordWrap
                font.pointSize:         ScreenTools.largeFontPointSize
                color:                  setupView._titleColor
                text:                   qsTr("Vehicle configuration pages will display after you connect your vehicle and parameters have been downloaded.")
            }
        }
    }

    Component {
        id: missingParametersVehicleSummaryComponent
        Rectangle {
            color: setupView._pageBackground
            QGCLabel {
                anchors.margins:        _defaultTextWidth * 2
                anchors.fill:           parent
                verticalAlignment:      Text.AlignVCenter
                horizontalAlignment:    Text.AlignHCenter
                wrapMode:               Text.WordWrap
                font.pointSize:         ScreenTools.mediumFontPointSize
                color:                  setupView._titleColor
                text:                   qsTr("Vehicle did not return the full parameter list. ") +
                                        qsTr("As a result, the configuration pages are not available.")
            }
        }
    }

    Component {
        id: messagePanelComponent
        Item {
            QGCLabel {
                anchors.margins:        _defaultTextWidth * 2
                anchors.fill:           parent
                verticalAlignment:      Text.AlignVCenter
                horizontalAlignment:    Text.AlignHCenter
                wrapMode:               Text.WordWrap
                font.pointSize:         ScreenTools.mediumFontPointSize
                color:                  setupView._titleColor
                text:                   _messagePanelText
            }
        }
    }
}
