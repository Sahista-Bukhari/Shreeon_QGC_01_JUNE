import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Window
import QtCharts

import QGroundControl
import QGroundControl.Controls

AnalyzePage {
    id: root

    headerComponent: headerComponent
    pageComponent:   pageComponent
    // Inspector navigation is a single-page master/detail flow. Keep it in
    // the Advanced panel instead of offering a separate floating window.
    allowPopout:     false
    contentTopMargin: inspectorDetailOpen ? 0 : ScreenTools.defaultFontPixelHeight

    property var    curSystem:         controller ? controller.activeSystem : null
    property var    curMessage:        curSystem && curSystem.messages.count ? curSystem.messages.get(curSystem.selected) : null
    property int    curCompID:         0
    property real   maxButtonWidth:    0
    property string messageSearchText: ""
    property bool   inspectorDetailOpen: false

    Behavior on contentTopMargin {
        NumberAnimation {
            duration:    260
            easing.type: Easing.InOutCubic
        }
    }

    readonly property bool _darkTheme: {
        if (typeof mainWindow !== "undefined" && mainWindow)
            return mainWindow.uiThemeMode === mainWindow.themeBlack
        return inspectorPal.globalTheme === QGCPalette.Dark
    }
    readonly property color _pageBackground:   _darkTheme ? inspectorPal.window : "#FFFFFF"
    readonly property color _titleColor:       _darkTheme ? "#AEAEB2" : "#3A3A3C"
    readonly property color _bodyColor:        _darkTheme ? "#8E8E93" : "#3A3A3C"
    readonly property color _accentGreen:      "#00a04c"
    readonly property color _cardIdleBorder:   _darkTheme ? inspectorPal.windowShade : "#E6E6E6"
    readonly property color _cardIdleFill:     _darkTheme ? inspectorPal.window : "#FFFFFF"
    readonly property color _cardSelectedFill: Qt.rgba(0, 160 / 255, 76 / 255, _darkTheme ? 0.16 : 0.08)
    readonly property color _dataCardFill:     _darkTheme ? inspectorPal.windowShade : "#F5F5F5"
    readonly property color _tableLine:        _darkTheme ? inspectorPal.windowShade : "#E5E5E5"
    readonly property real  _pagePad:          ScreenTools.defaultFontPixelWidth * 2.2
    readonly property real  _cardRadius:       ScreenTools.defaultFontPixelWidth * 0.9
    readonly property real  _controlSpacing:   ScreenTools.defaultFontPixelWidth
    readonly property real  _headerSpacing:    Math.ceil(ScreenTools.defaultFontPixelHeight * 0.65)
    readonly property real  _navigationWidth:  ScreenTools.defaultFontPixelWidth * 25
    readonly property real  _dataRowHeight:    ScreenTools.defaultFontPixelHeight * 2.2
    readonly property real  _minimumDataWidth: ScreenTools.defaultFontPixelWidth * 48

    QGCPalette {
        id:                inspectorPal
        colorGroupEnabled: root.enabled
    }

    MAVLinkInspectorController {
        id: controller
    }

    function messageMatches(message) {
        if (!message || messageSearchText.length === 0)
            return true
        return message.name.toLowerCase().indexOf(messageSearchText.toLowerCase()) >= 0
    }

    function openMessageDetails(messageIndex) {
        if (!curSystem)
            return
        curSystem.selected = messageIndex
        inspectorDetailOpen = true
    }

    function closeMessageDetails() {
        inspectorDetailOpen = false
    }

    onCurMessageChanged: {
        if (!curMessage && inspectorDetailOpen)
            closeMessageDetails()
    }

    function updateEnabledStatus(repeater, message, firstChart, secondChart) {
        if (!message)
            return

        for (let i = 0; i < repeater.count; i++) {
            let fieldRow = repeater.itemAt(i)
            if (!fieldRow)
                continue
            const messageField = message.fields.get(i)
            fieldRow.plot1CheckBox.enabled = isCheckboxEnabled(fieldRow.plot1CheckBox, messageField, firstChart)
            fieldRow.plot2CheckBox.enabled = isCheckboxEnabled(fieldRow.plot2CheckBox, messageField, secondChart)
        }
    }

    function isCheckboxEnabled(checkBox, messageField, chart) {
        if (checkBox.checkState === Qt.Checked)
            return true
        if (!messageField.selectable)
            return false
        if (messageField.series !== null)
            return false
        return chart.roomForNewDimension()
    }

    component InspectorOutlineButton: Button {
        id: outlineButton

        hoverEnabled:  !ScreenTools.isMobile
        focusPolicy:   Qt.ClickFocus
        leftPadding:   ScreenTools.defaultFontPixelWidth * 1.75
        rightPadding:  leftPadding
        topPadding:    ScreenTools.defaultFontPixelHeight * 0.3
        bottomPadding: topPadding
        font.family:   ScreenTools.normalFontFamily
        font.pointSize: ScreenTools.defaultFontPointSize
        implicitWidth: Math.max(ScreenTools.implicitButtonWidth,
                                buttonLabel.implicitWidth + leftPadding + rightPadding)
        implicitHeight: Math.max(ScreenTools.implicitButtonHeight,
                                 buttonLabel.implicitHeight + topPadding + bottomPadding)

        contentItem: QGCLabel {
            id:                  buttonLabel
            text:                outlineButton.text
            color:               outlineButton.pressed ? "#FFFFFF" : root._titleColor
            font:                outlineButton.font
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment:   Text.AlignVCenter
            elide:               Text.ElideRight
        }

        background: Rectangle {
            implicitWidth:  ScreenTools.implicitButtonWidth
            implicitHeight: ScreenTools.implicitButtonHeight
            radius:         outlineButton.height / 2
            border.width:   1
            border.color:   root._accentGreen
            color: {
                if (outlineButton.pressed)
                    return root._accentGreen
                if (outlineButton.hovered)
                    return root._cardSelectedFill
                return root._cardIdleFill
            }
        }
    }

    component InspectorComboBox: QGCComboBox {
        id: inspectorCombo

        contentItem: QGCLabel {
            text:                inspectorCombo.alternateText === "" ? inspectorCombo.currentText : inspectorCombo.alternateText
            font:                inspectorCombo.font
            color:               root._titleColor
            verticalAlignment:   Text.AlignVCenter
            horizontalAlignment: inspectorCombo.centeredLabel ? Text.AlignHCenter : Text.AlignLeft
            elide:               Text.ElideRight
        }

        indicator: QGCColoredImage {
            anchors.right:          parent.right
            anchors.rightMargin:    inspectorCombo.padding
            anchors.verticalCenter: parent.verticalCenter
            width:                  ScreenTools.defaultFontPixelWidth * 1.1
            height:                 width
            source:                 "/qmlimages/arrow-down.png"
            color:                  root._accentGreen
        }

        background: Rectangle {
            implicitWidth:  ScreenTools.implicitComboBoxWidth
            implicitHeight: ScreenTools.implicitComboBoxHeight
            radius:         ScreenTools.defaultBorderRadius * 2
            color:          root._cardIdleFill
            border.width:   inspectorCombo.activeFocus ? 2 : 1
            border.color:   root._accentGreen
        }
    }

    Component {
        id: headerComponent

        Item {
            implicitHeight: root.inspectorDetailOpen ? 0 : inspectorHeaderLayout.implicitHeight
            opacity:        root.inspectorDetailOpen ? 0 : 1
            clip:           true

            Behavior on implicitHeight {
                NumberAnimation {
                    duration:    280
                    easing.type: Easing.InOutCubic
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration:    180
                    easing.type: Easing.InOutQuad
                }
            }

            ColumnLayout {
                id:                  inspectorHeaderLayout
                anchors.left:        parent.left
                anchors.right:       parent.right
                anchors.leftMargin:  root._pagePad
                anchors.rightMargin: root._pagePad
                spacing:             root._headerSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing:          root._controlSpacing

                QGCTextField {
                    id:                     messageSearch
                    Layout.fillWidth:       true
                    placeholderText:        qsTr("Search")
                    activeFocusBorderColor: root._accentGreen
                    onTextChanged:          root.messageSearchText = text

                    background: Rectangle {
                        implicitWidth:  ScreenTools.implicitTextFieldWidth
                        implicitHeight: ScreenTools.implicitTextFieldHeight
                        radius:         ScreenTools.defaultBorderRadius * 2
                        color:          root._cardIdleFill
                        border.width:   messageSearch.activeFocus ? 2 : 1
                        border.color:   root._accentGreen
                    }
                }

                InspectorOutlineButton {
                    text: qsTr("Clear")
                    onClicked: {
                        if (ScreenTools.isMobile)
                            Qt.inputMethod.hide()
                        messageSearch.text = ""
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing:          root._controlSpacing

                QGCLabel {
                    Layout.fillWidth: true
                    text:             qsTr("Inspect real-time MAVLink messages")
                    color:            root._bodyColor
                    elide:            Text.ElideRight
                }

                InspectorComboBox {
                    id:             systemCombo
                    model:          controller.systemNames
                    sizeToContents: true
                    visible:        controller.systemNames.length > 1
                    onActivated: (index) => controller.setActiveSystem(controller.systems.get(index).id)

                    Connections {
                        target: controller
                        function onActiveSystemChanged() {
                            for (var systemIndex = 0; systemIndex < controller.systems.count; systemIndex++) {
                                if (controller.systems.get(systemIndex) === root.curSystem) {
                                    systemCombo.currentIndex = systemIndex
                                    root.curCompID = 0
                                    cidCombo.currentIndex = 0
                                    break
                                }
                            }
                        }
                    }
                }

                InspectorComboBox {
                    id:             cidCombo
                    model:          root.curSystem ? root.curSystem.compIDsStr : []
                    sizeToContents: true
                    visible:        root.curSystem ? root.curSystem.compIDsStr.length > 2 : false
                    onActivated: (index) => {
                        if (root.curSystem && root.curSystem.compIDsStr.length > 1)
                            root.curCompID = index < 1 ? 0 : root.curSystem.compIDs[index - 1]
                    }
                }
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

            Item {
                id:                  detailToolbar
                anchors.top:         parent.top
                anchors.left:        parent.left
                anchors.right:       parent.right
                anchors.leftMargin:  root._pagePad
                anchors.rightMargin: root._pagePad
                height:              root.inspectorDetailOpen ? ScreenTools.implicitButtonHeight * 0.9 : 0
                opacity:             root.inspectorDetailOpen ? 1 : 0
                clip:                true
                z:                   20

                RowLayout {
                    anchors.fill: parent
                    spacing:      root._controlSpacing

                    QGCLabel {
                        Layout.fillWidth: true
                        text:             root.curMessage ? root.curMessage.name : qsTr("MAVLink Message")
                        color:            root._titleColor
                        font.pointSize:   ScreenTools.defaultFontPointSize
                        font.weight:      Font.DemiBold
                        elide:            Text.ElideRight
                    }

                    InspectorOutlineButton {
                        Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 8.5
                        Layout.preferredHeight: detailToolbar.height
                        Layout.alignment:       Qt.AlignVCenter
                        text:                   qsTr("Close")
                        onClicked:              root.closeMessageDetails()
                    }
                }

                Behavior on height {
                    NumberAnimation {
                        duration:    260
                        easing.type: Easing.InOutCubic
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration:    180
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            Row {
                anchors.top:         detailToolbar.bottom
                anchors.left:        parent.left
                anchors.right:       parent.right
                anchors.bottom:      parent.bottom
                anchors.leftMargin:  root._pagePad
                anchors.rightMargin: root._pagePad
                anchors.topMargin:   root._headerSpacing
                anchors.bottomMargin: root._pagePad
                spacing:             0

                QGCFlickable {
                    id:                 buttonGrid
                    width:              root.inspectorDetailOpen ? 0 : parent.width
                    height:             parent.height
                    contentWidth:       width
                    contentHeight:      buttonCol.height
                    flickableDirection: Flickable.VerticalFlick
                    clip:               true
                    pixelAligned:       true
                    opacity:            root.inspectorDetailOpen ? 0 : 1
                    enabled:            !root.inspectorDetailOpen

                    Behavior on width {
                        NumberAnimation {
                            duration:    320
                            easing.type: Easing.InOutCubic
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration:    180
                            easing.type: Easing.InOutQuad
                        }
                    }

                    ColumnLayout {
                        id:             buttonCol
                        width:          Math.min(root._navigationWidth, buttonGrid.width)
                        anchors.left:    parent.left
                        spacing:        Math.ceil(ScreenTools.defaultFontPixelHeight * 0.25)

                        Repeater {
                            model: root.curSystem ? root.curSystem.messages : []

                            MAVLinkMessageButton {
                                Layout.fillWidth: true
                                text:             object.name + (object.fieldSelected ? " *" : "")
                                compID:           object.compId
                                checked:          root.curSystem ? root.curSystem.selected === index : false
                                messageHz:        object.actualRateHz
                                visible:          (root.curCompID === 0 || root.curCompID === compID) && root.messageMatches(object)
                                onClicked:        root.openMessageDetails(index)
                            }
                        }
                    }
                }

                QGCFlickable {
                    id:                 messageGrid
                    width:              root.inspectorDetailOpen ? parent.width : 0
                    height:             parent.height
                    contentWidth:       Math.max(width, root._minimumDataWidth)
                    contentHeight:      messageCol.height
                    flickableDirection: Flickable.HorizontalAndVerticalFlick
                    clip:               true
                    pixelAligned:       true
                    opacity:            root.inspectorDetailOpen ? 1 : 0
                    enabled:            root.inspectorDetailOpen

                    Behavior on width {
                        NumberAnimation {
                            duration:    320
                            easing.type: Easing.InOutCubic
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration:    220
                            easing.type: Easing.InOutQuad
                        }
                    }

                    ScrollBar.horizontal: ScrollBar {
                        id: horizontalInspectorScrollBar

                        policy:        messageGrid.contentWidth > messageGrid.width ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                        height:        Math.max(14, ScreenTools.defaultFontPixelHeight * 0.8)
                        leftPadding:   root._controlSpacing * 0.5
                        rightPadding:  leftPadding
                        topPadding:    Math.max(6, root._headerSpacing * 0.6)
                        bottomPadding: 2
                        minimumSize:   0.06

                        background: Rectangle {
                            color: root._pageBackground

                            Rectangle {
                                anchors.left:         parent.left
                                anchors.right:        parent.right
                                anchors.bottom:       parent.bottom
                                anchors.leftMargin:   horizontalInspectorScrollBar.leftPadding
                                anchors.rightMargin:  horizontalInspectorScrollBar.rightPadding
                                anchors.bottomMargin: horizontalInspectorScrollBar.bottomPadding
                                height:                horizontalInspectorScrollBar.height
                                                       - horizontalInspectorScrollBar.topPadding
                                                       - horizontalInspectorScrollBar.bottomPadding
                                radius:                height / 2
                                color:                 root._darkTheme ? root._dataCardFill : "#F0F0F0"
                            }
                        }

                        contentItem: Rectangle {
                            implicitWidth:  ScreenTools.defaultFontPixelHeight * 2
                            implicitHeight: Math.max(4, ScreenTools.defaultFontPixelWidth * 0.45)
                            radius:         height / 2
                            color:          root._accentGreen
                        }
                    }

                    Column {
                        id:      messageCol
                        width:   parent.width
                        spacing: root._headerSpacing

                        Rectangle {
                            width:        parent.width
                            height:       summaryGrid.implicitHeight + root._controlSpacing * 2
                            radius:       root._cardRadius
                            color:        root._dataCardFill
                            border.width: 1
                            border.color: root._tableLine

                            GridLayout {
                                id:              summaryGrid
                                anchors.fill:    parent
                                anchors.margins: root._controlSpacing
                                columns:         4
                                columnSpacing:   root._controlSpacing
                                rowSpacing:      root._headerSpacing * 0.6

                                QGCLabel {
                                    text:        qsTr("Message")
                                    color:       root._bodyColor
                                    font.weight: Font.DemiBold
                                }
                                QGCLabel {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    Layout.preferredWidth: summaryGrid.width * 0.36
                                    Layout.maximumWidth: summaryGrid.width * 0.36
                                    text:             root.curMessage ? root.curMessage.name + " (" + root.curMessage.id + ")" : ""
                                    color:            root._accentGreen
                                    font.weight:      Font.DemiBold
                                    elide:            Text.ElideRight
                                }
                                QGCLabel {
                                    text:        qsTr("Component")
                                    color:       root._bodyColor
                                    font.weight: Font.DemiBold
                                }
                                QGCLabel {
                                    Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 3
                                    text:                root.curMessage ? root.curMessage.compId : ""
                                    color:               root._titleColor
                                    elide:               Text.ElideRight
                                }

                                QGCLabel {
                                    text:        qsTr("Count")
                                    color:       root._bodyColor
                                    font.weight: Font.DemiBold
                                }
                                QGCLabel {
                                    Layout.minimumWidth: 0
                                    text:                root.curMessage ? root.curMessage.count : ""
                                    color:               root._titleColor
                                    elide:               Text.ElideRight
                                }
                                QGCLabel {
                                    text:        qsTr("Actual Rate")
                                    color:       root._bodyColor
                                    font.weight: Font.DemiBold
                                }
                                QGCLabel {
                                    Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 5
                                    text:                root.curMessage ? root.curMessage.actualRateHz.toFixed(1) + qsTr(" Hz") : ""
                                    color:               root._titleColor
                                    elide:               Text.ElideRight
                                }

                                QGCLabel {
                                    text:        qsTr("Set Rate")
                                    color:       root._bodyColor
                                    font.weight: Font.DemiBold
                                }
                                InspectorComboBox {
                                    id:                msgRateCombo
                                    Layout.columnSpan: 3
                                    Layout.alignment:  Qt.AlignLeft
                                    textRole:          "text"
                                    valueRole:         "value"
                                    sizeToContents:    true
                                    model: [
                                        { value: -1, text: qsTr("Disabled") },
                                        { value: 0, text: qsTr("Default") },
                                        { value: 1, text: qsTr("1 Hz") },
                                        { value: 2, text: qsTr("2 Hz") },
                                        { value: 3, text: qsTr("3 Hz") },
                                        { value: 4, text: qsTr("4 Hz") },
                                        { value: 5, text: qsTr("5 Hz") },
                                        { value: 6, text: qsTr("6 Hz") },
                                        { value: 7, text: qsTr("7 Hz") },
                                        { value: 8, text: qsTr("8 Hz") },
                                        { value: 9, text: qsTr("9 Hz") },
                                        { value: 10, text: qsTr("10 Hz") },
                                        { value: 25, text: qsTr("25 Hz") },
                                        { value: 50, text: qsTr("50 Hz") },
                                        { value: 100, text: qsTr("100 Hz") }
                                    ]
                                    Component.onCompleted: reset()
                                    onActivated: (index) => controller.setMessageInterval(currentValue)

                                    function reset() {
                                        currentIndex = indexOfValue(0)
                                    }

                                    Connections {
                                        target: root
                                        function onCurMessageChanged() {
                                            msgRateCombo.reset()
                                        }
                                    }

                                    Connections {
                                        target: root.curMessage
                                        ignoreUnknownSignals: true
                                        function onTargetRateHzChanged() {
                                            const targetIndex = msgRateCombo.indexOfValue(root.curMessage.targetRateHz)
                                            if (targetIndex !== -1)
                                                msgRateCombo.currentIndex = targetIndex
                                        }
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            id:      messageFieldsColumn
                            width:   parent.width
                            spacing: ScreenTools.defaultFontPixelHeight * 0.25

                            Item {
                                Layout.fillWidth:       true
                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.7

                                RowLayout {
                                    anchors.fill:        parent
                                    anchors.leftMargin:  ScreenTools.defaultFontPixelWidth
                                    anchors.rightMargin: ScreenTools.defaultFontPixelWidth
                                    spacing:             0

                                    QGCLabel {
                                        Layout.preferredWidth: parent.width * 0.34
                                        text:                  qsTr("Name")
                                        color:                 root._titleColor
                                        font.weight:           Font.DemiBold
                                    }
                                    QGCLabel {
                                        Layout.preferredWidth: parent.width * 0.27
                                        text:                  qsTr("Value")
                                        color:                 root._titleColor
                                        font.weight:           Font.DemiBold
                                    }
                                    QGCLabel {
                                        Layout.preferredWidth: parent.width * 0.18
                                        text:                  qsTr("Type")
                                        color:                 root._titleColor
                                        font.weight:           Font.DemiBold
                                    }
                                    QGCLabel {
                                        Layout.preferredWidth: parent.width * 0.105
                                        text:                  qsTr("Plot 1")
                                        color:                 root._titleColor
                                        font.weight:           Font.DemiBold
                                        horizontalAlignment:   Text.AlignHCenter
                                    }
                                    QGCLabel {
                                        Layout.preferredWidth: parent.width * 0.105
                                        text:                  qsTr("Plot 2")
                                        color:                 root._titleColor
                                        font.weight:           Font.DemiBold
                                        horizontalAlignment:   Text.AlignHCenter
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height:           1
                                color:            root._tableLine
                            }

                            Repeater {
                                id:    fieldRows
                                model: root.curMessage ? root.curMessage.fields : []

                                Rectangle {
                                    Layout.fillWidth:       true
                                    Layout.preferredHeight: root._dataRowHeight
                                    radius:                 root._cardRadius
                                    color:                  root._dataCardFill
                                    border.width:           1
                                    border.color:           root._tableLine

                                    property alias plot1CheckBox: plot1CheckBox
                                    property alias plot2CheckBox: plot2CheckBox

                                    RowLayout {
                                        anchors.fill:        parent
                                        anchors.leftMargin:  ScreenTools.defaultFontPixelWidth
                                        anchors.rightMargin: ScreenTools.defaultFontPixelWidth
                                        spacing:             0

                                        QGCLabel {
                                            Layout.preferredWidth: parent.width * 0.34
                                            text:                  object.name
                                            color:                 root._titleColor
                                            elide:                 Text.ElideRight
                                        }
                                        QGCLabel {
                                            Layout.preferredWidth: parent.width * 0.27
                                            text:                  object.value
                                            color:                 root._titleColor
                                            elide:                 Text.ElideRight
                                        }
                                        QGCLabel {
                                            Layout.preferredWidth: parent.width * 0.18
                                            text:                  object.type
                                            color:                 root._bodyColor
                                            elide:                 Text.ElideRight
                                        }
                                        Item {
                                            Layout.preferredWidth: parent.width * 0.105
                                            Layout.fillHeight:     true

                                            QGCCheckBox {
                                                id:                    plot1CheckBox
                                                anchors.centerIn:      parent
                                                checked:               object.series !== null && object.chartIndex === 0
                                                uncheckedBorderColor: root._accentGreen
                                                onClicked: {
                                                    if (checked)
                                                        chart1.addDimension(object)
                                                    else
                                                        chart1.delDimension(object)
                                                    root.updateEnabledStatus(fieldRows, root.curMessage, chart1, chart2)
                                                }
                                            }
                                        }
                                        Item {
                                            Layout.preferredWidth: parent.width * 0.105
                                            Layout.fillHeight:     true

                                            QGCCheckBox {
                                                id:                    plot2CheckBox
                                                anchors.centerIn:      parent
                                                checked:               object.series !== null && object.chartIndex === 1
                                                uncheckedBorderColor: root._accentGreen
                                                onClicked: {
                                                    if (checked)
                                                        chart2.addDimension(object)
                                                    else
                                                        chart2.delDimension(object)
                                                    root.updateEnabledStatus(fieldRows, root.curMessage, chart1, chart2)
                                                }
                                            }
                                        }
                                    }

                                    Component.onCompleted: root.updateEnabledStatus(fieldRows, root.curMessage, chart1, chart2)
                                }
                            }
                        }

                        MAVLinkChart {
                            id:                  chart1
                            width:               parent.width
                            height:              ScreenTools.defaultFontPixelHeight * 20
                            inspectorController: controller
                            chartIndex:          0
                        }

                        MAVLinkChart {
                            id:                  chart2
                            width:               parent.width
                            height:              ScreenTools.defaultFontPixelHeight * 20
                            inspectorController: controller
                            chartIndex:          1
                        }
                    }
                }

            }

            QGCLabel {
                anchors.centerIn:    parent
                width:               parent.width * 0.8
                visible:             !root.inspectorDetailOpen && !root.curSystem
                text:                qsTr("MAVLink messages will appear after a vehicle connects.")
                color:               root._bodyColor
                font.pointSize:      ScreenTools.mediumFontPointSize
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment:   Text.AlignVCenter
                wrapMode:            Text.WordWrap
            }

        }
    }
}
