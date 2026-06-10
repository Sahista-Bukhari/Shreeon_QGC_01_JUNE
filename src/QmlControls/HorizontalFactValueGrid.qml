import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQml

import QGroundControl.Controls
import QGroundControl.FlightMap
import QGroundControl

HorizontalFactValueGridTemplate {
    id: _root

    property real _editButtonSpacing: 2
    property real _margins: ScreenTools.defaultFontPixelWidth / 2
    property real _rowButtonHeight: ScreenTools.minTouchPixels / 2
    property real _rowButtonWidth: ScreenTools.minTouchPixels
    property int _rowMax: 2
    property bool settingsUnlocked: false

    Layout.preferredHeight: topLayout.height
    Layout.preferredWidth: topLayout.width

    QGCPalette {
        id: qgcPal

        colorGroupEnabled: enabled
    }
    ColumnLayout {
        id: topLayout

        spacing: 0

        RowLayout {
            spacing: parent.spacing

            RowLayout {
                id: labelValueColumnLayout

                spacing: 0

                Repeater {
                    id: columnRepeater

                    model: _root.columns

                    RowLayout {
                        property int columnIndex: index

                        spacing: 0

                        Repeater {
                            id: metricRepeater

                            model: object

                            RowLayout {
                                spacing: ScreenTools.defaultFontPixelWidth

                                Item {
                                    property var instrumentValueData: object

                                    Layout.alignment: Qt.AlignBottom
                                    Layout.leftMargin: ScreenTools.defaultFontPixelWidth * 1.2
                                    Layout.rightMargin: ScreenTools.defaultFontPixelWidth * 1.2
                                    implicitHeight: colLayout.implicitHeight
                                    implicitWidth: colLayout.implicitWidth

                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: _root.settingsUnlocked

                                        onClicked: valueEditDialog.createObject(mainWindow, {
                                            instrumentValueData: parent.instrumentValueData
                                        }).open()
                                    }
                                    ColumnLayout {
                                        id: colLayout

                                        anchors.fill: parent
                                        spacing: 0

                                        InstrumentValueLabel {
                                            Layout.alignment: Qt.AlignHCenter
                                            instrumentValueData: object
                                        }
                                        InstrumentValueValue {
                                            Layout.alignment: Qt.AlignHCenter
                                            instrumentValueData: object
                                        }
                                    }
                                }
                                Rectangle {
                                    Layout.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.2
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 1
                                    Layout.topMargin: 0
                                    color: "#B0B0B0"
                                    visible: (index < metricRepeater.count - 1) || (columnIndex < columnRepeater.count - 1)
                                }
                            }
                        }
                    }
                }
            }
            ColumnLayout {
                spacing: 1
                visible: settingsUnlocked

                QGCButton {
                    Layout.fillHeight: true
                    Layout.preferredWidth: ScreenTools.minTouchPixels
                    bottomPadding: 0
                    enabled: _root.columns.count < 2
                    leftPadding: 0
                    rightPadding: 0
                    text: qsTr("+")
                    topPadding: 0

                    onClicked: appendColumn()
                }
                QGCButton {
                    Layout.fillHeight: true
                    Layout.preferredWidth: ScreenTools.minTouchPixels
                    bottomPadding: 0
                    enabled: _root.columns.count > 1
                    leftPadding: 0
                    rightPadding: 0
                    text: qsTr("-")
                    topPadding: 0

                    onClicked: deleteLastColumn()
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 1
            visible: false // settingsUnlocked

            QGCButton {
                Layout.fillWidth: true
                Layout.preferredHeight: ScreenTools.minTouchPixels
                bottomPadding: 0
                enabled: (_root.height + (2 * (_rowButtonHeight + _margins))) < (screen.height - ScreenTools.toolbarHeight)
                leftPadding: 0
                rightPadding: 0
                text: qsTr("+")
                topPadding: 0

                onClicked: appendRow()
            }
            QGCButton {
                Layout.fillWidth: true
                Layout.preferredHeight: parent.height
                bottomPadding: 0
                enabled: _root.rowCount > 1
                leftPadding: 0
                rightPadding: 0
                text: qsTr("-")
                topPadding: 0

                onClicked: deleteLastRow()
            }
        }
    }

    // MouseArea removed - replaced with local MouseAreas in delegates

    Component {
        id: valueEditDialog

        InstrumentValueEditDialog {
        }
    }
}
