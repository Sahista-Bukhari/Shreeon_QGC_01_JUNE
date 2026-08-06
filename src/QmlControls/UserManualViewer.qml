import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls

Item {
    id: root
    anchors.fill: parent
    visible: false
    z: QGroundControl.zOrderTopMost + 80

    readonly property color _toolbarBg:     "#1C1C1E"
    readonly property color _pageBg:        "#F2F2F7"
    readonly property color _accentGreen:   "#00C853"
    readonly property color _textLight:     "#FFFFFF"
    readonly property color _textMuted:     "#AEAEB2"
    readonly property real  _toolbarHeight: ScreenTools.defaultFontPixelHeight * 3.2
    readonly property real  _buttonSize:    ScreenTools.defaultFontPixelHeight * 2.1
    readonly property real  _minZoom:       0.5
    readonly property real  _maxZoom:       3.0
    readonly property real  _zoomStep:      0.15

    property real   zoomFactor: 1.0
    property var    pageUrls: []
    property string pdfPath: ""
    property bool   loading: false
    property string statusMessage: ""

    signal closed
    signal goHomeRequested

    function open() {
        root.visible = true
        root.zoomFactor = 1.0
        flickable.contentX = 0
        flickable.contentY = 0
        root._loadPdf()
    }

    function close() {
        root.visible = false
        root.closed()
    }

    function goHome() {
        root.visible = false
        root.goHomeRequested()
    }

    function zoomIn() {
        root.zoomFactor = Math.min(root._maxZoom, Number((root.zoomFactor + root._zoomStep).toFixed(2)))
    }

    function zoomOut() {
        root.zoomFactor = Math.max(root._minZoom, Number((root.zoomFactor - root._zoomStep).toFixed(2)))
    }

    function _loadPdf() {
        root.loading = true
        root.statusMessage = qsTr("Loading user manual...")
        root.pageUrls = []
        root.pdfPath = QGCFileDialogController.resolveUserManualPdfPath()

        if (!root.pdfPath || root.pdfPath.length === 0) {
            root.loading = false
            root.statusMessage = qsTr("User manual PDF not found.")
            return
        }

        const pages = QGCFileDialogController.renderPdfPages(root.pdfPath, 130)
        root.pageUrls = pages
        root.loading = false

        if (!pages || pages.length === 0) {
            root.statusMessage = qsTr("Unable to render PDF. Make sure poppler-utils (pdftoppm) is installed.")
        } else {
            root.statusMessage = ""
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root._pageBg
    }

    Rectangle {
        id: toolbar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root._toolbarHeight
        color: root._toolbarBg
        z: 2

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 1.2
            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 1.2
            spacing: ScreenTools.defaultFontPixelWidth

            // Back to Custom Home Page
            Rectangle {
                Layout.preferredWidth: root._buttonSize
                Layout.preferredHeight: root._buttonSize
                radius: width / 2
                color: backMouse.pressed ? "#3A3A3C" : "#2C2C2E"

                QGCColoredImage {
                    anchors.centerIn: parent
                    width: parent.width * 0.55
                    height: parent.height * 0.55
                    source: "qrc:/res/buttonLeft.svg"
                    color: root._textLight
                    fillMode: Image.PreserveAspectFit
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.goHome()
                }
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("User Manual")
                color: root._textLight
                font.family: ScreenTools.normalFontFamily
                font.pointSize: ScreenTools.defaultFontPointSize * 1.15
                font.weight: Font.Bold
                elide: Text.ElideRight
            }

            // Zoom out
            Rectangle {
                Layout.preferredWidth: root._buttonSize
                Layout.preferredHeight: root._buttonSize
                radius: width / 2
                color: zoomOutMouse.pressed ? "#3A3A3C" : "#2C2C2E"

                Text {
                    anchors.centerIn: parent
                    text: "−"
                    color: root._textLight
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 1.4
                    font.weight: Font.Bold
                }

                MouseArea {
                    id: zoomOutMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.zoomOut()
                }
            }

            Text {
                text: Math.round(root.zoomFactor * 100) + "%"
                color: root._textMuted
                font.family: ScreenTools.normalFontFamily
                font.pointSize: ScreenTools.defaultFontPointSize * 0.9
                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 5
                horizontalAlignment: Text.AlignHCenter
            }

            // Zoom in
            Rectangle {
                Layout.preferredWidth: root._buttonSize
                Layout.preferredHeight: root._buttonSize
                radius: width / 2
                color: zoomInMouse.pressed ? "#3A3A3C" : "#2C2C2E"

                Text {
                    anchors.centerIn: parent
                    text: "+"
                    color: root._textLight
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 1.35
                    font.weight: Font.Bold
                }

                MouseArea {
                    id: zoomInMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.zoomIn()
                }
            }

            // Download
            Rectangle {
                Layout.preferredWidth: Math.max(root._buttonSize * 2.4, ScreenTools.defaultFontPixelWidth * 12)
                Layout.preferredHeight: root._buttonSize
                radius: height * 0.28
                color: downloadMouse.pressed ? "#00A844" : root._accentGreen

                Text {
                    anchors.centerIn: parent
                    text: qsTr("Download")
                    color: root._textLight
                    font.family: ScreenTools.normalFontFamily
                    font.pointSize: ScreenTools.defaultFontPointSize * 0.95
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: downloadMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.pdfPath || root.pdfPath.length === 0) {
                            mainWindow.showMessageDialog(qsTr("Download"), qsTr("User manual PDF not found."))
                            return
                        }
                        downloadDialog.openForSave()
                    }
                }
            }
        }
    }

    Flickable {
        id: flickable
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: toolbar.bottom
        anchors.bottom: parent.bottom
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: pagesColumn.width
        contentHeight: pagesColumn.height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
            id: pagesColumn
            width: Math.max(flickable.width, flickable.width * root.zoomFactor)
            spacing: ScreenTools.defaultFontPixelHeight * 0.8
            topPadding: ScreenTools.defaultFontPixelHeight
            bottomPadding: ScreenTools.defaultFontPixelHeight
            leftPadding: ScreenTools.defaultFontPixelWidth
            rightPadding: ScreenTools.defaultFontPixelWidth

            Repeater {
                model: root.pageUrls

                delegate: Rectangle {
                    width: Math.max(1, (flickable.width - pagesColumn.leftPadding - pagesColumn.rightPadding) * root.zoomFactor)
                    height: pageImage.status === Image.Ready
                            ? pageImage.implicitHeight * (width / Math.max(1, pageImage.implicitWidth))
                            : ScreenTools.defaultFontPixelHeight * 20
                    color: "white"
                    border.color: "#D1D1D6"
                    border.width: 1
                    anchors.horizontalCenter: parent.horizontalCenter

                    Image {
                        id: pageImage
                        anchors.fill: parent
                        source: modelData
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        mipmap: true
                        cache: true
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.7, ScreenTools.defaultFontPixelWidth * 42)
        height: statusColumn.implicitHeight + ScreenTools.defaultFontPixelHeight * 2
        radius: ScreenTools.defaultFontPixelHeight * 0.5
        color: Qt.rgba(0, 0, 0, 0.72)
        visible: root.loading || root.statusMessage.length > 0
        z: 3

        Column {
            id: statusColumn
            anchors.centerIn: parent
            spacing: ScreenTools.defaultFontPixelHeight * 0.5
            width: parent.width - ScreenTools.defaultFontPixelWidth * 3

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: root.loading
                visible: root.loading
                width: ScreenTools.defaultFontPixelHeight * 2
                height: width
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: "white"
                font.family: ScreenTools.normalFontFamily
                font.pointSize: ScreenTools.defaultFontPointSize
                text: root.statusMessage
                visible: text.length > 0
            }
        }
    }

    QGCFileDialog {
        id: downloadDialog
        title: qsTr("Save User Manual")
        nameFilters: [ qsTr("PDF files (*.pdf)") ]
        defaultSuffix: "pdf"
        suggestedFileName: "Agriculture drone.pdf"
        folder: QGroundControl.settingsManager.appSettings.savePath.valueString

        onAcceptedForSave: function(file) {
            if (QGCFileDialogController.copyFile(root.pdfPath, file)) {
                mainWindow.showMessageDialog(qsTr("Download"), qsTr("User manual saved successfully."))
            } else {
                mainWindow.showMessageDialog(qsTr("Download"), qsTr("Failed to save the user manual PDF."))
            }
        }
    }
}
