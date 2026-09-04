pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

// Compact Fly View entry point for the three agriculture sprayer parameters.
// The existing Agriculture Spraying shower icon opens the editable control card.
Item {
    id: root

    property var sprayEnableFact: null
    property var sprayNozzleRateFact: null
    property var sprayPumpRateFact: null
    property var planMasterController: null
    property bool controlsEnabled: false

    signal sprayerSettingsConfirmed(bool enabled, double nozzleRate, double pumpRate)

    readonly property bool sprayAvailable: sprayEnableFact !== null
                                                   || sprayNozzleRateFact !== null
                                                   || sprayPumpRateFact !== null
    readonly property bool _lightTheme: mainWindow.uiThemeMode === mainWindow.themeDefault
    // Same footprint as FlyViewMapTools.IconButton.
    readonly property real _iconSize: Math.round(ScreenTools.defaultFontPixelWidth * 5)

    property bool _draftEnabled: false
    property real _draftNozzleRate: NaN
    property real _draftPumpRate: NaN

    opacity: controlsEnabled ? 1.0 : 0.35
    Behavior on opacity { NumberAnimation { duration: 150 } }

    implicitWidth: _iconSize
    implicitHeight: _iconSize
    width: implicitWidth
    height: implicitHeight

    function _factNumber(fact) {
        if (!fact)
            return NaN
        var number = Number(fact.rawValue)
        return isFinite(number) ? number : NaN
    }

    function _factMinimum(fact) {
        if (!fact || fact.minIsDefaultForType)
            return 0
        var number = Number(fact.min)
        return isFinite(number) ? number : 0
    }

    function _factMaximum(fact) {
        var minimum = _factMinimum(fact)
        if (!fact || fact.maxIsDefaultForType)
            return 1
        var number = Number(fact.max)
        return isFinite(number) && number > minimum ? number : minimum + 1
    }

    function _clampRate(fact, value) {
        if (!fact)
            return NaN

        var minimum = _factMinimum(fact)
        var maximum = _factMaximum(fact)
        var clamped = Math.max(minimum, Math.min(maximum, Number(value)))
        return Math.round(clamped * 1000) / 1000
    }

    function _loadSprayerDraft() {
        if (planMasterController && planMasterController.sprayerConfigured) {
            _draftEnabled = planMasterController.sprayerEnabled
            _draftNozzleRate = planMasterController.sprayerNozzleRate
            _draftPumpRate = planMasterController.sprayerPumpRate
            return
        }

        _draftEnabled = false
        var nozzle = _factNumber(sprayNozzleRateFact)
        var pump = _factNumber(sprayPumpRateFact)
        _draftNozzleRate = isFinite(nozzle) ? nozzle : NaN
        _draftPumpRate = isFinite(pump) ? pump : NaN
    }

    function _confirmSprayerSettings() {
        var nozzleRate = isFinite(_draftNozzleRate) ? _draftNozzleRate : NaN
        var pumpRate = isFinite(_draftPumpRate) ? _draftPumpRate : NaN
        sprayerSettingsConfirmed(_draftEnabled, nozzleRate, pumpRate)
        sprayerPopup.close()
    }

    function _openControlPanel() {
        if (!controlsEnabled)
            return

        if (sprayerPopup.opened) {
            sprayerPopup.close()
            return
        }

        _loadSprayerDraft()

        var overlay = Overlay.overlay
        var topPoint = root.mapToItem(overlay, root.width / 2, 0)
        var bottomPoint = root.mapToItem(overlay, root.width / 2, root.height)
        var margin = ScreenTools.defaultFontPixelWidth
        sprayerPopup.x = Math.max(margin,
                                  Math.min(overlay.width - sprayerPopup.width - margin,
                                           bottomPoint.x - sprayerPopup.width / 2))

        var popupGap = ScreenTools.defaultFontPixelHeight * 0.45
        var belowY = bottomPoint.y + popupGap
        var aboveY = topPoint.y - sprayerPopup.height - popupGap
        var preferredY = belowY + sprayerPopup.height <= overlay.height - margin
                         ? belowY : aboveY
        sprayerPopup.y = Math.max(margin,
                                  Math.min(overlay.height - sprayerPopup.height - margin,
                                           preferredY))
        sprayerPopup.open()
    }

    onControlsEnabledChanged: {
        if (!controlsEnabled)
            sprayerPopup.close()
    }
    onVisibleChanged: {
        if (!visible)
            sprayerPopup.close()
    }

    Rectangle {
        id: iconButton

        anchors.fill: parent
        radius: width / 2
        color: iconMouseArea.pressed
               ? Qt.rgba(0, 0, 0, 0.20)
               : "transparent"
        border.width: 0

        Behavior on color { ColorAnimation { duration: 120 } }

        scale: !root.controlsEnabled ? 1
               : (iconMouseArea.pressed ? 0.97 : (iconMouseArea.containsMouse ? 1.03 : 1))
        Behavior on scale {
            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.42
            shadowVerticalOffset: 2
            shadowBlur: 0.6
        }

        QGCColoredImage {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: -0.45
            width: Math.round(Math.min(parent.width, parent.height) * 0.85)
            height: width
            source: "qrc:/ModeSelection/spray.png"
            color: "white"
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        // A sub-pixel duplicate thickens the raster glyph without changing the
        // shared Agriculture Spraying shower artwork.
        QGCColoredImage {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: 0.45
            width: Math.round(Math.min(parent.width, parent.height) * 0.85)
            height: width
            source: "qrc:/ModeSelection/spray.png"
            color: "white"
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        MouseArea {
            id: iconMouseArea

            anchors.fill: parent
            hoverEnabled: root.controlsEnabled
            enabled: root.controlsEnabled
            cursorShape: root.controlsEnabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
            onClicked: root._openControlPanel()
        }
    }

    Popup {
        id: sprayerPopup

        parent: Overlay.overlay
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: ScreenTools.defaultFontPixelWidth * 1.15
        width: Math.min(ScreenTools.defaultFontPixelWidth * 34,
                        parent ? parent.width - ScreenTools.defaultFontPixelWidth * 2
                               : ScreenTools.defaultFontPixelWidth * 34)
        height: popupColumn.implicitHeight + topPadding + bottomPadding

        background: Rectangle {
            color: root._lightTheme ? "#ffffff" : Qt.rgba(0.07, 0.08, 0.08, 0.98)
            radius: ScreenTools.defaultFontPixelHeight * 0.45
            border.width: 1
            border.color: root._lightTheme ? "#d9d9d9" : Qt.rgba(1, 1, 1, 0.24)

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: root._lightTheme ? 0.28 : 0.65
                shadowVerticalOffset: 4
                shadowBlur: 0.8
            }
        }

        contentItem: ColumnLayout {
            id: popupColumn

            spacing: ScreenTools.defaultFontPixelHeight * 0.75

            QGCLabel {
                Layout.fillWidth: true
                text: qsTr("Enable the sprayer and set rates, then click OK to apply them to this plan.")
                color: root._lightTheme ? "#7a7a7a" : Qt.rgba(1, 1, 1, 0.68)
                font.pointSize: ScreenTools.smallFontPointSize
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth * 0.6

                QGCLabel {
                    Layout.fillWidth: true
                    text: qsTr("Sprayer")
                    color: root._lightTheme ? "#333333" : "#ffffff"
                    font.pointSize: ScreenTools.defaultFontPointSize
                }

                QGCLabel {
                    text: !root.sprayEnableFact ? qsTr("Unavailable")
                                                : (root._draftEnabled ? qsTr("Enabled") : qsTr("Disabled"))
                    color: root._draftEnabled ? "#00a651"
                                              : (root._lightTheme ? "#707070" : Qt.rgba(1, 1, 1, 0.65))
                }

                QGCCheckBoxSlider {
                    checked: root._draftEnabled
                    enabled: root.sprayEnableFact !== null
                    onClicked: root._draftEnabled = checked
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: root._lightTheme ? "#eeeeee" : Qt.rgba(1, 1, 1, 0.12)
            }

            DraftRateControl {
                Layout.fillWidth: true
                title: qsTr("Nozzle rate")
                fact: root.sprayNozzleRateFact
                draftValue: root._draftNozzleRate
                onValueCommitted: function(value) { root._draftNozzleRate = value }
            }

            DraftRateControl {
                Layout.fillWidth: true
                title: qsTr("Pump rate")
                fact: root.sprayPumpRateFact
                draftValue: root._draftPumpRate
                onValueCommitted: function(value) { root._draftPumpRate = value }
            }

            QGCButton {
                Layout.fillWidth: true
                Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.15
                text: qsTr("OK")
                primary: true
                enabled: root.sprayEnableFact !== null
                onClicked: root._confirmSprayerSettings()
            }
        }
    }

    component DraftRateControl: ColumnLayout {
        id: rateControl

        property string title
        property var fact: null
        property real draftValue: NaN
        signal valueCommitted(real value)

        property real pendingValue: NaN
        readonly property real minimumValue: root._factMinimum(fact)
        readonly property real maximumValue: root._factMaximum(fact)
        readonly property real displayValue: {
            if (isFinite(pendingValue))
                return pendingValue
            if (isFinite(draftValue))
                return draftValue
            return minimumValue
        }

        enabled: root._draftEnabled && fact !== null
        opacity: enabled ? 1 : 0.55
        spacing: ScreenTools.defaultFontPixelHeight * 0.2

        function commitValue(value) {
            var clamped = root._clampRate(fact, value)
            if (isFinite(clamped))
                rateControl.valueCommitted(clamped)
            pendingValue = NaN
        }

        QGCLabel {
            Layout.fillWidth: true
            text: rateControl.title
            color: root._lightTheme ? "#6b6b6b" : Qt.rgba(1, 1, 1, 0.72)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth * 0.7

            QGCSlider {
                id: rateSlider

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                from: rateControl.minimumValue
                to: rateControl.maximumValue
                stepSize: 0.01
                value: rateControl.displayValue
                enabled: rateControl.enabled

                onMoved: {
                    rateControl.pendingValue = value
                    rateWriteTimer.restart()
                }
                onPressedChanged: {
                    if (!pressed && isFinite(rateControl.pendingValue)) {
                        rateWriteTimer.stop()
                        rateControl.commitValue(rateControl.pendingValue)
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 12.5
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2
                color: root._lightTheme ? "#ffffff" : Qt.rgba(1, 1, 1, 0.06)
                radius: ScreenTools.defaultFontPixelHeight * 0.3
                border.width: 1
                border.color: root._lightTheme ? "#dcdcdc" : Qt.rgba(1, 1, 1, 0.22)

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    Item {
                        Layout.preferredWidth: parent.width * 0.25
                        Layout.fillHeight: true

                        QGCLabel {
                            anchors.centerIn: parent
                            text: "−"
                            color: root._lightTheme ? "#353535" : "#ffffff"
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                            onClicked: rateControl.commitValue(rateControl.displayValue - 0.01)
                        }
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        text: rateControl.fact ? rateControl.displayValue.toFixed(3) : "—"
                        color: root._lightTheme ? "#353535" : "#ffffff"
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Item {
                        Layout.preferredWidth: parent.width * 0.25
                        Layout.fillHeight: true

                        QGCLabel {
                            anchors.centerIn: parent
                            text: "+"
                            color: root._lightTheme ? "#353535" : "#ffffff"
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                            onClicked: rateControl.commitValue(rateControl.displayValue + 0.01)
                        }
                    }
                }
            }
        }

        Timer {
            id: rateWriteTimer

            interval: 140
            repeat: false
            onTriggered: rateControl.commitValue(rateControl.pendingValue)
        }
    }
}
