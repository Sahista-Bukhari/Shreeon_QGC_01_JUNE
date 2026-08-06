import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls

QGCPopupDialog {
    id:         root
    title:      qsTr("Select Mission Command")
    buttons:    Dialog.Cancel

    property var    vehicle
    property var    missionItem
    property var    map
    property bool   flyThroughCommandsAllowed

    readonly property bool _glassTheme: typeof mainWindow !== "undefined"
                                        && mainWindow.activeMissionEditor === "customMission"
    readonly property real _cardRadius: ScreenTools.defaultFontPixelHeight * 0.55

    ColumnLayout {
        spacing: _glassTheme ? ScreenTools.defaultFontPixelHeight * 0.55 : 0
        width: ScreenTools.defaultFontPixelWidth * (_glassTheme ? 44 : 40)

        RowLayout {
            spacing: ScreenTools.defaultFontPixelWidth
            Layout.fillWidth: true

            QGCLabel {
                text: qsTr("Category:")
                color: _glassTheme ? "#ffffff" : qgcPal.text
            }

            QGCComboBox {
                id:                     categoryCombo
                Layout.preferredWidth:  30 * ScreenTools.defaultFontPixelWidth
                model:                  QGroundControl.missionCommandTree.categoriesForVehicle(vehicle)

                function categorySelected(category) {
                    commandList.model = QGroundControl.missionCommandTree.getCommandsForCategory(vehicle, category, flyThroughCommandsAllowed)
                }

                Component.onCompleted: {
                    var category  = missionItem.category
                    currentIndex = find(category)
                    categorySelected(category)
                }

                onActivated: (index) => { categorySelected(textAt(index)) }
            }
        }

        Repeater {
            id:                 commandList
            Layout.fillWidth:   true

            delegate: Item {
                width:  commandList.width
                height: commandColumn.height + ScreenTools.defaultFontPixelHeight * (_glassTheme ? 1.15 : 1)

                property var    mavCmdInfo: modelData
                property color  textColor:  _glassTheme ? "#ffffff" : QGroundControl.globalPalette.buttonText

                Rectangle {
                    anchors.fill: parent
                    visible: !_glassTheme
                    color: QGroundControl.globalPalette.button
                }

                LiquidGlassSurface {
                    anchors.fill: parent
                    visible: _glassTheme
                    cornerRadius: _cardRadius
                    blurAmount: 12
                    tintColor: commandMouse.pressed ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.14)
                    rimColor: Qt.rgba(1, 1, 1, 0.32)
                    innerGlow: "transparent"
                    showGlint: false
                    pressed: commandMouse.pressed
                }

                Column {
                    id:                 commandColumn
                    anchors.margins:    ScreenTools.defaultFontPixelWidth * (_glassTheme ? 1.25 : 1)
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing:            _glassTheme ? ScreenTools.defaultFontPixelHeight * 0.15 : 0

                    QGCLabel {
                        text:           mavCmdInfo.friendlyName
                        color:          textColor
                        font.bold:      true
                    }

                    QGCLabel {
                        anchors.left:       parent.left
                        anchors.right:      parent.right
                        text:               mavCmdInfo.description
                        wrapMode:           Text.WordWrap
                        color:              _glassTheme ? Qt.rgba(1, 1, 1, 0.72) : textColor
                    }
                }

                MouseArea {
                    id:             commandMouse
                    anchors.fill:   parent
                    onClicked: {
                        missionItem.setMapCenterHintForCommandChange(map.center)
                        missionItem.command = mavCmdInfo.command
                        root.close()
                    }
                }
            }
        }
    }

    QGCPalette { id: qgcPal }
}
