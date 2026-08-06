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

    readonly property color _pageBackground:    "white"
    readonly property color _titleColor:        "#1C1C1E"
    readonly property color _secondaryText:     "#8E8E93"
    readonly property color _dividerColor:      "#E5E5EA"
    readonly property color _accentGreen:       "#34C759"
    readonly property color _rowPressed:        "#F2F2F7"
    // Wide side gutters like the reference (~12% each side)
    readonly property real  _horizontalPad:     Math.max(ScreenTools.defaultFontPixelWidth * 8, width * 0.12)
    readonly property real  _rowHeight:         ScreenTools.defaultFontPixelHeight * 3.2
    readonly property real  _headerHeight:      ScreenTools.toolbarHeight

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
        settingsStack.push(detailPageComponent, {
                               pageTitle: pageName,
                               pageSource: pageUrl
                           })
    }

    DeadMouseArea {
        anchors.fill: parent
    }

    QGCPalette { id: qgcPal }

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
        property string iconSource: ""
        property bool   showChevron: true

        signal clicked()

        width:  parent ? parent.width : 0
        height: settingsView._rowHeight

        Rectangle {
            anchors.fill: parent
            color:        rowMouse.pressed ? settingsView._rowPressed : "transparent"
        }

        RowLayout {
            anchors.fill:           parent
            anchors.leftMargin:     settingsView._horizontalPad
            anchors.rightMargin:    settingsView._horizontalPad
            spacing:                ScreenTools.defaultFontPixelWidth * 1.5

            QGCColoredImage {
                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.35
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.35
                Layout.alignment:       Qt.AlignVCenter
                source:                 rowRoot.iconSource
                color:                  settingsView._titleColor
                visible:                rowRoot.iconSource !== ""
                fillMode:               Image.PreserveAspectFit
            }

            QGCLabel {
                Layout.fillWidth:   true
                text:               rowRoot.label
                color:              settingsView._titleColor
                font.pointSize:     ScreenTools.defaultFontPointSize
                elide:              Text.ElideRight
            }

            QGCLabel {
                visible:            rowRoot.showChevron
                text:               "›"
                color:              settingsView._secondaryText
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
                    color:              settingsView._titleColor
                    font.pointSize:     ScreenTools.largeFontPointSize
                    font.weight:        Font.DemiBold
                }

                Item {
                    anchors.right:          parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin:    settingsView._horizontalPad
                    height:                 ScreenTools.defaultFontPixelHeight * 2.2
                    width:                  height

                    QGCColoredImage {
                        anchors.centerIn:   parent
                        width:              parent.height * 0.4
                        height:             width
                        source:             "/res/XDeleteBlack.svg"
                        color:              settingsView._secondaryText
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
            }

            QGCFlickable {
                anchors.left:           parent.left
                anchors.right:          parent.right
                anchors.top:            hubHeader.bottom
                anchors.bottom:         resetToggleRow.top
                anchors.bottomMargin:   ScreenTools.defaultFontPixelHeight
                contentWidth:           width
                contentHeight:          hubList.height + ScreenTools.defaultFontPixelHeight * 2
                clip:                   true
                flickableDirection:     Flickable.VerticalFlick

                Column {
                    id:                 hubList
                    width:              parent.width
                    anchors.top:        parent.top
                    anchors.topMargin:  ScreenTools.defaultFontPixelHeight * 1.5

                    Repeater {
                        model: settingsPagesModel

                        delegate: Item {
                            width:  hubList.width
                            height: visible ? (isDivider ? ScreenTools.defaultFontPixelHeight * 2.2 : settingsView._rowHeight) : 0
                            visible: isDivider ? true : pageVisible()

                            readonly property bool isDivider: name === "Divider"

                            // Full-width soft section band (like the reference)
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left:           parent.left
                                anchors.right:          parent.right
                                height:                 ScreenTools.defaultFontPixelHeight * 0.55
                                color:                  "#F2F2F7"
                                visible:                parent.isDivider
                            }

                            SettingsNavRow {
                                anchors.fill:   parent
                                visible:        !parent.isDivider
                                label:          name
                                iconSource:     iconUrl
                                onClicked:      settingsView._openSettingsUrl(name, url)
                            }
                        }
                    }
                }
            }

            // Neumorphic Reset toggle — ON clears all settings on next start
            Row {
                id:                     resetToggleRow
                anchors.right:          parent.right
                anchors.bottom:         parent.bottom
                anchors.rightMargin:    settingsView._horizontalPad
                anchors.bottomMargin:   ScreenTools.defaultFontPixelHeight * 1.5
                spacing:                ScreenTools.defaultFontPixelWidth * 1.5

                QGCLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text:                   qsTr("Reset")
                    color:                  settingsView._titleColor
                    font.pointSize:         ScreenTools.defaultFontPointSize
                    font.weight:            Font.Medium
                }

                Item {
                    id:                     resetToggle
                    anchors.verticalCenter: parent.verticalCenter
                    width:                  ScreenTools.defaultFontPixelHeight * 4.4
                    height:                 ScreenTools.defaultFontPixelHeight * 2.35

                    property bool checked: false

                    // Soft outer shadow (neumorphic)
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter:   parent.verticalCenter
                        anchors.verticalCenterOffset: 2
                        width:              parent.width
                        height:             parent.height
                        radius:             height / 2
                        color:              "#D1D1D6"
                        opacity:            0.55
                        z:                  -1
                    }

                    Rectangle {
                        id:                 track
                        anchors.fill:       parent
                        radius:             height / 2
                        color:              resetToggle.checked ? "#34C759" : "#E8E8ED"

                        Behavior on color { ColorAnimation { duration: 180 } }

                        // White circular knob
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

                            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                            // soft faux shadow under knob
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top:              parent.top
                                anchors.topMargin:        2
                                width:                    parent.width
                                height:                   parent.height
                                radius:                   width / 2
                                color:                    "#000000"
                                opacity:                  0.12
                                z:                        -1
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill:   parent
                        cursorShape:    Qt.PointingHandCursor
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
    }

    Component {
        id: detailPageComponent

        Item {
            id: detailRoot

            property string pageTitle
            property url    pageSource

            Rectangle {
                anchors.fill: parent
                color:        qgcPal.window
            }

            Rectangle {
                id:             detailHeader
                anchors.left:   parent.left
                anchors.right:  parent.right
                anchors.top:    parent.top
                height:         settingsView._headerHeight
                color:          settingsView._pageBackground

                Item {
                    anchors.left:           parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin:     settingsView._horizontalPad
                    height:                 ScreenTools.defaultFontPixelHeight * 2.2
                    width:                  height

                    QGCLabel {
                        anchors.centerIn:   parent
                        text:               "‹"
                        color:              settingsView._titleColor
                        font.pointSize:     ScreenTools.largeFontPointSize
                        font.weight:        Font.Medium
                    }

                    MouseArea {
                        anchors.fill:   parent
                        cursorShape:    Qt.PointingHandCursor
                        onClicked:      settingsView._goBack()
                    }
                }

                QGCLabel {
                    anchors.centerIn:   parent
                    text:               detailRoot.pageTitle
                    color:              settingsView._titleColor
                    font.pointSize:     ScreenTools.largeFontPointSize
                    font.weight:        Font.DemiBold
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
