import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Rectangle {
    id:     root
    height: _currentItem ? valuesRect.y + valuesRect.height + (_margin * 2) : titleBar.y + titleBar.height + _margin
    color:  {
        if (_lightTheme)
            return "#ffffff"
        return _currentItem ? Qt.rgba(0.14, 0.69, 0.36, 0.22) : Qt.rgba(0.08, 0.10, 0.10, 0.45)
    }
    radius: _radius
    border.width: 1
    border.color: {
        if (_lightTheme)
            return _currentItem ? "#c8c8c8" : "#e2e2e2"
        return _currentItem ? Qt.rgba(0.14, 0.69, 0.36, 0.85) : Qt.rgba(1, 1, 1, 0.28)
    }
    antialiasing: !_lightTheme

    signal clicked()

    property var rallyPoint ///< RallyPoint object associated with editor
    property var controller ///< RallyPointController

    property bool   _currentItem:       rallyPoint ? rallyPoint === controller.currentRallyPoint : false
    readonly property bool _lightTheme: typeof mainWindow !== "undefined"
                                        && mainWindow
                                        && mainWindow.activeMissionEditor === "customMission"
    property color  _outerTextColor:    _lightTheme ? "#3f3f3f" : "#ffffff"

    readonly property real  _margin:            _lightTheme ? ScreenTools.defaultFontPixelWidth * 1.05 : ScreenTools.defaultFontPixelWidth / 2
    readonly property real  _radius:            _lightTheme ? ScreenTools.defaultFontPixelWidth * 0.75 : ScreenTools.defaultFontPixelWidth / 2
    readonly property real  _titleHeight:       ScreenTools.defaultFontPixelHeight * 2

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    MouseArea {
        anchors.fill: parent
        onClicked:    root.clicked()
    }

    Item {
        id:                 titleBar
        anchors.margins:    _margin
        anchors.top:        parent.top
        anchors.left:       parent.left
        anchors.right:      parent.right
        height:             _titleHeight

        MissionItemIndexLabel {
            id:                     indicator
            anchors.verticalCenter: parent.verticalCenter
            anchors.left:           parent.left
            label:                  "R"
            checked:                true
        }

        QGCLabel {
            anchors.leftMargin:     _margin
            anchors.left:           indicator.right
            anchors.verticalCenter: parent.verticalCenter
            text:                   qsTr("Rally Point")
            color:                  _outerTextColor
            font.weight:            _lightTheme ? Font.Medium : Font.Normal
            font.pointSize:         ScreenTools.defaultFontPointSize
        }

        QGCColoredImage {
            id:                     hamburger
            anchors.rightMargin:    _margin
            anchors.right:          parent.right
            anchors.verticalCenter: parent.verticalCenter
            width:                  ScreenTools.defaultFontPixelWidth * 2
            height:                 width
            sourceSize.height:      height
            source:                 "qrc:/qmlimages/Hamburger.svg"
            color:                  _outerTextColor

            MouseArea {
                anchors.fill:   parent
                onClicked:      hamburgerMenu.popup()

                QGCMenu {
                    id: hamburgerMenu

                    QGCMenuItem {
                        text:           qsTr("Delete")
                        onTriggered:    controller.removePoint(rallyPoint)
                    }
                }
            }
        }
    }

    Rectangle {
        id:                 valuesRect
        anchors.margins:    _margin
        anchors.left:       parent.left
        anchors.right:      parent.right
        anchors.top:        titleBar.bottom
        height:             valuesColumn.height + (_margin * 2)
        color:              _lightTheme ? "#f5f5f5" : Qt.rgba(1, 1, 1, 0.08)
        visible:            _currentItem
        radius:             _radius
        border.width:       1
        border.color:       _lightTheme ? "#e2e2e2" : Qt.rgba(1, 1, 1, 0.22)

        ColumnLayout {
            id:                 valuesColumn
            anchors.margins:    _margin
            anchors.left:       parent.left
            anchors.right:      parent.right
            anchors.top:        parent.top
            spacing:            _margin

            Repeater {
                model: rallyPoint ? rallyPoint.textFieldFacts : 0

                LabelledFactTextField {
                    Layout.fillWidth:   true
                    fact:               modelData
                    label:              modelData.name
                    visible:            modelData.name !== "RelativeAltitude"
                }
            }

            Repeater {
                model: rallyPoint ? rallyPoint.textFieldFacts : 0

                FactTextFieldSlider {
                    Layout.fillWidth:   true
                    label:              qsTr("Altitude")
                    fact:               modelData
                    backgroundColor:    "transparent"
                    visible:            modelData.name === "RelativeAltitude"
                }
            }
        }
    }
}
