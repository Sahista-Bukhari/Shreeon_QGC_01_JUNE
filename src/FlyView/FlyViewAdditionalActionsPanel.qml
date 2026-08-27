pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Qt5Compat.GraphicalEffects

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

Item {
    id: root
    
    property var additionalActions
    property var customActions
    property var mavlinkActions
    
    property var popupRef: null
    
    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var _guidedController: globals.guidedControllerFlyView
    readonly property bool _lightTheme: mainWindow.uiThemeMode === mainWindow.themeDefault
    
    property real _buttonHeight: ScreenTools.defaultFontPixelHeight * 2.1
    
    width: ScreenTools.defaultFontPixelWidth * 34
    implicitWidth: width
    implicitHeight: mainColumn.height + ScreenTools.defaultFontPixelHeight * 0.8

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    // --- SHARED SQUIRCLE BUTTON STYLE ---
    Component {
        id: actionButtonDelegate
        
        Rectangle {
            id: btn
            property string actionTitle: ""
            property var actionObj: null
            property var onTrigger: function() {}
            
            width: parent.width
            height: root._buttonHeight
            radius: height * 0.4
            color: mouseArea.containsMouse
                   ? (root._lightTheme ? "#e8f5ee" : Qt.rgba(0.08, 0.2, 0.1, 1.0))
                   : (root._lightTheme ? "#f3f3f3" : Qt.rgba(1, 1, 1, 0.1))
            border.color: mouseArea.containsMouse
                          ? (root._lightTheme ? "#00a651" : "#00ff88")
                          : (root._lightTheme ? "#dedede" : Qt.rgba(1, 1, 1, 0.15))
            border.width: 1
            clip: true

            property string icon: {
                var t = actionTitle.toLowerCase();
                if (t.includes("altitude")) return "qrc:/res/altitude.svg";
                if (t.includes("mission")) return "qrc:/res/mission.svg";
                if (t.includes("speed")) return "qrc:/res/speed.svg";
                if (t.includes("abort")) return "qrc:/res/abort.svg";
                return (actionObj && actionObj.iconSource && actionObj.iconSource !== "") ? actionObj.iconSource : "qrc:/qmlimages/Gears.svg";
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 1.5
                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 1.5
                spacing: ScreenTools.defaultFontPixelWidth * 1.5

                QGCColoredImage {
                    Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.1
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.1
                    source:                 btn.icon
                    color:                  mouseArea.containsMouse
                                            ? (root._lightTheme ? "#00a651" : "#00ff88")
                                            : (root._lightTheme ? "#343434" : "white")
                    fillMode:               Image.PreserveAspectFit
                }

                // Label Logic
                Text {
                    id: labelText
                    Layout.fillWidth: true
                    text: btn.actionTitle
                    color: root._lightTheme ? "#343434" : "white"
                    font.bold: true
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.75
                    font.family: "Noto Sans"
                    Layout.alignment: Qt.AlignVCenter
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    // 1. Close the popup
                    if (root.popupRef) {
                        root.popupRef.close();
                    } else {
                        // Fallback parent traversal
                        var p = root.parent;
                        while (p && !p.close) p = p.parent;
                        if (p && p.close) p.close();
                    }
                    
                    // 2. Trigger action
                    if (btn.onTrigger) btn.onTrigger();
                }
            }
        }
    }

    ColumnLayout {
        id: mainColumn
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.margins: ScreenTools.defaultFontPixelWidth * 0.8
        spacing:        ScreenTools.defaultFontPixelHeight * 0.4

        Text {
            Layout.alignment: Qt.AlignHCenter
            text:             qsTr("ADDITIONAL ACTIONS")
            font.pixelSize:   ScreenTools.defaultFontPixelHeight * 0.65
            font.bold:        true
            color:            root._lightTheme ? "#00a651" : "#00ff88"
            font.family:      "Noto Sans"
            font.capitalization: Font.AllUppercase
        }

        Rectangle {
            Layout.fillWidth: true
            height:           1
            color:            root._lightTheme ? Qt.rgba(0, 0.65, 0.32, 0.25) : Qt.rgba(0, 1, 0.5, 0.2)
        }

        // --- DYNAMIC SECTIONS ---

        Repeater {
            model: (root.additionalActions && root.additionalActions.model) ? root.additionalActions.model : []
            delegate: Item {
                required property var modelData
                Layout.fillWidth: true
                height: modelData.visible ? root._buttonHeight : 0
                visible: modelData.visible
                
                Loader {
                    anchors.fill: parent
                    sourceComponent: actionButtonDelegate
                    onLoaded: {
                        item.actionTitle = modelData.title;
                        item.actionObj = modelData;
                        item.onTrigger = function() {
                            if (root._guidedController) {
                                root._guidedController.confirmAction(modelData.action);
                            }
                        };
                    }
                }
            }
        }

        Repeater {
            model: (root.customActions && root.customActions.model) ? root.customActions.model : []
            delegate: Item {
                required property var modelData
                Layout.fillWidth: true
                height: modelData.visible ? root._buttonHeight : 0
                visible: modelData.visible
                
                Loader {
                    anchors.fill: parent
                    sourceComponent: actionButtonDelegate
                    onLoaded: {
                        item.actionTitle = modelData.title;
                        item.actionObj = modelData;
                        item.onTrigger = function() {
                            if (root._guidedController) {
                                root._guidedController.confirmAction(modelData.action);
                            }
                        };
                    }
                }
            }
        }

        Repeater {
            model: root.mavlinkActions ? root.mavlinkActions : []
            delegate: Item {
                required property var modelData
                Layout.fillWidth: true
                height: root._buttonHeight
                
                Loader {
                    anchors.fill: parent
                    sourceComponent: actionButtonDelegate
                    onLoaded: {
                        item.actionTitle = modelData.label;
                        item.actionObj = modelData;
                        item.onTrigger = function() {
                            if (modelData.sendTo && root._activeVehicle) {
                                modelData.sendTo(root._activeVehicle);
                            }
                        };
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            height: ScreenTools.defaultFontPixelHeight
            visible: mainColumn.children.length <= 4
            Text {
                anchors.centerIn: parent
                text: "No Actions Available"
                color: root._lightTheme ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(1, 1, 1, 0.3)
                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.7
            }
        }
    }
}
