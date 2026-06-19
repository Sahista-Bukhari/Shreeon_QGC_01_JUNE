import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Rectangle {
    id: root

    readonly property color _accentGreen:     "#78d957"
    readonly property color _titleColor:      "#1a1a1a"
    readonly property color _bodyColor:       "#515151"
    readonly property color _hintColor:       "#8a8a8a"
    readonly property color _cardBorderIdle:  "#d8d8d8"
    readonly property real  _pad:             ScreenTools.defaultFontPixelWidth
    readonly property real  _radius:          ScreenTools.defaultFontPixelWidth * 0.45

    property int routeMode:   0   // 0 = Area Route, 1 = Boundary Route
    property int resolution: 0   // 0 = Medium, 1 = High
    property var surveyItem:  null

    readonly property bool _showGridAngle: routeMode === 0 && surveyItem && surveyItem.gridAngle

    signal areaRouteSelected()

    color:  "white"
    radius: _radius
    clip:   true

    QGCFlickable {
        id: taskSettingsFlickable
        anchors.fill:       parent
        anchors.margins:    root._pad
        contentWidth:       width
        contentHeight:      taskSettingsColumn.implicitHeight
        clip:               true

        ColumnLayout {
            id: taskSettingsColumn
            width:              taskSettingsFlickable.width
            spacing:            ScreenTools.defaultFontPixelHeight * 0.45

            QGCLabel {
                Layout.fillWidth:   true
                text:               qsTr("Task Settings")
                color:              root._titleColor
                font.bold:          true
            }

            QGCLabel {
                Layout.fillWidth:   true
                Layout.topMargin:   ScreenTools.defaultFontPixelHeight * 0.15
                text:               qsTr("Route Mode")
                color:              root._titleColor
                font.bold:          true
            }

            Repeater {
                model: [
                    {
                        title: qsTr("Area Route"),
                        description: qsTr("Maps entire area. Mapping this route type is time consuming and of high accuracy.")
                    },
                    {
                        title: qsTr("Boundary Route"),
                        description: qsTr("Maps a boundary of the area with a width of 20m. Mapping this route type is time efficient and of moderate accuracy.")
                    }
                ]

                Rectangle {
                    Layout.fillWidth:   true
                    Layout.preferredHeight: routeModeCardLayout.implicitHeight + root._pad * 1.4
                    radius:             root._radius * 0.85
                    color:              "white"
                    border.width:       root.routeMode === index ? 2 : 1
                    border.color:       root.routeMode === index ? root._accentGreen : root._cardBorderIdle

                    RowLayout {
                        id: routeModeCardLayout
                        anchors.fill:   parent
                        anchors.margins: root._pad * 0.85
                        spacing:        root._pad * 0.75

                        Rectangle {
                            Layout.alignment:       Qt.AlignTop
                            Layout.topMargin:       ScreenTools.defaultFontPixelHeight * 0.15
                            width:                  ScreenTools.defaultFontPixelHeight * 1.05
                            height:                 width
                            radius:                 width / 2
                            color:                  "white"
                            border.width:           root.routeMode === index ? 0 : 1
                            border.color:           root._cardBorderIdle

                            Rectangle {
                                anchors.centerIn:   parent
                                width:              parent.width * (root.routeMode === index ? 0.55 : 0)
                                height:             width
                                radius:             width / 2
                                color:              root._accentGreen
                                visible:            root.routeMode === index
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth:   true
                            spacing:            ScreenTools.defaultFontPixelHeight * 0.2

                            QGCLabel {
                                Layout.fillWidth:   true
                                text:               modelData.title
                                color:              root._titleColor
                                font.bold:          true
                                wrapMode:           Text.WordWrap
                            }

                            QGCLabel {
                                Layout.fillWidth:   true
                                text:               modelData.description
                                color:              root._hintColor
                                font.pointSize:     ScreenTools.smallFontPointSize
                                wrapMode:           Text.WordWrap
                            }
                        }
                    }

                    QGCMouseArea {
                        anchors.fill:   parent
                        onClicked: {
                            root.routeMode = index
                            if (index === 0) {
                                root.areaRouteSelected()
                            }
                        }
                    }
                }
            }

            QGCLabel {
                Layout.fillWidth:   true
                Layout.topMargin:   ScreenTools.defaultFontPixelHeight * 0.25
                text:               qsTr("Resolution")
                color:              root._titleColor
                font.bold:          true
            }

            RowLayout {
                Layout.fillWidth:   true
                spacing:            0

                Repeater {
                    model: [qsTr("Medium"), qsTr("High")]

                    Rectangle {
                        Layout.fillWidth:       true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.0
                        color:                  root.resolution === index ? root._accentGreen : "white"
                        border.width:           1
                        border.color:           root.resolution === index ? root._accentGreen : root._cardBorderIdle

                        QGCLabel {
                            anchors.centerIn:   parent
                            text:               modelData
                            color:              root.resolution === index ? "white" : root._bodyColor
                            font.bold:          true
                        }

                        QGCMouseArea {
                            anchors.fill:   parent
                            onClicked:      root.resolution = index
                        }
                    }
                }
            }

            QGCLabel {
                Layout.fillWidth:   true
                Layout.topMargin:   ScreenTools.defaultFontPixelHeight * 0.15
                text:               root.resolution === 0
                                      ? qsTr("Medium resolution balances flight time and mapping detail.")
                                      : qsTr("High resolution increases photo count and flight time.")
                color:              root._hintColor
                font.pointSize:     ScreenTools.smallFontPointSize
                wrapMode:           Text.WordWrap
            }

            QGCLabel {
                Layout.fillWidth:   true
                Layout.topMargin:   ScreenTools.defaultFontPixelHeight * 0.25
                text:               qsTr("Grid Angle")
                color:              root._titleColor
                font.bold:          true
                visible:            root._showGridAngle
            }

            GridLayout {
                Layout.fillWidth:   true
                columns:            2
                columnSpacing:      root._pad * 0.5
                rowSpacing:         root._pad * 0.5
                visible:            root._showGridAngle

                QGCLabel {
                    text:       qsTr("Angle")
                    color:      root._bodyColor
                }

                FactTextField {
                    id:                 gridAngleField
                    fact:               root.surveyItem ? root.surveyItem.gridAngle : null
                    Layout.fillWidth:   true
                    enabled:            root._showGridAngle
                    onUpdated:          gridAngleSlider.value = root.surveyItem.gridAngle.value
                }

                QGCSlider {
                    id:                     gridAngleSlider
                    from:                   0
                    to:                     359
                    stepSize:               1
                    Layout.fillWidth:       true
                    Layout.columnSpan:      2
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.5
                    enabled:                root._showGridAngle
                    live:                   true
                    onValueChanged: {
                        if (root.surveyItem && root.surveyItem.gridAngle) {
                            root.surveyItem.gridAngle.value = value
                        }
                    }
                }
            }

            QGCLabel {
                Layout.fillWidth:   true
                Layout.topMargin:   ScreenTools.defaultFontPixelHeight * 0.1
                text:               qsTr("Adjust the angle of the survey transect pattern.")
                color:              root._hintColor
                font.pointSize:     ScreenTools.smallFontPointSize
                wrapMode:           Text.WordWrap
                visible:            root._showGridAngle
            }
        }
    }

    Connections {
        target: root.surveyItem ? root.surveyItem.gridAngle : null
        ignoreUnknownSignals: true
        function onValueChanged() {
            if (root.surveyItem && root.surveyItem.gridAngle) {
                gridAngleSlider.value = root.surveyItem.gridAngle.value
            }
        }
    }

    onSurveyItemChanged: {
        if (root.surveyItem && root.surveyItem.gridAngle) {
            gridAngleSlider.value = root.surveyItem.gridAngle.value
        }
    }
}
