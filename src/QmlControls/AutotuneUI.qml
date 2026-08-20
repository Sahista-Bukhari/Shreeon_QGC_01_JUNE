import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

ColumnLayout {
    id: root

    Layout.fillWidth: true
    spacing:          ScreenTools.defaultFontPixelHeight / 3

    property var  _activeVehicle:   globals.activeVehicle
    property var  _autotuneManager: _activeVehicle.autotune
    property real _margins:         ScreenTools.defaultFontPixelHeight

    QGCPalette {
        id: qgcPal
        colorGroupEnabled: root.enabled
    }

    QGCButton {
        id:               autotuneButton
        Layout.fillWidth: true
        primary:          true
        text:             qsTr("Start AutoTune")
        enabled:          _activeVehicle.flying && !_activeVehicle.landing && !_autotuneManager.autotuneInProgress

        onClicked: mainWindow.showMessageDialog(autotuneButton.text,
                                                qsTr("WARNING!\
        \n\nThe auto-tuning procedure should be executed with caution and requires the vehicle to fly stable enough before attempting the procedure! \
        \n\nBefore starting the auto-tuning process, make sure that: \
        \n1. You have read the auto-tuning guide and have followed the preliminary steps \
        \n2. The current control gains are good enough to stabilize the drone in presence of medium disturbances \
        \n3. You are ready to abort the auto-tuning sequence by moving the RC sticks, if anything unexpected happens. \
        \n\nClick Ok to start the auto-tuning process.\n"),
                                                Dialog.Ok | Dialog.Cancel,
                                                function() { _autotuneManager.autotuneRequest() })
    }

    QGCLabel {
        Layout.fillWidth: true
        text:             _autotuneManager.autotuneStatus
    }

    ProgressBar {
        id:                     autotuneProgress
        Layout.fillWidth:       true
        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight
        value:                  _autotuneManager.autotuneProgress

        background: Rectangle {
            implicitHeight: ScreenTools.defaultFontPixelHeight
            radius:         height / 2
            color:          qgcPal.globalTheme === QGCPalette.Dark ? "#555555" : "#626464"
        }

        contentItem: Item {
            implicitHeight: ScreenTools.defaultFontPixelHeight

            Rectangle {
                width:  autotuneProgress.visualPosition * parent.width
                height: parent.height
                radius: height / 2
                color:  qgcPal.primaryButton
            }

            QGCLabel {
                anchors.fill:             parent
                horizontalAlignment:      Text.AlignHCenter
                verticalAlignment:        Text.AlignVCenter
                elide:                    Text.ElideRight
                leftPadding:              ScreenTools.defaultFontPixelWidth
                rightPadding:             ScreenTools.defaultFontPixelWidth
                font.pointSize:           ScreenTools.smallFontPointSize
                color:                    qgcPal.primaryButtonText
                text:                     _autotuneManager.autotuneStatus
            }
        }
    }
}
