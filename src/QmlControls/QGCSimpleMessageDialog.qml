import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

QGCPopupDialog {
    property alias  text:           label.text
    property var    acceptFunction: null        // Mainly used by MainRootWindow.showMessage to specify accept function in call
    property var    closeFunction:  null

    onAccepted: {
        if (acceptFunction) {
            acceptFunction()
        }
    }

    onClosed: {
        if (closeFunction) {
            closeFunction()
        }
    }

    ColumnLayout {
        width: parent ? parent.width : implicitWidth

        QGCLabel {
            id:                     label
            Layout.fillWidth:       true
            wrapMode:               Text.WordWrap
            horizontalAlignment:    Text.AlignHCenter
            // White on Custom Mission glass dialogs; dark on white dialogs elsewhere
            color:                  (typeof mainWindow !== "undefined"
                                     && mainWindow
                                     && mainWindow.activeMissionEditor === "customMission")
                                    ? "#ffffff" : "#3f3f3f"
        }
    }
}
