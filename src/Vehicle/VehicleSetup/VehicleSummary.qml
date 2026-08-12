import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

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
                color:			setupComplete ? "#8E8E93" : qgcPal.warningText
                font.bold:      true
                font.pointSize: ScreenTools.smallFontPointSize
                horizontalAlignment: Text.AlignHCenter
                text:           setupComplete ?
                    qsTr("Your vehicle configuration summary appears below. Select components on the left to review or fine-tune settings.") :
                    qsTr("WARNING: Configuration tasks remain before this vehicle is ready to fly. Open the red-marked components on the left to finish setup.")

                property bool setupComplete: QGroundControl.multiVehicleManager.activeVehicle ? QGroundControl.multiVehicleManager.activeVehicle.autopilotPlugin.setupComplete : false
            }

            Column {
                id:         _flowCtl
                width:      _summaryRoot.width - ScreenTools.defaultFontPixelWidth * 4
                x:          ScreenTools.defaultFontPixelWidth * 2
                spacing:    ScreenTools.defaultFontPixelHeight * 0.8

                Repeater {
                    model: QGroundControl.multiVehicleManager.activeVehicle ? QGroundControl.multiVehicleManager.activeVehicle.autopilotPlugin.vehicleComponents : undefined

                    // One full-width row per component
                    Rectangle {
                        id:           rowCard
                        width:        _flowCtl.width
                        height:       ScreenTools.defaultFontPixelHeight * 8.5
                        visible:      modelData.summaryQmlSource.toString() !== ""
                        radius:       4
                        border.width: 1
                        clip:         true

                        readonly property real _titleColW:  ScreenTools.defaultFontPixelWidth * 16
                        readonly property real _innerPadH:  ScreenTools.defaultFontPixelWidth  * 1.2
                        readonly property real _innerPadV:  ScreenTools.defaultFontPixelHeight * 0.7
                        readonly property bool _hovered:    rowMouse.containsMouse
                        readonly property bool _pressed:    rowMouse.pressed

                        // Smooth background color transition
                        color: {
                            if (_pressed)
                                return Qt.rgba(0, 160/255, 76/255, 0.18)
                            if (_hovered)
                                return Qt.rgba(0, 160/255, 76/255, 0.08)
                            return qgcPal.windowShade
                        }
                        Behavior on color { ColorAnimation { duration: 180 } }

                        border.color: {
                            if (_hovered || _pressed)
                                return Qt.rgba(0, 160/255, 76/255, 0.55)
                            return Qt.rgba(qgcPal.text.r, qgcPal.text.g, qgcPal.text.b, 0.15)
                        }
                        Behavior on border.color { ColorAnimation { duration: 180 } }

                        // Green left accent bar — slides in on hover
                        Rectangle {
                            id:               accentBar
                            anchors.left:     parent.left
                            anchors.top:      parent.top
                            anchors.bottom:   parent.bottom
                            width:            3
                            radius:           2
                            color:            "#00a04c"
                            opacity:          rowCard._hovered || rowCard._pressed ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                            x:                rowCard._hovered || rowCard._pressed ? 0 : -3
                            Behavior on x     { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                        }

                        // Row title sidebar — title centered at top, then horizontal line
                        Item {
                            id:                   titleBar
                            anchors.left:         parent.left
                            anchors.top:          parent.top
                            anchors.bottom:       parent.bottom
                            anchors.leftMargin:   parent._innerPadH + 3  // offset for accent bar
                            anchors.topMargin:    parent._innerPadV
                            anchors.bottomMargin: parent._innerPadV
                            width:                parent._titleColW

                            ColumnLayout {
                                anchors.fill: parent
                                spacing:      ScreenTools.defaultFontPixelHeight * 0.35

                                // Title centered at top
                                Item {
                                    Layout.fillWidth:   true
                                    Layout.preferredHeight: titleLabel.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.1

                                    QGCLabel {
                                        id:                 titleLabel
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.verticalCenter:   parent.verticalCenter
                                        text:               capitalizeWords(modelData.name)
                                        font.bold:          rowCard._hovered || rowCard._pressed
                                        color:              rowCard._hovered || rowCard._pressed
                                                            ? "#00a04c"
                                                            : qgcPal.text
                                        font.pointSize:     ScreenTools.defaultFontPointSize
                                        horizontalAlignment: Text.AlignHCenter
                                        Behavior on color { ColorAnimation { duration: 180 } }
                                    }

                                    // Setup indicator dot
                                    Rectangle {
                                        anchors.right:          parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.rightMargin:    ScreenTools.defaultFontPixelWidth * 0.15
                                        width:                  ScreenTools.defaultFontPixelWidth * 1.3
                                        height:                 width
                                        radius:                 width / 2
                                        color:                  modelData.setupComplete ? "#00d932" : "red"
                                        visible:                modelData.requiresSetup && modelData.setupSource !== ""
                                    }
                                }

                                // Horizontal line below title
                                Rectangle {
                                    Layout.fillWidth:   true
                                    Layout.preferredHeight: 1
                                    color:  rowCard._hovered || rowCard._pressed
                                            ? Qt.rgba(0, 160/255, 76/255, 0.45)
                                            : Qt.rgba(qgcPal.text.r, qgcPal.text.g, qgcPal.text.b, 0.18)
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                }

                                // Component icon in remaining space below the line
                                Item {
                                    Layout.fillWidth:   true
                                    Layout.fillHeight:  true
                                    visible:            modelData.iconResource !== ""

                                    QGCColoredImage {
                                        anchors.centerIn: parent
                                        width:            Math.min(parent.width * 0.55, parent.height * 0.7)
                                        height:           width
                                        source:           modelData.iconResource
                                        color:            rowCard._hovered || rowCard._pressed
                                                          ? "#00a04c"
                                                          : "#8E8E93"
                                        fillMode:         Image.PreserveAspectFit
                                        Behavior on color { ColorAnimation { duration: 180 } }
                                    }
                                }
                            }
                        }

                        // Vertical divider
                        Rectangle {
                            anchors.left:         titleBar.right
                            anchors.top:          parent.top
                            anchors.bottom:       parent.bottom
                            anchors.topMargin:    parent._innerPadV
                            anchors.bottomMargin: parent._innerPadV
                            width:                1
                            color:                rowCard._hovered || rowCard._pressed
                                                  ? Qt.rgba(0, 160/255, 76/255, 0.4)
                                                  : Qt.rgba(qgcPal.text.r, qgcPal.text.g, qgcPal.text.b, 0.15)
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }

                        // Right: summary content
                        Loader {
                            anchors.left:         titleBar.right
                            anchors.right:        parent.right
                            anchors.top:          parent.top
                            anchors.bottom:       parent.bottom
                            anchors.leftMargin:   parent._innerPadH
                            anchors.rightMargin:  parent._innerPadH
                            anchors.topMargin:    parent._innerPadV
                            anchors.bottomMargin: parent._innerPadV
                            source:               modelData.summaryQmlSource

                            property var vehicleComponent: modelData
                        }

                        // Hover + click mouse area over whole row
                        MouseArea {
                            id:             rowMouse
                            anchors.fill:   parent
                            hoverEnabled:   true
                            cursorShape:    modelData.setupSource !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (modelData.setupSource !== "") {
                                    setupView.showVehicleComponentPanel(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
