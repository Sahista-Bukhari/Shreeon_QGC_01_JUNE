import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

AnalyzePage {
    id: geoTagPage

    headerComponent:  geoTagHeaderComponent
    pageComponent:    pageComponent
    contentTopMargin: _headerSpacing
    allowPopout:      false

    readonly property bool _darkTheme: {
        if (typeof mainWindow !== "undefined" && mainWindow)
            return mainWindow.uiThemeMode === mainWindow.themeBlack
        return geoTagPalette.globalTheme === QGCPalette.Dark
    }
    readonly property color _pageBackground:   _darkTheme ? geoTagPalette.window : "#FFFFFF"
    readonly property color _titleColor:       _darkTheme ? "#AEAEB2" : "#3A3A3C"
    readonly property color _bodyColor:        _darkTheme ? "#8E8E93" : "#5A5A5E"
    readonly property color _accentGreen:      "#00a04c"
    readonly property color _cardIdleFill:     _darkTheme ? geoTagPalette.window : "#FFFFFF"
    readonly property color _cardSelectedFill: Qt.rgba(0, 160 / 255, 76 / 255, _darkTheme ? 0.16 : 0.08)
    readonly property color _dataCardFill:     _darkTheme ? geoTagPalette.windowShade : "#F5F5F5"
    readonly property color _tableLine:        _darkTheme ? geoTagPalette.windowShade : "#E5E5E5"
    readonly property real  _pagePad:          ScreenTools.defaultFontPixelWidth * 2.2
    readonly property real  _controlSpacing:   ScreenTools.defaultFontPixelWidth
    readonly property real  _headerSpacing:    Math.ceil(ScreenTools.defaultFontPixelHeight * 0.65)
    readonly property real  _cardRadius:       ScreenTools.defaultFontPixelWidth * 0.9

    QGCPalette {
        id:                geoTagPalette
        colorGroupEnabled: geoTagPage.enabled
    }

    function outputDirectoryText() {
        if (geoController.saveDirectory)
            return geoController.saveDirectory
        if (geoController.imageDirectory)
            return geoController.imageDirectory + qsTr("/TAGGED")
        return ""
    }

    function progressStatusText() {
        if (geoController.errorMessage)
            return geoController.errorMessage
        if (geoController.inProgress)
            return qsTr("Tagging images… %1%").arg(Math.round(geoController.progress))
        if (geoController.progress >= 100)
            return qsTr("Image geotagging completed")
        if (geoController.logFile && geoController.imageDirectory)
            return qsTr("Ready to geotag images")
        return qsTr("Select a flight log and image directory to continue")
    }

    QGCFileDialog {
        id:            openLogFile
        title:         qsTr("Select flight log")
        nameFilters:   [qsTr("ULog file (*.ulg)"), qsTr("PX4 log file (*.px4log)"), qsTr("All Files (*)")]
        defaultSuffix: "ulg"

        onAcceptedForLoad: (file) => {
            geoController.logFile = file
            close()
        }
    }

    QGCFileDialog {
        id:           selectImageDir
        title:        qsTr("Select image directory")
        selectFolder: true

        onAcceptedForLoad: (file) => {
            geoController.imageDirectory = file
            close()
        }
    }

    QGCFileDialog {
        id:           selectDestDir
        title:        qsTr("Select output directory")
        selectFolder: true

        onAcceptedForLoad: (file) => {
            geoController.saveDirectory = file
            close()
        }
    }

    component GeoActionButton: Button {
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
                    return Qt.rgba(geoTagPage._bodyColor.r,
                                   geoTagPage._bodyColor.g,
                                   geoTagPage._bodyColor.b, 0.45)
                return actionButton.primaryAction || actionButton.pressed ? "#FFFFFF" : geoTagPage._titleColor
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
            border.color:   actionButton.enabled ? geoTagPage._accentGreen : geoTagPage._tableLine
            color: {
                if (!actionButton.enabled)
                    return geoTagPage._dataCardFill
                if (actionButton.primaryAction)
                    return actionButton.pressed
                           ? Qt.darker(geoTagPage._accentGreen, 1.12)
                           : geoTagPage._accentGreen
                if (actionButton.pressed)
                    return geoTagPage._accentGreen
                if (actionButton.hovered)
                    return geoTagPage._cardSelectedFill
                return geoTagPage._cardIdleFill
            }

            Behavior on color {
                ColorAnimation { duration: 120 }
            }
        }
    }

    component GeoPathCard: Rectangle {
        id: pathCard

        property int    stepNumber:  1
        property string title:       ""
        property string description: ""
        property string pathText:    ""
        property string placeholder: ""
        property string buttonText:  qsTr("Browse")
        property bool   required:    true

        signal browseClicked()

        Layout.fillWidth:       true
        Layout.preferredHeight: pathCardLayout.implicitHeight + geoTagPage._controlSpacing * 2
        radius:                 geoTagPage._cardRadius
        color:                  geoTagPage._dataCardFill
        border.width:           1
        border.color:           pathText.length > 0 ? geoTagPage._accentGreen : geoTagPage._tableLine

        ColumnLayout {
            id:              pathCardLayout
            anchors.fill:    parent
            anchors.margins: geoTagPage._controlSpacing
            spacing:         geoTagPage._headerSpacing * 0.65

            RowLayout {
                Layout.fillWidth: true
                spacing:          geoTagPage._controlSpacing

                Rectangle {
                    Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.55
                    Layout.preferredHeight: Layout.preferredWidth
                    radius:                 width / 2
                    color:                  pathCard.pathText.length > 0
                                            ? geoTagPage._accentGreen
                                            : geoTagPage._cardIdleFill
                    border.width:           1
                    border.color:           geoTagPage._accentGreen

                    QGCLabel {
                        anchors.centerIn: parent
                        text:             pathCard.pathText.length > 0 ? "✓" : pathCard.stepNumber
                        color:            pathCard.pathText.length > 0 ? "#FFFFFF" : geoTagPage._accentGreen
                        font.weight:      Font.DemiBold
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing:          0

                    QGCLabel {
                        Layout.fillWidth: true
                        text:             pathCard.title
                        color:            geoTagPage._titleColor
                        font.weight:      Font.DemiBold
                        elide:            Text.ElideRight
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        text:             pathCard.description
                        color:            geoTagPage._bodyColor
                        wrapMode:         Text.WordWrap
                    }
                }

                QGCLabel {
                    text:        pathCard.required ? qsTr("Required") : qsTr("Optional")
                    color:       pathCard.required ? geoTagPage._accentGreen : geoTagPage._bodyColor
                    font.weight: Font.DemiBold
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing:          geoTagPage._controlSpacing

                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: ScreenTools.implicitTextFieldHeight
                    radius:                 ScreenTools.defaultBorderRadius * 2
                    color:                  geoTagPage._cardIdleFill
                    border.width:           1
                    border.color:           pathCard.pathText.length > 0
                                            ? geoTagPage._accentGreen
                                            : geoTagPage._tableLine

                    QGCLabel {
                        anchors.fill:        parent
                        anchors.leftMargin:  geoTagPage._controlSpacing
                        anchors.rightMargin: geoTagPage._controlSpacing
                        text:                pathCard.pathText.length > 0 ? pathCard.pathText : pathCard.placeholder
                        color:               pathCard.pathText.length > 0
                                             ? geoTagPage._titleColor
                                             : geoTagPage._bodyColor
                        verticalAlignment:   Text.AlignVCenter
                        elide:               Text.ElideLeft
                    }
                }

                GeoActionButton {
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 14
                    text:                  pathCard.buttonText
                    enabled:               !geoController.inProgress
                    onClicked:             pathCard.browseClicked()
                }
            }
        }

        Behavior on border.color {
            ColorAnimation { duration: 160 }
        }
    }

    Component {
        id: geoTagHeaderComponent

        Item {
            implicitHeight: geoTagHeaderLayout.implicitHeight

            ColumnLayout {
                id:                  geoTagHeaderLayout
                anchors.left:        parent.left
                anchors.right:       parent.right
                anchors.leftMargin:  geoTagPage._pagePad
                anchors.rightMargin: geoTagPage._pagePad
                spacing:             geoTagPage._headerSpacing

                QGCLabel {
                    Layout.fillWidth: true
                    text:             qsTr("Add GPS coordinates from a flight log to images captured during a survey mission.")
                    color:            geoTagPage._bodyColor
                    wrapMode:         Text.WordWrap
                }

                Rectangle {
                    Layout.fillWidth: true
                    height:           1
                    color:            geoTagPage._tableLine
                }
            }
        }
    }

    Component {
        id: pageComponent

        Rectangle {
            width:  geoTagPage.availableWidth
            height: geoTagPage.availableHeight
            color:  geoTagPage._pageBackground

            QGCFlickable {
                id:                  geoTagScroll
                anchors.fill:        parent
                anchors.leftMargin:  geoTagPage._pagePad
                anchors.rightMargin: geoTagPage._pagePad
                anchors.bottomMargin: geoTagPage._pagePad
                contentWidth:        width
                contentHeight:       geoTagContent.height
                flickableDirection:  Flickable.VerticalFlick
                clip:                true
                pixelAligned:        true

                ColumnLayout {
                    id:      geoTagContent
                    width:   geoTagScroll.width
                    spacing: geoTagPage._headerSpacing

                    GeoPathCard {
                        stepNumber:  1
                        title:       qsTr("Flight log")
                        description: qsTr("Choose the ULog or PX4 log containing the camera trigger positions.")
                        pathText:    geoController.logFile
                        placeholder: qsTr("No flight log selected")
                        buttonText:  qsTr("Select Log")
                        onBrowseClicked: openLogFile.openForLoad()
                    }

                    GeoPathCard {
                        stepNumber:  2
                        title:       qsTr("Image directory")
                        description: qsTr("Choose the folder containing the original survey images.")
                        pathText:    geoController.imageDirectory
                        placeholder: qsTr("No image directory selected")
                        buttonText:  qsTr("Select Images")
                        onBrowseClicked: selectImageDir.openForLoad()
                    }

                    GeoPathCard {
                        stepNumber:  3
                        title:       qsTr("Output directory")
                        description: qsTr("Choose where tagged copies are saved, or use the automatic TAGGED folder.")
                        pathText:    geoTagPage.outputDirectoryText()
                        placeholder: qsTr("A TAGGED folder will be created inside the image directory")
                        buttonText:  qsTr("Select Output")
                        required:    false
                        onBrowseClicked: selectDestDir.openForLoad()
                    }

                    Rectangle {
                        Layout.fillWidth:       true
                        Layout.preferredHeight: statusLayout.implicitHeight + geoTagPage._controlSpacing * 2
                        radius:                 geoTagPage._cardRadius
                        color:                  geoTagPage._cardIdleFill
                        border.width:           1
                        border.color:           geoController.errorMessage
                                                ? geoTagPalette.warningText
                                                : geoTagPage._tableLine

                        ColumnLayout {
                            id:              statusLayout
                            anchors.fill:    parent
                            anchors.margins: geoTagPage._controlSpacing
                            spacing:         geoTagPage._headerSpacing

                            RowLayout {
                                Layout.fillWidth: true
                                spacing:          geoTagPage._controlSpacing

                                QGCLabel {
                                    Layout.fillWidth: true
                                    text:             geoTagPage.progressStatusText()
                                    color:            geoController.errorMessage
                                                      ? geoTagPalette.warningText
                                                      : geoTagPage._titleColor
                                    font.weight:      Font.DemiBold
                                    wrapMode:         Text.WordWrap
                                }

                                QGCLabel {
                                    text:    qsTr("%1%").arg(Math.round(geoController.progress))
                                    color:   geoTagPage._accentGreen
                                    visible: geoController.inProgress || geoController.progress > 0
                                }
                            }

                            ProgressBar {
                                id:               progressBar
                                Layout.fillWidth: true
                                from:             0
                                to:               100
                                value:            geoController.progress
                                opacity:          geoController.inProgress || geoController.progress > 0 ? 1 : 0.45

                                background: Rectangle {
                                    implicitHeight: Math.max(6, ScreenTools.defaultFontPixelWidth * 0.7)
                                    radius:         height / 2
                                    color:          geoTagPage._dataCardFill
                                    border.width:   1
                                    border.color:   geoTagPage._tableLine
                                }

                                contentItem: Item {
                                    implicitHeight: Math.max(6, ScreenTools.defaultFontPixelWidth * 0.7)

                                    Rectangle {
                                        width:  progressBar.visualPosition * parent.width
                                        height: parent.height
                                        radius: height / 2
                                        color:  geoTagPage._accentGreen
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing:          geoTagPage._controlSpacing

                                QGCLabel {
                                    Layout.fillWidth: true
                                    text:             qsTr("Original images are preserved; tagged copies are written to the output directory.")
                                    color:            geoTagPage._bodyColor
                                    wrapMode:         Text.WordWrap
                                }

                                GeoActionButton {
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 18
                                    text:                  geoController.inProgress
                                                           ? qsTr("Cancel Tagging")
                                                           : qsTr("Start Tagging")
                                    primaryAction:         !geoController.inProgress
                                    enabled:               (geoController.imageDirectory && geoController.logFile)
                                                           || geoController.inProgress
                                    onClicked: {
                                        if (geoController.inProgress)
                                            geoController.cancelTagging()
                                        else
                                            geoController.startTagging()
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth:       true
                        Layout.preferredHeight: geoTagPage._controlSpacing
                    }
                }
            }
        }
    }
}
