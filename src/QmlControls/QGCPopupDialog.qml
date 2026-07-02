import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls

// Provides the standard dialog mechanism for QGC. Works 99% like Qml Dialog.
//
// Example usage:
//      Component {
//          id: dialogComponent
//
//          QGCPopupDialog {
//              ...
//          }
//      }
//
//      onFoo: dialogComponent.createObject(mainWindow).open()
//
// Notes:
//  * QGCPopupDialog should be created from a component to limit the memory usage of the dialog
//      to only when it is displayed.
//  * Parent for createObject should always be mainWindow.
// Differences from standard Qml Dialog:
//  * The QGCPopupDialog object will automatically be destroyed when it closed. You can override this
//      behaviour by setting destroyOnClose to false if it was not created dynamically.
//  * Dialog will automatically close after accepted/rejected signal processing. You can prevent this by setting
//      preventClose = true prior to returning from your signal handlers.
Popup {
    id:                 root
    width:  mainWindow.width
    height: mainWindow.height
    parent:             Overlay.overlay
    modal:              true
    focus:              true
    margins:            0

    property string title
    property var    buttons:                Dialog.Ok
    property alias  acceptButtonEnabled:    acceptButton.enabled
    property alias  rejectButtonEnabled:    rejectButton.enabled
    property var    dialogProperties
    property bool   destroyOnClose:         true
    property bool   preventClose:           false

    property real maxContentAvailableWidth:    mainWindow.width - _contentMargin * 8
    property real maxContentAvailableHeight:   mainWindow.height - titleLabel.implicitHeight - buttonRow.implicitHeight - _contentMargin * 7

    readonly property real headerMinWidth: Math.max(titleLabel.implicitWidth + _contentMargin * 4, ScreenTools.defaultFontPixelWidth * 40)
    readonly property real dialogPreferredWidth: Math.min(mainWindow.width - _contentMargin * 4, ScreenTools.defaultFontPixelWidth * 54)

    signal accepted
    signal rejected

    property var    _qgcPal:            QGroundControl.globalPalette
    property real   _frameSize:         ScreenTools.defaultFontPixelWidth
    property real   _contentMargin:     ScreenTools.defaultFontPixelHeight / 2
    property bool   _acceptAllowed:     acceptButton.visible
    property bool   _rejectAllowed:     rejectButton.visible
    property int    _previousValidationErrorCount: 0

    background: QGCMouseArea {
        width:  mainWindow.width
        height: mainWindow.height

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.58)
        }

        onClicked: {
            if (closePolicy & Popup.CloseOnPressOutside) {
                _reject()
            }
        }
    }

    Component.onCompleted: {
        // Re-parent externally supplied dialog content into dialogContentParent.
        // Skip internal popup frame items so content is consistently visible.
        for (let i = 0; i < contentChildren.length; i++) {
            const child = contentChildren[i]
            if (child !== dialogFrame) {
                child.parent = dialogContentParent
            }
        }
    }

    onAboutToShow: {
        _previousValidationErrorCount = globals.validationErrorCount
        setupDialogButtons(buttons)
    }

    onClosed: {
        globals.validationErrorCount = _previousValidationErrorCount
        Qt.inputMethod.hide()
        if (destroyOnClose) {
            root.destroy()
        }
    }

    function _accept() {
        if (_acceptAllowed && mainWindow.allowViewSwitch(_previousValidationErrorCount)) {
            accepted()
            if (preventClose) {
                preventClose = false
            } else {
                close()
            }
        }
    }

    function _reject() {
        // Dialogs with cancel button are allowed to close with validation errors
        if (_rejectAllowed && ((buttons & Dialog.Cancel) || mainWindow.allowViewSwitch(_previousValidationErrorCount))) {
            rejected()
            if (preventClose) {
                preventClose = false
            } else {
                close()
            }
        }
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: parent.enabled }

    function setupDialogButtons(buttons) {
        acceptButton.visible = false
        rejectButton.visible = false
        // Accept role buttons
        if (buttons & Dialog.Ok) {
            acceptButton.text = qsTr("Ok")
            acceptButton.visible = true
        } else if (buttons & Dialog.Open) {
            acceptButton.text = qsTr("Open")
            acceptButton.visible = true
        } else if (buttons & Dialog.Save) {
            acceptButton.text = qsTr("Save")
            acceptButton.visible = true
        } else if (buttons & Dialog.Apply) {
            acceptButton.text = qsTr("Apply")
            acceptButton.visible = true
        } else if (buttons & Dialog.Open) {
            acceptButton.text = qsTr("Open")
            acceptButton.visible = true
        } else if (buttons & Dialog.SaveAll) {
            acceptButton.text = qsTr("Save All")
            acceptButton.visible = true
        } else if (buttons & Dialog.Yes) {
            acceptButton.text = qsTr("Yes")
            acceptButton.visible = true
        } else if (buttons & Dialog.YesToAll) {
            acceptButton.text = qsTr("Yes to All")
            acceptButton.visible = true
        } else if (buttons & Dialog.Retry) {
            acceptButton.text = qsTr("Retry")
            acceptButton.visible = true
        } else if (buttons & Dialog.Reset) {
            acceptButton.text = qsTr("Reset")
            acceptButton.visible = true
        } else if (buttons & Dialog.RestoreToDefaults) {
            acceptButton.text = qsTr("Restore to Defaults")
            acceptButton.visible = true
        } else if (buttons & Dialog.Ignore) {
            acceptButton.text = qsTr("Ignore")
            acceptButton.visible = true
        }

        // Reject role buttons
        if (buttons & Dialog.Cancel) {
            rejectButton.text = qsTr("Cancel")
            rejectButton.visible = true
        } else if (buttons & Dialog.Close) {
            rejectButton.text = qsTr("Close")
            rejectButton.visible = true
        } else if (buttons & Dialog.No) {
            rejectButton.text = qsTr("No")
            rejectButton.visible = true
        } else if (buttons & Dialog.NoToAll) {
            rejectButton.text = qsTr("No to All")
            rejectButton.visible = true
        } else if (buttons & Dialog.Abort) {
            rejectButton.text = qsTr("Abort")
            rejectButton.visible = true
        }

        closePolicy = Popup.NoAutoClose
        if (buttons & Dialog.Cancel) {
            closePolicy |= Popup.CloseOnEscape
        }
    }

    function disableAcceptButton() {
        acceptButton.enabled = false
    }

    Rectangle {
        id: dialogFrame
        anchors.centerIn: parent
        width: dialogPreferredWidth
        height: dialogColumn.implicitHeight
        implicitHeight: dialogColumn.implicitHeight
        color: "white"
        radius: ScreenTools.defaultFontPixelWidth * 0.8
        clip: true

        ColumnLayout {
            id: dialogColumn
            width: parent.width
            spacing: 0

            QGCLabel {
                id: titleLabel
                Layout.fillWidth: true
                Layout.topMargin: ScreenTools.defaultFontPixelHeight * 1.15
                Layout.leftMargin: ScreenTools.defaultFontPixelWidth * 2
                Layout.rightMargin: ScreenTools.defaultFontPixelWidth * 2
                Layout.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.75
                text: root.title
                color: "#202124"
                font.pointSize: ScreenTools.mediumFontPointSize
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                visible: root.title !== ""
            }

            Rectangle {
                id: messageArea
                Layout.fillWidth: true
                Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 3.5
                Layout.preferredHeight: Math.max(
                                            totalContentHeight,
                                            ScreenTools.defaultFontPixelHeight * 3.5)
                color: "white"

                property real contentWidth: dialogPreferredWidth - _contentMargin * 4
                property real totalContentWidth: Math.max(dialogContentParent.childrenRect.width, contentWidth)
                property real totalContentHeight: dialogContentParent.childrenRect.height + _contentMargin * 2

                QGCFlickable {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: _contentMargin * 2
                    anchors.rightMargin: _contentMargin * 2
                    anchors.topMargin: _contentMargin * 1.2
                    anchors.bottomMargin: _contentMargin * 1.2
                    contentWidth: messageArea.contentWidth
                    contentHeight: dialogContentParent.childrenRect.height

                    Item {
                        id: dialogContentParent
                        width: messageArea.contentWidth
                        focus: true

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Escape && _rejectAllowed) {
                                _reject()
                                event.accepted = true
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: "#dedede"
            }

            RowLayout {
                id: buttonRow
                Layout.fillWidth: true
                spacing: 0

                Rectangle {
                    id: rejectButton
                    property string text: ""
                    property bool enabled: true
                    Layout.fillWidth: true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3
                    color: rejectMouseArea.pressed ? "#f1f1f1" : "white"
                    visible: false

                    QGCLabel {
                        anchors.centerIn: parent
                        text: rejectButton.text
                        color: rejectButton.enabled ? "#5f6368" : "#a8a8a8"
                    }

                    QGCMouseArea {
                        id: rejectMouseArea
                        anchors.fill: parent
                        enabled: rejectButton.enabled
                        onClicked: _reject()
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    color: "#dedede"
                    visible: acceptButton.visible && rejectButton.visible
                }

                Rectangle {
                    id: acceptButton
                    property string text: ""
                    property bool enabled: true
                    Layout.fillWidth: true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3
                    color: acceptMouseArea.pressed ? "#f1f1f1" : "white"
                    visible: false

                    QGCLabel {
                        anchors.centerIn: parent
                        text: acceptButton.text
                        color: acceptButton.enabled ? "#58ad2f" : "#a8a8a8"
                        font.weight: Font.DemiBold
                    }

                    QGCMouseArea {
                        id: acceptMouseArea
                        anchors.fill: parent
                        enabled: acceptButton.enabled
                        onClicked: _accept()
                    }
                }
            }
        }
    }
}
