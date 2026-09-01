import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

// Three-control agriculture card:
//   Sprayer (full width)
//   Nozzle Rate | Pump Rate
Item {
    id: root

    property var sprayEnableFact: null
    property var sprayNozzleRateFact: null
    property var sprayPumpRateFact: null

    signal sprayerToggleRequested()

    readonly property real _outerPad: ScreenTools.defaultFontPixelWidth * 0.8
    readonly property real _cellGap: ScreenTools.defaultFontPixelWidth * 0.45
    readonly property real _cellSize: (width - (_outerPad * 2) - _cellGap) / 2
    readonly property bool _lightTheme: mainWindow.uiThemeMode === mainWindow.themeDefault
    readonly property bool sprayAvailable: sprayEnableFact !== null
                                                   || sprayNozzleRateFact !== null
                                                   || sprayPumpRateFact !== null
    readonly property bool sprayEnabled: sprayEnableFact !== null
                                                  && Number(sprayEnableFact.rawValue) !== 0

    width: ScreenTools.defaultFontPixelWidth * 20
    implicitHeight: controlColumn.implicitHeight + (_outerPad * 2)
    height: implicitHeight

    function _factNumber(fact) {
        if (!fact)
            return NaN
        var number = Number(fact.rawValue)
        return isFinite(number) ? number : NaN
    }

    function _rateText(fact) {
        var number = _factNumber(fact)
        return isFinite(number) ? number.toFixed(2) : "—"
    }

    function _rateUnits(fact) {
        return fact && fact.units ? fact.units : ""
    }

    function _rateMinimum(fact) {
        if (!fact || fact.minIsDefaultForType)
            return 0
        var number = Number(fact.min)
        return isFinite(number) ? number : 0
    }

    function _rateMaximum(fact) {
        if (!fact || fact.maxIsDefaultForType)
            return 1
        var number = Number(fact.max)
        return isFinite(number) ? number : 1
    }

    function nudgeRate(fact, direction) {
        if (!fact || !sprayEnabled)
            return

        var current = _factNumber(fact)
        if (!isFinite(current))
            return
        var next = Math.max(_rateMinimum(fact),
                            Math.min(_rateMaximum(fact), current + (direction * 0.01)))
        fact.value = Math.round(next * 1000) / 1000
    }

    Rectangle {
        anchors.fill: parent
        color: root._lightTheme ? "#f7f7f7" : Qt.rgba(0.08, 0.09, 0.09, 0.94)
        radius: ScreenTools.defaultFontPixelWidth * 0.75
        border.width: 1
        border.color: root._lightTheme ? "#d8d8d8" : Qt.rgba(1, 1, 1, 0.25)

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: root._lightTheme ? 0.22 : 0.55
            shadowVerticalOffset: 2
            shadowBlur: 0.65
        }
    }

    Column {
        id: controlColumn

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root._outerPad
        spacing: root._cellGap

        Item {
            id: sprayerTile

            width: parent.width
            height: visible ? root._cellSize : 0
            visible: root.sprayEnableFact !== null

            Rectangle {
                anchors.fill: parent
                radius: ScreenTools.defaultFontPixelWidth * 0.5
                color: {
                    if (sprayerMouseArea.pressed)
                        return "#008f45"
                    if (root.sprayEnabled)
                        return "#00a651"
                    if (sprayerMouseArea.containsMouse)
                        return root._lightTheme ? "#e8e8e8" : Qt.rgba(1, 1, 1, 0.16)
                    return root._lightTheme ? "#ffffff" : Qt.rgba(1, 1, 1, 0.08)
                }
                border.width: 1
                border.color: root.sprayEnabled
                              ? "#00a651"
                              : (root._lightTheme ? "#dfdfdf" : Qt.rgba(1, 1, 1, 0.18))
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Column {
                anchors.centerIn: parent
                spacing: 0

                QGCLabel {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.sprayEnabled ? qsTr("ON") : qsTr("OFF")
                    color: root.sprayEnabled
                           ? "#ffffff"
                           : (root._lightTheme ? "#4a4a4a" : "#ffffff")
                    font.bold: true
                    font.pointSize: ScreenTools.defaultFontPointSize + 1
                }

                QGCLabel {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Sprayer")
                    color: root.sprayEnabled
                           ? "#ffffff"
                           : (root._lightTheme ? "#5e5e5e" : Qt.rgba(1, 1, 1, 0.80))
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }

            MouseArea {
                id: sprayerMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.sprayerToggleRequested()

                ToolTip.visible: containsMouse
                ToolTip.text: root.sprayEnabled ? qsTr("Turn sprayer off") : qsTr("Turn sprayer on")
            }
        }

        Row {
            width: parent.width
            height: visible ? root._cellSize : 0
            spacing: root._cellGap
            visible: root.sprayNozzleRateFact !== null || root.sprayPumpRateFact !== null

            RateTile {
                title: qsTr("Nozzle Rate")
                symbol: "◉"
                fact: root.sprayNozzleRateFact
                visible: fact !== null
            }

            RateTile {
                title: qsTr("Pump Rate")
                symbol: "↻"
                fact: root.sprayPumpRateFact
                visible: fact !== null
            }
        }
    }

    component RateTile: Item {
        id: rateTile

        property var fact: null
        property string title
        property string symbol

        width: root._cellSize
        height: root._cellSize
        opacity: root.sprayEnabled ? 1 : 0.55

        Rectangle {
            anchors.fill: parent
            radius: ScreenTools.defaultFontPixelWidth * 0.5
            color: root._lightTheme ? "#ffffff" : Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            border.color: root._lightTheme ? "#dfdfdf" : Qt.rgba(1, 1, 1, 0.18)
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: ScreenTools.defaultFontPixelWidth * 0.55
            spacing: ScreenTools.defaultFontPixelHeight * 0.12

            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth * 0.3

                QGCLabel {
                    Layout.alignment: Qt.AlignVCenter
                    text: rateTile.symbol
                    color: "#00a651"
                    font.bold: true
                    font.pointSize: ScreenTools.smallFontPointSize
                }

                QGCLabel {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: rateTile.title
                    color: root._lightTheme ? "#5e5e5e" : Qt.rgba(1, 1, 1, 0.80)
                    font.bold: true
                    font.pointSize: ScreenTools.smallFontPointSize * 0.82
                    elide: Text.ElideRight
                }

                QGCLabel {
                    Layout.alignment: Qt.AlignVCenter
                    visible: text.length > 0
                    text: root._rateUnits(rateTile.fact)
                    color: root._lightTheme ? "#777777" : Qt.rgba(1, 1, 1, 0.70)
                    font.pointSize: ScreenTools.smallFontPointSize * 0.7
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: ScreenTools.defaultFontPixelWidth * 0.25

                Rectangle {
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 2.3
                    Layout.fillHeight: true
                    radius: ScreenTools.defaultFontPixelWidth * 0.35
                    color: decreaseMouse.pressed
                           ? "#00a651"
                           : (decreaseMouse.containsMouse
                              ? (root._lightTheme ? "#e8e8e8" : Qt.rgba(1, 1, 1, 0.16))
                              : (root._lightTheme ? "#f4f4f4" : Qt.rgba(1, 1, 1, 0.08)))
                    border.width: 1
                    border.color: root._lightTheme ? "#dddddd" : Qt.rgba(1, 1, 1, 0.18)

                    QGCLabel {
                        anchors.centerIn: parent
                        text: "−"
                        color: decreaseMouse.pressed
                               ? "#ffffff"
                               : (root._lightTheme ? "#4a4a4a" : "#ffffff")
                        font.bold: true
                    }

                    MouseArea {
                        id: decreaseMouse
                        anchors.fill: parent
                        enabled: root.sprayEnabled && rateTile.fact !== null
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        onClicked: root.nudgeRate(rateTile.fact, -1)
                    }
                }

                FactTextField {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    fact: rateTile.fact
                    enabled: root.sprayEnabled && rateTile.fact !== null
                    showUnits: false
                    showHelp: false
                    persistentBorder: true
                    fieldBorderWidth: 1
                    activeFocusBorderColor: "#00a651"
                    fieldBackgroundColor: root._lightTheme ? "#f4f4f4" : Qt.rgba(1, 1, 1, 0.10)
                    fieldTextColor: root._lightTheme ? "#3f3f3f" : "#ffffff"
                    font.pointSize: ScreenTools.smallFontPointSize
                    horizontalAlignment: TextInput.AlignHCenter
                }

                Rectangle {
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 2.3
                    Layout.fillHeight: true
                    radius: ScreenTools.defaultFontPixelWidth * 0.35
                    color: increaseMouse.pressed
                           ? "#00a651"
                           : (increaseMouse.containsMouse
                              ? (root._lightTheme ? "#e8e8e8" : Qt.rgba(1, 1, 1, 0.16))
                              : (root._lightTheme ? "#f4f4f4" : Qt.rgba(1, 1, 1, 0.08)))
                    border.width: 1
                    border.color: root._lightTheme ? "#dddddd" : Qt.rgba(1, 1, 1, 0.18)

                    QGCLabel {
                        anchors.centerIn: parent
                        text: "+"
                        color: increaseMouse.pressed
                               ? "#ffffff"
                               : (root._lightTheme ? "#4a4a4a" : "#ffffff")
                        font.bold: true
                    }

                    MouseArea {
                        id: increaseMouse
                        anchors.fill: parent
                        enabled: root.sprayEnabled && rateTile.fact !== null
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        onClicked: root.nudgeRate(rateTile.fact, 1)
                    }
                }
            }
        }
    }
}
