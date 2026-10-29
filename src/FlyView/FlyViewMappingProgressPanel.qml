import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id: root

    property int routePercent: 0
    property int photosTaken: 0
    property int photosRetrieved: 0
    property int photosPlanned: 0
    property int photoFailures: 0
    property int triggersReceived: 0
    property bool photosVisible: true
    property var photoModel: null
    property string reconstructionText: qsTr("Pending")
    property bool reconstructionReady: false
    property bool reconstructionRunning: false
    property bool reconstructionComplete: false
    property int reconstructionProgress: 0
    property bool orthomosaicVisible: false
    property bool orthomosaicLoading: false
    property real orthomosaicOpacity: 0.82

    signal reconstructionRequested()
    signal stitchFromDirectoryRequested()
    signal orthomosaicLoadRequested()
    signal orthomosaicHideRequested()
    signal orthomosaicOpacityEdited(real opacity)

    readonly property real _thumbSize: ScreenTools.defaultFontPixelHeight * 4.2

    readonly property int _photosPercent: photosPlanned > 0
                                          ? Math.min(100, Math.floor((photosTaken / photosPlanned) * 100))
                                          : 0
    readonly property bool _reconstructionPhaseActive: reconstructionReady
                                                        || reconstructionRunning
                                                        || reconstructionComplete
    readonly property int _reconstructionPercent: reconstructionComplete
                                                   ? 100
                                                   : (reconstructionRunning
                                                      ? reconstructionProgress
                                                      : 0)
    readonly property int totalPercent: !photosVisible ? routePercent
                                        : (_reconstructionPhaseActive
                                           ? Math.floor((routePercent
                                                         + _photosPercent
                                                         + _reconstructionPercent) / 3)
                                           : (photosTaken > 0
                                              ? Math.floor((routePercent + _photosPercent) / 2)
                                              : routePercent))

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
                labelText: qsTr("Triggers")
                valueText: root.photosTaken + " / " + root.photosPlanned
            }

            MetricItem {
                visible: root.photosVisible
                iconSource: "/res/modern-icons/MappingProgressPhotos.svg"
                coloredIcon: false
                iconScale: 0.85
                labelText: qsTr("On GCS")
                valueText: root.photosRetrieved + " / " + root.photosPlanned
            }

            MetricItem {
                visible: root.photosVisible
                iconSource: "/res/modern-icons/MappingProgressReconstruction.svg"
                labelText: qsTr("Reconstruction")
                valueText: root.reconstructionText
            }
        }

        QGCButton {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.photosVisible && (root.reconstructionReady || root.reconstructionRunning)
            enabled: root.reconstructionReady && !root.reconstructionRunning
            text: root.reconstructionRunning
                  ? root.reconstructionText
                  : qsTr("Start ODM Stitching")
            onClicked: root.reconstructionRequested()
        }

        ProgressBar {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.photosVisible && root.reconstructionRunning
            width: metricsRow.width
            from: 0
            to: 100
            value: root.reconstructionProgress
        }

        RowLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.photosVisible
            spacing: ScreenTools.defaultFontPixelWidth * 0.7

            QGCButton {
                enabled: !root.reconstructionRunning && !root.orthomosaicLoading
                text: qsTr("Stitch from Photos Directory")
                onClicked: root.stitchFromDirectoryRequested()
            }
        }

        RowLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.photosVisible
            spacing: ScreenTools.defaultFontPixelWidth * 0.7

            QGCButton {
                enabled: !root.reconstructionRunning && !root.orthomosaicLoading
                text: root.orthomosaicLoading
                      ? qsTr("Loading Orthomosaic...")
                      : (root.orthomosaicVisible
                         ? qsTr("Replace Orthomosaic")
                         : qsTr("Load Previous Orthomosaic"))
                onClicked: root.orthomosaicLoadRequested()
            }

            QGCButton {
                visible: root.orthomosaicVisible
                text: qsTr("Hide")
                onClicked: root.orthomosaicHideRequested()
            }
        }

        RowLayout {
            visible: root.orthomosaicVisible
            width: metricsRow.width
            spacing: ScreenTools.defaultFontPixelWidth * 0.7

            QGCLabel {
                text: qsTr("Orthomosaic")
                color: Qt.rgba(1, 1, 1, 0.92)
                font.pointSize: root._labelSize
            }

            QGCSlider {
                id: orthomosaicOpacitySlider
                Layout.fillWidth: true
                from: 0
                to: 1
                stepSize: 0.01
                value: root.orthomosaicOpacity
                activeColor: "#6beb17"
                onMoved: root.orthomosaicOpacityEdited(value)
            }

            QGCLabel {
                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 4.5
                horizontalAlignment: Text.AlignRight
                text: Math.round(root.orthomosaicOpacity * 100) + "%"
                color: "white"
                font.pointSize: root._labelSize
            }
        }

        QGCLabel {
            visible: root.photosVisible && root.photoFailures > 0
            // Keep camera/transfer failures separate from accepted-trigger
            // totals. A reconciled position-schedule marker is not a failure.
            text: qsTr("Capture/transfer issues: %1").arg(root.photoFailures)
            font.pointSize: ScreenTools.smallFontPointSize
            color: "#ffb74d"
        }

        QGCLabel {
            visible: root.photosVisible && root.photoModel && root.photoModel.count > 0
            text: qsTr("Captured Images")
            font.pointSize: root._labelSize
            font.weight: Font.Medium
            color: Qt.rgba(1, 1, 1, 0.92)
        }

        Flickable {
            id: photoStrip
            visible: root.photosVisible && root.photoModel && root.photoModel.count > 0
            width: Math.min(ScreenTools.defaultFontPixelWidth * 28, metricsRow.width)
            height: root._thumbSize + ScreenTools.defaultFontPixelHeight * 0.4
            contentWidth: photoStripRow.width
            clip: true

            Row {
                id: photoStripRow
                spacing: ScreenTools.defaultFontPixelWidth * 0.5

                Repeater {
                    model: root.photoModel

                    Rectangle {
                        required property int photoSequence
                        required property string photoImageSource
                        required property bool photoPlaceholder

                        width: root._thumbSize
                        height: root._thumbSize
                        radius: ScreenTools.defaultFontPixelWidth * 0.35
                        color: photoPlaceholder ? "#3a454c" : "#263238"
                        border.width: photoPlaceholder ? 2 : 1
                        border.color: photoPlaceholder
                                      ? Qt.rgba(0.43, 0.92, 0.09, 0.75)
                                      : Qt.rgba(1, 1, 1, 0.35)

                        Image {
                            anchors.fill: parent
                            anchors.margins: 1
                            visible: photoImageSource.length > 0
                            source: photoImageSource
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            sourceSize.width: Math.ceil(width * 2)
                            sourceSize.height: Math.ceil(height * 2)
                            smooth: true
                        }

                        QGCLabel {
                            anchors.centerIn: parent
                            visible: photoImageSource.length === 0
                            text: String(photoSequence)
                            font.bold: photoPlaceholder
                            font.pointSize: photoPlaceholder
                                          ? ScreenTools.defaultFontPointSize
                                          : ScreenTools.smallFontPointSize
                            color: "white"
                        }

                        QGCLabel {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 2
                            visible: photoImageSource.length > 0
                            text: String(photoSequence)
                            font.pointSize: ScreenTools.smallFontPointSize
                            color: "white"
                        }
                    }
                }
            }
        }
    }
}
