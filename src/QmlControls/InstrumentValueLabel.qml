import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

ColumnLayout {
    property var _color: instrumentValueData.isValidColor(instrumentValueData.currentColor) ? instrumentValueData.currentColor : qgcPal.text
    property real _doubleDescent: ScreenTools.defaultFontDescent * 2
    property bool _iconVisible: instrumentValueData.rangeType === InstrumentValueData.IconSelectRange || instrumentValueData.icon
    property var _rgFontSizeRatios: [1, ScreenTools.smallFontPointRatio, ScreenTools.mediumFontPointRatio, ScreenTools.largeFontPointRatio]
    property var _rgFontSizeTightHeights: [_tightDefaultFontHeight * _rgFontSizeRatios[0] + 2, _tightDefaultFontHeight * _rgFontSizeRatios[1] + 2, _tightDefaultFontHeight * _rgFontSizeRatios[2] + 2, _tightDefaultFontHeight * _rgFontSizeRatios[3] + 2]
    property var _rgFontSizes: [ScreenTools.defaultFontPointSize, ScreenTools.smallFontPointSize, ScreenTools.mediumFontPointSize, ScreenTools.largeFontPointSize]
    property real _tightDefaultFontHeight: ScreenTools.defaultFontPixelHeight - _doubleDescent
    property real _tightHeight: _rgFontSizeTightHeights[instrumentValueData.factValueGrid.fontSize]
    property var instrumentValueData: null

    QGCPalette {
        id: qgcPal

        colorGroupEnabled: enabled
    }
    QGCColoredImage {
        id: valueIcon

        readonly property string iconPrefix: "/InstrumentValueIcons/"

        function updateIcon() {
            if (instrumentValueData.rangeType === InstrumentValueData.IconSelectRange) {
                valueIcon.source = instrumentValueData.currentIcon != "" ? iconPrefix + instrumentValueData.currentIcon : "";
            } else if (instrumentValueData.icon) {
                valueIcon.source = instrumentValueData.icon != "" ? iconPrefix + instrumentValueData.icon : "";
            } else {
                valueIcon.source = "";
            }
        }

        Layout.alignment: Qt.AlignVCenter
        color: _color
        fillMode: Image.PreserveAspectFit
        height: _tightHeight * 0.75
        mipmap: true
        opacity: instrumentValueData.currentOpacity
        smooth: true
        sourceSize.height: height
        visible: false // Force Hide Icon

        width: _tightHeight * 0.85

        Component.onCompleted: updateIcon()

        Connections {
            function onCurrentIconChanged() {
                valueIcon.updateIcon();
            }
            function onIconChanged() {
                valueIcon.updateIcon();
            }
            function onRangeTypeChanged() {
                valueIcon.updateIcon();
            }

            target: instrumentValueData
        }
    }
    QGCLabel {
        Layout.alignment: Qt.AlignVCenter
        color: _color
        font.bold: true
        font.capitalization: Font.AllUppercase
        font.pointSize: ScreenTools.smallFontPointSize
        height: _tightHeight
        opacity: instrumentValueData.currentOpacity
        text: instrumentValueData.text
        visible: true // Force Show Text
    }
}
