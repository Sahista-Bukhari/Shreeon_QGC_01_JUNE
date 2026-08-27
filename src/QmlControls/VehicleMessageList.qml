import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

TextArea {
    id:                     messageText
    Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 50
    height:                 contentHeight
    readOnly:               true
    textFormat:             TextEdit.RichText
    color:                  "#000000"
    placeholderText:        qsTr("No Messages")
    placeholderTextColor:   "#000000"
    padding:                0
    wrapMode:               TextEdit.Wrap

    property bool noMessages: messageText.length === 0

    property var _fact: null

    function formatMessage(message) {
        const messageStyle = "color: black; font-family: monospace; font-size: "
                + (ScreenTools.defaultFontPointSize.toFixed(0) - 1) + "pt;"
        message = message.replace(new RegExp("<#E>", "g"), messageStyle)
        message = message.replace(new RegExp("<#I>", "g"), messageStyle)
        message = message.replace(new RegExp("<#N>", "g"), messageStyle)
        return message;
    }

    Component.onCompleted: {
        messageText.text = formatMessage(_activeVehicle.formattedMessages)
        if (_activeVehicle) {
            _activeVehicle.resetAllMessages()
        }
    }

    Connections {
        target: _activeVehicle
        function onNewFormattedMessage(formattedMessage) { messageText.insert(0, formatMessage(formattedMessage)) }
    }

    FactPanelController {
        id: controller
    }

    onLinkActivated: (link) => {
        if (link.startsWith('param://')) {
            var paramName = link.substr(8);
            _fact = controller.getParameterFact(-1, paramName, true)
            if (_fact != null) {
                paramEditorDialogComponent.createObject(mainWindow).open()
            }
        } else {
            Qt.openUrlExternally(link);
        }
    }

    Component {
        id: paramEditorDialogComponent

        ParameterEditorDialog {
            title:          qsTr("Edit Parameter")
            fact:           messageText._fact
            destroyOnClose: true
        }
    }

    Rectangle {
        anchors.right:   parent.right
        anchors.top:     parent.top
        width:                      ScreenTools.defaultFontPixelHeight * 1.25
        height:                     width
        radius:                     width / 2
        color:                      QGroundControl.globalPalette.button
        border.color:               QGroundControl.globalPalette.buttonText
        visible:                    !noMessages

        QGCColoredImage {
            anchors.margins:    ScreenTools.defaultFontPixelHeight * 0.25
            anchors.centerIn:   parent
            anchors.fill:       parent
            sourceSize.height:  height
            source:             "/res/TrashDelete.svg"
            fillMode:           Image.PreserveAspectFit
            mipmap:             true
            smooth:             true
            color:              qgcPal.text
        }

        QGCMouseArea {
            fillItem: parent
            onClicked: {
                _activeVehicle.clearMessages()
                mainWindow.closeIndicatorDrawer()
            }
        }
    }
}
