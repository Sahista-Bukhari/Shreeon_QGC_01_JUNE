import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Item {
    id:     summaryRow
    width:  parent ? parent.width : 0
    height: visible ? _rowH : 0

    property string labelText: "Label"
    property string valueText: "value"

    readonly property real  _rowH:          ScreenTools.defaultFontPixelHeight * 2.4
    readonly property color _textColor:     qgcPal.globalTheme === QGCPalette.Dark ? "#AEAEB2" : "#3A3A3C"
    readonly property color _readyColor:    "#00a04c"
    readonly property color _dividerColor:  qgcPal.globalTheme === QGCPalette.Dark
                                            ? Qt.rgba(1, 1, 1, 0.12)
                                            : "#E5E5EA"
    readonly property bool  _isReady:       valueText === qsTr("Ready") || valueText === "Ready"
    readonly property bool  _needsSetup:    valueText === qsTr("Setup required") || valueText === "Setup required"

    function _notifyCard() {
        var item = parent
        while (item) {
            if (typeof item.refreshRowStatus === "function") {
                item.refreshRowStatus()
                return
            }
            item = item.parent
        }
    }

    onValueTextChanged: _notifyCard()
    Component.onCompleted: _notifyCard()

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    Rectangle {
        anchors.top:        parent.top
        width:              parent.width
        height:             1
        color:              summaryRow._dividerColor
        visible:            summaryRow.y > 1
    }

    RowLayout {
        anchors.fill:           parent
        anchors.topMargin:      1
        spacing:                ScreenTools.defaultFontPixelWidth

        QGCLabel {
            Layout.fillWidth:       true
            Layout.minimumWidth:    0
            text:                   summaryRow.labelText
            color:                  summaryRow._textColor
            font.family:            ScreenTools.normalFontFamily
            font.pointSize:         ScreenTools.defaultFontPointSize
            elide:                  Text.ElideRight
            wrapMode:               Text.NoWrap
        }

        QGCLabel {
            text:                   summaryRow.valueText
            color:                  summaryRow._isReady
                                    ? summaryRow._readyColor
                                    : (summaryRow._needsSetup ? qgcPal.warningText : summaryRow._textColor)
            font.family:            ScreenTools.normalFontFamily
            font.pointSize:         ScreenTools.defaultFontPointSize
            elide:                  Text.ElideRight
            horizontalAlignment:    Text.AlignRight
            Layout.alignment:       Qt.AlignRight
        }
    }
}
