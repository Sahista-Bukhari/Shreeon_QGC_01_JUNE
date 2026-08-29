import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

CheckBox {
    id:             control
    focusPolicy:    Qt.ClickFocus
    checked:        true
    leftPadding:    0

    property var            color:          _glassTheme ? "#3f3f3f" : qgcPal.text
    property bool           showSpacer:     true
    property ButtonGroup    buttonGroup:    null
    readonly property bool  _glassTheme:    typeof mainWindow !== "undefined"
                                            && mainWindow.customMissionStyleActive

    property real _sectionSpacer: ScreenTools.defaultFontPixelWidth / 2  // spacing between section headings

    onButtonGroupChanged: {
        if (buttonGroup) {
            buttonGroup.addButton(control)
        }
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    background: Item { implicitWidth: 0; implicitHeight: 0 }

    contentItem: Item {
        implicitWidth: sectionColumn.implicitWidth
        implicitHeight: sectionColumn.implicitHeight

        RippleEffect {
            id: sectionRipple
            anchors.fill: parent
            rippleColor: control._glassTheme
                         ? Qt.rgba(0, 0, 0, 0.12)
                         : Qt.rgba(0, 0, 0, 0.12)
            clipRadius: ScreenTools.defaultFontPixelWidth * 0.4
        }

        Connections {
            target: control
            function onPressedChanged() {
                if (control.pressed)
                    sectionRipple.tap(control.pressX, control.pressY)
            }
        }

        ColumnLayout {
            id: sectionColumn
            anchors.fill: parent

            Item {
                Layout.preferredHeight: control._sectionSpacer
                width:                  1
                visible:                control.showSpacer
            }

            QGCLabel {
                text:               control.text
                color:              control.color
                Layout.fillWidth:   true

                QGCColoredImage {
                    anchors.right:          parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width:                  parent.height / 2
                    height:                 width
                    source:                 "/qmlimages/arrow-down.png"
                    color:                  control._glassTheme ? "#6a6a6a" : qgcPal.text
                    visible:                !control.checked
                }
            }

            Rectangle {
                Layout.fillWidth:   true
                height:             1
                color:              control._glassTheme ? "#e2e2e2" : qgcPal.text
            }
        }
    }

    indicator: Item {}
}
