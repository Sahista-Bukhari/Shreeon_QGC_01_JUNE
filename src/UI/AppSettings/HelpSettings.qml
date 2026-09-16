import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

SettingsPage {
    id: helpPage

    readonly property bool  _darkTheme:   helpPalette.globalTheme === QGCPalette.Dark
    readonly property color _headingColor: _darkTheme ? "#AEAEB2" : "#3A3A3C"
    readonly property color _bodyColor:    _darkTheme ? "#8E8E93" : "#5A5A5E"
    readonly property color _accentColor:  "#00a04c"
    readonly property color _mutedColor:   "#8E8E93"
    readonly property color _cardFill:     _darkTheme ? helpPalette.windowShade : "#F7F7F7"
    readonly property color _innerFill:    _darkTheme ? helpPalette.window : "#FFFFFF"
    readonly property color _dividerColor: _darkTheme ? helpPalette.windowShade : "#E5E5E5"

    readonly property real _sectionGap: ScreenTools.defaultFontPixelHeight * 1.1
    readonly property real _paraGap:    ScreenTools.defaultFontPixelHeight * 0.55
    readonly property real _contentPad: ScreenTools.defaultFontPixelWidth * 1.7
    readonly property real _cardRadius: ScreenTools.defaultFontPixelWidth * 1.0
    readonly property real _titleSize:  ScreenTools.defaultFontPointSize + 2
    readonly property real _sectionSize: ScreenTools.defaultFontPointSize + 1
    readonly property real _bodySize:   ScreenTools.defaultFontPointSize
    readonly property real _smallSize:  ScreenTools.smallFontPointSize

    QGCPalette {
        id:                helpPalette
        colorGroupEnabled: helpPage.enabled
    }

    component HelpSectionCard: Rectangle {
        id: sectionCard

        required property string sectionTitle
        required property string sectionText
        property string linkAddress: ""
        property string linkLabel:   ""

        Layout.fillWidth:       true
        Layout.preferredHeight: sectionLayout.implicitHeight + helpPage._contentPad * 1.45
        radius:                 helpPage._cardRadius * 0.75
        color:                  helpPage._innerFill
        border.width:           1
        border.color:           helpPage._dividerColor

        ColumnLayout {
            id:                  sectionLayout
            anchors.fill:        parent
            anchors.leftMargin:  helpPage._contentPad
            anchors.rightMargin: helpPage._contentPad
            anchors.topMargin:   helpPage._contentPad * 0.72
            anchors.bottomMargin: anchors.topMargin
            spacing:             helpPage._paraGap

            RowLayout {
                Layout.fillWidth: true
                spacing:          ScreenTools.defaultFontPixelWidth * 0.75

                Rectangle {
                    Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 0.55
                    Layout.preferredHeight: Layout.preferredWidth
                    radius:                 width / 2
                    color:                  helpPage._accentColor
                }

                QGCLabel {
                    Layout.fillWidth: true
                    text:             sectionCard.sectionTitle
                    color:            helpPage._headingColor
                    font.pointSize:   helpPage._sectionSize
                    font.weight:      Font.DemiBold
                    wrapMode:         Text.WrapAtWordBoundaryOrAnywhere
                }
            }

            QGCLabel {
                Layout.fillWidth: true
                text:             sectionCard.sectionText
                color:            helpPage._bodyColor
                font.pointSize:   helpPage._bodySize
                wrapMode:         Text.WrapAtWordBoundaryOrAnywhere
                lineHeight:       1.35
                lineHeightMode:   Text.ProportionalHeight
            }

            QGCLabel {
                Layout.fillWidth: true
                visible:          sectionCard.linkAddress !== ""
                text:             "<a href=\"" + sectionCard.linkAddress + "\">" + sectionCard.linkLabel + "</a>"
                color:            helpPage._accentColor
                linkColor:        helpPage._accentColor
                font.pointSize:   helpPage._bodySize
                font.weight:      Font.DemiBold
                wrapMode:         Text.WrapAtWordBoundaryOrAnywhere
                onLinkActivated:  (link) => Qt.openUrlExternally(link)
            }
        }
    }

    Rectangle {
        Layout.fillWidth:       true
        Layout.preferredHeight: helpLayout.implicitHeight + helpPage._contentPad * 2
        radius:                 helpPage._cardRadius
        color:                  helpPage._cardFill
        border.width:           1
        border.color:           helpPage._dividerColor

        ColumnLayout {
            id:              helpLayout
            anchors.fill:    parent
            anchors.margins: helpPage._contentPad
            spacing:         helpPage._sectionGap

            RowLayout {
                Layout.fillWidth: true
                spacing:          helpPage._contentPad

                Rectangle {
                    Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 2.8
                    Layout.preferredHeight: Layout.preferredWidth
                    Layout.alignment:       Qt.AlignTop
                    radius:                 width / 2
                    color:                  Qt.rgba(0, 160 / 255, 76 / 255, helpPage._darkTheme ? 0.16 : 0.10)
                    border.width:           1
                    border.color:           helpPage._accentColor

                    QGCColoredImage {
                        anchors.centerIn: parent
                        width:            parent.width * 0.48
                        height:           width
                        source:           "qrc:/InstrumentValueIcons/question.svg"
                        color:            helpPage._accentColor
                        fillMode:         Image.PreserveAspectFit
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing:          helpPage._paraGap

                    QGCLabel {
                        Layout.fillWidth: true
                        text:             qsTr("We're here to help")
                        color:            helpPage._headingColor
                        font.pointSize:   helpPage._titleSize
                        font.weight:      Font.DemiBold
                        wrapMode:         Text.WrapAtWordBoundaryOrAnywhere
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        text:             qsTr("Thank you for using our software. The resources below will help you get started and find support when you need it.")
                        color:            helpPage._bodyColor
                        font.pointSize:   helpPage._bodySize
                        wrapMode:         Text.WrapAtWordBoundaryOrAnywhere
                        lineHeight:       1.35
                        lineHeightMode:   Text.ProportionalHeight
                    }
                }
            }

            HelpSectionCard {
                sectionTitle: qsTr("Getting started")
                sectionText:  qsTr("For a clear walkthrough of how to operate this software, refer to the User Manual. It covers the essential steps needed to use the application confidently.")
            }

            HelpSectionCard {
                sectionTitle: qsTr("Need further assistance?")
                sectionText:  qsTr("If something is unclear or you run into an issue, our team is happy to help. Contact us at:")
                linkAddress:  "mailto:shreentechnlogies@gmail.com"
                linkLabel:    "shreentechnlogies@gmail.com"
            }

            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: piPhotoTestColumn.implicitHeight + helpPage._contentPad * 1.45
                radius:                 helpPage._cardRadius * 0.75
                color:                  helpPage._innerFill
                border.width:           1
                border.color:           helpPage._dividerColor

                ColumnLayout {
                    id: piPhotoTestColumn
                    anchors.fill:        parent
                    anchors.margins:     helpPage._contentPad
                    spacing:             helpPage._paraGap

                    QGCLabel {
                        Layout.fillWidth: true
                        text:             qsTr("Pi camera (Route Mapping)")
                        color:            helpPage._headingColor
                        font.pointSize:   helpPage._sectionSize
                        font.weight:      Font.DemiBold
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        wrapMode:         Text.WordWrap
                        color:            helpPage._bodyColor
                        font.pointSize:   helpPage._bodySize
                        text:             qsTr("Upload a Route Mapping plan to the vehicle, then start the mission from Fly View. QGC captures Pi stills automatically (survey distance and camera triggers) and saves them under Documents/QGC_RouteMapping/images/ as image_001.jpg, image_002.jpg, …")
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        wrapMode:         Text.WordWrap
                        color:            helpPage._bodyColor
                        font.pointSize:   helpPage._bodySize
                        visible:          QGroundControl.routeMappingPiPhotoCapture.busy
                        text:             qsTr("Pi capture in progress…")
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        wrapMode:         Text.WordWrap
                        color:            helpPage._bodyColor
                        font.pointSize:   helpPage._bodySize
                        text:             QGroundControl.routeMappingPiPhotoCapture.lastError.length > 0
                                          ? QGroundControl.routeMappingPiPhotoCapture.lastError
                                          : (QGroundControl.routeMappingPiPhotoCapture.lastLocalPath.length > 0
                                             ? qsTr("Last saved: %1").arg(QGroundControl.routeMappingPiPhotoCapture.lastLocalPath)
                                             : "")
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing:          helpPage._paraGap * 0.45

                QGCLabel {
                    Layout.fillWidth: true
                    text:             qsTr("Shreeon Technologies")
                    color:            helpPage._headingColor
                    font.pointSize:   helpPage._sectionSize
                    font.weight:      Font.DemiBold
                }

                QGCLabel {
                    Layout.fillWidth: true
                    text:             qsTr("Owned by Renish Posiya and Gorab Posiya")
                    color:            helpPage._mutedColor
                    font.pointSize:   helpPage._smallSize
                    wrapMode:         Text.WrapAtWordBoundaryOrAnywhere
                }
            }
        }
    }
}
