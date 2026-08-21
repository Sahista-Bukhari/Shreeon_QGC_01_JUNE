import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

AnalyzePage {
    id: vibrationPage

    headerComponent:   vibrationHeaderComponent
    pageComponent:     pageComponent
    contentTopMargin:  _headerSpacing
    allowPopout:       true
    popoutIconSource:  "/qmlimages/VibrationPopout.svg"
    popoutIconColor:   _accentGreen

    readonly property var  _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
                                           ? QGroundControl.multiVehicleManager.activeVehicle
                                           : QGroundControl.multiVehicleManager.offlineEditingVehicle
    readonly property var  _vibration:     _activeVehicle ? _activeVehicle.vibration : null
    readonly property bool _available:     _vibration && _vibration.xAxis &&
                                           !isNaN(Number(_vibration.xAxis.rawValue))

    readonly property real _xValue: _available ? Number(_vibration.xAxis.rawValue) : 0
    readonly property real _yValue: _available ? Number(_vibration.yAxis.rawValue) : 0
    readonly property real _zValue: _available ? Number(_vibration.zAxis.rawValue) : 0
    readonly property real _clip1:  _vibration && _vibration.clipCount1
                                    ? Number(_vibration.clipCount1.rawValue) : 0
    readonly property real _clip2:  _vibration && _vibration.clipCount2
                                    ? Number(_vibration.clipCount2.rawValue) : 0
    readonly property real _clip3:  _vibration && _vibration.clipCount3
                                    ? Number(_vibration.clipCount3.rawValue) : 0
    readonly property real _peakValue: Math.max(_xValue, _yValue, _zValue)

    readonly property real _barMinimum:  0
    readonly property real _barMaximum:  90
    readonly property real _barMidValue: 30
    readonly property real _barBadValue: 60

    readonly property bool _darkTheme: {
        if (typeof mainWindow !== "undefined" && mainWindow)
            return mainWindow.uiThemeMode === mainWindow.themeBlack
        return vibrationPalette.globalTheme === QGCPalette.Dark
    }
    readonly property color _pageBackground:   _darkTheme ? vibrationPalette.window : "#FFFFFF"
    readonly property color _titleColor:       _darkTheme ? "#AEAEB2" : "#3A3A3C"
    readonly property color _bodyColor:        _darkTheme ? "#8E8E93" : "#5A5A5E"
    readonly property color _accentGreen:      "#00a04c"
    readonly property color _elevatedColor:    _darkTheme ? "#8B9792" : "#77857F"
    readonly property color _highColor:        _darkTheme ? "#AEAEB2" : "#5A5A5E"
    readonly property color _cardIdleFill:     _darkTheme ? vibrationPalette.window : "#FFFFFF"
    readonly property color _cardSelectedFill: Qt.rgba(0, 160 / 255, 76 / 255, _darkTheme ? 0.16 : 0.08)
    readonly property color _dataCardFill:     _darkTheme ? vibrationPalette.windowShade : "#F5F5F5"
    readonly property color _tableLine:        _darkTheme ? vibrationPalette.windowShade : "#E5E5E5"
    readonly property real  _pagePad:          ScreenTools.defaultFontPixelWidth * 2.2
    readonly property real  _controlSpacing:   ScreenTools.defaultFontPixelWidth
    readonly property real  _headerSpacing:    Math.ceil(ScreenTools.defaultFontPixelHeight * 0.65)
    readonly property real  _cardRadius:       ScreenTools.defaultFontPixelWidth * 0.9

    QGCPalette {
        id:                vibrationPalette
        colorGroupEnabled: vibrationPage.enabled
    }

    function boundedValue(value) {
        return Math.max(_barMinimum, Math.min(_barMaximum, value))
    }

    function statusForValue(value) {
        if (value >= _barBadValue)
            return qsTr("High")
        if (value >= _barMidValue)
            return qsTr("Elevated")
        return qsTr("Normal")
    }

    function colorForValue(value) {
        if (value >= _barBadValue)
            return _highColor
        if (value >= _barMidValue)
            return _elevatedColor
        return _accentGreen
    }

    component AxisCard: Rectangle {
        id: axisCard

        required property string axisName
        required property real   axisValue

        Layout.fillWidth:       true
        Layout.minimumWidth:    ScreenTools.defaultFontPixelWidth * 10
        Layout.preferredHeight: axisLayout.implicitHeight + vibrationPage._controlSpacing * 2
        radius:                 vibrationPage._cardRadius
        color:                  vibrationPage._dataCardFill
        border.width:           1
        border.color:           vibrationPage._tableLine

        ColumnLayout {
            id:              axisLayout
            anchors.fill:    parent
            anchors.margins: vibrationPage._controlSpacing
            spacing:         vibrationPage._headerSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing:          vibrationPage._controlSpacing * 0.5

                Rectangle {
                    Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.55
                    Layout.preferredHeight: Layout.preferredWidth
                    radius:                 width / 2
                    color:                  vibrationPage._cardSelectedFill
                    border.width:           1
                    border.color:           vibrationPage._accentGreen

                    QGCLabel {
                        anchors.centerIn: parent
                        text:             axisCard.axisName
                        color:            vibrationPage._accentGreen
                        font.weight:      Font.DemiBold
                    }
                }

                Item { Layout.fillWidth: true }

                QGCLabel {
                    text:        axisCard.axisValue.toFixed(1)
                    color:       vibrationPage.colorForValue(axisCard.axisValue)
                    font.weight: Font.DemiBold
                }
            }

            QGCLabel {
                Layout.fillWidth: true
                text:             qsTr("%1 axis vibration").arg(axisCard.axisName)
                color:            vibrationPage._titleColor
                font.weight:      Font.DemiBold
                elide:            Text.ElideRight
            }

            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: Math.max(8, ScreenTools.defaultFontPixelHeight * 0.55)
                radius:                 height / 2
                color:                  vibrationPage._cardIdleFill
                border.width:           1
                border.color:           vibrationPage._tableLine
                clip:                   true

                Rectangle {
                    anchors.left:   parent.left
                    anchors.top:    parent.top
                    anchors.bottom: parent.bottom
                    width:          parent.width * vibrationPage.boundedValue(axisCard.axisValue) /
                                    (vibrationPage._barMaximum - vibrationPage._barMinimum)
                    radius:         parent.radius
                    color:          vibrationPage.colorForValue(axisCard.axisValue)

                    Behavior on width {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    Behavior on color {
                        ColorAnimation { duration: 140 }
                    }
                }

                Rectangle {
                    x:       parent.width * vibrationPage._barMidValue / vibrationPage._barMaximum
                    width:   1
                    height:  parent.height
                    color:   vibrationPage._bodyColor
                    opacity: 0.45
                }

                Rectangle {
                    x:       parent.width * vibrationPage._barBadValue / vibrationPage._barMaximum
                    width:   1
                    height:  parent.height
                    color:   vibrationPage._bodyColor
                    opacity: 0.65
                }
            }

            RowLayout {
                Layout.fillWidth: true

                QGCLabel {
                    text:           "0"
                    color:          vibrationPage._bodyColor
                    font.pointSize: ScreenTools.smallFontPointSize
                }

                Item { Layout.fillWidth: true }

                QGCLabel {
                    text:           "30"
                    color:          vibrationPage._bodyColor
                    font.pointSize: ScreenTools.smallFontPointSize
                }

                Item { Layout.fillWidth: true }

                QGCLabel {
                    text:           "60"
                    color:          vibrationPage._bodyColor
                    font.pointSize: ScreenTools.smallFontPointSize
                }

                Item { Layout.fillWidth: true }

                QGCLabel {
                    text:           "90"
                    color:          vibrationPage._bodyColor
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }

            QGCLabel {
                Layout.fillWidth:    true
                text:                vibrationPage.statusForValue(axisCard.axisValue)
                color:               vibrationPage.colorForValue(axisCard.axisValue)
                font.weight:         Font.DemiBold
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    component ClipRow: Rectangle {
        id: clipRow

        required property string sensorName
        required property real   clipCount

        Layout.fillWidth:       true
        Layout.preferredHeight: clipRowLayout.implicitHeight + vibrationPage._headerSpacing * 1.4
        radius:                 vibrationPage._cardRadius * 0.65
        color:                  vibrationPage._cardIdleFill
        border.width:           1
        border.color:           vibrationPage._tableLine

        RowLayout {
            id:                  clipRowLayout
            anchors.fill:        parent
            anchors.leftMargin:  vibrationPage._controlSpacing
            anchors.rightMargin: vibrationPage._controlSpacing
            spacing:             vibrationPage._controlSpacing

            Rectangle {
                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 0.55
                Layout.preferredHeight: Layout.preferredWidth
                radius:                 width / 2
                color:                  clipRow.clipCount === 0
                                        ? vibrationPage._accentGreen
                                        : vibrationPage._highColor
            }

            QGCLabel {
                Layout.fillWidth: true
                text:             clipRow.sensorName
                color:            vibrationPage._titleColor
            }

            QGCLabel {
                text:        qsTr("%1 clips").arg(clipRow.clipCount.toFixed(0))
                color:       clipRow.clipCount === 0
                             ? vibrationPage._accentGreen
                             : vibrationPage._highColor
                font.weight: Font.DemiBold
            }
        }
    }

    Component {
        id: vibrationHeaderComponent

        Item {
            implicitHeight: vibrationHeaderLayout.implicitHeight

            ColumnLayout {
                id:                  vibrationHeaderLayout
                anchors.left:        parent.left
                anchors.right:       parent.right
                anchors.leftMargin:  vibrationPage._pagePad
                anchors.rightMargin: vibrationPage._pagePad
                spacing:             vibrationPage._headerSpacing

                QGCLabel {
                    Layout.fillWidth: true
                    text:             qsTr("Monitor live accelerometer vibration and clipping across all axes.")
                    color:            vibrationPage._bodyColor
                    wrapMode:         Text.WordWrap
                }

                Rectangle {
                    Layout.fillWidth: true
                    height:           1
                    color:            vibrationPage._tableLine
                }
            }
        }
    }

    Component {
        id: pageComponent

        Rectangle {
            width:  vibrationPage.availableWidth
            height: vibrationPage.availableHeight
            color:  vibrationPage._pageBackground

            QGCFlickable {
                id:                 vibrationFlickable
                anchors.fill:       parent
                contentWidth:       width
                contentHeight:      vibrationContent.height + vibrationPage._pagePad
                flickableDirection: Flickable.VerticalFlick
                clip:               true

                ScrollBar.vertical: ScrollBar {
                    policy:        vibrationFlickable.contentHeight > vibrationFlickable.height
                                   ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                    width:         Math.max(7, ScreenTools.defaultFontPixelWidth * 0.7)
                    topPadding:    vibrationPage._headerSpacing
                    bottomPadding: vibrationPage._headerSpacing
                    leftPadding:   2
                    rightPadding:  2

                    background: Rectangle {
                        radius: parent.width / 2
                        color:  vibrationPage._dataCardFill
                    }

                    contentItem: Rectangle {
                        radius: width / 2
                        color:  vibrationPage._accentGreen
                    }
                }

                ColumnLayout {
                    id:      vibrationContent
                    x:       vibrationPage._pagePad
                    width:   Math.max(0, vibrationFlickable.width - vibrationPage._pagePad * 2)
                    spacing: vibrationPage._controlSpacing

                    Rectangle {
                        Layout.fillWidth:       true
                        Layout.preferredHeight: summaryLayout.implicitHeight + vibrationPage._controlSpacing * 1.5
                        radius:                 vibrationPage._cardRadius
                        color:                  vibrationPage._cardSelectedFill
                        border.width:           1
                        border.color:           vibrationPage._accentGreen

                        RowLayout {
                            id:              summaryLayout
                            anchors.fill:    parent
                            anchors.margins: vibrationPage._controlSpacing
                            spacing:         vibrationPage._controlSpacing

                            Rectangle {
                                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 0.7
                                Layout.preferredHeight: Layout.preferredWidth
                                radius:                 width / 2
                                color:                  vibrationPage._available
                                                        ? vibrationPage.colorForValue(vibrationPage._peakValue)
                                                        : vibrationPage._bodyColor
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing:          0

                                QGCLabel {
                                    Layout.fillWidth: true
                                    text:             vibrationPage._available
                                                      ? qsTr("Live vibration data")
                                                      : qsTr("Vibration data unavailable")
                                    color:            vibrationPage._titleColor
                                    font.weight:      Font.DemiBold
                                    elide:            Text.ElideRight
                                }

                                QGCLabel {
                                    Layout.fillWidth: true
                                    text:             vibrationPage._available
                                                      ? qsTr("Peak level %1 · %2")
                                                            .arg(vibrationPage._peakValue.toFixed(1))
                                                            .arg(vibrationPage.statusForValue(vibrationPage._peakValue))
                                                      : qsTr("Connect a supported vehicle to view live values.")
                                    color:            vibrationPage._bodyColor
                                    elide:            Text.ElideRight
                                }
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns:          3
                        columnSpacing:    vibrationPage._controlSpacing
                        rowSpacing:       vibrationPage._controlSpacing

                        AxisCard {
                            axisName:  qsTr("X")
                            axisValue: vibrationPage._xValue
                        }

                        AxisCard {
                            axisName:  qsTr("Y")
                            axisValue: vibrationPage._yValue
                        }

                        AxisCard {
                            axisName:  qsTr("Z")
                            axisValue: vibrationPage._zValue
                        }
                    }

                    Rectangle {
                        Layout.fillWidth:       true
                        Layout.preferredHeight: clipLayout.implicitHeight + vibrationPage._controlSpacing * 2
                        radius:                 vibrationPage._cardRadius
                        color:                  vibrationPage._dataCardFill
                        border.width:           1
                        border.color:           vibrationPage._tableLine

                        ColumnLayout {
                            id:              clipLayout
                            anchors.fill:    parent
                            anchors.margins: vibrationPage._controlSpacing
                            spacing:         vibrationPage._headerSpacing

                            RowLayout {
                                Layout.fillWidth: true

                                QGCLabel {
                                    Layout.fillWidth: true
                                    text:             qsTr("Accelerometer clip count")
                                    color:            vibrationPage._titleColor
                                    font.weight:      Font.DemiBold
                                }

                                QGCLabel {
                                    text:  qsTr("Lower is better")
                                    color: vibrationPage._bodyColor
                                }
                            }

                            ClipRow {
                                sensorName: qsTr("Accelerometer 1")
                                clipCount:  vibrationPage._clip1
                            }

                            ClipRow {
                                sensorName: qsTr("Accelerometer 2")
                                clipCount:  vibrationPage._clip2
                            }

                            ClipRow {
                                sensorName: qsTr("Accelerometer 3")
                                clipCount:  vibrationPage._clip3
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing:          vibrationPage._controlSpacing * 1.4

                        Repeater {
                            model: [
                                { label: qsTr("Normal 0–30"), color: vibrationPage._accentGreen },
                                { label: qsTr("Elevated 30–60"), color: vibrationPage._elevatedColor },
                                { label: qsTr("High 60–90"), color: vibrationPage._highColor }
                            ]

                            RowLayout {
                                spacing: vibrationPage._controlSpacing * 0.45

                                Rectangle {
                                    Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 0.5
                                    Layout.preferredHeight: Layout.preferredWidth
                                    radius:                 width / 2
                                    color:                  modelData.color
                                }

                                QGCLabel {
                                    text:           modelData.label
                                    color:          vibrationPage._bodyColor
                                    font.pointSize: ScreenTools.smallFontPointSize
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }
    }
}
