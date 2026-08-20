import QtQuick
import QtQuick.Controls
import QtCharts
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

ColumnLayout {
    id: root

    spacing: _margins

    property real   availableHeight
    property real   availableWidth
    property var    axis
    property string unit
    property string title
    property var    tuningMode
    property double chartDisplaySec:    8 // number of seconds to display
    property bool   showAutoModeChange: false
    property bool   showAutoTuning:     false
    property bool   cleanManualTuning:  false
    property bool   multiAxisPlot:      false
    property var    multiAxisIndices:   []
    property string multiAxisTitle:     qsTr("Multi-Axis PID Response")

    property real   _margins:           ScreenTools.defaultFontPixelHeight / 2
    property int    _currentAxis:       0
    property var    _xAxis:             xAxis
    property var    _yAxis:             yAxis
    property int    _msecs:             0
    property double _last_t:            0
    property bool   _componentComplete: false
    property var    _activePlots:       []
    property var    _savedTuningParamValues:    [ ]

    readonly property int _tickSeparation:      5
    readonly property int _maxTickSections:     10
    readonly property color _dividerColor:      qgcPal.globalTheme === QGCPalette.Dark
                                                ? qgcPal.windowShade
                                                : "#E5E5E5"
    readonly property color _chartBackgroundColor: qgcPal.globalTheme === QGCPalette.Dark
                                                    ? qgcPal.windowShade
                                                    : "#E8EAEA"
    readonly property color _chartPlotAreaColor:   qgcPal.globalTheme === QGCPalette.Dark
                                                    ? qgcPal.windowShadeDark
                                                    : "#F2F3F3"
    readonly property color _accentGreen:           "#00A651"
    readonly property var _plotColors: [
        "#08783f", // Roll response
        "#61d83e", // Roll setpoint
        "#71892e", // Pitch response
        "#75da8d", // Pitch setpoint
        "#d1a62c", // Additional response/setpoint pairs
        "#59b9ad"
    ]

    QGCPalette {
        id:                 qgcPal
        colorGroupEnabled:  enabled
    }

    function adjustYAxisMin(yAxis, newValue) {
        var newMin = Math.min(yAxis.min, newValue)
        if (newMin % 5 != 0) {
            newMin -= 5
            newMin = Math.floor(newMin / _tickSeparation) * _tickSeparation
        }
        yAxis.min = newMin
    }

    function adjustYAxisMax(yAxis, newValue) {
        var newMax = Math.max(yAxis.max, newValue)
        if (newMax % 5 != 0) {
            newMax += 5
            newMax = Math.floor(newMax / _tickSeparation) * _tickSeparation
        }
        yAxis.max = newMax
    }

    function resetGraphs() {
        for (var i = 0; i < chart.count; ++i) {
            chart.series(i).removePoints(0, chart.series(i).count)
        }
        _xAxis.min = 0
        _xAxis.max = 0
        _yAxis.min = 0
        _yAxis.max = 0
        _msecs = 0
        _last_t = 0
    }

    // Save the current set of tuning values so we can reset to them
    function saveTuningParamValues() {
        _savedTuningParamValues = [ ]
        for (var i=0; i<axis[_currentAxis].params.count; i++) {
            var currentTuneParam = controller.getParameterFact(-1, axis[_currentAxis].params.get(i).param)
            _savedTuningParamValues.push(currentTuneParam.valueString)
        }
        savedRepeater.model = _savedTuningParamValues
    }

    function resetToSavedTuningParamValues() {
        for (var i=0; i<axis[_currentAxis].params.count; i++) {
            var currentTuneParam = controller.getParameterFact(-1,
                axis[_currentAxis].params.get(i).param)
            currentTuneParam.value = _savedTuningParamValues[i]
        }
    }

    function axisIndexChanged() {
        chart.removeAllSeries()

        var plotReferences = []
        var selectedAxes = multiAxisPlot ? multiAxisIndices : [_currentAxis]
        if (selectedAxes.length === 0) {
            selectedAxes = [_currentAxis]
        }

        for (var selectedIndex = 0; selectedIndex < selectedAxes.length; selectedIndex++) {
            var axisIndex = selectedAxes[selectedIndex]
            if (axisIndex < 0 || axisIndex >= axis.length) {
                continue
            }

            var axisData = axis[axisIndex]
            for (var plotIndex = 0; plotIndex < axisData.plot.length; plotIndex++) {
                var plotData = axisData.plot[plotIndex]
                var seriesName = multiAxisPlot
                        ? axisData.name + " " + plotData.name
                        : plotData.name
                var series = chart.createSeries(ChartView.SeriesTypeLine, seriesName, xAxis, yAxis)
                series.color = _plotColors[plotReferences.length % _plotColors.length]
                series.width = 2
                plotReferences.push({ axisIndex: axisIndex, plotIndex: plotIndex })
            }
        }

        _activePlots = plotReferences

        if (multiAxisPlot) {
            chart.title = multiAxisTitle
        } else {
            var chartTitle = axis[_currentAxis].plotTitle
            if (chartTitle == null)
                chartTitle = axis[_currentAxis].name
            chart.title = chartTitle + " " + title
        }

        saveTuningParamValues()
        resetGraphs()
    }

    Component.onCompleted: {
        _componentComplete = true
        axisIndexChanged()
        globals.activeVehicle.setPIDTuningTelemetryMode(tuningMode)
        saveTuningParamValues()
    }

    Component.onDestruction: globals.activeVehicle.setPIDTuningTelemetryMode(Vehicle.ModeDisabled)
    on_CurrentAxisChanged: {
        if (_componentComplete) {
            axisIndexChanged()
        }
    }
    onMultiAxisPlotChanged: {
        if (_componentComplete) {
            axisIndexChanged()
        }
    }

    ValueAxis {
        id:                     xAxis
        min:                    0
        max:                    0
        labelFormat:            "%.1f"
        titleText:              qsTr("sec")
        tickCount:              Math.min(Math.max(Math.floor((chart.plotArea.width > 0 ? chart.plotArea.width : chart.width * 0.6)
                                                             / (ScreenTools.defaultFontPixelWidth * 8)), 3), 11)
        truncateLabels:         false
        labelsFont.pointSize:   chart.width < ScreenTools.defaultFontPixelWidth * 50
                                ? ScreenTools.smallFontPointSize
                                : ScreenTools.defaultFontPointSize
        labelsFont.family:      ScreenTools.normalFontFamily
        titleFont.pointSize:    ScreenTools.defaultFontPointSize
        titleFont.family:       ScreenTools.normalFontFamily
    }

    ValueAxis {
        id:                     yAxis
        min:                    0
        max:                    10
        titleText:              unit
        tickCount:              Math.min(((max - min) / _tickSeparation), _maxTickSections) + 1
        labelsFont.pointSize:   ScreenTools.defaultFontPointSize
        labelsFont.family:      ScreenTools.normalFontFamily
        titleFont.pointSize:    ScreenTools.defaultFontPointSize
        titleFont.family:       ScreenTools.normalFontFamily
    }

    Timer {
        id:         dataTimer
        interval:   10
        running:    true
        repeat:     true

        onTriggered: {
            _xAxis.max = _msecs / 1000
            _xAxis.min = _msecs / 1000 - chartDisplaySec

            var firstPoint = _msecs == 0

            var len = _activePlots.length
            for (var i = 0; i < len; ++i) {
                var plotReference = _activePlots[i]
                var value = axis[plotReference.axisIndex].plot[plotReference.plotIndex].value
                if (!isNaN(value)) {
                    chart.series(i).append(_msecs/1000, value)
                    if (firstPoint) {
                        _yAxis.min = value
                        _yAxis.max = value
                    } else {
                        adjustYAxisMin(_yAxis, value)
                        adjustYAxisMax(_yAxis, value)
                    }
                    // limit history
                    var minSec = _msecs/1000 - 3*60
                    while (chart.series(i).count > 0 && chart.series(i).at(0).x < minSec) {
                        chart.series(i).remove(0)
                    }
                }
            }

            var t = new Date().getTime() // in ms
            if (_last_t > 0)
                _msecs += t-_last_t
            _last_t = t
        }

        property int _maxPointCount:    10000 / interval
    }

    Column {
        id:                 leftPanel
        Layout.alignment:   Qt.AlignTop
        Layout.fillWidth:   true
        spacing:            ScreenTools.defaultFontPixelHeight / 4
        clip:               true // chart has redraw problems

        ChartView {
            id:                     chart
            width:                  Math.max(_minChartWidth, availableWidth - (_margins * 2))
            height:                 Math.max(_minChartHeight, availableHeight - leftPanelBottomColumn.height - parent.spacing - _margins)
            antialiasing:           true
            legend.visible:         false
            margins.top:            _margins * 2
            margins.bottom:         chartLegendColumn.implicitHeight + (_margins * 4)
            titleFont.pointSize:    ScreenTools.defaultFontPointSize
            titleFont.family:       ScreenTools.normalFontFamily
            backgroundColor:        _chartBackgroundColor
            plotAreaColor:          _chartPlotAreaColor
            backgroundRoundness:    ScreenTools.defaultFontPixelHeight / 2

            property real _chartMargin: 0
            property real _minChartWidth:   ScreenTools.defaultFontPixelWidth * 40
            property real _minChartHeight:  ScreenTools.defaultFontPixelHeight * 15

            // enable mouse dragging
            MouseArea {
                property var _startPoint: undefined
                property double _scaling: 0
                anchors.fill: parent
                onPressed: (mouse) => {
                    _startPoint = Qt.point(mouse.x, mouse.y)
                    var start = chart.mapToValue(_startPoint)
                    var next = chart.mapToValue(Qt.point(mouse.x+1, mouse.y+1))
                    _scaling = next.x - start.x
                }
                onWheel: (wheel) => {
                    // The PID chart must not consume page scrolling or alter its
                    // time scale when the pointer is over the chart.
                    wheel.accepted = false
                }
                onPositionChanged: (mouse) => {
                    if(_startPoint != undefined) {
                        dataTimer.running = false
                        var cp = Qt.point(mouse.x, mouse.y)
                        var dx = (cp.x - _startPoint.x) * _scaling
                        _startPoint = cp
                        _xAxis.max -= dx
                        _xAxis.min -= dx
                    }
                }

                onReleased: {
                    _startPoint = undefined
                }
            }

            ColumnLayout {
                id:                       chartLegendColumn
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom:           parent.bottom
                anchors.bottomMargin:     _margins * 2
                spacing:                  ScreenTools.defaultFontPixelHeight / 4
                z:                        2

                Repeater {
                    model: _activePlots

                    RowLayout {
                        spacing: ScreenTools.defaultFontPixelWidth / 2

                        Rectangle {
                            Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 0.55
                            Layout.preferredHeight: Layout.preferredWidth
                            Layout.alignment:       Qt.AlignVCenter
                            color:                  _plotColors[index % _plotColors.length]
                            border.width:           1
                            border.color:           Qt.darker(color, 1.35)
                        }

                        QGCLabel {
                            Layout.alignment: Qt.AlignVCenter
                            text: {
                                var plotReference = modelData
                                var axisData = axis[plotReference.axisIndex]
                                var plotData = axisData.plot[plotReference.plotIndex]
                                return multiAxisPlot
                                        ? axisData.name + " " + plotData.name
                                        : plotData.name
                            }
                        }
                    }
                }
            }
        }

        Column {
            id:         leftPanelBottomColumn
            width:      chart.width
            spacing:    ScreenTools.defaultFontPixelHeight / 4

            ColumnLayout {
                id:      tuningDetails
                width:   parent.width
                spacing: _margins

                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: 1
                    Layout.topMargin:       _margins
                    Layout.bottomMargin:    _margins
                    color:                  _dividerColor
                }

                RowLayout {
                    visible: showAutoTuning

                    QGCRadioButton {
                        id:         useAutoTuningRadio
                        text:       qsTr("Use auto-tuning")
                        checked:    useAutoTuning
                        onClicked:  useAutoTuning = true
                    }
                    QGCRadioButton {
                        id:         useManualTuningRadio
                        text:       qsTr("Use manual tuning")
                        checked:    !useAutoTuning
                        onClicked:  useAutoTuning = false
                    }
                }

                AutotuneUI {
                    visible: showAutoTuning && useAutoTuningRadio.checked
                }

                ColumnLayout {
                    Layout.fillWidth:   cleanManualTuning
                    Layout.maximumWidth: cleanManualTuning
                                         ? ScreenTools.defaultFontPixelWidth * 48
                                         : Number.POSITIVE_INFINITY
                    Layout.alignment:   Qt.AlignLeft
                    Layout.leftMargin:  cleanManualTuning ? _margins : 0
                    Layout.rightMargin: cleanManualTuning ? _margins : 0
                    spacing:            cleanManualTuning ? ScreenTools.defaultFontPixelHeight * 0.7 : _margins
                    visible:            !showAutoTuning || useManualTuningRadio.checked

                    RowLayout {
                        spacing: _margins
                        visible: axis.length > 1

                        QGCLabel { text: qsTr("Select Tuning:") }

                        Repeater {
                            model: axis
                            QGCRadioButton {
                                text:      modelData.name
                                checked:   index == _currentAxis
                                onClicked: _currentAxis = index
                            }
                        }
                    }

                    // Instantiate all sliders (instead of switching the model), so that
                    // values are not changed unexpectedly if they do not match with a tick value.
                    Repeater {
                        model: axis

                        Repeater {
                            model: axis[index].params

                            SettingsGroupLayout {
                                id:                     tuningGroup
                                heading:                title
                                headingDescription:     description
                                visible:                _currentAxis === index
                                Layout.fillWidth:       cleanManualTuning
                                Layout.preferredWidth:  cleanManualTuning
                                                        ? Math.min(Math.max(0, tuningDetails.width - (_margins * 2)),
                                                                   ScreenTools.defaultFontPixelWidth * 48)
                                                        : ScreenTools.defaultFontPixelWidth * 40
                                Layout.bottomMargin:    cleanManualTuning ? ScreenTools.defaultFontPixelHeight * 0.35 : 0
                                showDividers:           false

                                FactSlider {
                                    fact:                   controller.getParameterFact(-1, param)
                                    from:                   min
                                    to:                     max
                                    majorTickStepSize:      step
                                    rulerColor:             cleanManualTuning ? _accentGreen : qgcPal.text
                                    Layout.fillWidth:       true
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth:       true
                        Layout.preferredHeight: 1
                        Layout.topMargin:       ScreenTools.defaultFontPixelHeight * 0.25
                        Layout.bottomMargin:    ScreenTools.defaultFontPixelHeight * 0.25
                        color:                  _dividerColor
                        visible:                cleanManualTuning
                    }

                    Column {
                        QGCLabel { text: qsTr("Clipboard Values:") }

                        GridLayout {
                            rows:           savedRepeater.model.length
                            flow:           GridLayout.TopToBottom
                            rowSpacing:     0
                            columnSpacing:  _margins

                            Repeater {
                                model: axis[_currentAxis].params

                                QGCLabel { text: param }
                            }

                            Repeater {
                                id: savedRepeater

                                QGCLabel { text: modelData }
                            }
                        }
                    }

                    RowLayout {
                        spacing: _margins

                        QGCButton {
                            text:       qsTr("Save To Clipboard")
                            onClicked:  saveTuningParamValues()
                        }

                        QGCButton {
                            text:       qsTr("Restore From Clipboard")
                            onClicked:  resetToSavedTuningParamValues()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth:       true
                        Layout.preferredHeight: 1
                        Layout.topMargin:       ScreenTools.defaultFontPixelHeight * 0.25
                        Layout.bottomMargin:    ScreenTools.defaultFontPixelHeight * 0.25
                        color:                  _dividerColor
                        visible:                cleanManualTuning
                    }
                }
            }

            RowLayout {
                spacing: _margins

                QGCButton {
                    text:       qsTr("Clear")
                    onClicked:  resetGraphs()
                }

                QGCButton {
                    text:       dataTimer.running ? qsTr("Stop") : qsTr("Start")
                    onClicked: {
                        dataTimer.running = !dataTimer.running
                        _last_t = 0
                        if (showAutoModeChange && autoModeChange.checked) {
                            globals.activeVehicle.flightMode = dataTimer.running ? globals.activeVehicle.stabilizedFlightMode : globals.activeVehicle.pauseFlightMode
                        }
                    }
                }
                Connections {
                    target: globals.activeVehicle
                    onArmedChanged: {
                        if (armed && !dataTimer.running) { // start plotting on arming if not already running
                            dataTimer.running = true
                            _last_t = 0
                        }
                    }
                }
            }

            QGCCheckBox {
                visible: showAutoModeChange
                id:     autoModeChange
                text:   qsTr("Automatic Flight Mode Switching")
                onClicked: {
                    if (checked)
                        dataTimer.running = false
                }
            }

            Column {
                visible: autoModeChange.checked
                QGCLabel {
                    text:            qsTr("Switches to 'Stabilized' when you click Start.")
                    font.pointSize:     ScreenTools.smallFontPointSize
                }

                QGCLabel {
                    text:            qsTr("Switches to '%1' when you click Stop.").arg(globals.activeVehicle.pauseFlightMode)
                    font.pointSize:     ScreenTools.smallFontPointSize
                }
            }

        }
    }
} // ColumnLayout
