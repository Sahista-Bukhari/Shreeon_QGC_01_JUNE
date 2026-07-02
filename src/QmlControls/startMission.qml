import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Item {
    id: root

    width: ScreenTools.defaultFontPixelWidth * 48
    height: autoCheckCard.height

    signal executeRequested()
    signal collapsed()

    property real _margin: ScreenTools.defaultFontPixelWidth * 2.2
    property color _green: "#58a51c"
    property color _text: "#222222"
    property color _mutedText: "#666666"

    Rectangle {
        id: autoCheckCard
        anchors.left: parent.left
        anchors.right: parent.right
        height: contentColumn.implicitHeight
        radius: ScreenTools.defaultFontPixelWidth * 1.1
        color: "white"
        clip: true

        ColumnLayout {
            id: contentColumn
            width: parent.width
            spacing: 0

            QGCLabel {
                Layout.fillWidth: true
                Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.85
                text: qsTr("Pre-Task Auto Check")
                color: root._text
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.leftMargin: root._margin
                Layout.rightMargin: root._margin
                Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.85
                columns: 2
                rowSpacing: ScreenTools.defaultFontPixelHeight * 0.65
                columnSpacing: ScreenTools.defaultFontPixelWidth

                QGCLabel {
                    Layout.fillWidth: true
                    text: qsTr("Aircraft GNSS Signal")
                    color: root._mutedText
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: ScreenTools.defaultFontPixelWidth * 1.2

                    QGCLabel {
                        text: qsTr("Good")
                        color: root._text
                        font.weight: Font.DemiBold
                    }

                    QGCLabel {
                        text: qsTr("(41)")
                        color: root._green
                        font.weight: Font.DemiBold
                    }
                }

                QGCLabel {
                    Layout.fillWidth: true
                    text: qsTr("Radar")
                    color: root._mutedText
                }

                QGCLabel {
                    Layout.alignment: Qt.AlignRight
                    text: qsTr("OK")
                    color: root._text
                    font.weight: Font.DemiBold
                }

                QGCLabel {
                    Layout.fillWidth: true
                    text: qsTr("Connection Routing and RTH Speed")
                    color: root._mutedText
                    elide: Text.ElideRight
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: ScreenTools.defaultFontPixelWidth * 1.1

                    QGCLabel {
                        text: qsTr("24.8km/h")
                        color: root._mutedText
                    }

                    Slider {
                        id: speedSlider
                        from: 0
                        to: 40
                        value: 24.8
                        Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 12
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.7

                        background: Rectangle {
                            x: speedSlider.leftPadding
                            y: speedSlider.topPadding + speedSlider.availableHeight / 2 - height / 2
                            width: speedSlider.availableWidth
                            height: ScreenTools.defaultFontPixelHeight * 0.18
                            radius: height / 2
                            color: "#d8d8d8"

                            Rectangle {
                                width: speedSlider.visualPosition * parent.width
                                height: parent.height
                                radius: parent.radius
                                color: root._green
                            }
                        }

                        handle: Rectangle {
                            x: speedSlider.leftPadding + speedSlider.visualPosition * (speedSlider.availableWidth - width)
                            y: speedSlider.topPadding + speedSlider.availableHeight / 2 - height / 2
                            width: ScreenTools.defaultFontPixelHeight * 1.2
                            height: width
                            radius: width / 2
                            color: "white"
                            border.color: "#bdbdbd"
                            border.width: 1
                        }
                    }
                }

                QGCLabel {
                    Layout.fillWidth: true
                    text: qsTr("Task Complete")
                    color: root._mutedText
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: ScreenTools.defaultFontPixelWidth * 0.7

                    QGCLabel {
                        text: qsTr("Return-to-Home")
                        color: root._text
                    }

                    QGCLabel {
                        text: "\u25be"
                        color: "#b0b0b0"
                    }
                }

                QGCLabel {
                    Layout.fillWidth: true
                    text: qsTr("On Signal Lost")
                    color: root._mutedText
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: ScreenTools.defaultFontPixelWidth * 0.7

                    QGCLabel {
                        text: qsTr("Hover")
                        color: root._text
                    }

                    QGCLabel {
                        text: "\u25be"
                        color: "#b0b0b0"
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: root._margin
                Layout.rightMargin: root._margin
                Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.2
                spacing: ScreenTools.defaultFontPixelWidth

                QGCLabel {
                    Layout.fillWidth: true
                    text: qsTr("Continue task on signal lost")
                    color: root._text
                }

                Item {
                    id: continueSwitch
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 6.4
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.25
                    property bool checked: false

                    Rectangle {
                        id: toggleTrack
                        anchors.centerIn: parent
                        width: ScreenTools.defaultFontPixelWidth * 5.8
                        height: ScreenTools.defaultFontPixelHeight * 2.05
                        radius: height / 2
                        color: continueSwitch.checked ? root._green : "#e1e2e3"
                        border.color: continueSwitch.checked ? "#479116" : "#d5d6d8"
                        border.width: 1

                        Rectangle {
                            id: toggleThumb
                            x: continueSwitch.checked ? parent.width - width - ScreenTools.defaultFontPixelWidth * 0.25
                                                       : ScreenTools.defaultFontPixelWidth * 0.25
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.height - ScreenTools.defaultFontPixelWidth * 0.45
                            height: width
                            radius: width / 2
                            color: "white"
                            border.color: "#c7c7c7"
                            border.width: 1

                            Behavior on x {
                                NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
                            }
                        }
                    }

                    QGCMouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: continueSwitch.checked = !continueSwitch.checked
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.75
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 4.15

                Rectangle {
                    id: executeTrack
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(parent.width - root._margin * 2,
                                    ScreenTools.defaultFontPixelWidth * 35)
                    height: ScreenTools.defaultFontPixelHeight * 2.15
                    radius: height / 2
                    color: "#e3e3e3"

                    QGCLabel {
                        anchors.centerIn: parent
                        text: qsTr("Slide to Execute")
                        color: root._text
                        font.pointSize: ScreenTools.smallFontPointSize
                    }

                    Rectangle {
                        id: executeKnob
                        x: ScreenTools.defaultFontPixelWidth * 0.35
                        anchors.verticalCenter: parent.verticalCenter
                        width: ScreenTools.defaultFontPixelHeight * 1.75
                        height: width
                        radius: width / 2
                        color: "#555555"
                        border.color: "#bcbcbc"
                        border.width: 1

                        QGCLabel {
                            anchors.centerIn: parent
                            text: "\u00bb"
                            color: "#58e000"
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: dragArea
                            anchors.fill: parent
                            drag.target: executeKnob
                            drag.axis: Drag.XAxis
                            drag.minimumX: ScreenTools.defaultFontPixelWidth * 0.35
                            drag.maximumX: executeTrack.width - executeKnob.width - ScreenTools.defaultFontPixelWidth * 0.35

                            onReleased: {
                                if (executeKnob.x >= drag.maximumX * 0.82) {
                                    root.executeRequested()
                                }
                                executeKnob.x = drag.minimumX
                            }
                        }
                    }
                }

                QGCLabel {
                    anchors.top: executeTrack.bottom
                    anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.5
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: executeTrack.width
                    text: qsTr("Or press and hold R3 button to confirm")
                    color: "#555555"
                    font.pointSize: ScreenTools.smallFontPointSize
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: "#eeeeee"
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.05
                radius: autoCheckCard.radius
                color: "white"

                QGCLabel {
                    anchors.centerIn: parent
                    text: qsTr("Collapse(R2)")
                    color: root._text
                }

                QGCMouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.collapsed()
                }
            }
        }
    }
}