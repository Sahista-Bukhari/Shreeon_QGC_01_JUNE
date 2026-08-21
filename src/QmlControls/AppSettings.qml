import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.AppSettings

Rectangle {
    id:     settingsView
    color:  _pageBackground
    z:      QGroundControl.zOrderTopMost

    signal popout()

    QGCPalette { id: qgcPal }

    readonly property bool _darkTheme: {
        if (typeof mainWindow !== "undefined" && mainWindow)
            return mainWindow.uiThemeMode === mainWindow.themeBlack
        return qgcPal.globalTheme === QGCPalette.Dark
    }

    // Default theme colors from Units reference: green selected, light gray inactive, dark labels
    readonly property color _pageBackground:    _darkTheme ? qgcPal.window : "white"
    readonly property color _titleColor:        _darkTheme ? "#AEAEB2" : "#1C1C1E"
    readonly property color _secondaryText:     _darkTheme ? "#8E8E93" : "#8E8E93"
    readonly property color _headingColor:      _darkTheme ? "#AEAEB2" : "#1C1C1E"
    readonly property color _iconColor:         _darkTheme ? "#AEAEB2" : "#1C1C1E"
    readonly property color _dividerColor:      _darkTheme ? qgcPal.windowShade : "#f6f6f6"
    readonly property color _sectionBandColor:  _darkTheme ? qgcPal.windowShadeDark : "#f6f6f6"
    readonly property color _accentGreen:       "#00a04c"
    readonly property color _buttonGray:        "#f5f5f5"
    readonly property color _rowPressed:        _darkTheme ? qgcPal.windowShade : "#F2F2F2"
    readonly property color _cardFill:          _darkTheme ? qgcPal.windowShade : "#F7F7F7"
    readonly property color _cardBorder:        _darkTheme ? qgcPal.windowShade : "#E5E5E5"
    readonly property color _cardHover:         Qt.rgba(0, 160 / 255, 76 / 255, _darkTheme ? 0.16 : 0.08)
    readonly property color _greenTint:         Qt.rgba(0, 160 / 255, 76 / 255, _darkTheme ? 0.14 : 0.09)
    readonly property real  _contentSidePad:    Math.max(ScreenTools.defaultFontPixelWidth * 2.2, width * 0.05)
    readonly property real  _contentMaxWidth:   ScreenTools.defaultFontPixelWidth * 92
    readonly property real  _cardRadius:        ScreenTools.defaultFontPixelWidth * 1.05
    readonly property real  _controlSpacing:    ScreenTools.defaultFontPixelWidth
    readonly property real  _cardSpacing:       ScreenTools.defaultFontPixelHeight * 0.65
    readonly property real  _sectionSpacing:    ScreenTools.defaultFontPixelHeight * 1.25
    // Header back/close sit near the window edges, not in the content gutter
    readonly property real  _headerIconPad:     ScreenTools.defaultFontPixelWidth * 1.2
    readonly property real  _rowHeight:         ScreenTools.defaultFontPixelHeight * 4.2
    readonly property real  _headerHeight:      ScreenTools.toolbarHeight
    readonly property real  _detailHeaderInset: Math.max(_headerIconPad,
                                                          (width - Math.min(_contentMaxWidth,
                                                                            width - _headerIconPad * 2)) / 2)

    property string _selectedSettingsUrl: ""

    function _descriptionForUrl(pageUrl) {
        var source = pageUrl ? pageUrl.toString() : ""
        if (source.indexOf("GeneralSettings") >= 0)
            return qsTr("Language, units, theme, storage, and application behavior")
        if (source.indexOf("FlyViewSettings") >= 0)
            return qsTr("Configure flight controls, instruments, and map behavior")
        if (source.indexOf("PlanViewSettings") >= 0)
            return qsTr("Set mission planning defaults and waypoint options")
        if (source.indexOf("VideoSettings") >= 0)
            return qsTr("Manage video sources, recording, and streaming")
        if (source.indexOf("ADSBServerSettings") >= 0)
            return qsTr("Configure aircraft traffic server connectivity")
        if (source.indexOf("LinkSettings") >= 0)
            return qsTr("Create and manage vehicle communication links")
        if (source.indexOf("AppLogging") >= 0)
            return qsTr("Control application logging and diagnostic files")
        if (source.indexOf("MapSettings") >= 0)
            return qsTr("Choose map providers, cache, and offline map data")
        if (source.indexOf("NTRIPSettings") >= 0)
            return qsTr("Set up RTK correction data and NTRIP access")
        if (source.indexOf("PX4LogTransferSettings") >= 0)
            return qsTr("Configure automatic PX4 flight-log transfers")
        if (source.indexOf("RemoteIDSettings") >= 0)
            return qsTr("Review and configure Remote ID settings")
        if (source.indexOf("TelemetrySettings") >= 0)
            return qsTr("Configure telemetry saving and data forwarding")
        if (source.indexOf("HelpSettings") >= 0)
            return qsTr("Open documentation and application information")
        return qsTr("Open configuration options")
    }

    // Keep API used by MainWindow / Remote ID / Comm Links deep-links
    function showSettingsPage(settingsPage) {
        for (var i = 0; i < settingsPagesModel.count; i++) {
            var entry = settingsPagesModel.get(i)
            if (entry.name === "Divider")
                continue
            if (entry.name === settingsPage) {
                _openSettingsUrl(entry.name, entry.url)
                return
            }
        }
        while (settingsStack.depth > 1)
            settingsStack.pop()
    }

    function _closeSettings() {
        settingsView.popout()
        // Return to Mode Selection (same path Settings was opened from)
        if (typeof mainWindow !== "undefined" && mainWindow)
            mainWindow.showModeSelection(Qt.point(mainWindow.width / 2, ScreenTools.toolbarHeight / 2))
    }

    function _goBack() {
        if (settingsStack.depth > 1)
            settingsStack.pop()
    }

    function _openSettingsUrl(pageName, pageUrl) {
        if (!mainWindow.allowViewSwitch())
            return
        _selectedSettingsUrl = pageUrl ? pageUrl.toString() : ""
        settingsStack.push(detailPageComponent, {
                               pageTitle: pageName,
                               pageSource: pageUrl
                           })
    }

    DeadMouseArea {
        anchors.fill: parent
    }

    SettingsPagesModel { id: settingsPagesModel }

    Component.onCompleted: {
        if (globals.commingFromRIDIndicator) {
            globals.commingFromRIDIndicator = false
            showSettingsPage(qsTr("Remote ID"))
        }
    }

    component SettingsNavRow: Item {
        id: rowRoot

        property string label
        property string description
        property string iconSource: ""
        property bool   showChevron: true
        property bool   selected: false

        signal clicked()

        width:  parent ? parent.width : 0
        height: settingsView._rowHeight

        Rectangle {
            anchors.fill: parent
            radius:       settingsView._cardRadius
            color: {
                if (rowMouse.pressed)
                    return settingsView._greenTint
                if (rowRoot.selected || rowMouse.containsMouse)
                    return settingsView._cardHover
                return settingsView._cardFill
            }
            border.width: 1
            border.color: rowRoot.selected || rowMouse.containsMouse
                          ? settingsView._accentGreen
                          : settingsView._cardBorder

            Behavior on color { ColorAnimation { duration: 130 } }
            Behavior on border.color { ColorAnimation { duration: 130 } }
        }

        RowLayout {
            anchors.fill:           parent
            anchors.leftMargin:     ScreenTools.defaultFontPixelWidth * 1.6
            anchors.rightMargin:    ScreenTools.defaultFontPixelWidth * 1.4
            spacing:                ScreenTools.defaultFontPixelWidth * 1.25

            Item {
                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 2.35
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.35
                Layout.alignment:       Qt.AlignVCenter
                visible:                rowRoot.iconSource !== ""

                Rectangle {
                    anchors.fill: parent
                    radius:       width / 2
                    color:        Qt.rgba(0, 160 / 255, 76 / 255, 0.12)
                }

                QGCColoredImage {
                    anchors.centerIn:   parent
                    width:              parent.width * 0.52
                    height:             width
                    source:             rowRoot.iconSource
                    color:              settingsView._accentGreen
                    fillMode:           Image.PreserveAspectFit
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing:          ScreenTools.defaultFontPixelHeight * 0.12

                QGCLabel {
                    Layout.fillWidth: true
                    text:             rowRoot.label
                    color:            rowRoot.selected
                                      ? settingsView._accentGreen
                                      : settingsView._titleColor
                    font.pointSize:   ScreenTools.defaultFontPointSize
                    font.weight:      Font.DemiBold
                    elide:            Text.ElideRight
                }

                QGCLabel {
                    Layout.fillWidth: true
                    text:             rowRoot.description
                    color:            settingsView._secondaryText
                    font.pointSize:   ScreenTools.smallFontPointSize
                    elide:            Text.ElideRight
                }
            }

            Rectangle {
                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.65
                Layout.preferredHeight: Layout.preferredWidth
                Layout.alignment:   Qt.AlignVCenter
                visible:                rowRoot.showChevron
                radius:                 width / 2
                color:                  settingsView._pageBackground
                border.width:           1
                border.color:           rowRoot.selected || rowMouse.containsMouse
                                        ? settingsView._accentGreen
                                        : settingsView._cardBorder

                QGCLabel {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -1
                    text:             "›"
                    color:            rowRoot.selected || rowMouse.containsMouse
                                      ? settingsView._accentGreen
                                      : settingsView._secondaryText
                    font.pointSize:   ScreenTools.largeFontPointSize
                    font.weight:      Font.Normal
                }
            }
        }

        MouseArea {
            id:             rowMouse
            anchors.fill:   parent
            hoverEnabled:   !ScreenTools.isMobile
            cursorShape:    Qt.PointingHandCursor
            onClicked:      rowRoot.clicked()
        }
    }

    StackView {
        id:             settingsStack
        anchors.fill:   parent
        initialItem:    hubPage
        clip:           true
    }

    Component {
        id: hubPage

        Item {
            Rectangle {
                id:             hubHeader
                anchors.left:   parent.left
                anchors.right:  parent.right
                anchors.top:    parent.top
                height:         settingsView._headerHeight
                color:          settingsView._pageBackground

                QGCLabel {
                    anchors.centerIn:   parent
                    text:               qsTr("Application Settings")
                    color:              settingsView._headingColor
                    font.pointSize:     ScreenTools.largeFontPointSize
                    font.weight:        Font.DemiBold
                }

                Item {
                    anchors.right:          parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin:    settingsView._headerIconPad
                    height:                 ScreenTools.defaultFontPixelHeight * 2.2
                    width:                  height

                    QGCColoredImage {
                        anchors.centerIn:   parent
                        width:              parent.height * 0.4
                        height:             width
                        source:             "/res/XDeleteBlack.svg"
                        color:              settingsView._iconColor
                        opacity:            closeMouse.containsMouse ? 1.0 : 0.85
                    }

                    MouseArea {
                        id:             closeMouse
                        anchors.fill:   parent
                        hoverEnabled:   true
                        cursorShape:    Qt.PointingHandCursor
                        onClicked:      settingsView._closeSettings()
                    }
                }

                Rectangle {
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    anchors.bottom: parent.bottom
                    height:         1
                    color:          settingsView._dividerColor
                }
            }

            QGCFlickable {
                id:                 hubFlickable
                anchors.left:       parent.left
                anchors.right:      parent.right
                anchors.top:        hubHeader.bottom
                anchors.bottom:     parent.bottom
                contentWidth:       width
                contentHeight:      hubContent.implicitHeight + ScreenTools.defaultFontPixelHeight * 3
                clip:               true
                flickableDirection: Flickable.VerticalFlick

                ScrollBar.vertical: ScrollBar {
                    policy:        hubFlickable.contentHeight > hubFlickable.height
                                   ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                    width:         Math.max(7, ScreenTools.defaultFontPixelWidth * 0.7)
                    topPadding:    settingsView._cardSpacing
                    bottomPadding: topPadding
                    leftPadding:   2
                    rightPadding:  2

                    background: Rectangle {
                        radius: parent.width / 2
                        color:  settingsView._cardFill
                    }

                    contentItem: Rectangle {
                        radius: width / 2
                        color:  settingsView._accentGreen
                    }
                }

                Column {
                    id:    hubContent
                    x:     Math.round((hubFlickable.width - width) / 2)
                    y:     ScreenTools.defaultFontPixelHeight * 1.35
                    width: Math.max(0, Math.min(settingsView._contentMaxWidth,
                                                hubFlickable.width - settingsView._contentSidePad * 2))

                    Repeater {
                        model: settingsPagesModel

                        delegate: Item {
                            width:  hubContent.width
                            height: visible
                                    ? (isDivider
                                       ? settingsView._sectionSpacing
                                       : settingsView._rowHeight + settingsView._cardSpacing)
                                    : 0
                            visible: isDivider ? true : pageVisible()

                            readonly property bool isDivider: name === "Divider"

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left:           parent.left
                                anchors.right:          parent.right
                                height:                 1
                                color:                  settingsView._cardBorder
                                visible:                parent.isDivider

                                Rectangle {
                                    anchors.centerIn: parent
                                    width:            ScreenTools.defaultFontPixelWidth * 5
                                    height:           2
                                    radius:           height / 2
                                    color:            settingsView._accentGreen
                                }
                            }

                            SettingsNavRow {
                                anchors.left:  parent.left
                                anchors.right: parent.right
                                anchors.top:   parent.top
                                visible:       !parent.isDivider
                                label:         name
                                description:   settingsView._descriptionForUrl(url)
                                iconSource:    iconUrl
                                selected:      settingsView._selectedSettingsUrl === url.toString()
                                onClicked:     settingsView._openSettingsUrl(name, url)
                            }
                        }
                    }

                    Item {
                        width:  parent.width
                        height: settingsView._cardSpacing * 0.5
                    }

                    Rectangle {
                        width:  parent.width
                        height: Math.max(ScreenTools.defaultFontPixelHeight * 4.6,
                                         resetLayout.implicitHeight + settingsView._controlSpacing * 2)
                        radius: settingsView._cardRadius
                        color:  settingsView._cardFill
                        border.width: 1
                        border.color: settingsView._cardBorder

                        RowLayout {
                            id:              resetLayout
                            anchors.fill:    parent
                            anchors.margins: settingsView._controlSpacing * 1.25
                            spacing:         settingsView._controlSpacing * 1.2

                            Rectangle {
                                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 2.35
                                Layout.preferredHeight: Layout.preferredWidth
                                Layout.alignment:       Qt.AlignVCenter
                                radius:                 width / 2
                                color:                  settingsView._greenTint

                                QGCColoredImage {
                                    anchors.centerIn: parent
                                    width:            parent.width * 0.5
                                    height:           width
                                    source:           "/qmlimages/Gears.svg"
                                    color:            settingsView._accentGreen
                                    fillMode:         Image.PreserveAspectFit
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing:          ScreenTools.defaultFontPixelHeight * 0.12

                                QGCLabel {
                                    Layout.fillWidth: true
                                    text:             qsTr("Reset application settings")
                                    color:            settingsView._titleColor
                                    font.weight:      Font.DemiBold
                                    elide:            Text.ElideRight
                                }

                                QGCLabel {
                                    Layout.fillWidth: true
                                    text:             qsTr("Clear saved preferences the next time the application starts")
                                    color:            settingsView._secondaryText
                                    font.pointSize:   ScreenTools.smallFontPointSize
                                    elide:            Text.ElideRight
                                }
                            }

                            Item {
                                id:                     resetToggle
                                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 4.4
                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.35
                                Layout.alignment:       Qt.AlignVCenter

                                property bool checked: false

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.verticalCenter:   parent.verticalCenter
                                    anchors.verticalCenterOffset: 2
                                    width:                    parent.width
                                    height:                   parent.height
                                    radius:                   height / 2
                                    color:                    "#D1D1D6"
                                    opacity:                  0.48
                                    z:                        -1
                                }

                                Rectangle {
                                    id:           track
                                    anchors.fill: parent
                                    radius:       height / 2
                                    color:        resetToggle.checked
                                                  ? settingsView._accentGreen
                                                  : (settingsView._darkTheme ? "#3A3A3C" : settingsView._buttonGray)
                                    border.width: 1
                                    border.color: resetToggle.checked
                                                  ? settingsView._accentGreen
                                                  : settingsView._cardBorder

                                    Behavior on color { ColorAnimation { duration: 180 } }

                                    Rectangle {
                                        id:                     knob
                                        anchors.verticalCenter: parent.verticalCenter
                                        x:                      resetToggle.checked
                                                                ? parent.width - width - 3
                                                                : 3
                                        width:                  parent.height - 6
                                        height:                 width
                                        radius:                 width / 2
                                        color:                  "#FFFFFF"
                                        border.width:           0.5
                                        border.color:           "#E5E5EA"

                                        Behavior on x {
                                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape:  Qt.PointingHandCursor
                                    onClicked: {
                                        if (!resetToggle.checked) {
                                            mainWindow.showMessageDialog(
                                                qsTr("Reset Settings"),
                                                qsTr("Clear all application settings on next start? This cannot be undone."),
                                                Dialog.Cancel | Dialog.Reset,
                                                function() {
                                                    resetToggle.checked = true
                                                    QGroundControl.deleteAllSettingsNextBoot()
                                                })
                                        } else {
                                            resetToggle.checked = false
                                            QGroundControl.clearDeleteAllSettingsNextBoot()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        width:  parent.width
                        height: ScreenTools.defaultFontPixelHeight * 1.5
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
            property url    pageSource

            Rectangle {
                anchors.fill: parent
                color:        settingsView._pageBackground
            }

            Rectangle {
                id:             detailHeader
                anchors.left:   parent.left
                anchors.right:  parent.right
                anchors.top:    parent.top
                height:         settingsView._headerHeight
                color:          settingsView._pageBackground

                // Back — far left edge of the header
                Item {
                    id:                     backButton
                    anchors.left:           parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin:     settingsView._detailHeaderInset
                    height:                 ScreenTools.defaultFontPixelHeight * 2.2
                    width:                  height

                    Rectangle {
                        anchors.fill: parent
                        radius:       width / 2
                        color:        detailBackMouse.containsMouse
                                      ? settingsView._cardHover
                                      : settingsView._cardFill
                        border.width: 1
                        border.color: detailBackMouse.containsMouse
                                      ? settingsView._accentGreen
                                      : settingsView._cardBorder

                        Behavior on color { ColorAnimation { duration: 130 } }
                        Behavior on border.color { ColorAnimation { duration: 130 } }
                    }

                    QGCColoredImage {
                        anchors.centerIn:   parent
                        width:              ScreenTools.defaultFontPixelHeight * 0.82
                        height:             width
                        source:             "qrc:/InstrumentValueIcons/arrow-thin-left.svg"
                        color:              detailBackMouse.containsMouse
                                            ? settingsView._accentGreen
                                            : settingsView._secondaryText
                    }

                    MouseArea {
                        id:             detailBackMouse
                        anchors.fill:   parent
                        hoverEnabled:   true
                        cursorShape:    Qt.PointingHandCursor
                        onClicked:      settingsView._goBack()
                    }
                }

                // Title — truly centered on the page (same as reference)
                QGCLabel {
                    anchors.centerIn:       parent
                    width:                  parent.width - (backButton.width + closeButton.width
                                                           + settingsView._headerIconPad * 2
                                                           + ScreenTools.defaultFontPixelWidth * 2)
                    horizontalAlignment:    Text.AlignHCenter
                    elide:                  Text.ElideRight
                    text:                   detailRoot.pageTitle
                    color:                  settingsView._headingColor
                    font.pointSize:         ScreenTools.largeFontPointSize
                    font.weight:            Font.DemiBold
                }

                // Close — far right edge of the header
                Item {
                    id:                     closeButton
                    anchors.right:          parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin:    settingsView._detailHeaderInset
                    height:                 ScreenTools.defaultFontPixelHeight * 2.2
                    width:                  height

                    Rectangle {
                        anchors.fill: parent
                        radius:       width / 2
                        color:        detailCloseMouse.containsMouse
                                      ? settingsView._cardHover
                                      : settingsView._cardFill
                        border.width: 1
                        border.color: detailCloseMouse.containsMouse
                                      ? settingsView._accentGreen
                                      : settingsView._cardBorder

                        Behavior on color { ColorAnimation { duration: 130 } }
                        Behavior on border.color { ColorAnimation { duration: 130 } }
                    }

                    QGCColoredImage {
                        anchors.centerIn:   parent
                        width:              ScreenTools.defaultFontPixelHeight * 0.72
                        height:             width
                        source:             "/res/XDeleteBlack.svg"
                        color:              detailCloseMouse.containsMouse
                                            ? settingsView._accentGreen
                                            : settingsView._secondaryText
                    }

                    MouseArea {
                        id:             detailCloseMouse
                        anchors.fill:   parent
                        hoverEnabled:   true
                        cursorShape:    Qt.PointingHandCursor
                        onClicked:      settingsView._closeSettings()
                    }
                }

                Rectangle {
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    anchors.bottom: parent.bottom
                    height:         1
                    color:          settingsView._dividerColor
                }
            }

            Loader {
                id:                     pageLoader
                anchors.left:           parent.left
                anchors.right:          parent.right
                anchors.top:            detailHeader.bottom
                anchors.bottom:         parent.bottom
                anchors.margins:        ScreenTools.defaultFontPixelWidth
                source:                 detailRoot.pageSource
            }
        }
    }
}
