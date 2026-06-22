import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Rectangle {
    id: root

    readonly property color _accentGreen:     "#23a800"
    readonly property color _accentSoftGreen: "#efffee"
    readonly property color _titleColor:      "#3f3f3f"
    readonly property color _bodyColor:       "#6a6a6a"
    readonly property color _hintColor:       "#8a8a8a"
    readonly property color _cardBorderIdle:  "#e2e2e2"
    readonly property real  _pad:             ScreenTools.defaultFontPixelWidth * 1.05
    readonly property real  _radius:          ScreenTools.defaultFontPixelWidth * 0.75

    property int routeMode:   0   // 0 = Area Route, 1 = Boundary Route
    property int resolution: 0   // 0 = Medium, 1 = High
    property var surveyItem:  null

    property var  _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property Fact _speedFact:     _activeVehicle && speedParameterLoader.item
                                  ? speedParameterLoader.item.fact
                                  : null

    readonly property bool _showGridAngle: routeMode === 0 && surveyItem && surveyItem.gridAngle
    readonly property bool _speedAvailable: _speedFact !== null

    signal areaRouteSelected()

    color:  "#fbfbfb"
    radius: _radius
    clip:   true

    on_ActiveVehicleChanged: {
        speedParameterLoader.active = false
        speedParameterReloadTimer.restart()
    }

    Timer {
        id: speedParameterReloadTimer
        interval: 0
        repeat: false
        onTriggered: speedParameterLoader.active = root._activeVehicle !== null
    }

    Loader {
        id: speedParameterLoader
        active: root._activeVehicle !== null
        sourceComponent: speedParameterComponent
    }

    Component {
        id: speedParameterComponent

        Item {
            property bool parametersReady: root._activeVehicle && root._activeVehicle.parameterManager
                                           ? root._activeVehicle.parameterManager.parametersReady
                                           : false
            property Fact fact: {
                var ready = parametersReady
                if (!ready && !controller.parameterExists(-1, "MPC_XY_CRUISE")) {
                    return null
                }
                return controller.getParameterFact(-1, "MPC_XY_CRUISE", false)
            }

            FactPanelController {
                id: controller
            }
        }
    }

    Timer {
        id: speedWriteTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (root._speedFact) {
                root._speedFact.value = speedSlider.value
            }
        }
    }

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
            spacing:            ScreenTools.defaultFontPixelHeight * 0.55

            QGCLabel {
                Layout.fillWidth:   true
                text:               qsTr("Task Settings")
                color:              root._titleColor
                font.weight:        Font.Medium
                font.pointSize:     ScreenTools.mediumFontPointSize
                horizontalAlignment: Text.AlignHCenter
            }

            QGCLabel {
                Layout.fillWidth:   true
                Layout.topMargin:   ScreenTools.defaultFontPixelHeight * 0.6
                text:               qsTr("Route Mode")
                color:              root._titleColor
                font.pointSize:     ScreenTools.defaultFontPointSize
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
                    Layout.preferredHeight: routeModeCardLayout.implicitHeight + root._pad * 2.4
                    radius:             root._radius
                    color:              root.routeMode === index ? root._accentSoftGreen : "white"
                    border.width:       root.routeMode === index ? 2 : 1
                    border.color:       root.routeMode === index ? root._accentGreen : root._cardBorderIdle

                    RowLayout {
                        id: routeModeCardLayout
                        anchors.fill:   parent
                        anchors.margins: root._pad * 1.35
                        spacing:        root._pad

                        Rectangle {
                            Layout.alignment:       Qt.AlignTop
                            Layout.topMargin:       ScreenTools.defaultFontPixelHeight * 0.12
                            width:                  ScreenTools.defaultFontPixelHeight * 1.05
                            height:                 width
                            radius:                 width / 2
                            color:                  "white"
                            border.width:           root.routeMode === index ? 0 : 1
                            border.color:           root._cardBorderIdle

                            Rectangle {
                                anchors.centerIn:   parent
                                width:              parent.width * (root.routeMode === index ? 0.72 : 0)
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
                                color:              root.routeMode === index ? root._accentGreen : root._titleColor
                                font.weight:        Font.Medium
                                font.pointSize:     ScreenTools.defaultFontPointSize
                                wrapMode:           Text.WordWrap
                            }

                            QGCLabel {
                                Layout.fillWidth:   true
                                text:               modelData.description
                                color:              root._bodyColor
                                font.pointSize:     ScreenTools.defaultFontPointSize
                                wrapMode:           Text.WordWrap
                            }
                        }

                        QGCLabel {
                            Layout.alignment:   Qt.AlignTop
                            Layout.topMargin:   ScreenTools.defaultFontPixelHeight * 0.1
                            text:               index === 0 ? "\u2261" : "\u2317"
                            color:              root.routeMode === index ? root._accentGreen : root._hintColor
                            font.weight:        Font.Medium
                            font.pointSize:     ScreenTools.defaultFontPointSize
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

            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: 1
                Layout.topMargin:       ScreenTools.defaultFontPixelHeight * 0.2
                Layout.bottomMargin:    ScreenTools.defaultFontPixelHeight * 0.2
                color:                  root._cardBorderIdle
                opacity:                0.75
            }

            QGCLabel {
                Layout.fillWidth:   true
                Layout.topMargin:   ScreenTools.defaultFontPixelHeight * 0.8
                text:               qsTr("Resolution")
                color:              root._titleColor
                font.pointSize:     ScreenTools.defaultFontPointSize
            }

            RowLayout {
                Layout.fillWidth:   true
                spacing:            0
                clip:               true

                Repeater {
                    model: [qsTr("Medium"), qsTr("High")]

                    Rectangle {
                        Layout.fillWidth:       true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.15
                        color:                  root.resolution === index ? root._accentGreen : "white"
                        border.width:           1
                        border.color:           root.resolution === index ? root._accentGreen : root._cardBorderIdle
                        radius:                 root._radius

                        QGCLabel {
                            anchors.centerIn:   parent
                            text:               modelData
                            color:              root.resolution === index ? "white" : root._bodyColor
                            font.weight:        Font.Medium
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
                                      ? qsTr("High-resolution reconstruction (3D) captures high-quality imagery.")
                                      : qsTr("High resolution increases photo count and flight time.")
                color:              root._hintColor
                font.pointSize:     ScreenTools.defaultFontPointSize
                wrapMode:           Text.WordWrap
            }

            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: 1
                Layout.topMargin:       ScreenTools.defaultFontPixelHeight * 0.35
                Layout.bottomMargin:    ScreenTools.defaultFontPixelHeight * 0.2
                color:                  root._cardBorderIdle
                opacity:                0.75
                visible:                root._showGridAngle
            }

            QGCLabel {
                Layout.fillWidth:   true
                Layout.topMargin:   ScreenTools.defaultFontPixelHeight * 0.25
                text:               qsTr("Grid Angle")
                color:              root._titleColor
                font.weight:        Font.Medium
                font.pointSize:     ScreenTools.defaultFontPointSize
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
                    activeColor:            "#23a800"
                    barHeight:              Math.max(1, ScreenTools.defaultFontPixelHeight * 0.12)
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

            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: 1
                Layout.topMargin:       ScreenTools.defaultFontPixelHeight * 0.35
                Layout.bottomMargin:    ScreenTools.defaultFontPixelHeight * 0.2
                color:                  root._cardBorderIdle
                opacity:                0.75
            }

            QGCLabel {
                Layout.fillWidth:   true
                Layout.topMargin:   ScreenTools.defaultFontPixelHeight * 0.25
                text:               qsTr("Cruise Speed")
                color:              root._titleColor
                font.weight:        Font.Medium
                font.pointSize:     ScreenTools.defaultFontPointSize
            }

            GridLayout {
                Layout.fillWidth:   true
                columns:            2
                columnSpacing:      root._pad * 0.5
                rowSpacing:         root._pad * 0.5
                visible:            root._speedAvailable

                QGCLabel {
                    text:       qsTr("Speed")
                    color:      root._bodyColor
                }

                FactTextField {
                    fact:               root._speedFact
                    Layout.fillWidth:   true
                    enabled:            root._speedAvailable
                    onUpdated:          speedSlider.value = Number(root._speedFact.value)
                }

                QGCSlider {
                    id:                     speedSlider
                    from:                   root._speedFact ? Number(root._speedFact.min) : 3
                    to:                     root._speedFact ? Number(root._speedFact.max) : 20
                    stepSize:               root._speedFact && Number(root._speedFact.increment) > 0
                                                ? Number(root._speedFact.increment)
                                                : 0.1
                    value:                  root._speedFact ? Number(root._speedFact.value) : 5
                    Layout.fillWidth:       true
                    Layout.columnSpan:      2
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.5
                    enabled:                root._speedAvailable
                    activeColor:            root._accentGreen
                    barHeight:              Math.max(1, ScreenTools.defaultFontPixelHeight * 0.12)
                    live:                   true
                    onMoved:                speedWriteTimer.restart()
                }
            }

            QGCLabel {
                Layout.fillWidth:   true
                text:               root._speedAvailable
                                      ? qsTr("Adjusts MPC_XY_CRUISE on the connected vehicle. The value is written automatically.")
                                      : qsTr("Connect a PX4 vehicle to adjust MPC_XY_CRUISE.")
                color:              root._hintColor
                font.pointSize:     ScreenTools.smallFontPointSize
                wrapMode:           Text.WordWrap
            }
        }
    }

    Connections {
        target: root._speedFact
        ignoreUnknownSignals: true
        function onRawValueChanged() {
            if (root._speedFact && !speedSlider.pressed) {
                speedSlider.value = Number(root._speedFact.value)
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
