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
    readonly property color _accentGreen:       "#00a04c"
    readonly property color _rowPressed:        _darkTheme ? qgcPal.windowShade : "#F2F2F2"
    // Half-screen panel: tighter gutters so list + detail pages use the width well
    readonly property real  _horizontalPad:     Math.max(ScreenTools.defaultFontPixelWidth * 2.5, width * 0.06)
    readonly property real  _headerIconPad:     ScreenTools.defaultFontPixelWidth * 1.2
    readonly property real  _rowHeight:         ScreenTools.defaultFontPixelHeight * 3.2
    readonly property real  _headerHeight:      ScreenTools.toolbarHeight

    readonly property real      _defaultTextHeight: ScreenTools.defaultFontPixelHeight
    readonly property real      _defaultTextWidth:  ScreenTools.defaultFontPixelWidth
    readonly property string    _armedVehicleText:  qsTr("This operation cannot be performed while the vehicle is armed.")

    property var    _activeVehicle:                 QGroundControl.multiVehicleManager.activeVehicle
    property bool   _vehicleArmed:                  _activeVehicle ? _activeVehicle.armed : false
    property string _messagePanelText:              qsTr("missing message panel text")
    property bool   _fullParameterVehicleAvailable: QGroundControl.multiVehicleManager.parameterReadyVehicleAvailable && !_activeVehicle.parameterManager.missingParameters
    property var    _corePlugin:                    QGroundControl.corePlugin

    DeadMouseArea {
        anchors.fill: parent
    }

    function showSummaryPanel() {
        if (mainWindow.allowViewSwitch())
            _openDetail(qsTr("Summary"), "", true)
    }

    function _showSummaryPanel() {
        // Kept for Connections that previously flipped the Summary button
        if (setupStack.depth > 1)
            while (setupStack.depth > 1)
                setupStack.pop()
    }

    function showPanel(button, qmlSource) {
        // Legacy API — open detail by source
        if (!mainWindow.allowViewSwitch())
            return
        var title = button && button.text ? button.text : qsTr("Configuration")
        _openDetail(title, qmlSource, false)
    }

    function showVehicleComponentPanel(vehicleComponent) {
        if (!mainWindow.allowViewSwitch())
            return
        var autopilotPlugin = _activeVehicle.autopilotPlugin
        var prereq = autopilotPlugin.prerequisiteSetup(vehicleComponent)
        if (prereq !== "") {
            _messagePanelText = qsTr("%1 setup must be completed prior to %2 setup.").arg(prereq).arg(vehicleComponent.name)
            _openDetail(vehicleComponent.name, "", false, true)
        } else {
            _openDetail(vehicleComponent.name, vehicleComponent.setupSource, false, false, vehicleComponent)
        }
    }

    function showParametersPanel() {
        if (!mainWindow.allowViewSwitch())
            return
        _openDetail(qsTr("Parameters"), "qrc:/qml/QGroundControl/VehicleSetup/SetupParameterEditor.qml", false)
    }

    function _closeSetup() {
        setupView.popout()
        if (typeof mainWindow !== "undefined" && mainWindow)
            mainWindow.showModeSelection(Qt.point(mainWindow.width / 2, ScreenTools.toolbarHeight / 2))
    }

    function _goBack() {
        if (setupStack.depth > 1)
            setupStack.pop()
    }

    function _openDetail(pageTitle, pageSource, isSummary, isMessage, vehicleComponent) {
        // Always return to hub first, then open the selected page
        while (setupStack.depth > 1)
            setupStack.pop()
        setupStack.push(detailPageComponent, {
                            pageTitle: pageTitle,
                            pageSource: pageSource ? pageSource.toString() : "",
                            isSummary: isSummary === true,
                            isMessage: isMessage === true,
                            vehicleComponent: vehicleComponent ? vehicleComponent : null
                        })
    }

    Component.onCompleted: { /* hub is the default */ }

    Connections {
        target: QGroundControl.corePlugin
        function onShowAdvancedUIChanged(showAdvancedUI) {
            if (!showAdvancedUI && setupStack.depth > 1)
                _showSummaryPanel()
        }
    }

    Connections {
        target: QGroundControl.multiVehicleManager
        function onParameterReadyVehicleAvailableChanged(parametersReady) {
            // Return to hub when vehicle availability changes
            if (setupStack.depth > 1)
                _showSummaryPanel()
        }
    }

    component SetupNavRow: Item {
        id: rowRoot

        property string label
        property string iconSource: ""
        property bool   showChevron: true
        property bool   setupComplete: true
        property bool   rowVisible: true

        signal clicked()

        width:  parent ? parent.width : 0
        height: rowVisible ? setupView._rowHeight : 0
        visible: rowVisible

        Rectangle {
            anchors.fill: parent
            color:        rowMouse.pressed ? setupView._rowPressed : "transparent"
        }

        RowLayout {
            anchors.fill:           parent
            anchors.leftMargin:     setupView._horizontalPad
            anchors.rightMargin:    setupView._horizontalPad
            spacing:                ScreenTools.defaultFontPixelWidth * 1.5

            Item {
                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 2.2
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2
                Layout.alignment:       Qt.AlignVCenter
                visible:                rowRoot.iconSource !== ""

                Rectangle {
                    anchors.fill: parent
                    radius:       width / 2
                    color:        rowRoot.setupComplete
                                  ? Qt.rgba(0, 160 / 255, 76 / 255, 0.12)
                                  : Qt.rgba(229 / 255, 57 / 255, 53 / 255, 0.12)
                }

                QGCColoredImage {
                    anchors.centerIn:   parent
                    width:              parent.width * 0.52
                    height:             width
                    source:             rowRoot.iconSource
                    color:              rowRoot.setupComplete ? setupView._accentGreen : "#E53935"
                    fillMode:           Image.PreserveAspectFit
                }
            }

            QGCLabel {
                Layout.fillWidth:   true
                Layout.alignment:   Qt.AlignVCenter
                text:               rowRoot.label
                color:              setupView._titleColor
                font.pointSize:     ScreenTools.defaultFontPointSize
                elide:              Text.ElideRight
            }

            Rectangle {
                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 0.55
                Layout.preferredHeight: Layout.preferredWidth
                Layout.alignment:       Qt.AlignVCenter
                radius:                 width / 2
                color:                  "#E53935"
                visible:                !rowRoot.setupComplete
            }

            QGCLabel {
                Layout.alignment:   Qt.AlignVCenter
                visible:            rowRoot.showChevron
                text:               "›"
                color:              setupView._secondaryText
                font.pointSize:     ScreenTools.largeFontPointSize * 1.8
                font.weight:        Font.Light
            }
        }

        MouseArea {
            id:             rowMouse
            anchors.fill:   parent
            cursorShape:    Qt.PointingHandCursor
            onClicked:      rowRoot.clicked()
        }
    }

    StackView {
        id:             setupStack
        anchors.fill:   parent
        initialItem:    hubPage
        clip:           true
    }

    Component {
        id: hubPage

        Item {
            width:  setupStack.width
            height: setupStack.height

            Rectangle {
                id:             hubHeader
                anchors.left:   parent.left
                anchors.right:  parent.right
                anchors.top:    parent.top
                height:         setupView._headerHeight
                color:          setupView._pageBackground
                z:              20

                QGCLabel {
                    anchors.centerIn:   parent
                    text:               qsTr("Vehicle Configuration")
                    color:              setupView._headingColor
                    font.pointSize:     ScreenTools.largeFontPointSize
                    font.weight:        Font.DemiBold
                }

                Item {
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

                    MouseArea {
                        id:             closeMouse
                        anchors.fill:   parent
                        hoverEnabled:   true
                        cursorShape:    Qt.PointingHandCursor
                        onClicked:      setupView._closeSetup()
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

            QGCFlickable {
                anchors.left:           parent.left
                anchors.right:          parent.right
                anchors.top:            hubHeader.bottom
                anchors.bottom:         parent.bottom
                contentWidth:           width
                contentHeight:          hubList.height + ScreenTools.defaultFontPixelHeight * 2
                clip:                   true
                flickableDirection:     Flickable.VerticalFlick

                Column {
                    id:                 hubList
                    width:              parent.width
                    anchors.top:        parent.top
                    anchors.topMargin:  ScreenTools.defaultFontPixelHeight * 1.5

                    SetupNavRow {
                        label:      qsTr("Summary")
                        iconSource: "/qmlimages/VehicleSummaryIcon.png"
                        onClicked:  setupView._openDetail(qsTr("Summary"), "", true)
                    }

                    SetupNavRow {
                        label:          qsTr("Optical Flow")
                        rowVisible:     _activeVehicle ? _activeVehicle.flowImageIndex > 0 : false
                        onClicked:      setupView._openDetail(qsTr("Optical Flow"),
                                                              "qrc:/qml/QGroundControl/VehicleSetup/OpticalFlowSensor.qml",
                                                              false)
                    }

                    SetupNavRow {
                        id:             joystickRow
                        label:          _forcedToButtonsOnly ? qsTr("Buttons") : qsTr("Joystick")
                        iconSource:     "/qmlimages/Joystick.png"
                        setupComplete:  _activeJoystick ? _activeJoystick.calibrated || _buttonsOnly : false
                        rowVisible:     _fullParameterVehicleAvailable && joystickManager.joysticks.length !== 0
                        onClicked:      setupView._openDetail(joystickRow.label,
                                                              "qrc:/qml/QGroundControl/VehicleSetup/JoystickConfig.qml",
                                                              false)

                        property Joystick _activeJoystick:      joystickManager.activeJoystick
                        property bool   _buttonsOnly:           _activeJoystick ? _activeJoystick.axisCount == 0 : false
                        property bool   _forcedToButtonsOnly:   !QGroundControl.corePlugin.options.allowJoystickSelection && _buttonsOnly
                    }

                    Repeater {
                        id:     componentRepeater
                        model:  _fullParameterVehicleAvailable ? _activeVehicle.autopilotPlugin.vehicleComponents : 0

                        SetupNavRow {
                            label:          modelData.name
                            iconSource:     modelData.iconResource
                            setupComplete:  modelData.setupComplete
                            rowVisible:     modelData.setupSource.toString() !== ""
                            onClicked:      setupView.showVehicleComponentPanel(modelData)
                        }
                    }

                    SetupNavRow {
                        label:      qsTr("Parameters")
                        iconSource: "/qmlimages/subMenuButtonImage.png"
                        rowVisible: QGroundControl.multiVehicleManager.parameterReadyVehicleAvailable &&
                                    _activeVehicle &&
                                    !_activeVehicle.usingHighLatencyLink &&
                                    _corePlugin.showAdvancedUI
                        onClicked:  setupView.showParametersPanel()
                    }

                    SetupNavRow {
                        label:      qsTr("Firmware")
                        iconSource: "/qmlimages/FirmwareUpgradeIcon.png"
                        rowVisible: !ScreenTools.isMobile && _corePlugin.options.showFirmwareUpgrade
                        onClicked:  setupView._openDetail(qsTr("Firmware"),
                                                          "qrc:/qml/QGroundControl/VehicleSetup/FirmwareUpgrade.qml",
                                                          false)
                    }
                }
            }
        }
    }

    Component {
        id: detailPageComponent

        Item {
            id: detailRoot

            property string pageTitle
            property string pageSource
            property bool   isSummary: false
            property bool   isMessage: false
            property var    vehicleComponent: null

            // StackView sizes children; keep explicit fill for reliable header layout
            width:  setupStack.width
            height: setupStack.height

            Rectangle {
                anchors.fill: parent
                color:        setupView._pageBackground
            }

            Rectangle {
                id:             detailHeader
                anchors.left:   parent.left
                anchors.right:  parent.right
                anchors.top:    parent.top
                height:         setupView._headerHeight
                color:          setupView._pageBackground
                z:              20

                // Back — far left edge
                Item {
                    id:                     backButton
                    anchors.left:           parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin:     setupView._headerIconPad
                    height:                 ScreenTools.defaultFontPixelHeight * 2.0
                    width:                  height
                    z:                      21

                    Rectangle {
                        anchors.fill: parent
                        radius:       height / 2
                        color:        backMouse.containsMouse ? setupView._rowPressed : "transparent"
                    }

                    QGCColoredImage {
                        anchors.centerIn:   parent
                        width:              ScreenTools.defaultFontPixelHeight * 0.95
                        height:             width
                        source:             "qrc:/InstrumentValueIcons/arrow-thin-left.svg"
                        color:              setupView._iconColor
                    }

                    MouseArea {
                        id:             backMouse
                        anchors.fill:   parent
                        hoverEnabled:   true
                        cursorShape:    Qt.PointingHandCursor
                        onClicked:      setupView._goBack()
                    }
                }

                QGCLabel {
                    anchors.centerIn:       parent
                    width:                  parent.width - (backButton.width + closeButton.width
                                                           + setupView._headerIconPad * 2
                                                           + ScreenTools.defaultFontPixelWidth * 2)
                    horizontalAlignment:    Text.AlignHCenter
                    elide:                  Text.ElideRight
                    text:                   detailRoot.pageTitle
                    color:                  setupView._headingColor
                    font.pointSize:         ScreenTools.largeFontPointSize
                    font.weight:            Font.DemiBold
                }

                Item {
                    id:                     closeButton
                    anchors.right:          parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin:    setupView._headerIconPad
                    height:                 ScreenTools.defaultFontPixelHeight * 2.0
                    width:                  height
                    z:                      21

                    QGCColoredImage {
                        anchors.centerIn:   parent
                        width:              ScreenTools.defaultFontPixelHeight * 0.85
                        height:             width
                        source:             "/res/XDeleteBlack.svg"
                        color:              setupView._iconColor
                        opacity:            detailCloseMouse.containsMouse ? 1.0 : 0.85
                    }

                    MouseArea {
                        id:             detailCloseMouse
                        anchors.fill:   parent
                        hoverEnabled:   true
                        cursorShape:    Qt.PointingHandCursor
                        onClicked:      setupView._closeSetup()
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

            Loader {
                id:                     panelLoader
                anchors.left:           parent.left
                anchors.right:          parent.right
                anchors.top:            detailHeader.bottom
                anchors.bottom:         parent.bottom
                anchors.leftMargin:     setupView._horizontalPad * 0.5
                anchors.rightMargin:    setupView._horizontalPad * 0.5
                anchors.topMargin:      ScreenTools.defaultFontPixelHeight * 0.35
                anchors.bottomMargin:   ScreenTools.defaultFontPixelHeight * 0.35
                z:                      1

                property var vehicleComponent: detailRoot.vehicleComponent

                Component.onCompleted: {
                    if (detailRoot.isMessage) {
                        sourceComponent = messagePanelComponent
                    } else if (detailRoot.isSummary) {
                        sourceComponent = summaryLoaderComponent
                    } else if (detailRoot.pageSource !== "") {
                        source = detailRoot.pageSource
                    }
                }

                onWidthChanged: {
                    // Let Flow / Grid pages reflow when the half-panel width settles
                    if (item && typeof item.computeSummaryBoxSize === "function")
                        item.computeSummaryBoxSize()
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
