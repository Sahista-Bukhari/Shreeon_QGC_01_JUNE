import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

SetupPage {
    id:             firmwarePage
    pageComponent:  firmwarePageComponent
    pageName:       qsTr("Firmware")
    showAdvanced:   globals.activeVehicle && globals.activeVehicle.apmFirmware

    readonly property bool _darkTheme:         firmwarePalette.globalTheme === QGCPalette.Dark
    readonly property color _pageBackground:   _darkTheme ? firmwarePalette.window : "#FFFFFF"
    readonly property color _titleColor:       _darkTheme ? "#AEAEB2" : "#3A3A3C"
    readonly property color _bodyColor:        _darkTheme ? "#8E8E93" : "#5A5A5E"
    readonly property color _accentGreen:      "#00a04c"
    readonly property color _cardFill:         _darkTheme ? firmwarePalette.windowShade : "#F5F5F5"
    readonly property color _innerCardFill:    _darkTheme ? firmwarePalette.window : "#FFFFFF"
    readonly property color _dividerColor:     _darkTheme ? firmwarePalette.windowShade : "#E5E5E5"
    readonly property real  _pagePad:          ScreenTools.defaultFontPixelWidth * 2.2
    readonly property real  _controlSpacing:   ScreenTools.defaultFontPixelWidth
    readonly property real  _cardRadius:       ScreenTools.defaultFontPixelWidth * 0.9

    QGCPalette {
        id:                firmwarePalette
        colorGroupEnabled: firmwarePage.enabled
    }

    Component {
        id: firmwarePageComponent

        ColumnLayout {
            anchors.left:        parent.left
            anchors.right:       parent.right
            anchors.leftMargin:  firmwarePage._pagePad
            anchors.rightMargin: firmwarePage._pagePad
            height:              firmwarePage.availableHeight
            spacing:             firmwarePage._controlSpacing

            // Those user visible strings are hard to translate because we can't send the
            // HTML strings to translation as this can create a security risk. we need to find
            // a better way to highlight them, or use less highlights.

            // User visible strings
            readonly property string title:             qsTr("Firmware Setup") // Popup dialog title
            readonly property string highlightPrefix:   "<font color=\"" + firmwarePalette.warningText + "\">"
            readonly property string accentPrefix:      "<font color=\"" + firmwarePage._accentGreen + "\"><b>"
            readonly property string accentSuffix:      "</b></font>"
            readonly property string highlightSuffix:   "</font>"
            readonly property string welcomeText:       qsTr("%1 can upgrade the firmware on Pixhawk devices and SiK Radios.").arg(QGroundControl.appName)
            readonly property string welcomeTextSingle: qsTr("Update the autopilot firmware to the latest version")
            readonly property string plugInText:        accentPrefix + qsTr("Connect your device") + accentSuffix + qsTr(" directly by USB to start the firmware upgrade.")
            readonly property string flashFailText:     qsTr("If upgrade failed, make sure to connect ") + highlightPrefix + qsTr("directly") + highlightSuffix + qsTr(" to a powered USB port on your computer, not through a USB hub. ") +
                                                        qsTr("Also make sure you are only powered via USB ") + highlightPrefix + qsTr("not battery") + highlightSuffix + "."
            readonly property string qgcUnplugText1:    qsTr("All %1 connections to vehicles must be ").arg(QGroundControl.appName) + highlightPrefix + qsTr(" disconnected ") + highlightSuffix + qsTr("prior to firmware upgrade.")
            readonly property string qgcUnplugText2:    highlightPrefix + "<big>" + qsTr("Please unplug your Pixhawk and/or Radio from USB.") + "</big>" + highlightSuffix

            readonly property int _defaultFimwareTypePX4:   12
            readonly property int _defaultFimwareTypeAPM:   3

            property var    _firmwareUpgradeSettings:   QGroundControl.settingsManager.firmwareUpgradeSettings
            property var    _defaultFirmwareFact:       _firmwareUpgradeSettings.defaultFirmwareType
            property bool   _defaultFirmwareIsPX4:      true

            property string firmwareWarningMessage
            property bool   firmwareWarningMessageVisible:  false
            property bool   initialBoardSearch:             true
            property string firmwareName

            property bool _singleFirmwareMode:          QGroundControl.corePlugin.options.firmwareUpgradeSingleURL.length != 0   ///< true: running in special single firmware download mode

            function setupPageCompleted() {
                controller.startBoardSearch()
                _defaultFirmwareIsPX4 = _defaultFirmwareFact.rawValue === _defaultFimwareTypePX4 // we don't want this to be bound and change as radios are selected
            }

            QGCFileDialog {
                id:                 customFirmwareDialog
                title:              qsTr("Select Firmware File")
                nameFilters:        [qsTr("Firmware Files (*.px4 *.apj *.bin *.ihx)"), qsTr("All Files (*)")]
                folder:             QGroundControl.settingsManager.appSettings.logSavePath
                onAcceptedForLoad: (file) => {
                    controller.flashFirmwareUrl(file)
                    close()
                }
            }

            FirmwareUpgradeController {
                id:             controller
                progressBar:    progressBar
                statusLog:      statusTextArea

                property var activeVehicle: QGroundControl.multiVehicleManager.activeVehicle

                onActiveVehicleChanged: {
                    if (!globals.activeVehicle) {
                        statusTextArea.append(plugInText)
                    }
                }

                onNoBoardFound: {
                    initialBoardSearch = false
                    if (!QGroundControl.multiVehicleManager.activeVehicleAvailable) {
                        statusTextArea.append(plugInText)
                    }
                }

                onBoardGone: {
                    initialBoardSearch = false
                    if (!QGroundControl.multiVehicleManager.activeVehicleAvailable) {
                        statusTextArea.append(plugInText)
                    }
                }

                onBoardFound: {
                    if (initialBoardSearch) {
                        // Board was found right away, so something is already plugged in before we've started upgrade
                        statusTextArea.append(qgcUnplugText1)
                        statusTextArea.append(qgcUnplugText2)

                        var availableDevices = controller.availableBoardsName()
                        if (availableDevices.length > 1) {
                            statusTextArea.append(highlightPrefix + qsTr("Multiple devices detected! Remove all detected devices to perform the firmware upgrade."))
                            statusTextArea.append(qsTr("Detected [%1]: ").arg(availableDevices.length) + availableDevices.join(", "))
                        }
                        if (QGroundControl.multiVehicleManager.activeVehicle) {
                            QGroundControl.multiVehicleManager.activeVehicle.vehicleLinkManager.autoDisconnect = true
                        }
                    } else {
                        // We end up here when we detect a board plugged in after we've started upgrade
                        statusTextArea.append(accentPrefix + qsTr("Found device") + accentSuffix + ": " + controller.boardType)
                    }
                }

                onShowFirmwareSelectDlg:    firmwareSelectDialogComponent.createObject(mainWindow).open()
                onError:                    statusTextArea.append(flashFailText)
            }

            Component {
                id: firmwareSelectDialogComponent

                QGCPopupDialog {
                    id:         firmwareSelectDialog
                    title:      qsTr("Firmware Setup")
                    buttons:    Dialog.Ok | Dialog.Cancel

                    property bool showFirmwareTypeSelection:    _advanced.checked

                    function firmwareVersionChanged(model) {
                        firmwareWarningMessageVisible = false
                        // All of this bizarre, setting model to null and index to 1 and then to 0 is to work around
                        // strangeness in the combo box implementation. This sequence of steps correctly changes the combo model
                        // without generating any warnings and correctly updates the combo text with the new selection.
                        firmwareBuildTypeCombo.model = null
                        firmwareBuildTypeCombo.model = model
                        firmwareBuildTypeCombo.currentIndex = 1
                        firmwareBuildTypeCombo.currentIndex = 0
                    }

                    function updatePX4VersionDisplay() {
                        var versionString = ""
                        if (_advanced.checked) {
                            switch (controller.selectedFirmwareBuildType) {
                            case FirmwareUpgradeController.StableFirmware:
                                versionString = controller.px4StableVersion
                                break
                            case FirmwareUpgradeController.BetaFirmware:
                                versionString = controller.px4BetaVersion
                                break
                            }
                        } else {
                            versionString = controller.px4StableVersion
                        }
                        px4FlightStackRadio.text = qsTr("PX4 Pro ") + versionString
                        //px4FlightStackRadio2.text = qsTr("PX4 Pro ") + versionString
                    }

                    Component.onCompleted: {
                        firmwarePage.advanced = false
                        firmwarePage.showAdvanced = false
                        updatePX4VersionDisplay()
                    }

                    Connections {
                        target:     controller
                        onError:    reject()
                    }

                    onAccepted: {
                        if (_singleFirmwareMode) {
                            controller.flashSingleFirmwareMode(controller.selectedFirmwareBuildType)
                        } else {
                            var firmwareBuildType = firmwareBuildTypeCombo.model.get(firmwareBuildTypeCombo.currentIndex).firmwareType
                            var vehicleType = FirmwareUpgradeController.DefaultVehicleFirmware

                            var stack = apmFlightStack.checked ? FirmwareUpgradeController.AutoPilotStackAPM : FirmwareUpgradeController.AutoPilotStackPX4
                            if (apmFlightStack.checked) {
                                if (firmwareBuildType === FirmwareUpgradeController.CustomFirmware) {
                                    vehicleType = apmVehicleTypeCombo.currentIndex
                                } else {
                                    if (controller.apmFirmwareNames.length === 0) {
                                        // Not ready yet, or no firmware available
                                        mainWindow.showMessageDialog(firmwareSelectDialog.title, qsTr("Either firmware list is still downloading, or no firmware is available for current selection."))
                                        firmwareSelectDialog.preventClose = true
                                        return
                                    }
                                    if (ardupilotFirmwareSelectionCombo.currentIndex == -1) {
                                        mainWindow.showMessageDialog(firmwareSelectDialog.title, qsTr("You must choose a board type."))
                                        firmwareSelectDialog.preventClose = true
                                        return
                                    }

                                    var firmwareUrl = controller.apmFirmwareUrls[ardupilotFirmwareSelectionCombo.currentIndex]
                                    if (firmwareUrl == "") {
                                        mainWindow.showMessageDialog(firmwareSelectDialog.title, qsTr("No firmware was found for the current selection."))
                                        firmwareSelectDialog.preventClose = true
                                        return
                                    }
                                    controller.flashFirmwareUrl(controller.apmFirmwareUrls[ardupilotFirmwareSelectionCombo.currentIndex])
                                    return
                                }
                            }
                            //-- If custom, get file path
                            if (firmwareBuildType === FirmwareUpgradeController.CustomFirmware) {
                                customFirmwareDialog.openForLoad()
                            } else {
                                controller.flash(stack, firmwareBuildType, vehicleType)
                            }
                        }
                    }

                    function reject() {
                        statusTextArea.append(highlightPrefix + qsTr("Upgrade cancelled") + highlightSuffix)
                        statusTextArea.append("------------------------------------------")
                        controller.cancel()
                        close()
                    }

                    ListModel {
                        id: firmwareBuildTypeList

                        ListElement {
                            text:           qsTr("Standard Version (stable)")
                            firmwareType:   FirmwareUpgradeController.StableFirmware
                        }
                        ListElement {
                            text:           qsTr("Beta Testing (beta)")
                            firmwareType:   FirmwareUpgradeController.BetaFirmware
                        }
                        ListElement {
                            text:           qsTr("Developer Build (master)")
                            firmwareType:   FirmwareUpgradeController.DeveloperFirmware
                        }
                        ListElement {
                            text:           qsTr("Custom firmware file...")
                            firmwareType:   FirmwareUpgradeController.CustomFirmware
                        }
                    }

                    ListModel {
                        id: singleFirmwareModeTypeList

                        ListElement {
                            text:           qsTr("Standard Version")
                            firmwareType:   FirmwareUpgradeController.StableFirmware
                        }
                        ListElement {
                            text:           qsTr("Custom firmware file...")
                            firmwareType:   FirmwareUpgradeController.CustomFirmware
                        }
                    }

                    ColumnLayout {
                        width:      Math.max(ScreenTools.defaultFontPixelWidth * 40, firmwareRadiosColumn.width)
                        spacing:    globals.defaultTextHeight / 2

                        QGCLabel {
                            Layout.fillWidth:   true
                            wrapMode:           Text.WordWrap
                            text:               (_singleFirmwareMode || !QGroundControl.apmFirmwareSupported) ? _singleFirmwareLabel : _pixhawkLabel

                            readonly property string _pixhawkLabel:          qsTr("Detected Pixhawk board. You can select from the following flight stacks:")
                            readonly property string _singleFirmwareLabel:   qsTr("Press Ok to upgrade your vehicle.")
                        }

                        Column {
                            id:         firmwareRadiosColumn
                            spacing:    0

                            visible: !_singleFirmwareMode && QGroundControl.apmFirmwareSupported

                            Component.onCompleted: {
                                if(!QGroundControl.apmFirmwareSupported) {
                                    _defaultFirmwareFact.rawValue = _defaultFimwareTypePX4
                                    firmwareVersionChanged(firmwareBuildTypeList)
                                }
                            }

                            QGCRadioButton {
                                id:             px4FlightStackRadio
                                text:           qsTr("PX4 Pro ")
                                font.bold:      _defaultFirmwareIsPX4
                                checked:        _defaultFirmwareIsPX4

                                onClicked: {
                                    _defaultFirmwareFact.rawValue = _defaultFimwareTypePX4
                                    firmwareVersionChanged(firmwareBuildTypeList)
                                }
                            }

                            QGCRadioButton {
                                id:             apmFlightStack
                                text:           qsTr("ArduPilot")
                                font.bold:      !_defaultFirmwareIsPX4
                                checked:        !_defaultFirmwareIsPX4

                                onClicked: {
                                    _defaultFirmwareFact.rawValue = _defaultFimwareTypeAPM
                                    firmwareVersionChanged(firmwareBuildTypeList)
                                }
                            }
                        }

                        FactComboBox {
                            Layout.fillWidth:   true
                            visible:            apmFlightStack.checked
                            fact:               _firmwareUpgradeSettings.apmChibiOS
                            indexModel:         false
                        }

                        FactComboBox {
                            id:                 apmVehicleTypeCombo
                            Layout.fillWidth:   true
                            visible:            apmFlightStack.checked
                            fact:               _firmwareUpgradeSettings.apmVehicleType
                            indexModel:         false
                        }

                        QGCComboBox {
                            id:                 ardupilotFirmwareSelectionCombo
                            Layout.fillWidth:   true
                            visible:            apmFlightStack.checked && !controller.downloadingFirmwareList && controller.apmFirmwareNames.length !== 0
                            model:              controller.apmFirmwareNames
                            onModelChanged:     currentIndex = controller.apmFirmwareNamesBestIndex
                        }

                        QGCLabel {
                            Layout.fillWidth:   true
                            wrapMode:           Text.WordWrap
                            text:               qsTr("Downloading list of available firmwares...")
                            visible:            controller.downloadingFirmwareList
                        }

                        QGCLabel {
                            Layout.fillWidth:   true
                            wrapMode:           Text.WordWrap
                            text:               qsTr("No Firmware Available")
                            visible:            !controller.downloadingFirmwareList && (QGroundControl.apmFirmwareSupported && controller.apmFirmwareNames.length === 0)
                        }

                        QGCCheckBox {
                            id:         _advanced
                            text:       qsTr("Advanced settings")
                            checked:    false

                            onClicked: {
                                firmwareBuildTypeCombo.currentIndex = 0
                                firmwareWarningMessageVisible = false
                                updatePX4VersionDisplay()
                            }
                        }

                        QGCLabel {
                            Layout.fillWidth:   true
                            wrapMode:           Text.WordWrap
                            visible:            showFirmwareTypeSelection
                            text:               _singleFirmwareMode ?  qsTr("Select the standard version or one from the file system (previously downloaded):") :
                                                                      qsTr("Select which version of the above flight stack you would like to install:")
                        }

                        QGCComboBox {
                            id:                 firmwareBuildTypeCombo
                            Layout.fillWidth:   true
                            visible:            showFirmwareTypeSelection
                            textRole:           "text"
                            model:              _singleFirmwareMode ? singleFirmwareModeTypeList : firmwareBuildTypeList

                            onActivated: (index) => {
                                controller.selectedFirmwareBuildType = model.get(index).firmwareType
                                if (model.get(index).firmwareType === FirmwareUpgradeController.BetaFirmware) {
                                    firmwareWarningMessageVisible = true
                                    firmwareVersionWarningLabel.text = qsTr("WARNING: BETA FIRMWARE. ") +
                                            qsTr("This firmware version is ONLY intended for beta testers. ") +
                                            qsTr("Although it has received FLIGHT TESTING, it represents actively changed code. ") +
                                            qsTr("Do NOT use for normal operation.")
                                } else if (model.get(index).firmwareType === FirmwareUpgradeController.DeveloperFirmware) {
                                    firmwareWarningMessageVisible = true
                                    firmwareVersionWarningLabel.text = qsTr("WARNING: CONTINUOUS BUILD FIRMWARE. ") +
                                            qsTr("This firmware has NOT BEEN FLIGHT TESTED. ") +
                                            qsTr("It is only intended for DEVELOPERS. ") +
                                            qsTr("Run bench tests without props first. ") +
                                            qsTr("Do NOT fly this without additional safety precautions. ") +
                                            qsTr("Follow the forums actively when using it.")
                                } else {
                                    firmwareWarningMessageVisible = false
                                }
                                updatePX4VersionDisplay()
                            }
                        }

                        QGCLabel {
                            id:                 firmwareVersionWarningLabel
                            Layout.fillWidth:   true
                            wrapMode:           Text.WordWrap
                            visible:            firmwareWarningMessageVisible
                        }
                    } // ColumnLayout
                } // QGCPopupDialog
            } // Component - firmwareSelectDialogComponent

            ProgressBar {
                id:                     progressBar
                Layout.fillWidth:       true
                Layout.preferredHeight: visible ? Math.max(6, ScreenTools.defaultFontPixelHeight * 0.35) : 0
                visible:                !flashBootloaderButton.visible && value > 0 && value < 1

                background: Rectangle {
                    implicitHeight: ScreenTools.defaultFontPixelHeight * 0.35
                    radius:         height / 2
                    color:          firmwarePage._dividerColor
                }

                contentItem: Item {
                    implicitHeight: ScreenTools.defaultFontPixelHeight * 0.35

                    Rectangle {
                        width:  progressBar.visualPosition * parent.width
                        height: parent.height
                        radius: height / 2
                        color:  firmwarePage._accentGreen

                        Behavior on width {
                            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }

            QGCButton {
                id:               flashBootloaderButton
                Layout.alignment: Qt.AlignLeft
                text:             qsTr("Flash ChibiOS Bootloader")
                primary:          true
                visible:          firmwarePage.advanced
                onClicked:        globals.activeVehicle.flashBootloader()
            }

            Rectangle {
                Layout.fillWidth:       true
                Layout.fillHeight:      true
                Layout.minimumHeight:   ScreenTools.defaultFontPixelHeight * 12
                radius:                 firmwarePage._cardRadius
                color:                  firmwarePage._cardFill
                border.width:           1
                border.color:           firmwarePage._dividerColor
                clip:                   true

                ColumnLayout {
                    anchors.fill:    parent
                    anchors.margins: firmwarePage._controlSpacing * 1.25
                    spacing:         firmwarePage._controlSpacing

                    RowLayout {
                        Layout.fillWidth: true
                        spacing:          firmwarePage._controlSpacing

                        Rectangle {
                            Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 0.7
                            Layout.preferredHeight: Layout.preferredWidth
                            radius:                 width / 2
                            color:                  firmwarePage._accentGreen
                        }

                        QGCLabel {
                            Layout.fillWidth: true
                            text:             qsTr("Firmware upgrade status")
                            color:            firmwarePage._titleColor
                            font.family:      ScreenTools.normalFontFamily
                            font.weight:      Font.DemiBold
                        }

                        QGCLabel {
                            Layout.preferredWidth: Math.min(ScreenTools.defaultFontPixelWidth * 14,
                                                            firmwarePage.width * 0.30)
                            Layout.maximumWidth:   Layout.preferredWidth
                            text:                  qsTr("USB connection")
                            color:                 firmwarePage._accentGreen
                            font.family:           ScreenTools.normalFontFamily
                            font.weight:           Font.DemiBold
                            elide:                 Text.ElideRight
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height:           1
                        color:            firmwarePage._dividerColor
                    }

                    ScrollView {
                        id:                 statusScrollView
                        Layout.fillWidth:   true
                        Layout.fillHeight:  true
                        clip:               true
                        leftPadding:        1
                        rightPadding:       1
                        topPadding:         1
                        bottomPadding:      1

                        background: Rectangle {
                            radius:       firmwarePage._cardRadius * 0.65
                            color:        firmwarePage._innerCardFill
                            border.width: 1
                            border.color: firmwarePage._dividerColor
                        }

                        TextArea {
                            id:                  statusTextArea
                            width:               statusScrollView.availableWidth
                            readOnly:            true
                            selectByMouse:       true
                            persistentSelection: true
                            wrapMode:            TextEdit.Wrap
                            font.family:         ScreenTools.normalFontFamily
                            font.pointSize:      ScreenTools.defaultFontPointSize
                            textFormat:          TextEdit.RichText
                            text:                _singleFirmwareMode ? welcomeTextSingle : welcomeText
                            color:               firmwarePage._titleColor
                            leftPadding:         firmwarePage._controlSpacing
                            rightPadding:        firmwarePage._controlSpacing * 1.5
                            topPadding:          firmwarePage._controlSpacing
                            bottomPadding:       firmwarePage._controlSpacing

                            background: Item {}
                        }

                        ScrollBar.vertical: ScrollBar {
                            policy:        statusTextArea.contentHeight > statusScrollView.availableHeight
                                           ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                            width:         Math.max(7, ScreenTools.defaultFontPixelWidth * 0.7)
                            topPadding:    firmwarePage._controlSpacing * 0.65
                            bottomPadding: topPadding
                            leftPadding:   2
                            rightPadding:  2

                            background: Rectangle {
                                radius: parent.width / 2
                                color:  firmwarePage._cardFill
                            }

                            contentItem: Rectangle {
                                radius: width / 2
                                color:  firmwarePage._accentGreen
                            }
                        }
                    }
                }
            }
        } // ColumnLayout
    } // Component
} // SetupPage
