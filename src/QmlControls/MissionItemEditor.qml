import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQml
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

/// Mission item edit control
Rectangle {
    id:             _root
    height:         _currentItem
                        ? (editorLoader.y + editorLoader.height + (_lightTheme ? ScreenTools.defaultFontPixelWidth * 1.1 : _innerMargin))
                        : (topRowLayout.y + topRowLayout.height + (_lightTheme ? ScreenTools.defaultFontPixelWidth * 1.1 : _margin))
    color:          "transparent"
    radius:         _radius
    opacity:        1.0
    // Light theme draws its own bordered card below so ListView clip can't eat the outline.
    // Dark theme keeps the root border.
    border.width:   _lightTheme ? 0 : 1
    border.color: {
        if (_lightTheme)
            return "transparent"
        return _currentItem ? Qt.rgba(0.14, 0.69, 0.36, 0.85)
                            : (_readyForSave ? Qt.rgba(1, 1, 1, 0.28) : "#23a800")
    }
    clip:           _lightTheme

    property var    map                 ///< Map control
    property var    masterController
    property var    missionItem         ///< MissionItem associated with this editor
    property bool   readOnly            ///< true: read only view, false: full editing view

    signal clicked
    signal remove
    signal selectNextNotReadyItem

    property var    _masterController:          masterController
    property var    _missionController:         _masterController.missionController
    property bool   _currentItem:               missionItem.isCurrentItem
    readonly property bool _lightTheme: typeof mainWindow !== "undefined"
                                        && mainWindow
                                        && mainWindow.customMissionStyleActive
    property color  _outerTextColor:            _lightTheme ? "#3f3f3f" : "#ffffff"
    property bool   _noMissionItemsAdded:       ListView.view.model.count === 1
    property real   _sectionSpacer:             ScreenTools.defaultFontPixelWidth / 2  // spacing between section headings
    property bool   _singleComplexItem:         _missionController.complexMissionItemNames.length === 1
    property bool   _readyForSave:              missionItem.readyForSaveState === VisualMissionItem.ReadyForSave

    readonly property real  _editFieldWidth:    Math.min(width - _innerMargin * 2, ScreenTools.defaultFontPixelWidth * 12)
    readonly property real  _margin:            ScreenTools.defaultFontPixelWidth * 0.7
    readonly property real  _innerMargin:       ScreenTools.defaultFontPixelWidth * 0.55
    readonly property real  _radius:            _lightTheme ? ScreenTools.defaultFontPixelWidth * 0.75 : ScreenTools.defaultFontPixelHeight * 0.55
    readonly property real  _hamburgerSize:     commandPicker.height * 0.75
    readonly property real  _trashSize:         commandPicker.height * 0.75
    readonly property bool  _waypointsOnlyMode: QGroundControl.corePlugin.options.missionWaypointsOnly
    readonly property color _cardBorderColor: {
        if (!_lightTheme)
            return "transparent"
        // Thin gray outline for Custom Mission cards
        return _currentItem ? "#c8c8c8" : "#e2e2e2"
    }

    QGCPalette {
        id: qgcPal
        colorGroupEnabled: enabled
    }

    // Custom Mission: white fill + crisp thin outline above content
    Rectangle {
        anchors.fill: parent
        visible: _root._lightTheme
        z: -1
        radius: _root._radius
        color: "#ffffff"
        border.width: 0
    }

    Rectangle {
        anchors.fill: parent
        visible: _root._lightTheme
        z: 100
        radius: _root._radius
        color: "transparent"
        // Hairline green/gray frame — keep thin on all sides
        border.width: 1
        border.color: _root._cardBorderColor
        antialiasing: false
        enabled: false
    }

    LiquidGlassSurface {
        anchors.fill: parent
        visible: !_root._lightTheme
        cornerRadius: _root._radius
        blurAmount: 16
        tintColor: _currentItem ? Qt.rgba(0.14, 0.69, 0.36, 0.22) : Qt.rgba(0.08, 0.10, 0.10, 0.55)
        rimColor: "transparent"
        innerGlow: "transparent"
        showGlint: false
    }

    RippleEffect {
        id: itemRipple
        rippleColor: _root._lightTheme
                     ? (_currentItem ? Qt.rgba(0.0, 0.63, 0.30, 0.28) : Qt.rgba(0, 0, 0, 0.12))
                     : Qt.rgba(1, 1, 1, 0.32)
        duration: 520
        clipRadius: _radius
    }

    FocusScope {
        id:             currentItemScope
        anchors.fill:   parent

        MouseArea {
            anchors.fill:   parent
            onClicked: function(mouse) {
                itemRipple.tap(mouse.x, mouse.y)
                if (mainWindow.allowViewSwitch()) {
                    currentItemScope.focus = true
                    _root.clicked()
                }
            }
        }
    }

    Component {
        id: editPositionDialog

        EditPositionDialog {
            coordinate:             missionItem.isSurveyItem ?  missionItem.centerCoordinate : missionItem.coordinate
            onCoordinateChanged:    missionItem.isSurveyItem ?  missionItem.centerCoordinate = coordinate : missionItem.coordinate = coordinate
        }
    }

    Row {
        id:                 topRowLayout
        anchors.left:       parent.left
        anchors.top:        parent.top
        anchors.leftMargin: _lightTheme ? ScreenTools.defaultFontPixelWidth * 1.1 : _margin
        anchors.topMargin:  _lightTheme ? ScreenTools.defaultFontPixelWidth * 1.1 : _margin
        spacing:            _margin

        Rectangle {
            id:                     notReadyForSaveIndicator
            anchors.verticalCenter: parent.verticalCenter
            width:                  _hamburgerSize
            height:                 width
            border.width:           1
            border.color:           "#00a651"
            color:                  "white"
            radius:                 width / 2
            visible:                !_readyForSave

            QGCLabel {
                id:                 readyForSaveLabel
                anchors.centerIn:   parent
                //: Indicator in Plan view to show mission item is not ready for save/send
                text:               qsTr("?")
                color:              "#00a651"
                font.pointSize:     ScreenTools.smallFontPointSize
            }
        }

        QGCColoredImage {
            id:                     deleteButton
            anchors.verticalCenter: parent.verticalCenter
            height:                 _hamburgerSize
            width:                  height
            sourceSize.height:      height
            fillMode:               Image.PreserveAspectFit
            mipmap:                 true
            smooth:                 true
            color:                  _outerTextColor
            visible:                _currentItem && missionItem.sequenceNumber !== 0
            source:                 "/res/TrashDelete.svg"

            QGCMouseArea {
                fillItem:   parent
                onClicked:  remove()
            }
        }

        Item {
            id:                     commandPicker
            anchors.verticalCenter: parent.verticalCenter
            height:                 ScreenTools.implicitComboBoxHeight
            width:                  innerLayout.width
            visible:                !commandLabel.visible

            RowLayout {
                id:                     innerLayout
                anchors.verticalCenter: parent.verticalCenter
                spacing:                _padding

                property real _padding: ScreenTools.comboBoxPadding

                QGCLabel {
                    text:           missionItem.commandName
                    color:          _outerTextColor
                    font.bold:      !_lightTheme
                    font.weight:    _lightTheme ? Font.Medium : Font.Normal
                    font.pointSize: _lightTheme ? ScreenTools.defaultFontPointSize : ScreenTools.mediumFontPointSize
                }

                QGCColoredImage {
                    height:             ScreenTools.defaultFontPixelWidth
                    width:              height
                    fillMode:           Image.PreserveAspectFit
                    smooth:             true
                    antialiasing:       true
                    color:              _outerTextColor
                    source:             "/qmlimages/arrow-down.png"
                }
            }

            QGCMouseArea {
                fillItem:   parent
                onClicked:  commandDialog.createObject(mainWindow).open()
            }

            Component {
                id: commandDialog

                MissionCommandDialog {
                    vehicle:                    masterController.controllerVehicle
                    missionItem:                _root.missionItem
                    map:                        _root.map
                    // FIXME: Disabling fly through commands doesn't work since you may need to change from an RTL to something else
                    flyThroughCommandsAllowed:  true //_missionController.flyThroughCommandsAllowed
                }
            }
        }

        QGCLabel {
            id:                     commandLabel
            anchors.verticalCenter: parent.verticalCenter
            width:                  commandPicker.width
            height:                 commandPicker.height
            visible:                !missionItem.isCurrentItem || !missionItem.isSimpleItem || _waypointsOnlyMode || missionItem.isTakeoffItem
            verticalAlignment:      Text.AlignVCenter
            text:                   missionItem.commandName
            color:                  _outerTextColor
            font.bold:              !_lightTheme
            font.weight:            _lightTheme ? Font.Medium : Font.Normal
            font.pointSize:         _lightTheme ? ScreenTools.defaultFontPointSize : ScreenTools.mediumFontPointSize
        }
    }

    Component {
        id: hamburgerMenuDropPanelComponent

        DropPanel {
            id: hamburgerMenuDropPanel

            sourceComponent: Component {
                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelHeight / 2

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Move to vehicle position")
                        enabled:            _activeVehicle && missionItem.specifiesCoordinate

                        onClicked: {
                            missionItem.coordinate = _activeVehicle.coordinate
                            hamburgerMenuDropPanel.close()
                        }

                        property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
                    }

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Move to previous item position")
                        enabled:            _missionController.previousCoordinate.isValid
                        onClicked: {
                            missionItem.coordinate = _missionController.previousCoordinate
                            hamburgerMenuDropPanel.close()
                        }
                    }

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Edit position...")
                        enabled:            missionItem.specifiesCoordinate
                        onClicked: {
                            editPositionDialog.createObject(mainWindow).open()
                            hamburgerMenuDropPanel.close()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth:       true
                        Layout.preferredHeight: 1
                        color:                  qgcPal.groupBorder
                    }

                    QGCCheckBoxSlider {
                        Layout.fillWidth:   true
                        text:               qsTr("Show all values")
                        visible:            QGroundControl.corePlugin.showAdvancedUI
                        checked:            missionItem.isSimpleItem ? missionItem.rawEdit : false
                        enabled:            missionItem.isSimpleItem && !_waypointsOnlyMode

                        onClicked: {
                            missionItem.rawEdit = checked
                            if (missionItem.rawEdit && !missionItem.friendlyEditAllowed) {
                                missionItem.rawEdit = false
                                checked = false
                                mainWindow.showMessageDialog(qsTr("Mission Edit"), qsTr("You have made changes to the mission item which cannot be shown in Simple Mode"))
                            }
                            hamburgerMenuDropPanel.close()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth:       true
                        Layout.preferredHeight: 1
                        color:                  qgcPal.groupBorder
                    }

                    QGCLabel {
                        text:       qsTr("Item #%1").arg(missionItem.sequenceNumber)
                        color:      _outerTextColor
                        enabled:    false
                    }
                }
            }
        }
    }


    QGCColoredImage {
        id:                     hamburger
        anchors.right:          parent.right
        anchors.rightMargin:    _lightTheme ? ScreenTools.defaultFontPixelWidth * 1.1 : _margin
        anchors.topMargin:      _lightTheme ? ScreenTools.defaultFontPixelWidth * 1.1 : _margin
        anchors.bottomMargin:   _margin
        anchors.verticalCenter: topRowLayout.verticalCenter
        width:                  _hamburgerSize
        height:                 _hamburgerSize
        sourceSize.height:      _hamburgerSize
        source:                 "qrc:/qmlimages/Hamburger.svg"
        visible:                missionItem.isCurrentItem && missionItem.sequenceNumber !== 0
        color:                  _outerTextColor

        QGCMouseArea {
            fillItem:   hamburger
            onClicked: (position) => {
                currentItemScope.focus = true
                // Custom Mission: open beside the mission list (over the map), not on top of the cards.
                var customMission = typeof mainWindow !== "undefined"
                                    && mainWindow
                                    && mainWindow.customMissionStyleActive
                var dropPanel
                if (customMission) {
                    var origin = _root.mapToItem(globals.parent, 0, 0)
                    dropPanel = hamburgerMenuDropPanelComponent.createObject(mainWindow, {
                        clickRect: Qt.rect(origin.x, origin.y, 0, Math.max(_root.height, hamburger.height)),
                        preferLeft: true
                    })
                } else {
                    position = Qt.point(position.x, position.y)
                    // For some strange reason using mainWindow in mapToItem doesn't work, so we use globals.parent instead which also gets us mainWindow
                    position = mapToItem(globals.parent, position)
                    dropPanel = hamburgerMenuDropPanelComponent.createObject(mainWindow, {
                        clickRect: Qt.rect(position.x, position.y, 0, 0)
                    })
                }
                dropPanel.open()
            }
        }
    }

    /*
    QGCLabel {
        id:                     notReadyForSaveLabel
        anchors.margins:        _margin
        anchors.left:           notReadyForSaveIndicator.right
        anchors.right:          parent.right
        anchors.top:            commandPicker.bottom
        visible:                _currentItem && !_readyForSave
        text:                   missionItem.readyForSaveState === VisualMissionItem.NotReadyForSaveTerrain ?
                                    qsTr("Incomplete: Waiting on terrain data.") :
                                    qsTr("Incomplete: Item not fully specified.")
        wrapMode:               Text.WordWrap
        horizontalAlignment:    Text.AlignHCenter
        color:                  qgcPal.warningText
    }

*/

    Loader {
        id:                 editorLoader
        anchors.left:       parent.left
        anchors.right:      parent.right
        anchors.top:        topRowLayout.bottom
        anchors.leftMargin:  _lightTheme ? ScreenTools.defaultFontPixelWidth * 1.1 : _innerMargin
        anchors.topMargin:   _lightTheme ? ScreenTools.defaultFontPixelWidth * 1.1 : _innerMargin
        anchors.rightMargin: _lightTheme ? ScreenTools.defaultFontPixelWidth * 1.1 : _innerMargin
        source:             _currentItem ? missionItem.editorQml : ""
        // Only the current mission item creates an editor. Loading it
        // synchronously prevents the delegate/context from being destroyed
        // while MissionSettingsEditor is still incubating during plan reloads.
        asynchronous:       false

        property var    masterController:   _masterController
        property real   availableWidth:     _root.width - anchors.leftMargin - anchors.rightMargin ///< How wide the editor should be
        property var    editorRoot:         _root
    }
}
