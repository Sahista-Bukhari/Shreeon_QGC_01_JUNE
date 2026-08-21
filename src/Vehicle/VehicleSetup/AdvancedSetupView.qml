import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id:     advancedView
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
    readonly property color _headingColor:      _darkTheme ? "#AEAEB2" : "#1C1C1E"
    readonly property color _iconColor:         _darkTheme ? "#AEAEB2" : "#1C1C1E"
    readonly property color _dividerColor:      _darkTheme ? qgcPal.windowShade : "#f6f6f6"
    readonly property color _sidebarBg:         _darkTheme ? qgcPal.windowShade : "white"
    readonly property color _accentGreen:       "#00a04c"
    readonly property color _rowPressed:        _darkTheme ? qgcPal.windowShade : "#F2F2F2"
    readonly property real  _headerIconPad:     ScreenTools.defaultFontPixelWidth * 1.0
    readonly property real  _headerHeight:      ScreenTools.toolbarHeight
    readonly property real  _rowHeight:         ScreenTools.defaultFontPixelHeight * 3.2
    readonly property real  _sidebarWidth:      Math.max(ScreenTools.defaultFontPixelWidth * 20,
                                                         Math.min(width * 0.32, ScreenTools.defaultFontPixelWidth * 24))
    readonly property real  _sidebarPad:        ScreenTools.defaultFontPixelWidth * 1.4
    readonly property real  _sideIconSize:      ScreenTools.defaultFontPixelHeight * 2.2
    readonly property real  _contentPad:        ScreenTools.defaultFontPixelWidth * 0.75
    readonly property real  _defaultTextWidth:  ScreenTools.defaultFontPixelWidth
    readonly property string _mainTitleFamily:  ScreenTools.normalFontFamily
    readonly property real   _mainTitlePointSize: ScreenTools.largeFontPointSize
    readonly property int    _mainTitleWeight:  Font.DemiBold

    property var    _activeVehicle:                 QGroundControl.multiVehicleManager.activeVehicle
    property string _messagePanelText:              ""
    property bool   _fullParameterVehicleAvailable: QGroundControl.multiVehicleManager.parameterReadyVehicleAvailable &&
                                                    _activeVehicle &&
                                                    !_activeVehicle.parameterManager.missingParameters
    property var    _corePlugin:                    QGroundControl.corePlugin

    property string _selectedKey:       ""
    property string _selectedTitle:     qsTr("Advanced")
    property string _selectedSource:    ""
    property bool   _selectedIsMessage: false
    property var    _selectedComponent: null

    readonly property var _advancedComponentMatchers: [
        "SensorsComponent",
        "AirframeComponent",
        "ActuatorComponent",
        "MotorComponent",
        "TuningComponent",
        "FlightBehavior"
    ]

    DeadMouseArea {
        anchors.fill: parent
    }

    // GeoTagPage uses this controller from its loading context. It lived in
    // AnalyzeView before the analyzer pages were moved into this view.
    GeoTagController {
        id: geoController
    }

    function _vehicleComponentSetupSource(component) {
        return component ? component.setupSource.toString() : ""
    }

    function _findAdvancedVehicleComponent(matchStr) {
        if (!_activeVehicle || !_fullParameterVehicleAvailable)
            return null
        var components = _activeVehicle.autopilotPlugin.vehicleComponents
        for (var i = 0; i < components.length; i++) {
            var source = _vehicleComponentSetupSource(components[i])
            if (source !== "" && source.indexOf(matchStr) >= 0)
                return components[i]
        }
        return null
    }

    function _advancedVehicleComponents() {
        var result = []
        for (var i = 0; i < _advancedComponentMatchers.length; i++) {
            var component = _findAdvancedVehicleComponent(_advancedComponentMatchers[i])
            if (component)
                result.push(component)
        }
        return result
    }

    function showVehicleComponentPanel(vehicleComponent) {
        if (!mainWindow.allowViewSwitch())
            return
        var prereq = _activeVehicle.autopilotPlugin.prerequisiteSetup(vehicleComponent)
        var key = "component:" + vehicleComponent.name
        if (prereq !== "") {
            _messagePanelText = qsTr("%1 setup must be completed prior to %2 setup.").arg(prereq).arg(vehicleComponent.name)
            _selectPage(key, vehicleComponent.name, "", true, vehicleComponent)
        } else {
            _selectPage(key, vehicleComponent.name, vehicleComponent.setupSource.toString(), false, vehicleComponent)
        }
    }

    function showParametersPanel() {
        if (!mainWindow.allowViewSwitch())
            return
        _selectPage("parameters", qsTr("Parameters"),
                    "qrc:/qml/QGroundControl/VehicleSetup/SetupParameterEditor.qml",
                    false, null)
    }

    function showFirmwarePanel() {
        if (!mainWindow.allowViewSwitch())
            return
        _selectPage("firmware", qsTr("Firmware"),
                    "qrc:/qml/QGroundControl/VehicleSetup/FirmwareUpgrade.qml",
                    false, null)
    }

    function showAnalyzePanel(analyzePage) {
        if (!mainWindow.allowViewSwitch() || !analyzePage)
            return
        _selectPage("analyze:" + analyzePage.url.toString(),
                    analyzePage.title,
                    analyzePage.url.toString(),
                    false, null)
    }

    function _closeView() {
        advancedView.popout()
        if (typeof mainWindow !== "undefined" && mainWindow)
            mainWindow.showModeSelection(Qt.point(mainWindow.width / 2, ScreenTools.toolbarHeight / 2))
    }

    function _selectPage(key, title, pageSource, isMessage, vehicleComponent) {
        _selectedKey = key
        _selectedTitle = title
        _selectedSource = pageSource ? pageSource.toString() : ""
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
        } else if (_selectedKey === "disconnected") {
            panelLoader.sourceComponent = disconnectedPanelComponent
        } else if (_selectedSource !== "") {
            panelLoader.source = _selectedSource
        }
        panelLoader.opacity = 0
        panelLoader.x = ScreenTools.defaultFontPixelWidth * 2.4
        pageInAnim.restart()
    }

    function _selectInitialPage() {
        if (!_fullParameterVehicleAvailable) {
            _selectPage("disconnected", qsTr("Advanced"), "", false, null)
            return
        }
        var components = _advancedVehicleComponents()
        if (components.length > 0) {
            showVehicleComponentPanel(components[0])
            return
        }
        if (_corePlugin.showAdvancedUI &&
                QGroundControl.multiVehicleManager.parameterReadyVehicleAvailable &&
                _activeVehicle && !_activeVehicle.usingHighLatencyLink) {
            showParametersPanel()
            return
        }
        if (!ScreenTools.isMobile && _corePlugin.options.showFirmwareUpgrade) {
            showFirmwarePanel()
            return
        }
        _selectPage("disconnected", qsTr("Advanced"), "", false, null)
    }

    Component.onCompleted: _selectInitialPage()

    Connections {
        target: QGroundControl.corePlugin
        function onShowAdvancedUIChanged(showAdvancedUI) {
            if (!showAdvancedUI && _selectedKey === "parameters")
                _selectInitialPage()
        }
    }

    Connections {
        target: QGroundControl.multiVehicleManager
        function onParameterReadyVehicleAvailableChanged(parametersReady) {
            _selectInitialPage()
        }
    }

    component SetupSideButton: Item {
        id: sideBtn

        property string label
        property string iconSource: ""
        property string pageKey
        property bool   setupComplete: true
        property bool   buttonVisible: true
        property bool   selected: advancedView._selectedKey === pageKey

        signal clicked()

        width:  parent ? parent.width : 0
        height: buttonVisible ? advancedView._rowHeight : 0
        visible: buttonVisible

        Rectangle {
            anchors.fill: parent
            color: {
                if (sideMouse.pressed)
                    return advancedView._rowPressed
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
            color:          sideBtn.selected ? advancedView._accentGreen : "transparent"
        }

        RowLayout {
            anchors.fill:           parent
            anchors.leftMargin:     advancedView._sidebarPad
            anchors.rightMargin:    advancedView._sidebarPad
            spacing:                ScreenTools.defaultFontPixelWidth * 1.25

            Item {
                Layout.preferredWidth:  advancedView._sideIconSize
                Layout.preferredHeight: advancedView._sideIconSize
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
                    color:              !sideBtn.setupComplete ? "#E53935" : advancedView._titleColor
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
                                    : (sideBtn.selected ? advancedView._accentGreen : advancedView._titleColor)
                font.pointSize:     ScreenTools.defaultFontPointSize
                font.bold:          sideBtn.selected
                wrapMode:           Text.WordWrap
                maximumLineCount:   2
                elide:              Text.ElideRight
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
            rippleColor: advancedView._darkTheme ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(0, 160 / 255, 76 / 255, 0.22)
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

        Rectangle {
            Layout.preferredWidth: advancedView._sidebarWidth
            Layout.fillHeight:     true
            color:                 advancedView._sidebarBg

            Rectangle {
                anchors.top:    parent.top
                anchors.bottom: parent.bottom
                anchors.right:  parent.right
                width:          1
                color:          advancedView._dividerColor
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

                    Repeater {
                        model: _fullParameterVehicleAvailable ? advancedView._advancedVehicleComponents() : []

                        SetupSideButton {
                            label:          modelData.name
                            iconSource:     modelData.iconResource
                            pageKey:        "component:" + modelData.name
                            setupComplete:  modelData.setupComplete
                            buttonVisible:  modelData.setupSource.toString() !== ""
                            onClicked:      advancedView.showVehicleComponentPanel(modelData)
                        }
                    }

                    SetupSideButton {
                        label:          qsTr("Parameters")
                        iconSource:     "/qmlimages/subMenuButtonImage.png"
                        pageKey:        "parameters"
                        buttonVisible:  _corePlugin.showAdvancedUI &&
                                        QGroundControl.multiVehicleManager.parameterReadyVehicleAvailable &&
                                        _activeVehicle &&
                                        !_activeVehicle.usingHighLatencyLink
                        onClicked:      advancedView.showParametersPanel()
                    }

                    SetupSideButton {
                        label:          qsTr("Firmware")
                        iconSource:     "/qmlimages/FirmwareUpgradeIcon.png"
                        pageKey:        "firmware"
                        buttonVisible:  !ScreenTools.isMobile && _corePlugin.options.showFirmwareUpgrade
                        onClicked:      advancedView.showFirmwarePanel()
                    }

                    Repeater {
                        model: _corePlugin ? _corePlugin.analyzePages : []

                        SetupSideButton {
                            label:          modelData.title
                            iconSource:     modelData.icon
                            pageKey:        "analyze:" + modelData.url.toString()
                            onClicked:      advancedView.showAnalyzePanel(modelData)
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth:   true
            Layout.fillHeight:  true

            Rectangle {
                anchors.fill: parent
                color:        advancedView._pageBackground
            }

            Rectangle {
                id:             contentHeader
                anchors.left:   parent.left
                anchors.right:  parent.right
                anchors.top:    parent.top
                height:         advancedView._headerHeight
                color:          advancedView._pageBackground
                z:              20

                QGCLabel {
                    anchors.centerIn:   parent
                    width:              parent.width - closeButton.width * 2
                                        - advancedView._headerIconPad * 2
                    horizontalAlignment: Text.AlignHCenter
                    elide:              Text.ElideRight
                    text:               advancedView._selectedTitle
                    color:              advancedView._headingColor
                    font.family:        advancedView._mainTitleFamily
                    font.pointSize:     advancedView._mainTitlePointSize
                    font.weight:        advancedView._mainTitleWeight
                }

                Item {
                    id:                     closeButton
                    anchors.right:          parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin:    advancedView._headerIconPad
                    height:                 ScreenTools.defaultFontPixelHeight * 2.0
                    width:                  height

                    QGCColoredImage {
                        anchors.centerIn:   parent
                        width:              ScreenTools.defaultFontPixelHeight * 0.85
                        height:             width
                        source:             "/res/XDeleteBlack.svg"
                        color:              advancedView._iconColor
                        opacity:            closeMouse.containsMouse ? 1.0 : 0.85
                    }

                    RippleEffect {
                        id:          closeRipple
                        rippleColor: advancedView._darkTheme ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.16)
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
                        onTriggered: advancedView._closeView()
                    }
                }

                Rectangle {
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    anchors.bottom: parent.bottom
                    height:         1
                    color:          advancedView._dividerColor
                }
            }

            Item {
                id:                     contentHost
                anchors.left:           parent.left
                anchors.right:          parent.right
                anchors.top:            contentHeader.bottom
                anchors.bottom:         parent.bottom
                anchors.leftMargin:     advancedView._contentPad
                anchors.rightMargin:    advancedView._contentPad
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

                    property var vehicleComponent: advancedView._selectedComponent

                    Connections {
                        target:               panelLoader.item
                        ignoreUnknownSignals: true
                        function onPopout() {
                            mainWindow.createrWindowedAnalyzePage(advancedView._selectedTitle,
                                                                  advancedView._selectedSource)
                        }
                    }
                }

                SequentialAnimation {
                    id: pageOutAnim
                    NumberAnimation {
                        target:      panelLoader
                        property:    "opacity"
                        to:          0
                        duration:    120
                        easing.type: Easing.InQuad
                    }
                    ScriptAction { script: advancedView._reloadContent() }
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
        id: disconnectedPanelComponent
        Rectangle {
            color: advancedView._pageBackground
            QGCLabel {
                anchors.margins:        _defaultTextWidth * 2
                anchors.fill:           parent
                verticalAlignment:      Text.AlignVCenter
                horizontalAlignment:    Text.AlignHCenter
                wrapMode:               Text.WordWrap
                font.pointSize:         ScreenTools.mediumFontPointSize
                color:                  advancedView._titleColor
                text:                   _fullParameterVehicleAvailable
                                        ? qsTr("No advanced configuration pages are available for this vehicle.")
                                        : qsTr("Advanced configuration pages will display after you connect your vehicle and parameters have been downloaded.")
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
                color:                  advancedView._titleColor
                text:                   _messagePanelText
            }
        }
    }
}
