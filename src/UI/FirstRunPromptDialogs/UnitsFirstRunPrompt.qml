import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

FirstRunPrompt {
    id:       root
    title:    qsTr("Measurement Units")
    promptId: QGroundControl.corePlugin.unitsFirstRunPromptId

    property real _cardPadding: ScreenTools.defaultFontPixelHeight * 0.9
    property real _rowSpacing:  ScreenTools.defaultFontPixelHeight * 0.35
    property real _fieldWidth:  ScreenTools.defaultFontPixelWidth * 19
    property var  _unitsSettings: QGroundControl.settingsManager.unitsSettings
    property var  _rgFacts: [
        _unitsSettings.horizontalDistanceUnits,
        _unitsSettings.verticalDistanceUnits,
        _unitsSettings.areaUnits,
        _unitsSettings.speedUnits,
        _unitsSettings.temperatureUnits
    ]
    property var _rgLabels: [
        qsTr("Horizontal Distance"),
        qsTr("Vertical Distance"),
        qsTr("Area"),
        qsTr("Speed"),
        qsTr("Temperature")
    ]
    readonly property color _titleText:      "#343434"
    readonly property color _secondaryText:  "#707070"
    readonly property color _cardBackground: "#f5f6f5"
    readonly property color _cardBorder:     "#dedede"
    readonly property color _divider:        "#e2e2e2"

    function changeSystemOfUnits(metric) {
        // Hack to force reload the ComboBoxes, otherwise they don't update
        unitComboBoxRepeater.model = 0
        unitComboBoxRepeater.model = _rgFacts.length

        if (_unitsSettings.horizontalDistanceUnits.visible) {
            _unitsSettings.horizontalDistanceUnits.value = metric ? UnitsSettings.HorizontalDistanceUnitsMeters : UnitsSettings.HorizontalDistanceUnitsFeet
        }
        if (_unitsSettings.verticalDistanceUnits.visible) {
            _unitsSettings.verticalDistanceUnits.value = metric ? UnitsSettings.VerticalDistanceUnitsMeters : UnitsSettings.VerticalDistanceUnitsFeet
        }
        if (_unitsSettings.areaUnits.visible) {
            _unitsSettings.areaUnits.value = metric ? UnitsSettings.AreaUnitsSquareMeters : UnitsSettings.AreaUnitsSquareFeet
        }
        if (_unitsSettings.speedUnits.visible) {
            _unitsSettings.speedUnits.value = metric ? UnitsSettings.SpeedUnitsMetersPerSecond : UnitsSettings.SpeedUnitsFeetPerSecond
        }
        if (_unitsSettings.temperatureUnits.visible) {
            _unitsSettings.temperatureUnits.value = metric ? UnitsSettings.TemperatureUnitsCelsius : UnitsSettings.TemperatureUnitsFarenheit
        }
    }

    function displayUnitName(unitName) {
        switch (unitName) {
        case "SquareFeet":
            return qsTr("Square Feet")
        case "SquareMeters":
            return qsTr("Square Meters")
        case "SquareKilometers":
            return qsTr("Square Kilometers")
        case "SquareMiles":
            return qsTr("Square Miles")
        case "Feet/second":
            return qsTr("Feet / second")
        case "Meters/second":
            return qsTr("Meters / second")
        case "Miles/hour":
            return qsTr("Miles / hour")
        case "Kilometers/hour":
            return qsTr("Kilometers / hour")
        default:
            return unitName
        }
    }

    ColumnLayout {
        id:    settingsColumn
        width: parent ? parent.width : implicitWidth
        spacing: ScreenTools.defaultFontPixelHeight * 0.85

        QGCLabel {
            Layout.fillWidth: true
            text: qsTr("Choose the measurement units you want to use. You can change them later in General Settings.")
            color: root._secondaryText
            font.pointSize: ScreenTools.defaultFontPointSize
            lineHeight: 1.15
            wrapMode: Text.WordWrap
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: unitsColumn.implicitHeight + (root._cardPadding * 2)
            color: root._cardBackground
            radius: ScreenTools.defaultFontPixelWidth
            border.width: 1
            border.color: root._cardBorder

            ColumnLayout {
                id: unitsColumn
                anchors.fill: parent
                anchors.margins: root._cardPadding
                spacing: root._rowSpacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth

                    QGCLabel {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: qsTr("System of units")
                        color: root._titleText
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    QGCComboBox {
                        Layout.preferredWidth: root._fieldWidth
                        Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 13
                        compact: true
                        font.pointSize: ScreenTools.defaultFontPointSize
                        lightStyle: true
                        sizeToContents: false
                        model: [ qsTr("Metric System"), qsTr("Imperial System") ]
                        currentIndex: _unitsSettings.horizontalDistanceUnits.value === UnitsSettings.HorizontalDistanceUnitsMeters ? 0 : 1
                        onActivated: (index) => { changeSystemOfUnits(index === 0) }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.15
                    Layout.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.15
                    color: root._divider
                }

                Repeater {
                    id: unitComboBoxRepeater
                    model: _rgFacts.length

                    RowLayout {
                        required property int index

                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelWidth
                        visible: root._rgFacts[index].visible

                        QGCLabel {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: root._rgLabels[index]
                            color: root._titleText
                            elide: Text.ElideRight
                        }

                        FactComboBox {
                            Layout.preferredWidth: root._fieldWidth
                            Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 13
                            compact: true
                            font.pointSize: ScreenTools.defaultFontPointSize
                            lightStyle: true
                            sizeToContents: false
                            fact: root._rgFacts[index]
                            indexModel: false
                            alternateText: root.displayUnitName(currentText)
                        }
                    }
                }
            }
        }
    }
}
