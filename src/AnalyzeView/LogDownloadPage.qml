import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

AnalyzePage {
    id: logDownloadPage

    headerComponent:  logHeaderComponent
    pageComponent:    pageComponent
    contentTopMargin: _headerSpacing
    allowPopout:      false

    readonly property bool _darkTheme: {
        if (typeof mainWindow !== "undefined" && mainWindow)
            return mainWindow.uiThemeMode === mainWindow.themeBlack
        return logPalette.globalTheme === QGCPalette.Dark
    }
    readonly property color _pageBackground:   _darkTheme ? logPalette.window : "#FFFFFF"
    readonly property color _titleColor:       _darkTheme ? "#AEAEB2" : "#3A3A3C"
    readonly property color _bodyColor:        _darkTheme ? "#8E8E93" : "#5A5A5E"
    readonly property color _accentGreen:      "#00a04c"
    readonly property color _cardIdleFill:     _darkTheme ? logPalette.window : "#FFFFFF"
    readonly property color _cardSelectedFill: Qt.rgba(0, 160 / 255, 76 / 255, _darkTheme ? 0.16 : 0.08)
    readonly property color _dataCardFill:     _darkTheme ? logPalette.windowShade : "#F5F5F5"
    readonly property color _tableLine:        _darkTheme ? logPalette.windowShade : "#E5E5E5"
    readonly property real  _pagePad:          ScreenTools.defaultFontPixelWidth * 2.2
    readonly property real  _controlSpacing:   ScreenTools.defaultFontPixelWidth
    readonly property real  _headerSpacing:    Math.ceil(ScreenTools.defaultFontPixelHeight * 0.65)
    readonly property real  _cardRadius:       ScreenTools.defaultFontPixelWidth * 0.9
    readonly property real  _dataRowHeight:    ScreenTools.defaultFontPixelHeight * 2.45
    readonly property real  _tableHeaderHeight: ScreenTools.implicitButtonHeight * 0.85
    readonly property int   _selectedLogCount: selectedLogCount()

    property int _selectionRevision: 0

    QGCPalette {
        id:                logPalette
        colorGroupEnabled: logDownloadPage.enabled
    }

    function refreshLogs() {
        const vehicle = QGroundControl.multiVehicleManager.activeVehicle
        if (!vehicle || vehicle.isOfflineEditingVehicle) {
            mainWindow.showMessageDialog(qsTr("Log Refresh"),
                                         qsTr("You must be connected to a vehicle in order to download logs."))
            return
        }
        LogDownloadController.refresh()
    }

    function downloadSelectedLogs() {
        let logsSelected = false
        for (let logIndex = 0; logIndex < LogDownloadController.model.count; logIndex++) {
            if (LogDownloadController.model.get(logIndex).selected) {
                logsSelected = true
                break
            }
        }

        if (!logsSelected) {
            mainWindow.showMessageDialog(qsTr("Log Download"),
                                         qsTr("You must select at least one log file to download."))
            return
        }

        if (ScreenTools.isMobile) {
            LogDownloadController.download()
            return
        }

        fileDialog.title = qsTr("Select save directory")
        fileDialog.folder = QGroundControl.settingsManager.appSettings.logSavePath
        fileDialog.selectFolder = true
        fileDialog.openForLoad()
    }

    function allLogsSelected() {
        return LogDownloadController.model.count > 0
               && _selectedLogCount === LogDownloadController.model.count
    }

    function selectedLogCount() {
        let selectedCount = _selectionRevision * 0
        for (let logIndex = 0; logIndex < LogDownloadController.model.count; logIndex++) {
            if (LogDownloadController.model.get(logIndex).selected)
                selectedCount++
        }
        return selectedCount
    }

    function setAllLogsSelected(selected) {
        for (let logIndex = 0; logIndex < LogDownloadController.model.count; logIndex++)
            LogDownloadController.model.get(logIndex).selected = selected
        _selectionRevision++
    }

    QGCFileDialog {
        id: fileDialog

        onAcceptedForLoad: (file) => {
            LogDownloadController.download(file)
            close()
        }
    }

    component LogActionButton: Button {
        id: actionButton

        property bool primaryAction: false

        hoverEnabled:   !ScreenTools.isMobile
        focusPolicy:    Qt.ClickFocus
        leftPadding:    ScreenTools.defaultFontPixelWidth * 1.5
        rightPadding:   leftPadding
        topPadding:     ScreenTools.defaultFontPixelHeight * 0.32
        bottomPadding:  topPadding
        font.family:    ScreenTools.normalFontFamily
        font.pointSize: ScreenTools.defaultFontPointSize
        implicitWidth:  Math.max(ScreenTools.implicitButtonWidth,
                                 actionButtonLabel.implicitWidth + leftPadding + rightPadding)
        implicitHeight: Math.max(ScreenTools.implicitButtonHeight,
                                 actionButtonLabel.implicitHeight + topPadding + bottomPadding)

        contentItem: QGCLabel {
            id:                  actionButtonLabel
            text:                actionButton.text
            color: {
                if (!actionButton.enabled)
                    return Qt.rgba(logDownloadPage._bodyColor.r,
                                   logDownloadPage._bodyColor.g,
                                   logDownloadPage._bodyColor.b, 0.45)
                return actionButton.primaryAction || actionButton.pressed ? "#FFFFFF" : logDownloadPage._titleColor
            }
            font:                actionButton.font
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment:   Text.AlignVCenter
            elide:               Text.ElideRight
        }

        background: Rectangle {
            implicitWidth:  ScreenTools.implicitButtonWidth
            implicitHeight: ScreenTools.implicitButtonHeight
            radius:         actionButton.height / 2
            border.width:   1
            border.color:   actionButton.enabled ? logDownloadPage._accentGreen : logDownloadPage._tableLine
            color: {
                if (!actionButton.enabled)
                    return logDownloadPage._dataCardFill
                if (actionButton.primaryAction)
                    return actionButton.pressed
                           ? Qt.darker(logDownloadPage._accentGreen, 1.12)
                           : logDownloadPage._accentGreen
                if (actionButton.pressed)
                    return logDownloadPage._accentGreen
                if (actionButton.hovered)
                    return logDownloadPage._cardSelectedFill
                return logDownloadPage._cardIdleFill
            }

            Behavior on color {
                ColorAnimation { duration: 120 }
            }
        }
    }

    component LogTableLabel: QGCLabel {
        property real columnFraction: 0
        property bool tableHeader:    false

        Layout.minimumWidth:   0
        Layout.preferredWidth: parent ? parent.width * columnFraction : 0
        Layout.maximumWidth:   Layout.preferredWidth
        color:                 logDownloadPage._titleColor
        font.weight:           tableHeader ? Font.DemiBold : Font.Normal
        verticalAlignment:     Text.AlignVCenter
        elide:                 Text.ElideRight
    }

    Component {
        id: logHeaderComponent

        Item {
            implicitHeight: logHeaderLayout.implicitHeight

            ColumnLayout {
                id:                  logHeaderLayout
                anchors.left:        parent.left
                anchors.right:       parent.right
                anchors.leftMargin:  logDownloadPage._pagePad
                anchors.rightMargin: logDownloadPage._pagePad
                spacing:             logDownloadPage._headerSpacing

                QGCLabel {
                    Layout.fillWidth: true
                    text:             qsTr("Download and manage binary flight logs stored on your vehicle.")
                    color:            logDownloadPage._bodyColor
                    wrapMode:         Text.WordWrap
                }

                Rectangle {
                    Layout.fillWidth: true
                    height:           1
                    color:            logDownloadPage._tableLine
                }
            }
        }
    }

    Component {
        id: pageComponent

        Rectangle {
            width:  logDownloadPage.availableWidth
            height: logDownloadPage.availableHeight
            color:  logDownloadPage._pageBackground

            ColumnLayout {
                anchors.fill:         parent
                anchors.leftMargin:   logDownloadPage._pagePad
                anchors.rightMargin:  logDownloadPage._pagePad
                anchors.bottomMargin: logDownloadPage._pagePad
                spacing:              logDownloadPage._headerSpacing

                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: actionGrid.implicitHeight + logDownloadPage._controlSpacing * 2
                    radius:                 logDownloadPage._cardRadius
                    color:                  logDownloadPage._dataCardFill
                    border.width:           1
                    border.color:           logDownloadPage._tableLine

                    GridLayout {
                        id:              actionGrid
                        anchors.fill:    parent
                        anchors.margins: logDownloadPage._controlSpacing
                        columns:         width >= ScreenTools.defaultFontPixelWidth * 58 ? 4 : 2
                        columnSpacing:   logDownloadPage._controlSpacing
                        rowSpacing:      logDownloadPage._controlSpacing * 0.75

                        LogActionButton {
                            Layout.fillWidth: true
                            text:             qsTr("Refresh")
                            enabled:          !LogDownloadController.requestingList
                                              && !LogDownloadController.downloadingLogs
                            onClicked:        logDownloadPage.refreshLogs()
                        }

                        LogActionButton {
                            Layout.fillWidth: true
                            text:             qsTr("Download")
                            primaryAction:    true
                            enabled:          !LogDownloadController.requestingList
                                              && !LogDownloadController.downloadingLogs
                            onClicked:        logDownloadPage.downloadSelectedLogs()
                        }

                        LogActionButton {
                            Layout.fillWidth: true
                            text:             qsTr("Erase All")
                            enabled:          !LogDownloadController.requestingList
                                              && !LogDownloadController.downloadingLogs
                                              && LogDownloadController.model.count > 0
                            onClicked: mainWindow.showMessageDialog(
                                           qsTr("Delete All Log Files"),
                                           qsTr("All log files will be erased permanently. Is this really what you want?"),
                                           Dialog.Yes | Dialog.No,
                                           function() { LogDownloadController.eraseAll() })
                        }

                        LogActionButton {
                            Layout.fillWidth: true
                            text:             qsTr("Cancel")
                            enabled:          LogDownloadController.requestingList
                                              || LogDownloadController.downloadingLogs
                            onClicked:        LogDownloadController.cancel()
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth:       true
                    Layout.minimumHeight:   logDownloadPage._tableHeaderHeight
                    Layout.preferredHeight: logDownloadPage._tableHeaderHeight
                    Layout.maximumHeight:   logDownloadPage._tableHeaderHeight
                    spacing:                0

                    Item {
                        Layout.minimumWidth:   0
                        Layout.preferredWidth: parent.width * 0.09
                        Layout.maximumWidth:   Layout.preferredWidth
                        Layout.fillHeight:     true

                        QGCCheckBox {
                            anchors.centerIn:      parent
                            enabled:               LogDownloadController.model.count > 0
                            uncheckedBorderColor: logDownloadPage._accentGreen

                            Binding on checkState {
                                value: logDownloadPage.allLogsSelected() ? Qt.Checked : Qt.Unchecked
                            }

                            onClicked: logDownloadPage.setAllLogsSelected(checked)
                        }
                    }

                    LogTableLabel {
                        columnFraction: 0.10
                        tableHeader:    true
                        text:           qsTr("ID")
                        visible:        logDownloadPage._selectedLogCount === 0
                    }

                    LogTableLabel {
                        columnFraction: 0.35
                        tableHeader:    true
                        text:           qsTr("Date")
                        visible:        logDownloadPage._selectedLogCount === 0
                    }

                    LogTableLabel {
                        columnFraction: 0.18
                        tableHeader:    true
                        text:           qsTr("Size")
                        visible:        logDownloadPage._selectedLogCount === 0
                    }

                    LogTableLabel {
                        columnFraction: 0.28
                        tableHeader:    true
                        text:           qsTr("Status")
                        visible:        logDownloadPage._selectedLogCount === 0
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing:          logDownloadPage._controlSpacing
                        visible:          logDownloadPage._selectedLogCount > 0

                        QGCLabel {
                            Layout.fillWidth: true
                            text:             qsTr("%1 selected").arg(logDownloadPage._selectedLogCount)
                            color:            logDownloadPage._accentGreen
                            font.weight:      Font.DemiBold
                            elide:            Text.ElideRight
                        }

                        LogActionButton {
                            Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 12
                            Layout.preferredHeight: ScreenTools.implicitButtonHeight * 0.78
                            text:                   qsTr("Download")
                            primaryAction:          true
                            onClicked:              logDownloadPage.downloadSelectedLogs()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height:           1
                    color:            logDownloadPage._tableLine
                }

                Item {
                    Layout.fillWidth:  true
                    Layout.fillHeight: true

                    QGCFlickable {
                        id:                 logList
                        anchors.fill:       parent
                        contentWidth:       width
                        contentHeight:      logRows.height + logDownloadPage._controlSpacing
                        flickableDirection: Flickable.VerticalFlick
                        clip:               true
                        pixelAligned:       true

                        Column {
                            id:      logRows
                            width:   logList.width
                            spacing: Math.ceil(ScreenTools.defaultFontPixelHeight * 0.3)

                            Repeater {
                                model: LogDownloadController.model

                                Rectangle {
                                    width:        logRows.width
                                    height:       logDownloadPage._dataRowHeight
                                    radius:       logDownloadPage._cardRadius
                                    color:        object.selected
                                                  ? logDownloadPage._cardSelectedFill
                                                  : logDownloadPage._dataCardFill
                                    border.width: 1
                                    border.color: object.selected
                                                  ? logDownloadPage._accentGreen
                                                  : logDownloadPage._tableLine

                                    RowLayout {
                                        anchors.fill: parent
                                        spacing:      0

                                        Item {
                                            Layout.minimumWidth:   0
                                            Layout.preferredWidth: parent.width * 0.09
                                            Layout.maximumWidth:   Layout.preferredWidth
                                            Layout.fillHeight:     true

                                            QGCCheckBox {
                                                anchors.centerIn:      parent
                                                uncheckedBorderColor: logDownloadPage._accentGreen

                                                Binding on checkState {
                                                    value: object.selected ? Qt.Checked : Qt.Unchecked
                                                }

                                                onClicked: {
                                                    object.selected = checked
                                                    logDownloadPage._selectionRevision++
                                                }
                                            }
                                        }

                                        LogTableLabel {
                                            columnFraction: 0.10
                                            text:           object.id
                                        }

                                        LogTableLabel {
                                            columnFraction: 0.35
                                            text: {
                                                if (!object.received)
                                                    return ""
                                                if (object.time.getUTCFullYear() < 2010)
                                                    return qsTr("Date Unknown")
                                                return object.time.toLocaleString(undefined)
                                            }
                                        }

                                        LogTableLabel {
                                            columnFraction: 0.18
                                            text:           object.sizeStr
                                        }

                                        LogTableLabel {
                                            columnFraction: 0.28
                                            text:           object.status
                                            color:          object.selected
                                                            ? logDownloadPage._accentGreen
                                                            : logDownloadPage._bodyColor
                                        }
                                    }
                                }
                            }
                        }
                    }

                    QGCLabel {
                        anchors.centerIn:    parent
                        width:               parent.width * 0.85
                        visible:             LogDownloadController.model.count === 0
                        text:                LogDownloadController.requestingList
                                             ? qsTr("Requesting the vehicle log list…")
                                             : qsTr("No logs loaded. Select Refresh to request the vehicle log list.")
                        color:               logDownloadPage._bodyColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment:   Text.AlignVCenter
                        wrapMode:            Text.WordWrap
                    }
                }
            }
        }
    }
}
