import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id:             _summaryRoot
    anchors.fill:   parent
    anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.4
    anchors.leftMargin:  ScreenTools.defaultFontPixelWidth * 0.4
    color:          typeof setupView !== "undefined" && setupView ? setupView._pageBackground : qgcPal.window

    // Compact cards for the Vehicle Config side panel
    property real _minSummaryW:     ScreenTools.isTinyScreen ? ScreenTools.defaultFontPixelWidth * 16 : ScreenTools.defaultFontPixelWidth * 18
    property real _summaryBoxWidth: _minSummaryW
    property real _summaryBoxSpace: ScreenTools.defaultFontPixelWidth * 0.6

    function computeSummaryBoxSize() {
        var gap = ScreenTools.defaultFontPixelWidth * 0.6
        var idx = Math.floor((_summaryRoot.width + gap) / (_minSummaryW + gap))
        if (idx < 1) {
            _summaryBoxWidth = _summaryRoot.width
            _summaryBoxSpace = 0
        } else {
            _summaryBoxSpace = idx > 1 ? gap : 0
            var sw = _summaryBoxSpace * (idx - 1)
            _summaryBoxWidth = (_summaryRoot.width - sw) / idx
        }
    }

    function capitalizeWords(sentence) {
        return sentence.replace(/(?:^|\s)\S/g, function(a) { return a.toUpperCase(); });
    }

    QGCPalette {
        id:                 qgcPal
        colorGroupEnabled:  enabled
    }

    Component.onCompleted: {
        computeSummaryBoxSize()
    }

    onWidthChanged: {
        computeSummaryBoxSize()
    }

    QGCFlickable {
        clip:               true
        anchors.fill:       parent
        contentHeight:      summaryColumn.height
        contentWidth:       _summaryRoot.width
        flickableDirection: Flickable.VerticalFlick

        Column {
            id:             summaryColumn
            width:          _summaryRoot.width
            spacing:        ScreenTools.defaultFontPixelHeight * 0.45

            QGCLabel {
                width:			parent.width
                wrapMode:		Text.WordWrap
                color:			setupComplete ? qgcPal.text : qgcPal.warningText
                font.bold:      true
                font.pointSize: ScreenTools.smallFontPointSize
                horizontalAlignment: Text.AlignHCenter
                text:           setupComplete ?
                    qsTr("Your vehicle configuration summary appears below. Select components on the left to review or fine-tune settings.") :
                    qsTr("WARNING: Configuration tasks remain before this vehicle is ready to fly. Open the red-marked components on the left to finish setup.")

                property bool setupComplete: QGroundControl.multiVehicleManager.activeVehicle ? QGroundControl.multiVehicleManager.activeVehicle.autopilotPlugin.setupComplete : false
            }

            Flow {
                id:         _flowCtl
                width:      _summaryRoot.width
                spacing:    _summaryBoxSpace

                Repeater {
                    model: QGroundControl.multiVehicleManager.activeVehicle ? QGroundControl.multiVehicleManager.activeVehicle.autopilotPlugin.vehicleComponents : undefined

                    // Outer summary item rectangle
                    Rectangle {
                        width:      _summaryBoxWidth
                        height:     ScreenTools.defaultFontPixelHeight * 10.5
                        color:      qgcPal.windowShade
                        visible:    modelData.summaryQmlSource.toString() !== ""
                        border.width: 1
                        border.color: qgcPal.text
                        Component.onCompleted: {
                            border.color = Qt.rgba(border.color.r, border.color.g, border.color.b, 0.1)
                        }

                        readonly property real titleHeight: ScreenTools.defaultFontPixelHeight * 1.65

                        // Title bar
                        QGCButton {
                            id:     titleBar
                            width:  parent.width
                            height: titleHeight
                            text:   capitalizeWords(modelData.name)

                            // Setup indicator
                            Rectangle {
                                anchors.rightMargin:    ScreenTools.defaultFontPixelWidth * 0.5
                                anchors.right:          parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width:                  ScreenTools.defaultFontPixelWidth * 1.25
                                height:                 width
                                radius:                 width / 2
                                color:                  modelData.setupComplete ? "#00d932" : "red"
                                visible:                modelData.requiresSetup && modelData.setupSource !== ""
                            }

                            onClicked : {
                                if (modelData.setupSource !== "") {
                                    setupView.showVehicleComponentPanel(modelData)
                                }
                            }
                        }
                        // Summary Qml
                        Rectangle {
                            anchors.top:    titleBar.bottom
                            anchors.bottom: parent.bottom
                            width:          parent.width
                            color:          "transparent"
                            Loader {
                                anchors.fill:       parent
                                anchors.margins:    ScreenTools.defaultFontPixelWidth * 0.45
                                source:             modelData.summaryQmlSource

                                property var vehicleComponent: modelData
                            }
                        }
                    }
                }
            }
        }
    }
}
