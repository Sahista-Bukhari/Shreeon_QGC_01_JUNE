import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Item {
    id: root

    property bool listViewLoadCompleted: false

    readonly property bool  _darkTheme:      loggingPalette.globalTheme === QGCPalette.Dark
    readonly property color _pageBackground: _darkTheme ? loggingPalette.window : "#FFFFFF"
    readonly property color _cardFill:       _darkTheme ? loggingPalette.windowShade : "#F7F7F7"
    readonly property color _innerFill:      _darkTheme ? loggingPalette.window : "#FFFFFF"
    readonly property color _dividerColor:   _darkTheme ? loggingPalette.windowShade : "#E5E5E5"
    readonly property color _titleColor:     _darkTheme ? "#AEAEB2" : "#3A3A3C"
    readonly property color _accentGreen:    "#00a04c"
    readonly property real  _pagePad:        ScreenTools.defaultFontPixelWidth * 2.2
    readonly property real  _controlSpacing: ScreenTools.defaultFontPixelWidth
    readonly property real  _cardRadius:     ScreenTools.defaultFontPixelWidth * 1.0

    QGCPalette {
        id:                loggingPalette
        colorGroupEnabled: root.enabled
    }

    Rectangle {
        anchors.fill: parent
        color:        root._pageBackground
    }

    Item {
        id:              panel
        anchors.fill:    parent
        anchors.margins: root._pagePad

        Component {
            id: delegateItem

            Rectangle {
                width:  listView.width
                height: field.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.8
                color:  index % 2 === 0 ? root._innerFill : root._cardFill

                QGCLabel {
                    id:                  field
                    anchors.fill:        parent
                    anchors.leftMargin:  root._controlSpacing * 1.25
                    anchors.rightMargin: root._controlSpacing * 1.25
                    anchors.topMargin:   ScreenTools.defaultFontPixelHeight * 0.35
                    anchors.bottomMargin: anchors.topMargin
                    text:                display
                    color:               root._titleColor
                    wrapMode:            Text.WrapAtWordBoundaryOrAnywhere
                    verticalAlignment:   Text.AlignVCenter
                }
            }
        }

        Rectangle {
            id:             logCard
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.top:    parent.top
            anchors.bottom: actionCard.top
            anchors.bottomMargin: root._controlSpacing
            radius:         root._cardRadius
            color:          root._innerFill
            border.width:   1
            border.color:   root._dividerColor
            clip:           true

            QGCListView {
                id:                     listView
                anchors.fill:           parent
                anchors.margins:        1
                clip:                   true
                model:                  debugMessageModel
                delegate:               delegateItem
                boundsBehavior:         Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy:        listView.contentHeight > listView.height
                                   ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                    width:         Math.max(7, ScreenTools.defaultFontPixelWidth * 0.7)
                    topPadding:    root._controlSpacing * 0.5
                    bottomPadding: topPadding
                    leftPadding:   2
                    rightPadding:  2

                    background: Rectangle {
                        radius: parent.width / 2
                        color:  root._cardFill
                    }

                    contentItem: Rectangle {
                        radius: width / 2
                        color:  root._accentGreen
                    }
                }

                function scrollToEnd() {
                    if (listViewLoadCompleted) {
                        if (followTail.checked) {
                            listView.positionViewAtEnd();
                        }
                    }
                }

                Component.onCompleted: {
                    listViewLoadCompleted = true
                    listView.scrollToEnd()
                }

                Connections {
                    target:         debugMessageModel
                    function onDataChanged(topLeft, bottomRight, roles) { listView.scrollToEnd() }
                }
            }
        }

        Rectangle {
            id:             actionCard
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.bottom: parent.bottom
            height:         actionLayout.implicitHeight + root._controlSpacing * 1.5
            radius:         root._cardRadius
            color:          root._cardFill
            border.width:   1
            border.color:   root._dividerColor

            RowLayout {
                id:              actionLayout
                anchors.fill:    parent
                anchors.margins: root._controlSpacing * 0.75
                spacing:         root._controlSpacing

                QGCButton {
                    id:        writeButton
                    text:      qsTr("Save App Log")
                    onClicked: writeDialog.openForSave()
                }

                QGCLabel {
                    id:             gstLabel
                    text:           qsTr("GStreamer Debug Level")
                    color:          root._titleColor
                    visible:        QGroundControl.settingsManager.appSettings.gstDebugLevel.visible
                    elide:          Text.ElideRight
                }

                FactComboBox {
                    id:             gstCombo
                    fact:           QGroundControl.settingsManager.appSettings.gstDebugLevel
                    visible:        QGroundControl.settingsManager.appSettings.gstDebugLevel.visible
                    sizeToContents: true
                }

                Item { Layout.fillWidth: true }

                QGCButton {
                    id:        followTail
                    text:      qsTr("Show Latest")
                    checkable: true
                    checked:   true
                    primary:   checked

                    onCheckedChanged: {
                        if (checked && listViewLoadCompleted) {
                            listView.positionViewAtEnd();
                        }
                    }
                }

                QGCButton {
                    id:        filterButton
                    text:      qsTr("Set Logging")
                    onClicked: filtersDialogComponent.createObject(mainWindow).open()
                }
            }
        }

        QGCFileDialog {
            id:          writeDialog
            folder:      QGroundControl.settingsManager.appSettings.logSavePath
            nameFilters: [qsTr("Log files (*.txt)"), qsTr("All Files (*)")]
            title:       qsTr("Select log save file")

            onAcceptedForSave: (file) => {
                debugMessageModel.writeMessages(file)
                visible = false
            }
        }

        Connections {
            target: debugMessageModel
            function onWriteStarted() { writeButton.enabled = false }
            function onWriteFinished(success) { writeButton.enabled = true }
        }
    }

    Component {
        id: filtersDialogComponent

        QGCPopupDialog {
            title:      qsTr("Logging")
            buttons:    Dialog.Close

            ColumnLayout {
                width: maxContentAvailableWidth

                SettingsGroupLayout {
                    heading:            qsTr("Search")
                    Layout.fillWidth:   true

                    RowLayout {
                        Layout.fillWidth:   true
                        spacing:            ScreenTools.defaultFontPixelHeight / 2

                        QGCTextField {
                            Layout.fillWidth:   true
                            id:                 searchText
                            text:               ""
                            enabled:            true
                        }

                        QGCButton {
                            text:       qsTr("Clear")
                            onClicked:  searchText.text = ""
                        }
                    }
                }

                SettingsGroupLayout {
                    heading:            qsTr("Enabled Categories")
                    Layout.fillWidth:   true

                    Flow {
                        Layout.fillWidth:   true
                        spacing:            ScreenTools.defaultFontPixelHeight / 2

                        Repeater {
                            model: QGroundControl.flatLoggingCategoriesModel()

                            QGCCheckBoxSlider {
                                Layout.fillWidth:       true
                                Layout.maximumHeight:   visible ? implicitHeight : 0
                                text:                   object.fullCategory
                                visible:                object.enabled
                                checked:                object.enabled
                                onClicked:              object.enabled = checked
                            }
                        }

                        QGCButton {
                            text:       qsTr("Disable All")
                            onClicked:  QGroundControl.disableAllLoggingCategories()
                        }
                    }
                }

                // Shown when not filtered
                Flow {
                    Layout.fillWidth:   true
                    spacing:            ScreenTools.defaultFontPixelHeight / 2
                    visible:            searchText.text === ""

                    Repeater {
                        model: QGroundControl.treeLoggingCategoriesModel()

                        ColumnLayout {
                            spacing: ScreenTools.defaultFontPixelHeight / 2

                            RowLayout {
                                spacing:                ScreenTools.defaultFontPixelWidth

                                QGCLabel {
                                    Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth
                                    text:                   object.expanded ? qsTr("-") : qsTr("+")
                                    horizontalAlignment:    Text.AlignLeft
                                    visible:                object.children

                                    QGCMouseArea {
                                        anchors.fill:   parent
                                        onClicked:      object.expanded = !object.expanded
                                    }
                                }

                                QGCCheckBoxSlider {
                                    Layout.fillWidth:   true
                                    text:               object.shortCategory
                                    checked:            object.enabled
                                    onClicked:          object.enabled = checked
                                }
                            }

                            Repeater {
                                model: object.expanded ? object.children : undefined

                                QGCCheckBoxSlider {
                                    Layout.fillWidth:   true
                                    text:               "   " + object.shortCategory
                                    checked:            object.enabled
                                    onClicked:          object.enabled = checked
                                }
                            }
                        }
                    }
                }

                // Shown when filtered
                Flow {
                    Layout.fillWidth:   true
                    spacing:            ScreenTools.defaultFontPixelHeight / 2
                    visible:            searchText.text !== ""

                    Repeater {
                        model: QGroundControl.flatLoggingCategoriesModel()

                        QGCCheckBoxSlider {
                            Layout.fillWidth:       true
                            Layout.maximumHeight:   visible ? implicitHeight : 0
                            text:                   object.fullCategory
                            visible:                text.match(`(${searchText.text})`, "i")
                            checked:                object.enabled
                            onClicked:              object.enabled = checked
                        }
                    }
                }
            }
        }
    }
}
