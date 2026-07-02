import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Popup {
    id: root

    signal saveRequested(string taskName)
    signal dismissed()

    property string initialTaskName: qsTr("Mapping Task")

    parent: Overlay.overlay
    x: 0
    y: 0
    width: mainWindow.width
    height: mainWindow.height
    padding: 0
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape

    onOpened: {
        taskNameField.text = root.initialTaskName
        taskNameField.forceActiveFocus()
        taskNameField.selectAll()
    }
    onClosed: dismissed()

    function submit() {
        var taskName = taskNameField.text.trim()
        if (taskName === "") {
            return
        }
        saveRequested(taskName)
        close()
    }

    background: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.58)
    }

    contentItem: Item {
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - ScreenTools.defaultFontPixelWidth * 4,
                            ScreenTools.defaultFontPixelWidth * 44)
            height: dialogColumn.implicitHeight
            radius: ScreenTools.defaultFontPixelWidth * 0.8
            color: "white"
            clip: true

            ColumnLayout {
                id: dialogColumn
                width: parent.width
                spacing: 0

                QGCLabel {
                    Layout.fillWidth: true
                    Layout.topMargin: ScreenTools.defaultFontPixelHeight * 1.4
                    text: qsTr("Saving Mapping Task")
                    color: "#202124"
                    font.pointSize: ScreenTools.mediumFontPointSize
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                }

                QGCLabel {
                    Layout.fillWidth: true
                    Layout.topMargin: ScreenTools.defaultFontPixelHeight
                    text: qsTr("Task Name")
                    color: "#343434"
                    horizontalAlignment: Text.AlignHCenter
                }

                QGCTextField {
                    id: taskNameField
                    Layout.fillWidth: true
                    Layout.leftMargin: ScreenTools.defaultFontPixelWidth * 2
                    Layout.rightMargin: ScreenTools.defaultFontPixelWidth * 2
                    Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.4
                    Layout.bottomMargin: ScreenTools.defaultFontPixelHeight * 1.2
                    text: qsTr("Mapping Task")
                    placeholderText: qsTr("Enter task name")
                    selectByMouse: true

                    background: Rectangle {
                        color: "white"
                        radius: ScreenTools.defaultBorderRadius * 2
                        border.width: 1
                        border.color: "#58ad2f"
                        implicitWidth: ScreenTools.implicitTextFieldWidth
                        implicitHeight: ScreenTools.implicitTextFieldHeight
                    }

                    Keys.onReturnPressed: root.submit()
                    Keys.onEnterPressed: root.submit()
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: "#dedede"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3
                        color: cancelMouseArea.pressed ? "#f1f1f1" : "white"

                        QGCLabel {
                            anchors.centerIn: parent
                            text: qsTr("Cancel")
                            color: "#5f6368"
                        }

                        QGCMouseArea {
                            id: cancelMouseArea
                            anchors.fill: parent
                            onClicked: root.close()
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                        color: "#dedede"
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3
                        color: saveMouseArea.pressed ? "#f1f1f1" : "white"

                        QGCLabel {
                            anchors.centerIn: parent
                            text: qsTr("Save")
                            color: taskNameField.text.trim() === "" ? "#a8a8a8" : "#58ad2f"
                            font.weight: Font.DemiBold
                        }

                        QGCMouseArea {
                            id: saveMouseArea
                            anchors.fill: parent
                            enabled: taskNameField.text.trim() !== ""
                            onClicked: root.submit()
                        }
                    }
                }
            }
        }
    }
}
