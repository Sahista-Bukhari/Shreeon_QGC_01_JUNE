import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCharts

import QGroundControl
import QGroundControl.Controls

ChartView {
    id:                 chartView
    theme:              _darkTheme ? ChartView.ChartThemeDark : ChartView.ChartThemeLight
    antialiasing:       true
    animationOptions:   ChartView.NoAnimation
    legend.visible:     false
    backgroundColor:    _dataCardFill
    backgroundRoundness: ScreenTools.defaultBorderRadius * 2
    dropShadowEnabled:  false
    margins.bottom:     ScreenTools.defaultFontPixelHeight * 1.5
    margins.top:        chartHeader.height + (ScreenTools.defaultFontPixelHeight * 2)
    visible:            chartController.chartFields.length > 0

    required property var inspectorController
    required property int chartIndex

    readonly property bool _darkTheme: {
        if (typeof mainWindow !== "undefined" && mainWindow)
            return mainWindow.uiThemeMode === mainWindow.themeBlack
        return chartPalette.globalTheme === QGCPalette.Dark
    }
    readonly property color _titleColor:   _darkTheme ? "#AEAEB2" : "#3A3A3C"
    readonly property color _bodyColor:    _darkTheme ? "#8E8E93" : "#3A3A3C"
    readonly property color _accentGreen:  "#00a04c"
    readonly property color _dataCardFill: _darkTheme ? chartPalette.windowShade : "#F5F5F5"
    readonly property color _tableLine:    _darkTheme ? chartPalette.windowShadeDark : "#E5E5E5"

    property var _seriesColors: ["#00E04B","#DE8500","#F32836","#BFBFBF","#536DFF","#EECC44"]

    QGCPalette {
        id:                chartPalette
        colorGroupEnabled: chartView.enabled
    }

    function addDimension(field) {
        var color   = _seriesColors[chartView.count]
        var serie   = createSeries(ChartView.SeriesTypeLine, field.label)
        serie.axisX = axisX
        serie.axisY = axisY
        serie.useOpenGL = QGroundControl.videoManager.gstreamerEnabled // Details on why here: https://github.com/mavlink/qgroundcontrol/issues/13068
        serie.color = color
        serie.width = 1
        chartController.addSeries(field, serie)
    }

    function delDimension(field) {
        if(chartController) {
            chartView.removeSeries(field.series)
            chartController.delSeries(field)
        }
    }

    function roomForNewDimension() {
        return chartController.chartFields.length < _seriesColors.length
    }

    MAVLinkChartController {
        id:                     chartController
        inspectorController:    chartView.inspectorController
        chartIndex:             chartView.chartIndex
    }

    DateTimeAxis {
        id:                         axisX
        min:                        chartController ? chartController.rangeXMin : new Date()
        max:                        chartController ? chartController.rangeXMax : new Date()
        visible:                    chartController !== null
        format:                     "<br/>mm:ss.zzz"
        tickCount:                  5
        gridVisible:                true
        gridLineColor:              chartView._tableLine
        labelsFont.family:          ScreenTools.fixedFontFamily
        labelsFont.pointSize:       ScreenTools.smallFontPointSize
        labelsColor:                chartView._bodyColor
    }

    ValueAxis {
        id:                         axisY
        min:                        chartController ? chartController.rangeYMin : 0
        max:                        chartController ? chartController.rangeYMax : 0
        visible:                    chartController !== null
        lineVisible:                false
        gridLineColor:              chartView._tableLine
        labelsFont.family:          ScreenTools.fixedFontFamily
        labelsFont.pointSize:       ScreenTools.smallFontPointSize
        labelsColor:                chartView._bodyColor
    }

    Row {
        id:                         chartHeader
        anchors.left:               parent.left
        anchors.leftMargin:         ScreenTools.defaultFontPixelWidth  * 4
        anchors.right:              parent.right
        anchors.rightMargin:        ScreenTools.defaultFontPixelWidth  * 4
        anchors.top:                parent.top
        anchors.topMargin:          ScreenTools.defaultFontPixelHeight * 1.5
        spacing:                    ScreenTools.defaultFontPixelWidth  * 2
        visible:                    chartController !== null
        GridLayout {
            columns:                2
            columnSpacing:          ScreenTools.defaultFontPixelWidth
            rowSpacing:             ScreenTools.defaultFontPixelHeight * 0.25
            anchors.verticalCenter: parent.verticalCenter
            QGCLabel {
                text:               qsTr("Scale:");
                color:              chartView._titleColor
                Layout.alignment:   Qt.AlignVCenter
            }
            QGCComboBox {
                Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 10
                Layout.maximumWidth: ScreenTools.defaultFontPixelWidth * 10
                height:             ScreenTools.defaultFontPixelHeight
                model:              controller.timeScales
                currentIndex:       chartController ? chartController.rangeXIndex : 0
                onActivated: (index) => { if(chartController) chartController.rangeXIndex = index; }
                Layout.alignment:   Qt.AlignVCenter

                background: Rectangle {
                    radius:       ScreenTools.defaultBorderRadius * 2
                    color:        chartView._dataCardFill
                    border.width: 1
                    border.color: chartView._accentGreen
                }
            }
            QGCLabel {
                text:               qsTr("Range:");
                color:              chartView._titleColor
                Layout.alignment:   Qt.AlignVCenter
            }
            QGCComboBox {
                Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 10
                Layout.maximumWidth: ScreenTools.defaultFontPixelWidth * 10
                height:             ScreenTools.defaultFontPixelHeight
                model:              controller.rangeList
                currentIndex:       chartController ? chartController.rangeYIndex : 0
                onActivated: (index) => { if(chartController) chartController.rangeYIndex = index; }
                Layout.alignment:   Qt.AlignVCenter

                background: Rectangle {
                    radius:       ScreenTools.defaultBorderRadius * 2
                    color:        chartView._dataCardFill
                    border.width: 1
                    border.color: chartView._accentGreen
                }
            }
        }
        ColumnLayout {
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
                model:              chartController ? chartController.chartFields : []
                QGCLabel {
                    text:           modelData.label
                    color:          chartView.series(index).color
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }
        }
    }
}
