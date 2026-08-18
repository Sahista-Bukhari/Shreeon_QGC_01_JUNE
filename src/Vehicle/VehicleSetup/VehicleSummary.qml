import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id:             _summaryRoot
    anchors.fill:   parent
    color:          qgcPal.globalTheme === QGCPalette.Dark ? qgcPal.window : "white"

    readonly property real  _pageHPad:      ScreenTools.defaultFontPixelWidth * 2.2
    readonly property real  _cardGap:       ScreenTools.defaultFontPixelHeight * 0.7
    readonly property real  _cardRadius:    ScreenTools.defaultFontPixelWidth * 0.7
    readonly property real  _textPad:       ScreenTools.defaultFontPixelWidth * 1.6
    readonly property real  _cardW:         Math.max(0, width - _pageHPad * 2)
    readonly property color _titleColor:    qgcPal.globalTheme === QGCPalette.Dark ? "#AEAEB2" : "#3A3A3C"
    readonly property color _bodyColor:     qgcPal.globalTheme === QGCPalette.Dark ? "#8E8E93" : "#3A3A3C"
    readonly property color _cardColor:     qgcPal.globalTheme === QGCPalette.Dark ? qgcPal.windowShade : "white"
    readonly property color _innerGray:     qgcPal.globalTheme === QGCPalette.Dark ? qgcPal.window : "#F2F2F2"
    readonly property color _cardBorder:    qgcPal.globalTheme === QGCPalette.Dark
                                            ? Qt.rgba(1, 1, 1, 0.12)
                                            : "#E5E5EA"
    readonly property color _dividerColor:  qgcPal.globalTheme === QGCPalette.Dark
                                            ? Qt.rgba(1, 1, 1, 0.12)
                                            : "#E5E5EA"
    readonly property color _badgeGreen:    "#00a04c"
    readonly property color _badgeOrange:   "#E67E22"

    function computeSummaryBoxSize() { }

    function capitalizeWords(sentence) {
        return sentence.replace(/(?:^|\s)\S/g, function(a) { return a.toUpperCase(); })
    }

    function summaryContentHeight(loadedItem) {
        if (!loadedItem)
            return ScreenTools.defaultFontPixelHeight * 4
        var col = loadedItem.children.length > 0 ? loadedItem.children[0] : loadedItem
        var h = col.childrenRect ? col.childrenRect.height : 0
        if (h < 1 && col.implicitHeight)
            h = col.implicitHeight
        return Math.max(h, ScreenTools.defaultFontPixelHeight * 3)
    }

    QGCPalette {
        id:                 qgcPal
        colorGroupEnabled:  enabled
    }

    QGCFlickable {
        clip:               true
        anchors.fill:       parent
        contentHeight:      summaryColumn.height + ScreenTools.defaultFontPixelHeight
        contentWidth:       _summaryRoot.width
        flickableDirection: Flickable.VerticalFlick

        Column {
            id:         summaryColumn
            width:      _summaryRoot.width
            spacing:    ScreenTools.defaultFontPixelHeight * 0.55
            topPadding: ScreenTools.defaultFontPixelHeight * 0.25

            QGCLabel {
                x:                  _summaryRoot._pageHPad
                width:              parent.width - _summaryRoot._pageHPad * 2
                wrapMode:           Text.WordWrap
                color:              setupComplete ? _summaryRoot._bodyColor : qgcPal.warningText
                font.family:        ScreenTools.normalFontFamily
                font.pointSize:     ScreenTools.smallFontPointSize
                text:               setupComplete ?
                    qsTr("Your vehicle configuration summary appears below. Select a card to review or fine-tune settings.") :
                    qsTr("WARNING: Configuration tasks remain before this vehicle is ready to fly. Open the incomplete cards to finish setup.")

                property bool setupComplete: QGroundControl.multiVehicleManager.activeVehicle ? QGroundControl.multiVehicleManager.activeVehicle.autopilotPlugin.setupComplete : false
            }

            Column {
                x:          _summaryRoot._pageHPad
                width:      parent.width - _summaryRoot._pageHPad * 2
                spacing:    _summaryRoot._cardGap

                Repeater {
                    model: QGroundControl.multiVehicleManager.activeVehicle
                           ? QGroundControl.multiVehicleManager.activeVehicle.autopilotPlugin.vehicleComponents
                           : undefined

                    Rectangle {
                        id:         card
                        width:      visible ? _summaryRoot._cardW : 0
                        height:     visible ? innerColumn.height + ScreenTools.defaultFontPixelHeight * 0.85 : 0
                        visible:    modelData.summaryQmlSource.toString() !== ""
                        radius:     _summaryRoot._cardRadius
                        color:      _summaryRoot._cardColor
                        border.width: 1
                        border.color: _summaryRoot._cardBorder
                        clip:       true

                        property bool rowsIncomplete: false
                        property bool setupOk:        modelData.setupComplete && !rowsIncomplete

                        function _hasSetupRequired(item) {
                            if (!item)
                                return false
                            if (typeof item.valueText === "string") {
                                var v = item.valueText
                                if (v === qsTr("Setup required") || v === "Setup required")
                                    return true
                            }
                            var kids = item.children
                            for (var i = 0; i < kids.length; i++) {
                                if (_hasSetupRequired(kids[i]))
                                    return true
                            }
                            return false
                        }

                        function refreshRowStatus() {
                            rowsIncomplete = _hasSetupRequired(summaryLoader.item)
                        }

                        Column {
                            id:                         innerColumn
                            anchors.left:               parent.left
                            anchors.right:              parent.right
                            anchors.top:                parent.top
                            anchors.leftMargin:         _summaryRoot._textPad
                            anchors.rightMargin:        _summaryRoot._textPad
                            anchors.topMargin:          ScreenTools.defaultFontPixelHeight * 0.55
                            spacing:                    ScreenTools.defaultFontPixelHeight * 0.45

                            RowLayout {
                                width:      parent.width
                                spacing:    ScreenTools.defaultFontPixelWidth * 0.7

                                QGCColoredImage {
                                    Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.55
                                    Layout.preferredHeight: Layout.preferredWidth
                                    Layout.alignment:       Qt.AlignVCenter
                                    visible:                modelData.iconResource !== ""
                                    source:                 modelData.iconResource
                                    color:                  _summaryRoot._titleColor
                                    fillMode:               Image.PreserveAspectFit
                                }

                                QGCLabel {
                                    Layout.fillWidth:   true
                                    text:               capitalizeWords(modelData.name)
                                    color:              _summaryRoot._titleColor
                                    font.bold:          true
                                    font.family:        ScreenTools.normalFontFamily
                                    font.pointSize:     ScreenTools.defaultFontPointSize + 1
                                    elide:              Text.ElideRight
                                }

                                Rectangle {
                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.45
                                    Layout.preferredWidth:  badgeLabel.implicitWidth + ScreenTools.defaultFontPixelWidth * 1.6
                                    Layout.minimumWidth:    ScreenTools.defaultFontPixelWidth * 8
                                    radius:                 height / 2
                                    color:                  "transparent"
                                    border.width:           1
                                    border.color:           card.setupOk ? _summaryRoot._badgeGreen : _summaryRoot._badgeOrange

                                    QGCLabel {
                                        id:                 badgeLabel
                                        anchors.centerIn:   parent
                                        text:               card.setupOk ? qsTr("Complete") : qsTr("Incomplete")
                                        color:              card.setupOk ? _summaryRoot._badgeGreen : _summaryRoot._badgeOrange
                                        font.family:        ScreenTools.normalFontFamily
                                        font.pointSize:     ScreenTools.smallFontPointSize
                                        font.bold:          true
                                    }
                                }
                            }

                            Rectangle {
                                width:      parent.width
                                height:     1
                                color:      _summaryRoot._dividerColor
                            }

                            Rectangle {
                                width:      parent.width
                                height:     summaryLoader.height + ScreenTools.defaultFontPixelHeight * 0.5
                                radius:     _summaryRoot._cardRadius
                                color:      _summaryRoot._innerGray
                                clip:       true

                                Loader {
                                    id:         summaryLoader
                                    anchors.left:           parent.left
                                    anchors.right:          parent.right
                                    anchors.top:            parent.top
                                    anchors.leftMargin:     ScreenTools.defaultFontPixelWidth * 1.1
                                    anchors.rightMargin:    ScreenTools.defaultFontPixelWidth * 1.1
                                    anchors.topMargin:      ScreenTools.defaultFontPixelHeight * 0.15
                                    height:     _summaryRoot.summaryContentHeight(item)
                                    source:     modelData.summaryQmlSource

                                    property var vehicleComponent: modelData

                                    onLoaded: {
                                        if (item) {
                                            item.anchors.fill = undefined
                                            item.width = Qt.binding(function() { return summaryLoader.width })
                                            item.height = Qt.binding(function() { return summaryLoader.height })
                                        }
                                        card.refreshRowStatus()
                                    }
                                }
                            }
                        }

                        RippleEffect {
                            id:          cardRipple
                            rippleColor: Qt.rgba(0, 0, 0, 0.12)
                            clipRadius:  _summaryRoot._cardRadius
                        }

                        MouseArea {
                            id:             cardMouse
                            anchors.fill:   parent
                            hoverEnabled:   true
                            cursorShape:    modelData.setupSource !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: function(mouse) {
                                cardRipple.tap(mouse.x, mouse.y)
                                if (modelData.setupSource !== "")
                                    setupView.showVehicleComponentPanel(modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
