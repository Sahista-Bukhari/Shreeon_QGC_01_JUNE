import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

AnalyzePage {
    id: root

    headerComponent:   consoleHeaderComponent
    pageComponent:     pageComponent
    contentTopMargin:  _headerSpacing
    allowPopout:       true
    popoutIconSource:  "/qmlimages/MAVLinkConsolePopout.svg"
    popoutIconColor:   _accentGreen

    property bool isLoaded: false

    readonly property bool _separateCommandInput: ScreenTools.isMobile
    readonly property var  _activeVehicle:        QGroundControl.multiVehicleManager.activeVehicle
    readonly property bool _vehicleConnected:     _activeVehicle && !_activeVehicle.isOfflineEditingVehicle
    readonly property bool _darkTheme: {
        if (typeof mainWindow !== "undefined" && mainWindow)
            return mainWindow.uiThemeMode === mainWindow.themeBlack
        return consolePalette.globalTheme === QGCPalette.Dark
    }
    readonly property color _pageBackground:   _darkTheme ? consolePalette.window : "#FFFFFF"
    readonly property color _titleColor:       _darkTheme ? "#AEAEB2" : "#3A3A3C"
    readonly property color _bodyColor:        _darkTheme ? "#8E8E93" : "#5A5A5E"
    readonly property color _accentGreen:      "#00a04c"
    readonly property color _cardIdleFill:     _darkTheme ? consolePalette.window : "#FFFFFF"
    readonly property color _cardSelectedFill: Qt.rgba(0, 160 / 255, 76 / 255, _darkTheme ? 0.16 : 0.08)
    readonly property color _dataCardFill:     _darkTheme ? consolePalette.windowShade : "#F5F5F5"
    readonly property color _tableLine:        _darkTheme ? consolePalette.windowShade : "#E5E5E5"
    readonly property real  _pagePad:          ScreenTools.defaultFontPixelWidth * 2.2
    readonly property real  _controlSpacing:   ScreenTools.defaultFontPixelWidth
    readonly property real  _headerSpacing:    Math.ceil(ScreenTools.defaultFontPixelHeight * 0.65)
    readonly property real  _cardRadius:       ScreenTools.defaultFontPixelWidth * 0.9

    QGCPalette {
        id:                consolePalette
        colorGroupEnabled: root.enabled
    }

    MAVLinkConsoleController {
        id: conController
    }

    component ConsoleActionButton: Button {
        id: actionButton

        hoverEnabled:   !ScreenTools.isMobile
        focusPolicy:    Qt.ClickFocus
        leftPadding:    ScreenTools.defaultFontPixelWidth * 1.5
        rightPadding:   leftPadding
        topPadding:     ScreenTools.defaultFontPixelHeight * 0.32
        bottomPadding:  topPadding
        font.family:    ScreenTools.normalFontFamily
        font.pointSize: ScreenTools.defaultFontPointSize
        implicitWidth:  Math.max(ScreenTools.implicitButtonWidth,
                                 actionButtonLabel.implicitWidth + leftPadding + rightPadding)
        implicitHeight: Math.max(ScreenTools.implicitButtonHeight,
                                 actionButtonLabel.implicitHeight + topPadding + bottomPadding)

        contentItem: QGCLabel {
            id:                  actionButtonLabel
            text:                actionButton.text
            color:               actionButton.enabled ? "#FFFFFF" : root._bodyColor
            opacity:             actionButton.enabled ? 1 : 0.45
            font:                actionButton.font
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment:   Text.AlignVCenter
        }

        background: Rectangle {
            implicitWidth:  ScreenTools.implicitButtonWidth
            implicitHeight: ScreenTools.implicitButtonHeight
            radius:         actionButton.height / 2
            border.width:   1
            border.color:   actionButton.enabled ? root._accentGreen : root._tableLine
            color: {
                if (!actionButton.enabled)
                    return root._dataCardFill
                if (actionButton.pressed)
                    return Qt.darker(root._accentGreen, 1.12)
                return root._accentGreen
            }
        }
    }

    Component {
        id: consoleHeaderComponent

        Item {
            implicitHeight: consoleHeaderLayout.implicitHeight

            ColumnLayout {
                id:                  consoleHeaderLayout
                anchors.left:        parent.left
                anchors.right:       parent.right
                anchors.leftMargin:  root._pagePad
                anchors.rightMargin: root._pagePad
                spacing:             root._headerSpacing

                QGCLabel {
                    Layout.fillWidth: true
                    text:             qsTr("Connect to the vehicle system shell and send MAVLink console commands.")
                    color:            root._bodyColor
                    wrapMode:         Text.WordWrap
                }

                Rectangle {
                    Layout.fillWidth: true
                    height:           1
                    color:            root._tableLine
                }
            }
        }
    }

    Component {
        id: pageComponent

        Rectangle {
            width:  root.availableWidth
            height: root.availableHeight
            color:  root._pageBackground

            ColumnLayout {
                id:                  consoleLayout
                anchors.fill:        parent
                anchors.leftMargin:  root._pagePad
                anchors.rightMargin: root._pagePad
                anchors.bottomMargin: root._pagePad
                spacing:             root._headerSpacing

                property int _consoleOutputLen: 0

                function scrollToBottom() {
                    if (flickable.contentHeight > flickable.height)
                        flickable.contentY = flickable.contentHeight - flickable.height
                }

                function getCommand() {
                    return textConsole.getText(_consoleOutputLen, textConsole.length)
                }

                function getCommandAndClear() {
                    const command = getCommand()
                    textConsole.remove(_consoleOutputLen, textConsole.length)
                    return command
                }

                function pasteFromClipboard() {
                    const cursor = textConsole.cursorPosition - _consoleOutputLen
                    const command = getCommandAndClear()
                    let commandPre = ""
                    let commandPost = command
                    if (cursor > 0) {
                        commandPre = command.substr(0, cursor)
                        commandPost = command.substr(cursor)
                    }
                    const commandLeftover = conController.handleClipboard(commandPre) + commandPost
                    textConsole.insert(textConsole.length, commandLeftover)
                    textConsole.cursorPosition = textConsole.length - commandPost.length
                }

                Connections {
                    target: conController

                    function onDataChanged(topLeft, bottomRight, roles) {
                        if (root.isLoaded)
                            updateTimer.start()
                    }
                }

                Timer {
                    id:       updateTimer
                    interval: 30
                    running:  false
                    repeat:   false

                    onTriggered: {
                        if (flickable.atYEnd) {
                            const command = consoleLayout.getCommand()
                            const cursor = textConsole.cursorPosition - consoleLayout._consoleOutputLen
                            textConsole.text = conController.text
                            consoleLayout._consoleOutputLen = textConsole.length
                            textConsole.insert(textConsole.length, command)
                            textConsole.cursorPosition = textConsole.length
                            consoleLayout.scrollToBottom()
                            if (cursor >= 0)
                                textConsole.cursorPosition = consoleLayout._consoleOutputLen + cursor
                        } else {
                            updateTimer.start()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: connectionRow.implicitHeight + root._controlSpacing * 1.5
                    Layout.maximumHeight:   Layout.preferredHeight
                    radius:                 root._cardRadius
                    color:                  root._dataCardFill
                    border.width:           1
                    border.color:           root._tableLine

                    RowLayout {
                        id:              connectionRow
                        anchors.fill:    parent
                        anchors.margins: root._controlSpacing * 0.75
                        spacing:         root._controlSpacing

                        Rectangle {
                            Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 0.65
                            Layout.preferredHeight: Layout.preferredWidth
                            radius:                 width / 2
                            color:                  root._vehicleConnected ? root._accentGreen : root._bodyColor
                            opacity:                root._vehicleConnected ? 1 : 0.45
                        }

                        QGCLabel {
                            text:        root._vehicleConnected ? qsTr("Vehicle connected") : qsTr("Waiting for vehicle")
                            color:       root._vehicleConnected ? root._accentGreen : root._bodyColor
                            font.weight: Font.DemiBold
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        QGCLabel {
                            Layout.maximumWidth: parent.width * 0.55
                            text:                root._separateCommandInput
                                                 ? qsTr("Enter a command below and select Send")
                                                 : qsTr("Type in the console and press Enter to send")
                            color:               root._bodyColor
                            horizontalAlignment: Text.AlignRight
                            elide:                Text.ElideRight
                        }
                    }
                }

                Rectangle {
                    id:                  terminalCard
                    Layout.fillWidth:    true
                    Layout.fillHeight:   true
                    radius:              root._cardRadius
                    color:               root._dataCardFill
                    border.width:        textConsole.activeFocus ? 2 : 1
                    border.color:        textConsole.activeFocus ? root._accentGreen : root._tableLine
                    clip:                true

                    Behavior on border.color {
                        ColorAnimation { duration: 140 }
                    }

                    QGCFlickable {
                        id:                 flickable
                        anchors.fill:       parent
                        anchors.margins:    root._controlSpacing * 0.75
                        contentWidth:       textConsole.width
                        contentHeight:      textConsole.height
                        flickableDirection: Flickable.VerticalFlick
                        clip:               true

                        ScrollBar.vertical: ScrollBar {
                            id: consoleScrollBar

                            policy:        flickable.contentHeight > flickable.height ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                            width:         Math.max(8, ScreenTools.defaultFontPixelWidth * 0.85)
                            topPadding:    root._controlSpacing * 0.5
                            bottomPadding: topPadding
                            leftPadding:   2
                            rightPadding:  2
                            minimumSize:   0.06

                            background: Rectangle {
                                color: "transparent"
                            }

                            contentItem: Rectangle {
                                implicitWidth:  Math.max(4, ScreenTools.defaultFontPixelWidth * 0.45)
                                implicitHeight: ScreenTools.defaultFontPixelHeight * 2
                                radius:         width / 2
                                color:          root._accentGreen
                            }
                        }

                        TextArea.flickable: TextArea {
                            id:                  textConsole
                            width:               flickable.width - consoleScrollBar.width
                            wrapMode:            Text.WordWrap
                            readOnly:            root._separateCommandInput
                            textFormat:          TextEdit.RichText
                            inputMethodHints:    Qt.ImhNoAutoUppercase | Qt.ImhMultiLine
                            text:                "> "
                            focus:               true
                            color:               root._titleColor
                            selectedTextColor:   "#FFFFFF"
                            selectionColor:      root._accentGreen
                            font.pointSize:      ScreenTools.defaultFontPointSize
                            font.family:         ScreenTools.fixedFontFamily
                            leftPadding:         root._controlSpacing
                            rightPadding:        root._controlSpacing
                            topPadding:          root._controlSpacing
                            bottomPadding:       root._controlSpacing

                            Component.onCompleted: {
                                root.isLoaded = true
                                consoleLayout._consoleOutputLen = textConsole.length
                                textConsole.cursorPosition = consoleLayout._consoleOutputLen
                                if (!root._separateCommandInput)
                                    textConsole.forceActiveFocus()
                            }

                            background: Rectangle {
                                color: "transparent"
                            }

                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Tab)
                                    event.accepted = true

                                if (event.matches(StandardKey.Cut))
                                    event.accepted = true

                                if (!event.matches(StandardKey.Copy)
                                        && event.key !== Qt.Key_Escape
                                        && event.key !== Qt.Key_Insert
                                        && event.key !== Qt.Key_Pause
                                        && event.key !== Qt.Key_Print
                                        && event.key !== Qt.Key_SysReq
                                        && event.key !== Qt.Key_Clear
                                        && event.key !== Qt.Key_Home
                                        && event.key !== Qt.Key_End
                                        && event.key !== Qt.Key_Left
                                        && event.key !== Qt.Key_Up
                                        && event.key !== Qt.Key_Right
                                        && event.key !== Qt.Key_Down
                                        && event.key !== Qt.Key_PageUp
                                        && event.key !== Qt.Key_PageDown
                                        && event.key !== Qt.Key_Shift
                                        && event.key !== Qt.Key_Control
                                        && event.key !== Qt.Key_Meta
                                        && event.key !== Qt.Key_Alt
                                        && event.key !== Qt.Key_AltGr
                                        && event.key !== Qt.Key_CapsLock
                                        && event.key !== Qt.Key_NumLock
                                        && event.key !== Qt.Key_ScrollLock
                                        && event.key !== Qt.Key_Super_L
                                        && event.key !== Qt.Key_Super_R
                                        && event.key !== Qt.Key_Menu
                                        && event.key !== Qt.Key_Hyper_L
                                        && event.key !== Qt.Key_Hyper_R
                                        && event.key !== Qt.Key_Direction_L
                                        && event.key !== Qt.Key_Direction_R) {
                                    consoleLayout.scrollToBottom()

                                    if (textConsole.selectionStart < consoleLayout._consoleOutputLen)
                                        textConsole.select(consoleLayout._consoleOutputLen, textConsole.selectionEnd)

                                    if (textConsole.cursorPosition < consoleLayout._consoleOutputLen)
                                        textConsole.cursorPosition = textConsole.length
                                }

                                switch (event.key) {
                                case Qt.Key_Left:
                                    if (textConsole.cursorPosition === consoleLayout._consoleOutputLen)
                                        event.accepted = true
                                    break
                                case Qt.Key_Backspace:
                                    if (textConsole.cursorPosition <= consoleLayout._consoleOutputLen)
                                        event.accepted = true
                                    break
                                case Qt.Key_Enter:
                                case Qt.Key_Return:
                                    conController.sendCommand(consoleLayout.getCommandAndClear())
                                    event.accepted = true
                                    break
                                default:
                                    break
                                }

                                if (event.matches(StandardKey.Paste)) {
                                    consoleLayout.pasteFromClipboard()
                                    event.accepted = true
                                }

                                if (event.key === Qt.Key_Up) {
                                    const previousCommand = conController.historyUp(consoleLayout.getCommandAndClear())
                                    textConsole.insert(textConsole.length, previousCommand)
                                    textConsole.cursorPosition = textConsole.length
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Down) {
                                    const nextCommand = conController.historyDown(consoleLayout.getCommandAndClear())
                                    textConsole.insert(textConsole.length, nextCommand)
                                    textConsole.cursorPosition = textConsole.length
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: mobileCommandRow.implicitHeight + root._controlSpacing * 1.5
                    Layout.maximumHeight:   Layout.preferredHeight
                    radius:                 root._cardRadius
                    color:                  root._dataCardFill
                    border.width:           1
                    border.color:           root._tableLine
                    visible:                root._separateCommandInput

                    RowLayout {
                        id:              mobileCommandRow
                        anchors.fill:    parent
                        anchors.margins: root._controlSpacing * 0.75
                        spacing:         root._controlSpacing

                        QGCTextField {
                            id:                     commandInput
                            Layout.fillWidth:       true
                            placeholderText:        qsTr("Enter command")
                            inputMethodHints:       Qt.ImhNoAutoUppercase
                            activeFocusBorderColor: root._accentGreen
                            fieldTextColor:         root._titleColor
                            onAccepted:             sendCommand()

                            background: Rectangle {
                                implicitWidth:  ScreenTools.implicitTextFieldWidth
                                implicitHeight: ScreenTools.implicitTextFieldHeight
                                radius:         ScreenTools.defaultBorderRadius * 2
                                color:          root._cardIdleFill
                                border.width:   commandInput.activeFocus ? 2 : 1
                                border.color:   root._accentGreen
                            }

                            function sendCommand() {
                                conController.sendCommand(text)
                                text = ""
                                consoleLayout.scrollToBottom()
                            }
                        }

                        ConsoleActionButton {
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10
                            text:                  qsTr("Send")
                            enabled:               commandInput.text.length > 0
                            onClicked:             commandInput.sendCommand()
                        }
                    }
                }
            }
        }
    }
}
