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
    property bool   compact:                false
    property bool   largeTitleText:         false
    property real   minimumContentHeight:   -1

    property real maxContentAvailableWidth:    mainWindow.width - _contentMargin * 8
    property real maxContentAvailableHeight:   mainWindow.height - titleLabel.implicitHeight - buttonRow.implicitHeight - _contentMargin * 7

    readonly property real headerMinWidth: Math.max(titleLabel.implicitWidth + _contentMargin * 4, ScreenTools.defaultFontPixelWidth * (compact ? 28 : 40))
    readonly property real dialogPreferredWidth: Math.min(mainWindow.width - _contentMargin * 4, ScreenTools.defaultFontPixelWidth * (compact ? 36 : 54))
    readonly property real messageMinHeight: minimumContentHeight >= 0 ? minimumContentHeight : ScreenTools.defaultFontPixelHeight * (compact ? 1.4 : 3.5)
    readonly property real buttonRowHeight: ScreenTools.defaultFontPixelHeight * (compact ? 2.35 : 3)

    signal accepted
    signal rejected

    property var    _qgcPal:            QGroundControl.globalPalette
    property real   _frameSize:         ScreenTools.defaultFontPixelWidth
    property real   _contentMargin:     ScreenTools.defaultFontPixelHeight / 2
    property bool   _acceptAllowed:     acceptButton.visible
    property bool   _rejectAllowed:     rejectButton.visible
    property int    _previousValidationErrorCount: 0
    readonly property bool _customMissionChrome: typeof mainWindow !== "undefined"
                                                 && mainWindow.activeMissionEditor === "customMission"

    // Match RouteMappingTaskSettings light form colors on white popup surfaces.
    readonly property color _accentGreen:            "#23a800"
    readonly property color _accentSoftGreen:        "#efffee"
    readonly property color _titleColor:             "#3f3f3f"
    readonly property color _bodyColor:              "#6a6a6a"
    readonly property color _hintColor:              "#8a8a8a"
    readonly property color _cardBorderIdle:         "#e2e2e2"
    readonly property color _dialogContentTextColor: _titleColor
    readonly property real  _dialogControlRadius:    ScreenTools.defaultFontPixelWidth * 0.75

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

    function _isThemedButtonChrome(item) {
        // Skip Button content (e.g. Alt Mode rows) — those sit on dark button fills.
        // Keep CheckBox / RadioButton so their labels on white get fixed.
        if (!item) {
            return false
        }
        return (item instanceof Button) && !(item instanceof CheckBox) && !(item instanceof RadioButton)
            && item.backgroundColor === undefined
    }

    function _styleDialogContentControls(item) {
        if (!item || _isThemedButtonChrome(item)) {
            return
        }

        // Custom Mission: dark glass dialogs need light text (gated — other modes unchanged).
        if (_customMissionChrome) {
            if (item.textColor !== undefined && item.primary === undefined) {
                item.textColor = "#ffffff"
            }

            if (item.color !== undefined && typeof item.text === "string") {
                const c = item.color
                const isWarning = Qt.colorEqual(c, qgcPal.warningText)
                const isGreen = Qt.colorEqual(c, qgcPal.colorGreen) || Qt.colorEqual(c, _accentGreen)
                if (!isWarning && !isGreen) {
                    item.color = "#ffffff"
                }
            }

            const glassKids = item.children
            if (glassKids) {
                for (let g = 0; g < glassKids.length; g++) {
                    _styleDialogContentControls(glassKids[g])
                }
            }
            return
        }

        // QGCButton: green selected chip style from Route Mapping (Medium/High).
        const isQgcButton = item.backgroundColor !== undefined && item.textColor !== undefined && item.primary !== undefined
        if (isQgcButton) {
            item.backgroundColor = _accentGreen
            item.textColor = "white"
            if (item.showBorder !== undefined) {
                item.showBorder = false
            }
            if (item.backRadius !== undefined) {
                item.backRadius = _dialogControlRadius
            }
            // Do not restyle white label text inside the green button.
            return
        }

        if (item.textColor !== undefined) {
            item.textColor = _dialogContentTextColor
        }

        if (item.uncheckedBorderColor !== undefined) {
            item.uncheckedBorderColor = _cardBorderIdle
        }

        // FactTextField / QGCTextField: green focus + dark value text.
        if (item.activeFocusBorderColor !== undefined) {
            item.activeFocusBorderColor = _accentGreen
        }
        if (item.fieldTextColor !== undefined) {
            item.fieldTextColor = _dialogContentTextColor
        }

        if (item.color !== undefined && typeof item.text === "string") {
            // Keep intentional accents (warnings / green) — only rewrite theme/white text.
            const c = item.color
            const isWarning = Qt.colorEqual(c, qgcPal.warningText)
            const isGreen = Qt.colorEqual(c, qgcPal.colorGreen) || Qt.colorEqual(c, _accentGreen)
            const isThemeOrWhite = Qt.colorEqual(c, qgcPal.text)
                    || Qt.colorEqual(c, qgcPal.buttonText)
                    || (c.r > 0.9 && c.g > 0.9 && c.b > 0.9)
            if (!isWarning && !isGreen && isThemeOrWhite) {
                item.color = _dialogContentTextColor
            }
        }

        const kids = item.children
        if (kids) {
            for (let i = 0; i < kids.length; i++) {
                _styleDialogContentControls(kids[i])
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
        Qt.callLater(function() { _styleDialogContentControls(dialogContentParent) })
    }

    onAboutToShow: {
        _previousValidationErrorCount = globals.validationErrorCount
        setupDialogButtons(buttons)
        Qt.callLater(function() { _styleDialogContentControls(dialogContentParent) })
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
        color: _customMissionChrome ? "transparent" : "white"
        radius: ScreenTools.defaultFontPixelWidth * (_customMissionChrome ? 1.4 : 0.8)
        clip: true

        LiquidGlassSurface {
            anchors.fill: parent
            visible: root._customMissionChrome
            cornerRadius: dialogFrame.radius
            blurAmount: 18
            tintColor: Qt.rgba(0.10, 0.12, 0.12, 0.78)
            rimColor: Qt.rgba(1, 1, 1, 0.30)
            innerGlow: "transparent"
            showGlint: false
        }

        ColumnLayout {
            id: dialogColumn
            width: parent.width
            spacing: 0

            QGCLabel {
                id: titleLabel
                Layout.fillWidth: true
                Layout.topMargin: ScreenTools.defaultFontPixelHeight * (compact ? 0.85 : 1.15)
                Layout.leftMargin: ScreenTools.defaultFontPixelWidth * (compact ? 1.5 : 2)
                Layout.rightMargin: ScreenTools.defaultFontPixelWidth * (compact ? 1.5 : 2)
                Layout.bottomMargin: ScreenTools.defaultFontPixelHeight * (compact ? 0.45 : 0.75)
                text: root.title
                color: root._customMissionChrome ? "#ffffff" : root._titleColor
                font.pointSize: (compact && largeTitleText) ? ScreenTools.largeFontPointSize
                                              : (compact ? ScreenTools.smallFontPointSize : ScreenTools.mediumFontPointSize)
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                visible: root.title !== ""
            }

            Rectangle {
                id: messageArea
                Layout.fillWidth: true
                Layout.minimumHeight: messageMinHeight
                Layout.preferredHeight: Math.max(
                                            totalContentHeight,
                                            messageMinHeight)
                color: root._customMissionChrome ? "transparent" : "white"

                property real contentWidth: dialogPreferredWidth - _contentMargin * 4
                property real totalContentWidth: Math.max(dialogContentParent.childrenRect.width, contentWidth)
                property real totalContentHeight: dialogContentParent.childrenRect.height + _contentMargin * (compact ? 1.4 : 2.8)

                QGCFlickable {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: _contentMargin * 2
                    anchors.rightMargin: _contentMargin * 2
                    anchors.topMargin: _contentMargin * (compact ? 0.6 : 1.2)
                    anchors.bottomMargin: _contentMargin * (compact ? 0.6 : 1.2)
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
                color: root._customMissionChrome ? Qt.rgba(1, 1, 1, 0.18) : root._cardBorderIdle
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
                    Layout.preferredHeight: buttonRowHeight
                    color: {
                        if (root._customMissionChrome)
                            return rejectMouseArea.pressed ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                        return rejectMouseArea.pressed ? "#f1f1f1" : "white"
                    }
                    visible: false

                    QGCLabel {
                        anchors.centerIn: parent
                        text: rejectButton.text
                        color: {
                            if (!rejectButton.enabled)
                                return root._customMissionChrome ? Qt.rgba(1, 1, 1, 0.35) : root._hintColor
                            return root._customMissionChrome ? "#ffffff" : root._bodyColor
                        }
                        font.weight: Font.Medium
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
                    color: root._customMissionChrome ? Qt.rgba(1, 1, 1, 0.18) : root._cardBorderIdle
                    visible: acceptButton.visible && rejectButton.visible
                }

                Rectangle {
                    id: acceptButton
                    property string text: ""
                    property bool enabled: true
                    Layout.fillWidth: true
                    Layout.preferredHeight: buttonRowHeight
                    color: {
                        if (root._customMissionChrome)
                            return acceptMouseArea.pressed ? Qt.rgba(0.14, 0.69, 0.36, 0.28) : "transparent"
                        return acceptMouseArea.pressed ? root._accentSoftGreen : "white"
                    }
                    visible: false

                    QGCLabel {
                        anchors.centerIn: parent
                        text: acceptButton.text
                        color: {
                            if (!acceptButton.enabled)
                                return root._customMissionChrome ? Qt.rgba(1, 1, 1, 0.35) : root._hintColor
                            return root._customMissionChrome ? "#8cff7a" : root._accentGreen
                        }
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
