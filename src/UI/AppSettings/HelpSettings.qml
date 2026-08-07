import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

SettingsPage {
    id: helpPage

    readonly property color _headingColor:  "#3A3A3C"
    readonly property color _bodyColor:     qgcPal.text
    readonly property color _accentColor:   "#00a04c"
    readonly property color _mutedColor:    "#8E8E93"

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    readonly property real _sectionGap:     ScreenTools.defaultFontPixelHeight * 1.4
    readonly property real _paraGap:        ScreenTools.defaultFontPixelHeight * 0.55
    readonly property real _titleSize:      ScreenTools.defaultFontPointSize + 2
    readonly property real _sectionSize:    ScreenTools.defaultFontPointSize + 1
    readonly property real _bodySize:       ScreenTools.defaultFontPointSize
    readonly property real _smallSize:      ScreenTools.smallFontPointSize

    ColumnLayout {
        Layout.fillWidth:   true
        spacing:            helpPage._sectionGap

        ColumnLayout {
            Layout.fillWidth:   true
            spacing:            helpPage._paraGap

            QGCLabel {
                Layout.fillWidth:   true
                text:               qsTr("We're here to help")
                color:              helpPage._headingColor
                font.pointSize:     helpPage._titleSize
                font.bold:          true
                wrapMode:           Text.WrapAtWordBoundaryOrAnywhere
            }

            QGCLabel {
                Layout.fillWidth:   true
                text:               qsTr("Thank you for using our software. If you need guidance at any point, the resources below will help you get started and stay supported.")
                color:              helpPage._bodyColor
                font.pointSize:     helpPage._bodySize
                wrapMode:           Text.WrapAtWordBoundaryOrAnywhere
                lineHeight:         1.35
                lineHeightMode:     Text.ProportionalHeight
            }
        }

        ColumnLayout {
            Layout.fillWidth:   true
            spacing:            helpPage._paraGap

            QGCLabel {
                Layout.fillWidth:   true
                text:               qsTr("Getting started")
                color:              helpPage._headingColor
                font.pointSize:     helpPage._sectionSize
                font.bold:          true
                wrapMode:           Text.WrapAtWordBoundaryOrAnywhere
            }

            QGCLabel {
                Layout.fillWidth:   true
                text:               qsTr("For a clear walkthrough of how to operate this software, please refer to our User Manual. It is available from the beginning of the software experience and covers the essential steps to use the application confidently.")
                color:              helpPage._bodyColor
                font.pointSize:     helpPage._bodySize
                wrapMode:           Text.WrapAtWordBoundaryOrAnywhere
                lineHeight:         1.35
                lineHeightMode:     Text.ProportionalHeight
            }
        }

        ColumnLayout {
            Layout.fillWidth:   true
            spacing:            helpPage._paraGap

            QGCLabel {
                Layout.fillWidth:   true
                text:               qsTr("Need further assistance?")
                color:              helpPage._headingColor
                font.pointSize:     helpPage._sectionSize
                font.bold:          true
                wrapMode:           Text.WrapAtWordBoundaryOrAnywhere
            }

            QGCLabel {
                Layout.fillWidth:   true
                text:               qsTr("If something is unclear or you run into an issue, our team is happy to help. Reach out to us anytime at:")
                color:              helpPage._bodyColor
                font.pointSize:     helpPage._bodySize
                wrapMode:           Text.WrapAtWordBoundaryOrAnywhere
                lineHeight:         1.35
                lineHeightMode:     Text.ProportionalHeight
            }

            QGCLabel {
                Layout.fillWidth:   true
                text:               "<a href=\"mailto:shreentechnlogies@gmail.com\">shreentechnlogies@gmail.com</a>"
                color:              helpPage._accentColor
                linkColor:          helpPage._accentColor
                font.pointSize:     helpPage._bodySize
                font.bold:          true
                wrapMode:           Text.WrapAtWordBoundaryOrAnywhere
                onLinkActivated:    (link) => Qt.openUrlExternally(link)
            }
        }

        ColumnLayout {
            Layout.fillWidth:   true
            spacing:            helpPage._paraGap * 0.6

            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: 1
                color:                  "#f6f6f6"
            }

            QGCLabel {
                Layout.fillWidth:   true
                Layout.topMargin:   helpPage._paraGap
                text:               qsTr("Shreeon Technologies")
                color:              helpPage._headingColor
                font.pointSize:     helpPage._sectionSize
                font.bold:          true
                wrapMode:           Text.WrapAtWordBoundaryOrAnywhere
            }

            QGCLabel {
                Layout.fillWidth:   true
                text:               qsTr("Owned by Renish Posiya and Gorab Posiya")
                color:              helpPage._mutedColor
                font.pointSize:     helpPage._smallSize
                wrapMode:           Text.WrapAtWordBoundaryOrAnywhere
                lineHeight:         1.3
                lineHeightMode:     Text.ProportionalHeight
            }
        }
    }
}
