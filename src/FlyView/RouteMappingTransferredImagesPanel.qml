import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id: root

    property bool routeMappingActive: false

    readonly property real _pad: ScreenTools.defaultFontPixelWidth * 0.75
    readonly property int _thumbSize: ScreenTools.defaultFontPixelHeight * 5

    implicitWidth: Math.min(ScreenTools.defaultFontPixelWidth * 28, _thumbSize * 2 + _pad * 3)
    implicitHeight: titleRow.height + grid.contentHeight + _pad * 2
    radius: ScreenTools.defaultFontPixelWidth * 0.5
    color: Qt.rgba(0.03, 0.03, 0.03, 0.55)
    clip: true

    visible: routeMappingActive
             && (QGroundControl.routeMappingImageCatalog.count > 0
                 || QGroundControl.routeMappingPiPhotoCapture.busy)

    Row {
        id: titleRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root._pad
        spacing: ScreenTools.defaultFontPixelWidth * 0.5

        QGCLabel {
            text: qsTr("Pi photos (%1)").arg(QGroundControl.routeMappingImageCatalog.count)
            color: "white"
            font.bold: true
        }
    }

    GridView {
        id: grid

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: titleRow.bottom
        anchors.margins: root._pad
        height: Math.min(contentHeight, root._thumbSize * 2 + root._pad)
        cellWidth: root._thumbSize + root._pad
        cellHeight: root._thumbSize + ScreenTools.defaultFontPixelHeight * 1.2
        model: QGroundControl.routeMappingImageCatalog

        delegate: Item {
            width: grid.cellWidth
            height: grid.cellHeight

            Rectangle {
                anchors.top: parent.top
                width: root._thumbSize
                height: root._thumbSize
                color: "#263238"
                border.color: Qt.rgba(1, 1, 1, 0.35)

                Image {
                    anchors.fill: parent
                    source: model.fileUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }
            }

            QGCLabel {
                anchors.top: parent.top
                anchors.topMargin: root._thumbSize + 2
                width: root._thumbSize
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: model.fileName
                color: Qt.rgba(1, 1, 1, 0.9)
                font.pointSize: ScreenTools.smallFontPointSize
            }
        }
    }

    Connections {
        target: QGroundControl.routeMappingPiPhotoCapture
        function onCaptureSucceeded(path) {
            QGroundControl.routeMappingImageCatalog.refresh()
        }
    }
}
