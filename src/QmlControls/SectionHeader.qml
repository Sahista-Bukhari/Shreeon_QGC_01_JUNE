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

    property var            color:          _glassTheme ? "#ffffff" : qgcPal.text
    property bool           showSpacer:     true
    property ButtonGroup    buttonGroup:    null
    readonly property bool  _glassTheme:    typeof mainWindow !== "undefined"
                                            && mainWindow.activeMissionEditor === "customMission"

    property real _sectionSpacer: ScreenTools.defaultFontPixelWidth / 2  // spacing between section headings

    onButtonGroupChanged: {
        if (buttonGroup) {
            buttonGroup.addButton(control)
        }
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    background: Item { implicitWidth: 0; implicitHeight: 0 }

    contentItem: ColumnLayout {
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
                color:                  control._glassTheme ? "#ffffff" : qgcPal.text
                visible:                !control.checked
            }
        }

        Rectangle {
            Layout.fillWidth:   true
            height:             1
            color:              control._glassTheme ? Qt.rgba(1, 1, 1, 0.28) : qgcPal.text
        }
    }

    indicator: Item {}
}
