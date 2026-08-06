import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id: root

    property int routePercent: 0
    property int photosTaken: 0
    property int photosPlanned: 0
    property bool photosVisible: true
    property string reconstructionText: qsTr("Pending")

    readonly property int _photosPercent: photosPlanned > 0
                                          ? Math.min(100, Math.floor((photosTaken / photosPlanned) * 100))
                                          : 0
    readonly property int totalPercent: photosVisible
                                        ? Math.floor((routePercent + _photosPercent) / 2)
                                        : routePercent

    readonly property real _hPad: ScreenTools.defaultFontPixelWidth * 1.8
    readonly property real _vPad: ScreenTools.defaultFontPixelHeight * 0.5
    readonly property real _iconSize: ScreenTools.defaultFontPixelHeight * 1.0
    readonly property real _titleSize: ScreenTools.defaultFontPointSize * 1.05
    readonly property real _labelSize: ScreenTools.defaultFontPointSize * 0.9
    readonly property real _valueSize: ScreenTools.defaultFontPointSize * 1.15
    readonly property real _metricGap: ScreenTools.defaultFontPixelWidth * 1.2

    implicitWidth: contentColumn.implicitWidth + (_hPad * 2)
    implicitHeight: contentColumn.implicitHeight + (_vPad * 2)
    width: implicitWidth
    height: implicitHeight
    radius: ScreenTools.defaultFontPixelWidth * 0.7
    color: Qt.rgba(0.03, 0.03, 0.03, 0.52)
    border.width: 0
    clip: false

    component MetricItem: Item {
        id: metric

        property string iconSource
        property string labelText
        property string valueText
        property bool coloredIcon: true
        property real iconScale: 1.0

        // Size to content so long labels like "Reconstruction" are never clipped
        implicitWidth: Math.max(headerRow.implicitWidth,
                                valueLabel.anchors.leftMargin + valueLabel.implicitWidth)
        implicitHeight: headerRow.implicitHeight + valueLabel.implicitHeight + 2
        width: implicitWidth
        height: implicitHeight

        Row {
            id: headerRow
            anchors.left: parent.left
            anchors.top: parent.top
            spacing: ScreenTools.defaultFontPixelWidth * 0.4

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: root._iconSize
                height: root._iconSize

                QGCColoredImage {
                    anchors.centerIn: parent
                    width: parent.width * metric.iconScale
                    height: parent.height * metric.iconScale
                    visible: metric.coloredIcon
                    source: metric.coloredIcon ? metric.iconSource : ""
                    color: "white"
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                    sourceSize.width: width * 2
                    sourceSize.height: height * 2
                }

                Image {
                    anchors.centerIn: parent
                    width: parent.width * metric.iconScale
                    height: parent.height * metric.iconScale
                    visible: !metric.coloredIcon
                    source: metric.coloredIcon ? "" : metric.iconSource
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                    smooth: true
                    sourceSize.width: width * 2
                    sourceSize.height: height * 2
                }
            }

            QGCLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: metric.labelText
                font.pointSize: root._labelSize
                color: Qt.rgba(1, 1, 1, 0.92)
            }
        }

        QGCLabel {
            id: valueLabel
            anchors.left: parent.left
            anchors.leftMargin: root._iconSize + ScreenTools.defaultFontPixelWidth * 0.4
            anchors.top: headerRow.bottom
            anchors.topMargin: 1
            text: metric.valueText
            font.pointSize: root._valueSize
            font.weight: Font.Medium
            color: "white"
        }
    }

    Column {
        id: contentColumn
        x: root._hPad
        y: root._vPad
        spacing: ScreenTools.defaultFontPixelHeight * 0.28

        QGCLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Total Progress %1%").arg(root.totalPercent)
            font.pointSize: root._titleSize
            font.weight: Font.DemiBold
            color: "white"
        }

        Rectangle {
            width: metricsRow.width
            height: Math.max(6, ScreenTools.defaultFontPixelHeight * 0.42)
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.2)

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, root.totalPercent / 100.0))
                height: parent.height
                radius: parent.radius
                color: "#6beb17"

                Behavior on width {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
        Row {
            id: metricsRow
            spacing: root._metricGap

            MetricItem {
                iconSource: "/res/modern-icons/MappingProgressRoute.svg"
                labelText: qsTr("Route")
                valueText: root.routePercent + "%"
            }

            MetricItem {
                visible: root.photosVisible
                iconSource: "/res/modern-icons/MappingProgressPhotos.svg"
                labelText: qsTr("Photos")
                valueText: root.photosTaken + " / " + root.photosPlanned
            }

            MetricItem {
                visible: root.photosVisible
                iconSource: "/res/modern-icons/MappingProgressReconstruction.svg"
                labelText: qsTr("Reconstruction")
                valueText: root.reconstructionText
            }
        }
    }
}
