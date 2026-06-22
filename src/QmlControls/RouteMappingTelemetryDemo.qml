import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Item {
    id: root

    width:  ScreenTools.defaultFontPixelWidth * 58
    height: ScreenTools.defaultFontPixelHeight * 13

    readonly property color _glassColor:  Qt.rgba(0.07, 0.05, 0.08, 0.46)
    readonly property color _textColor:   "white"
    readonly property color _mutedColor:  Qt.rgba(1, 1, 1, 0.78)
    readonly property color _accentGreen: "#4af200"

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.10)
    }

    Item {
        id: compassPane
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.height * 0.95
        height: width

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.86
            height: width
            radius: width / 2
            color: Qt.rgba(0.04, 0.04, 0.05, 0.24)
            border.color: Qt.rgba(1, 1, 1, 0.18)
            border.width: 1
        }

        QGCLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            text: "N"
            color: root._textColor
            font.pointSize: ScreenTools.smallFontPointSize
            font.bold: true
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: ScreenTools.defaultFontPixelWidth * 1.2
            height: ScreenTools.defaultFontPixelHeight * 2.4
            color: "#ff1d25"
            rotation: 0
            transformOrigin: Item.Bottom
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: ScreenTools.defaultFontPixelWidth * 0.7
            height: width
            radius: width / 2
            color: "white"
        }
    }

    Rectangle {
        id: telemetryGlass
        anchors.left: compassPane.right
        anchors.leftMargin: ScreenTools.defaultFontPixelWidth
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height * 0.72
        color: root._glassColor
        radius: ScreenTools.defaultFontPixelWidth * 0.35

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 2
            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 2
            spacing: ScreenTools.defaultFontPixelWidth * 3

            MetricBlock {
                title: qsTr("Relative to\nHome")
                value: "0.0"
                unit: "m"
                iconText: "\u25b3"
            }

            MetricBlock {
                title: qsTr("Speed")
                value: "0.0"
                unit: "km/h"
            }

            MetricBlock {
                title: qsTr("Distance")
                value: "19.3"
                unit: "m"
            }

            MetricBlock {
                Layout.alignment: Qt.AlignBottom
                title: qsTr("Flow")
                value: "0.0"
                unit: "L/min"
                iconText: "\u27f3"
                iconColor: root._accentGreen
            }
        }
    }

    component MetricBlock: ColumnLayout {
        property string title
        property string value
        property string unit
        property string iconText: ""
        property color  iconColor: root._mutedColor

        Layout.fillWidth: true
        spacing: ScreenTools.defaultFontPixelHeight * 0.12

        Row {
            spacing: ScreenTools.defaultFontPixelWidth * 0.25

            QGCLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: iconText
                color: iconColor
                visible: iconText !== ""
                font.pointSize: ScreenTools.defaultFontPointSize
            }

            QGCLabel {
                text: title
                color: root._mutedColor
                lineHeight: 0.86
                font.pointSize: ScreenTools.defaultFontPointSize
            }
        }

        Row {
            spacing: ScreenTools.defaultFontPixelWidth * 0.35

            QGCLabel {
                anchors.baseline: unitLabel.baseline
                text: value
                color: root._textColor
                font.bold: true
                font.pointSize: ScreenTools.largeFontPointSize * 1.35
            }

            QGCLabel {
                id: unitLabel
                anchors.verticalCenter: parent.verticalCenter
                text: unit
                color: root._mutedColor
                font.pointSize: ScreenTools.smallFontPointSize
            }
        }
    }
}
