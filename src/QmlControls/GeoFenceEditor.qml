import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtPositioning

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Rectangle {
    id:     geoFenceEditorRect
    height: geoFenceItems.y + geoFenceItems.height + (_margin * 2)
    radius: _radius
    color:  _lightTheme ? "#ffffff" : Qt.rgba(0.14, 0.69, 0.36, 0.22)
    border.width: 1
    border.color: _lightTheme ? "#c8c8c8" : Qt.rgba(0.14, 0.69, 0.36, 0.85)
    antialiasing: !_lightTheme

    property var    myGeoFenceController
    property var    flightMap

    readonly property bool  _lightTheme: typeof mainWindow !== "undefined"
                                         && mainWindow
                                         && mainWindow.activeMissionEditor === "customMission"
    readonly property real  _editFieldWidth:    Math.min(width - _margin * 2, ScreenTools.defaultFontPixelWidth * 15)
    readonly property real  _margin:            _lightTheme ? ScreenTools.defaultFontPixelWidth * 1.05 : ScreenTools.defaultFontPixelWidth / 2
    readonly property real  _radius:            _lightTheme ? ScreenTools.defaultFontPixelWidth * 0.75 : ScreenTools.defaultFontPixelWidth / 2
    readonly property color _titleColor:        "#3f3f3f"
    readonly property color _bodyColor:         _lightTheme ? "#6a6a6a" : Qt.rgba(1, 1, 1, 0.88)

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    QGCLabel {
        id:                 geoFenceLabel
        anchors.margins:    _margin
        anchors.left:       parent.left
        anchors.right:      parent.right
        anchors.top:        parent.top
        text:               qsTr("GeoFence")
        color:              geoFenceEditorRect._titleColor
        font.weight:        Font.Medium
        font.pointSize:     _lightTheme ? ScreenTools.defaultFontPointSize : ScreenTools.mediumFontPointSize
        horizontalAlignment: Text.AlignLeft
        anchors.leftMargin: _margin
    }

    Rectangle {
        id:                 geoFenceItems
        anchors.margins:    _margin
        anchors.left:       parent.left
        anchors.right:      parent.right
        anchors.top:        geoFenceLabel.bottom
        height:             fenceColumn.y + fenceColumn.height + (_margin * 2)
        color:              _lightTheme ? "#f5f5f5" : Qt.rgba(1, 1, 1, 0.08)
        radius:             _radius
        border.width:       1
        border.color:       _lightTheme ? "#e2e2e2" : Qt.rgba(1, 1, 1, 0.22)

        Column {
            id:                 fenceColumn
            anchors.margins:    _margin
            anchors.top:        parent.top
            anchors.left:       parent.left
            anchors.right:      parent.right
            spacing:            _margin

            QGCLabel {
                anchors.left:       parent.left
                anchors.right:      parent.right
                wrapMode:           Text.WordWrap
                color:              geoFenceEditorRect._bodyColor
                font.pointSize:     myGeoFenceController.supported ? ScreenTools.smallFontPointSize : ScreenTools.defaultFontPointSize
                text:               myGeoFenceController.supported ?
                                        qsTr("GeoFencing allows you to set a virtual fence around the area you want to fly in.") :
                                        qsTr("This vehicle does not support GeoFence.")
            }

            Column {
                anchors.left:       parent.left
                anchors.right:      parent.right
                spacing:            _margin
                visible:            myGeoFenceController.supported

                Repeater {
                    model: myGeoFenceController.params

                    Item {
                        width:  fenceColumn.width
                        height: showCombo ? comboField.height : (sliderField.visible ? sliderField.height : textField.height)

                        property bool showCombo: modelData.enumStrings.length > 0

                        QGCLabel {
                            id:                 textFieldLabel
                            anchors.baseline:   textField.baseline
                            text:               myGeoFenceController.paramLabels[index]
                            color:              geoFenceEditorRect._bodyColor
                            visible:            parent.showCombo || !sliderField.visible
                        }

                        FactTextField {
                            id:             textField
                            anchors.right:  parent.right
                            width:          _editFieldWidth
                            showUnits:      true
                            fact:           modelData
                            visible:        !parent.showCombo && !sliderField.visible
                        }

                        FactTextFieldSlider {
                            id:                 sliderField
                            anchors.left:       parent.left
                            anchors.right:      parent.right
                            label:              myGeoFenceController.paramLabels[index]
                            fact:               modelData
                            backgroundColor:    "transparent"
                            visible:            !parent.showCombo && fact && fact.userMin !== undefined && fact.userMax !== undefined
                        }

                        FactComboBox {
                            id:             comboField
                            anchors.right:  parent.right
                            width:          _editFieldWidth
                            indexModel:     false
                            fact:           showCombo ? modelData : _nullFact
                            visible:        parent.showCombo

                            property var _nullFact: Fact { }
                        }
                    }
                }

                SectionHeader {
                    id:             insertSection
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    text:           qsTr("Insert GeoFence")
                    color:          geoFenceEditorRect._titleColor
                }

                QGCButton {
                    width:  parent.width
                    text:   qsTr("Polygon Fence")

                    onClicked: {
                        var rect = Qt.rect(flightMap.centerViewport.x, flightMap.centerViewport.y, flightMap.centerViewport.width, flightMap.centerViewport.height)
                        var topLeftCoord = flightMap.toCoordinate(Qt.point(rect.x, rect.y), false /* clipToViewPort */)
                        var bottomRightCoord = flightMap.toCoordinate(Qt.point(rect.x + rect.width, rect.y + rect.height), false /* clipToViewPort */)
                        myGeoFenceController.addInclusionPolygon(topLeftCoord, bottomRightCoord)
                    }
                }

                QGCButton {
                    width:  parent.width
                    text:   qsTr("Circular Fence")

                    onClicked: {
                        var rect = Qt.rect(flightMap.centerViewport.x, flightMap.centerViewport.y, flightMap.centerViewport.width, flightMap.centerViewport.height)
                        var topLeftCoord = flightMap.toCoordinate(Qt.point(rect.x, rect.y), false /* clipToViewPort */)
                        var bottomRightCoord = flightMap.toCoordinate(Qt.point(rect.x + rect.width, rect.y + rect.height), false /* clipToViewPort */)
                        myGeoFenceController.addInclusionCircle(topLeftCoord, bottomRightCoord)
                    }
                }

                SectionHeader {
                    id:             polygonSection
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    text:           qsTr("Polygon Fences")
                    color:          geoFenceEditorRect._titleColor
                }

                QGCLabel {
                    text:       qsTr("None")
                    color:      geoFenceEditorRect._bodyColor
                    visible:    polygonSection.checked && myGeoFenceController.polygons.count === 0
                }

                GridLayout {
                    width:              parent.width
                    columns:            3
                    flow:               GridLayout.TopToBottom
                    visible:            polygonSection.checked && myGeoFenceController.polygons.count > 0

                    QGCLabel {
                        text:               qsTr("Inclusion")
                        color:              geoFenceEditorRect._bodyColor
                        Layout.column:      0
                        Layout.alignment:   Qt.AlignHCenter
                    }

                    Repeater {
                        model: myGeoFenceController.polygons

                        QGCCheckBox {
                            checked:            object.inclusion
                            onClicked:          object.inclusion = checked
                            Layout.alignment:   Qt.AlignHCenter
                        }
                    }

                    QGCLabel {
                        text:               qsTr("Edit")
                        color:              geoFenceEditorRect._bodyColor
                        Layout.column:      1
                        Layout.alignment:   Qt.AlignHCenter
                    }

                    Repeater {
                        model: myGeoFenceController.polygons

                        QGCRadioButton {
                            checked:            _interactive
                            Layout.alignment:   Qt.AlignHCenter

                            property bool _interactive: object.interactive

                            on_InteractiveChanged: checked = _interactive

                            onClicked: {
                                myGeoFenceController.clearAllInteractive()
                                object.interactive = checked
                            }
                        }
                    }

                    QGCLabel {
                        text:               qsTr("Delete")
                        color:              geoFenceEditorRect._bodyColor
                        Layout.column:      2
                        Layout.alignment:   Qt.AlignHCenter
                    }

                    Repeater {
                        model: myGeoFenceController.polygons

                        QGCButton {
                            text:               qsTr("Del")
                            Layout.alignment:   Qt.AlignHCenter
                            onClicked:          myGeoFenceController.deletePolygon(index)
                        }
                    }
                }

                SectionHeader {
                    id:             circleSection
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    text:           qsTr("Circular Fences")
                    color:          geoFenceEditorRect._titleColor
                }

                QGCLabel {
                    text:       qsTr("None")
                    color:      geoFenceEditorRect._bodyColor
                    visible:    circleSection.checked && myGeoFenceController.circles.count === 0
                }

                GridLayout {
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    columns:            4
                    flow:               GridLayout.TopToBottom
                    visible:            circleSection.checked && myGeoFenceController.circles.count > 0

                    QGCLabel {
                        text:               qsTr("Inclusion")
                        color:              geoFenceEditorRect._bodyColor
                        Layout.column:      0
                        Layout.alignment:   Qt.AlignHCenter
                    }

                    Repeater {
                        model: myGeoFenceController.circles

                        QGCCheckBox {
                            checked:            object.inclusion
                            onClicked:          object.inclusion = checked
                            Layout.alignment:   Qt.AlignHCenter
                        }
                    }

                    QGCLabel {
                        text:               qsTr("Edit")
                        color:              geoFenceEditorRect._bodyColor
                        Layout.column:      1
                        Layout.alignment:   Qt.AlignHCenter
                    }

                    Repeater {
                        model: myGeoFenceController.circles

                        QGCRadioButton {
                            checked:            _interactive
                            Layout.alignment:   Qt.AlignHCenter

                            property bool _interactive: object.interactive

                            on_InteractiveChanged: checked = _interactive

                            onClicked: {
                                myGeoFenceController.clearAllInteractive()
                                object.interactive = checked
                            }
                        }
                    }

                    QGCLabel {
                        text:               qsTr("Radius")
                        color:              geoFenceEditorRect._bodyColor
                        Layout.column:      2
                        Layout.alignment:   Qt.AlignHCenter
                    }

                    Repeater {
                        model: myGeoFenceController.circles

                        FactTextFieldSlider {
                            fact:               object.radius
                            label:              ""
                            backgroundColor:    "transparent"
                            Layout.fillWidth:   true
                            Layout.alignment:   Qt.AlignHCenter
                        }
                    }

                    QGCLabel {
                        text:               qsTr("Delete")
                        color:              geoFenceEditorRect._bodyColor
                        Layout.column:      3
                        Layout.alignment:   Qt.AlignHCenter
                    }

                    Repeater {
                        model: myGeoFenceController.circles

                        QGCButton {
                            text:               qsTr("Del")
                            Layout.alignment:   Qt.AlignHCenter
                            onClicked:          myGeoFenceController.deleteCircle(index)
                        }
                    }
                }

                SectionHeader {
                    id:             breachReturnSection
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    text:           qsTr("Breach Return Point")
                    color:          geoFenceEditorRect._titleColor
                }

                QGCButton {
                    text:               qsTr("Add Breach Return Point")
                    visible:            breachReturnSection.visible && !myGeoFenceController.breachReturnPoint.isValid
                    anchors.left:       parent.left
                    anchors.right:      parent.right

                    onClicked: myGeoFenceController.breachReturnPoint = flightMap.center
                }

                QGCButton {
                    text:               qsTr("Remove Breach Return Point")
                    visible:            breachReturnSection.visible && myGeoFenceController.breachReturnPoint.isValid
                    anchors.left:       parent.left
                    anchors.right:      parent.right

                    onClicked: myGeoFenceController.breachReturnPoint = QtPositioning.coordinate()
                }

                ColumnLayout {
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    spacing:            _margin
                    visible:            breachReturnSection.visible && myGeoFenceController.breachReturnPoint.isValid

                    FactTextFieldSlider {
                        Layout.fillWidth:   true
                        label:              qsTr("Altitude")
                        fact:               myGeoFenceController.breachReturnAltitude
                        backgroundColor:    "transparent"
                    }
                }
            }
        }
    }
}
