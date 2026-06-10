import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

ColumnLayout {
    property real _doubleDescent: ScreenTools.defaultFontDescent * 2
    property real _fontSize: _rgFontSizes[instrumentValueData.factValueGrid.fontSize]
    property real _height: 0
    property real _horizontalLabelSpacing: ScreenTools.defaultFontPixelWidth
    property var _rgFontSizeRatios: [1, ScreenTools.smallFontPointRatio, ScreenTools.mediumFontPointRatio, ScreenTools.largeFontPointRatio]
    property var _rgFontSizeTightHeights: [_tightDefaultFontHeight * _rgFontSizeRatios[0] + 2, _tightDefaultFontHeight * _rgFontSizeRatios[1] + 2, _tightDefaultFontHeight * _rgFontSizeRatios[2] + 2, _tightDefaultFontHeight * _rgFontSizeRatios[3] + 2]
    property var _rgFontSizes: [ScreenTools.defaultFontPointSize, ScreenTools.smallFontPointSize, ScreenTools.mediumFontPointSize, ScreenTools.largeFontPointSize]
    property real _tightDefaultFontHeight: ScreenTools.defaultFontPixelHeight - _doubleDescent
    property real _tightHeight: _rgFontSizeTightHeights[instrumentValueData.factValueGrid.fontSize]
    property real _width: 0
    property alias contentWidth: valueRowLayout.implicitWidth
    property var instrumentValueData: null
    property bool settingsUnlocked: false

    // Helper to get just the unit
    function unitTextOnly() {
        if (instrumentValueData.fact && instrumentValueData.showUnits) {
            return instrumentValueData.fact.units;
        } else {
            return "";
        }
    }

    // Helper to get just the value
    function valueTextOnly() {
        if (instrumentValueData.fact) {
            return instrumentValueData.fact.enumOrValueString;
        } else {
            return qsTr("–");
        }
    }

    RowLayout {
        id: valueRowLayout

        Layout.alignment: Qt.AlignBottom
        spacing: ScreenTools.defaultFontPixelWidth / 4

        QGCLabel {
            Layout.alignment: Qt.AlignBaseline
            Layout.bottomMargin: 0
            color: instrumentValueData.isValidColor(instrumentValueData.currentColor) ? instrumentValueData.currentColor : qgcPal.text
            font.bold: true
            font.pointSize: ScreenTools.largeFontPointSize * 1.5
            text: valueTextOnly()
        }
        QGCLabel {
            Layout.alignment: Qt.AlignBaseline
            Layout.bottomMargin: 0
            color: "#B0B0B0"
            font.bold: true
            font.pointSize: ScreenTools.smallFontPointSize * 1.3
            text: unitTextOnly()
            visible: text !== ""
        }
    }
}
