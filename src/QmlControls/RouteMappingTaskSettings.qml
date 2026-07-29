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
    property var takeoffItem: null
    property bool sprayPatternExpanded: false
    property bool missionExpanded: false
    // Temporary feature gate. Keep the Boundary Route UI and implementation
    // in place so it can be re-enabled without restoring removed code.
    property bool boundaryRouteEnabled: false

    readonly property bool _showGridAngle: routeMode === 0 && surveyItem && surveyItem.gridAngle
    readonly property bool _surveyPolygonValid: _showGridAngle
                                                && surveyItem.surveyAreaPolygon
                                                && surveyItem.surveyAreaPolygon.isValid
    readonly property var  _cameraCalc: surveyItem && surveyItem.cameraCalc
                                        ? surveyItem.cameraCalc
                                        : null

    // These two Facts belong to the SurveyComplexItem. Updating them changes
    // only the generated survey waypoints and never the takeoff item.
    property Fact _patternAltitudeFact: _cameraCalc && _cameraCalc.distanceToSurface
                                        ? _cameraCalc.distanceToSurface
                                        : null
    property Fact _patternSpeedFact: surveyItem && surveyItem.patternFlightSpeed
                                     ? surveyItem.patternFlightSpeed
                                     : null
    readonly property bool _patternAltitudeAvailable: _patternAltitudeFact !== null
    readonly property bool _patternSpeedAvailable: _patternSpeedFact !== null

    // Mission altitude is bound directly to the takeoff item so it remains
    // independent from the survey pattern altitude.
    property Fact _missionAltitudeFact: takeoffItem && takeoffItem.altitude
                                        ? takeoffItem.altitude
                                        : null
    readonly property bool _missionAltitudeAvailable: _missionAltitudeFact !== null

    signal areaRouteSelected()

    color:  "#fbfbfb"
    radius: _radius
    clip:   true

    // Slider writes are debounced while dragging so survey rebuilds are not
    // hammered every pixel. Always flush before Upload/Save (see flushPendingWrites).
    Timer {
        id: patternAltitudeWriteTimer
        interval: 300
        repeat: false
        onTriggered: root._commitPatternAltitude(patternAltitudeSlider.value)
    }

    Timer {
        id: patternSpeedWriteTimer
        interval: 300
        repeat: false
        onTriggered: root._commitPatternSpeed(patternSpeedSlider.value)
    }

    Timer {
        id: missionAltitudeWriteTimer
        interval: 300
        repeat: false
        onTriggered: root._commitMissionAltitude(missionAltitudeSlider.value)
    }

    // Consume pointer and wheel events which are not handled by a control in
    // this panel. This prevents them from reaching and zooming/panning the map
    // underneath while the task settings are being scrolled.
    DeadMouseArea {
        anchors.fill: parent
    }

    // Matches TransectStyleComplexItem::applyNewAltitude so camera-calc
    // does not overwrite DistanceToSurface from GSD for known cameras.
    function _commitPatternAltitude(altitudeValue) {
        if (!root._patternAltitudeFact || !root._cameraCalc) {
            return
        }
        var alt = Number(altitudeValue)
        if (isNaN(alt)) {
            return
        }
        if (root._cameraCalc.valueSetIsDistance) {
            root._cameraCalc.valueSetIsDistance.value = true
        }
        root._patternAltitudeFact.value = alt
    }

    function _commitPatternSpeed(speedValue) {
        if (!root._patternSpeedFact || !root.surveyItem) {
            return
        }
        var speed = Number(speedValue)
        if (isNaN(speed)) {
            return
        }
        root._patternSpeedFact.value = speed
        // Enabling the override causes QGC to insert a speed command
        // before the pattern and restore the previous speed afterward.
        root.surveyItem.specifyPatternFlightSpeed = true
    }

    function _commitMissionAltitude(altitudeValue) {
        if (!root._missionAltitudeFact) {
            return
        }
        var alt = Number(altitudeValue)
        if (isNaN(alt)) {
            return
        }
        root._missionAltitudeFact.value = alt
    }

    // Call from Upload/Save so pending slider drags are not lost.
    // Only commits when a write is pending or the slider differs from the Fact,
    // so an uninitialized slider cannot clobber the real altitude.
    function flushPendingWrites() {
        if (patternAltitudeWriteTimer.running) {
            patternAltitudeWriteTimer.stop()
            root._commitPatternAltitude(patternAltitudeSlider.value)
        } else if (root._patternAltitudeAvailable && root._patternAltitudeFact) {
            var patternAlt = Number(root._patternAltitudeFact.value)
            if (!isNaN(patternAlt)
                    && Math.abs(patternAltitudeSlider.value - patternAlt) > 0.01) {
                root._commitPatternAltitude(patternAltitudeSlider.value)
            }
        }

        if (patternSpeedWriteTimer.running) {
            patternSpeedWriteTimer.stop()
            root._commitPatternSpeed(patternSpeedSlider.value)
        } else if (root._patternSpeedAvailable && root._patternSpeedFact) {
            var patternSpeed = Number(root._patternSpeedFact.value)
            if (!isNaN(patternSpeed)
                    && Math.abs(patternSpeedSlider.value - patternSpeed) > 0.01) {
                root._commitPatternSpeed(patternSpeedSlider.value)
            }
        }

        if (missionAltitudeWriteTimer.running) {
            missionAltitudeWriteTimer.stop()
            root._commitMissionAltitude(missionAltitudeSlider.value)
        } else if (root._missionAltitudeAvailable && root._missionAltitudeFact) {
            var missionAlt = Number(root._missionAltitudeFact.value)
            if (!isNaN(missionAlt)
                    && Math.abs(missionAltitudeSlider.value - missionAlt) > 0.01) {
                root._commitMissionAltitude(missionAltitudeSlider.value)
            }
        }
    }

    function _syncPatternAltitudeSlider() {
        // Keep external Fact changes visible without fighting an active drag.
        if (!root._patternAltitudeFact || patternAltitudeSlider.pressed) {
            return
        }
        var alt = Number(root._patternAltitudeFact.value)
        if (!isNaN(alt) && Math.abs(patternAltitudeSlider.value - alt) > 0.01) {
            patternAltitudeSlider.value = alt
        }
    }

    function _syncPatternSpeedSlider() {
        // Keep loaded/edited plan values synchronized with the slider.
        if (!root._patternSpeedFact || patternSpeedSlider.pressed) {
            return
        }
        var speed = Number(root._patternSpeedFact.value)
        if (!isNaN(speed) && Math.abs(patternSpeedSlider.value - speed) > 0.01) {
            patternSpeedSlider.value = speed
        }
    }

    function _syncMissionAltitudeSlider() {
        // Takeoff altitude is synchronized separately from pattern altitude.
        if (!root._missionAltitudeFact || missionAltitudeSlider.pressed) {
            return
        }
        var alt = Number(root._missionAltitudeFact.value)
        if (!isNaN(alt) && Math.abs(missionAltitudeSlider.value - alt) > 0.01) {
            missionAltitudeSlider.value = alt
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
                id: boundarrate
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
                    enabled:            index === 0 || root.boundaryRouteEnabled
                    opacity:            enabled ? 1.0 : 0.45
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
                        enabled:        index === 0 || root.boundaryRouteEnabled
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

            Rectangle {
                Layout.fillWidth:   true
                Layout.topMargin:   ScreenTools.defaultFontPixelHeight * 0.25
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.15
                visible:            root._showGridAngle
                radius:             root._radius
                color:              sprayPatternHeaderMouseArea.pressed
                                    ? root._accentSoftGreen
                                    : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: root._pad * 0.35
                    anchors.rightMargin: root._pad * 0.35

                    QGCLabel {
                        Layout.fillWidth: true
                        text:             qsTr("Spray Pattern")
                        color:            root._titleColor
                        font.weight:      Font.Medium
                        font.pointSize:   ScreenTools.defaultFontPointSize
                    }

                    QGCColoredImage {
                        Layout.alignment: Qt.AlignVCenter
                        width:            ScreenTools.defaultFontPixelHeight * 0.65
                        height:           width
                        source:           "/res/DropArrow.svg"
                        color:            root._bodyColor
                        rotation:         root.sprayPatternExpanded ? 180 : 0

                        Behavior on rotation {
                            NumberAnimation { duration: 160 }
                        }
                    }
                }

                QGCMouseArea {
                    id:           sprayPatternHeaderMouseArea
                    anchors.fill: parent
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    root.sprayPatternExpanded = !root.sprayPatternExpanded
                }
            }
            // Survey-only parameters. Altitude changes survey waypoint heights;
            // speed controls the temporary speed override around those waypoints.
            GridLayout {
                Layout.fillWidth:    true
                Layout.topMargin:    ScreenTools.defaultFontPixelHeight * 0.25
                Layout.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.35
                columns:             2
                columnSpacing:       root._pad * 0.65
                rowSpacing:          ScreenTools.defaultFontPixelHeight * 0.55
                visible:             root._showGridAngle && root.sprayPatternExpanded

                QGCLabel {
                    text:       qsTr("Angle")
                    color:      root._bodyColor
                }

                FactTextField {
                    id:                 gridAngleField
                    fact:               root.surveyItem ? root.surveyItem.gridAngle : null
                    Layout.fillWidth:   true
                    enabled:            root._showGridAngle
                    activeFocusBorderColor: root._accentGreen
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

                QGCLabel {
                    text: root._cameraCalc && root._cameraCalc.isManualCamera
                          ? qsTr("Spacing")
                          : qsTr("Side Lap")
                    color: root._bodyColor
                }

                FactTextField {
                    fact: root._cameraCalc
                          ? (root._cameraCalc.isManualCamera
                             ? root._cameraCalc.adjustedFootprintSide
                             : root._cameraCalc.sideOverlap)
                          : null
                    Layout.fillWidth: true
                    enabled: root._showGridAngle
                    activeFocusBorderColor: root._accentGreen
                }

                QGCLabel {
                    text:  qsTr("Turnaround")
                    color: root._bodyColor
                }

                FactTextField {
                    fact: root.surveyItem ? root.surveyItem.turnAroundDistance : null
                    Layout.fillWidth: true
                    enabled: root._showGridAngle
                    activeFocusBorderColor: root._accentGreen
                }

                QGCLabel {
                    text:  qsTr("Altitude")
                    color: root._bodyColor
                }

                AltitudeFactTextField {
                    fact:               root._patternAltitudeFact
                    altitudeMode:       root._cameraCalc
                                        ? root._cameraCalc.distanceMode
                                        : QGroundControl.AltitudeModeNone
                    Layout.fillWidth:   true
                    enabled:            root._patternAltitudeAvailable
                    activeFocusBorderColor: root._accentGreen
                    onUpdated: {
                        if (root._cameraCalc && root._cameraCalc.valueSetIsDistance) {
                            root._cameraCalc.valueSetIsDistance.value = true
                        }
                        root._syncPatternAltitudeSlider()
                    }
                }

                QGCSlider {
                    id:                     patternAltitudeSlider
                    from:                   1
                    to:                     500
                    stepSize:               1
                    Layout.fillWidth:       true
                    Layout.columnSpan:      2
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.5
                    enabled:                root._patternAltitudeAvailable
                    activeColor:            root._accentGreen
                    barHeight:              Math.max(1, ScreenTools.defaultFontPixelHeight * 0.12)
                    live:                   true
                    // Do not bind value: to the Fact while dragging — that snaps
                    // the handle back and can upload the old/default altitude.
                    Binding {
                        target:   patternAltitudeSlider
                        property: "value"
                        value:    root._patternAltitudeFact
                                  ? Number(root._patternAltitudeFact.value)
                                  : patternAltitudeSlider.from
                        when:     !patternAltitudeSlider.pressed
                    }
                    onMoved:                patternAltitudeWriteTimer.restart()
                    onPressedChanged: {
                        if (!pressed) {
                            patternAltitudeWriteTimer.stop()
                            root._commitPatternAltitude(value)
                        }
                    }
                }

                QGCLabel {
                    text:  qsTr("Speed")
                    color: root._bodyColor
                }

                FactTextField {
                    fact:               root._patternSpeedFact
                    Layout.fillWidth:   true
                    enabled:            root._patternSpeedAvailable
                    activeFocusBorderColor: root._accentGreen
                    onUpdated: {
                        if (root.surveyItem) {
                            root.surveyItem.specifyPatternFlightSpeed = true
                        }
                        root._syncPatternSpeedSlider()
                    }
                }

                QGCSlider {
                    id:                     patternSpeedSlider
                    from:                   0.5
                    to:                     30
                    stepSize:               0.5
                    Layout.fillWidth:       true
                    Layout.columnSpan:      2
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.5
                    enabled:                root._patternSpeedAvailable
                    activeColor:            root._accentGreen
                    barHeight:              Math.max(1, ScreenTools.defaultFontPixelHeight * 0.12)
                    live:                   true
                    Binding {
                        target:   patternSpeedSlider
                        property: "value"
                        value:    root._patternSpeedFact
                                  ? Number(root._patternSpeedFact.value)
                                  : patternSpeedSlider.from
                        when:     !patternSpeedSlider.pressed
                    }
                    onMoved:                patternSpeedWriteTimer.restart()
                    onPressedChanged: {
                        if (!pressed) {
                            patternSpeedWriteTimer.stop()
                            root._commitPatternSpeed(value)
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth:       true
                Layout.leftMargin:      root._pad
                Layout.rightMargin:     root._pad
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.15
                visible:                root._showGridAngle && root.sprayPatternExpanded
                enabled:                root._surveyPolygonValid
                opacity:                enabled ? 1.0 : 0.45
                color:                  rotateEntryMouseArea.pressed
                                        ? Qt.darker(root._accentGreen, 1.12)
                                        : root._accentGreen
                border.width:           1
                border.color:           root._accentGreen
                radius:                 root._radius

                QGCLabel {
                    anchors.centerIn: parent
                    text:             qsTr("Rotate Entry Point")
                    color:            "white"
                    font.weight:      Font.Medium
                }

                QGCMouseArea {
                    id:           rotateEntryMouseArea
                    anchors.fill: parent
                    enabled:      parent.enabled
                    cursorShape:  enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (root.surveyItem) {
                            root.surveyItem.rotateEntryPoint()
                        }
                    }
                }
            }

            QGCLabel {
                Layout.fillWidth:   true
                Layout.topMargin:   ScreenTools.defaultFontPixelHeight * 0.1
                text:               qsTr("Adjust direction, spacing, turnaround, and the survey entry point.")
                color:              root._hintColor
                font.pointSize:     ScreenTools.smallFontPointSize
                wrapMode:           Text.WordWrap
                visible:            root._showGridAngle && root.sprayPatternExpanded
            }

            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: 1
                Layout.topMargin:       ScreenTools.defaultFontPixelHeight * 0.35
                Layout.bottomMargin:    ScreenTools.defaultFontPixelHeight * 0.2
                color:                  root._cardBorderIdle
                opacity:                0.75
                visible:                root.takeoffItem !== null
            }

            Rectangle {
                Layout.fillWidth:       true
                Layout.topMargin:       ScreenTools.defaultFontPixelHeight * 0.25
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.15
                visible:                root.takeoffItem !== null
                radius:                 root._radius
                color:                  missionHeaderMouseArea.pressed
                                        ? root._accentSoftGreen
                                        : "transparent"

                RowLayout {
                    anchors.fill:        parent
                    anchors.leftMargin:  root._pad * 0.35
                    anchors.rightMargin: root._pad * 0.35

                    QGCLabel {
                        Layout.fillWidth: true
                        text:             qsTr("Mission")
                        color:            root._titleColor
                        font.weight:      Font.Medium
                        font.pointSize:   ScreenTools.defaultFontPointSize
                    }

                    QGCColoredImage {
                        Layout.alignment: Qt.AlignVCenter
                        width:            ScreenTools.defaultFontPixelHeight * 0.65
                        height:           width
                        source:           "/res/DropArrow.svg"
                        color:            root._bodyColor
                        rotation:         root.missionExpanded ? 180 : 0

                        Behavior on rotation {
                            NumberAnimation { duration: 160 }
                        }
                    }
                }

                QGCMouseArea {
                    id:           missionHeaderMouseArea
                    anchors.fill: parent
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    root.missionExpanded = !root.missionExpanded
                }
            }

            // Mission settings operate on the takeoff item, not on the survey.
            GridLayout {
                Layout.fillWidth:   true
                columns:            2
                columnSpacing:      root._pad * 0.5
                rowSpacing:         root._pad * 0.5
                visible:            root.missionExpanded && root._missionAltitudeAvailable

                QGCLabel {
                    text:  qsTr("Altitude")
                    color: root._bodyColor
                }

                AltitudeFactTextField {
                    fact:               root._missionAltitudeFact
                    altitudeMode:       root.takeoffItem
                                        ? root.takeoffItem.altitudeMode
                                        : QGroundControl.AltitudeModeNone
                    Layout.fillWidth:   true
                    enabled:            root._missionAltitudeAvailable
                    activeFocusBorderColor: root._accentGreen
                    onUpdated: {
                        if (root._missionAltitudeFact) {
                            var alt = Number(root._missionAltitudeFact.value)
                            if (!isNaN(alt)) {
                                missionAltitudeSlider.value = alt
                            }
                        }
                    }
                }

                QGCSlider {
                    id:                     missionAltitudeSlider
                    from:                   1
                    to:                     500
                    stepSize:               1
                    Layout.fillWidth:       true
                    Layout.columnSpan:      2
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.5
                    enabled:                root._missionAltitudeAvailable
                    activeColor:            root._accentGreen
                    barHeight:              Math.max(1, ScreenTools.defaultFontPixelHeight * 0.12)
                    live:                   true
                    Binding {
                        target:   missionAltitudeSlider
                        property: "value"
                        value:    root._missionAltitudeFact
                                  ? Number(root._missionAltitudeFact.value)
                                  : missionAltitudeSlider.from
                        when:     !missionAltitudeSlider.pressed
                    }
                    onMoved:                missionAltitudeWriteTimer.restart()
                    onPressedChanged: {
                        if (!pressed) {
                            missionAltitudeWriteTimer.stop()
                            root._commitMissionAltitude(value)
                        }
                    }
                }
            }

            QGCLabel {
                Layout.fillWidth:   true
                Layout.topMargin:   ScreenTools.defaultFontPixelHeight * 0.1
                text:               qsTr("Takeoff altitude only. Survey Pattern altitude is separate — if Mission is higher than Survey, the vehicle will descend into the pattern after takeoff.")
                color:              root._hintColor
                font.pointSize:     ScreenTools.smallFontPointSize
                wrapMode:           Text.WordWrap
                visible:            root.missionExpanded && root._missionAltitudeAvailable
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

    Connections {
        target: root._patternAltitudeFact
        ignoreUnknownSignals: true
        function onValueChanged() {
            root._syncPatternAltitudeSlider()
        }
    }

    Connections {
        target: root._patternSpeedFact
        ignoreUnknownSignals: true
        function onValueChanged() {
            root._syncPatternSpeedSlider()
        }
    }

    Connections {
        target: root._missionAltitudeFact
        ignoreUnknownSignals: true
        function onValueChanged() {
            root._syncMissionAltitudeSlider()
        }
    }

    onSurveyItemChanged: {
        if (root.surveyItem && root.surveyItem.gridAngle) {
            gridAngleSlider.value = root.surveyItem.gridAngle.value
        }
        root._syncPatternAltitudeSlider()
        root._syncPatternSpeedSlider()
    }

    onTakeoffItemChanged: {
        root._syncMissionAltitudeSlider()
    }
}
