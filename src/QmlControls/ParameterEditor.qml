import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Rectangle {
    id:         _root
    color:      _pageBackground

    QGCPalette { id: qgcPal; colorGroupEnabled: _root.enabled }

    readonly property bool  _darkTheme: {
        if (typeof mainWindow !== "undefined" && mainWindow)
            return mainWindow.uiThemeMode === mainWindow.themeBlack
        return qgcPal.globalTheme === QGCPalette.Dark
    }
    readonly property color _pageBackground:    _darkTheme ? qgcPal.window : "#FFFFFF"
    readonly property color _titleColor:        _darkTheme ? "#AEAEB2" : "#3A3A3C"
    readonly property color _bodyColor:         _darkTheme ? "#8E8E93" : "#3A3A3C"
    readonly property color _accentGreen:       "#00a04c"
    readonly property color _cardIdleBorder:    _darkTheme ? qgcPal.windowShade : "#E6E6E6"
    readonly property color _cardIdleFill:      _darkTheme ? qgcPal.window : "#FFFFFF"
    readonly property color _cardSelectedFill:  Qt.rgba(0, 160 / 255, 76 / 255, _darkTheme ? 0.16 : 0.08)
    readonly property color _dataCardFill:      _darkTheme ? qgcPal.windowShade : "#F5F5F5"
    readonly property color _tableLine:         _darkTheme ? qgcPal.windowShade : "#E5E5E5"
    readonly property real  _pagePad:           ScreenTools.defaultFontPixelWidth * 2.2
    readonly property real  _cardRadius:        ScreenTools.defaultFontPixelWidth * 0.9
    readonly property real  _controlSpacing:     ScreenTools.defaultFontPixelWidth
    readonly property real  _headerSpacing:      Math.ceil(ScreenTools.defaultFontPixelHeight * 0.65)
    readonly property real  _minimumParameterRowWidth: ScreenTools.defaultFontPixelWidth * 58
    property Fact   _editorDialogFact: Fact { }
    property int    _rowHeight:         ScreenTools.defaultFontPixelHeight * 2
    property int    _rowWidth:          10 // Dynamic adjusted at runtime
    property var    _searchResults      ///< List of parameter names from search results
    property var    _expandedCategory:  null
    property var    _activeVehicle:     QGroundControl.multiVehicleManager.activeVehicle
    property bool   _showRCToParam:     _activeVehicle.px4Firmware
    property var    _appSettings:       QGroundControl.settingsManager.appSettings
    property var    _controller:        controller

    ParameterEditorController {
        id: controller
    }

    Timer {
        id:         clearTimer
        interval:   100;
        running:    false;
        repeat:     false
        onTriggered: {
            searchText.text = ""
            controller.searchText = ""
        }
    }

    QGCMenu {
        id:                 toolsMenu
        QGCMenuItem {
            text:           qsTr("Refresh")
            onTriggered:	controller.refresh()
        }
        QGCMenuItem {
            text:           qsTr("Reset all to firmware's defaults")
            onTriggered:    mainWindow.showMessageDialog(qsTr("Reset All"),
                                                         qsTr("Select Reset to reset all parameters to their defaults.\n\nNote that this will also completely reset everything, including UAVCAN nodes, all vehicle settings, setup and calibrations."),
                                                         Dialog.Cancel | Dialog.Reset,
                                                         function() { controller.resetAllToDefaults() })
        }
        QGCMenuItem {
            text:           qsTr("Reset to vehicle's configuration defaults")
            visible:        !_activeVehicle.apmFirmware
            onTriggered:    mainWindow.showMessageDialog(qsTr("Reset All"),
                                                         qsTr("Select Reset to reset all parameters to the vehicle's configuration defaults."),
                                                         Dialog.Cancel | Dialog.Reset,
                                                         function() { controller.resetAllToVehicleConfiguration() })
        }
        QGCMenuSeparator { }
        QGCMenuItem {
            text:           qsTr("Load from file for review...")
            onTriggered: {
                fileDialog.title =          qsTr("Load Parameters")
                fileDialog.openForLoad()
            }
        }
        QGCMenuItem {
            text:           qsTr("Save to file...")
            onTriggered: {
                fileDialog.title =          qsTr("Save Parameters")
                fileDialog.openForSave()
            }
        }
        QGCMenuSeparator { visible: _showRCToParam }
        QGCMenuItem {
            text:           qsTr("Clear all RC to Param")
            onTriggered:	_activeVehicle.clearAllParamMapRC()
            visible:        _showRCToParam
        }
        QGCMenuSeparator { }
        QGCMenuItem {
            text:           qsTr("Reboot Vehicle")
            onTriggered:    mainWindow.showMessageDialog(qsTr("Reboot Vehicle"),
                                                         qsTr("Select Ok to reboot vehicle."),
                                                         Dialog.Cancel | Dialog.Ok,
                                                         function() { _activeVehicle.rebootVehicle() })
        }
    }


    QGCFileDialog {
        id:             fileDialog
        folder:         _appSettings.parameterSavePath
        nameFilters:    [ qsTr("Parameter Files (*.%1)").arg(_appSettings.parameterFileExtension) , qsTr("All Files (*)") ]

        onAcceptedForSave: (file) => {
            controller.saveToFile(file)
            close()
        }

        onAcceptedForLoad: (file) => {
            close()
            if (controller.buildDiffFromFile(file)) {
                parameterDiffDialog.createObject(mainWindow).open()
            }
        }
    }

    Component {
        id: editorDialogComponent

        ParameterEditorDialog {
            fact:           _editorDialogFact
            showRCToParam:  _showRCToParam
        }
    }

    Component {
        id: parameterDiffDialog

        ParameterDiffDialog {
            paramController: _controller
        }
    }

    component ParameterOutlineButton: QGCButton {
        id: outlineButton

        readonly property bool _darkTheme: {
            if (typeof mainWindow !== "undefined" && mainWindow)
                return mainWindow.uiThemeMode === mainWindow.themeBlack
            return outlinePalette.globalTheme === QGCPalette.Dark
        }
        readonly property color _idleFill:     _darkTheme ? outlinePalette.window : "#FFFFFF"
        readonly property color _idleBorder:   _darkTheme ? outlinePalette.windowShade : "#E6E6E6"
        readonly property color _titleColor:   _darkTheme ? "#AEAEB2" : "#3A3A3C"
        readonly property color _selectedFill: Qt.rgba(0, 160 / 255, 76 / 255, _darkTheme ? 0.16 : 0.08)

        QGCPalette { id: outlinePalette; colorGroupEnabled: outlineButton.enabled }

        textColor: checked || pressed ? "#ffffff" : _titleColor

        background: Rectangle {
            implicitWidth:  ScreenTools.implicitButtonWidth
            implicitHeight: ScreenTools.implicitButtonHeight
            radius:         outlineButton.height / 2
            border.width:   1
            border.color:   outlineButton.checked ? "#00a04c" : outlineButton._idleBorder
            color: {
                if (outlineButton.checked || outlineButton.pressed) {
                    return "#00a04c"
                }
                if (outlineButton.hovered) {
                    return outlineButton._selectedFill
                }
                return outlineButton._idleFill
            }
        }
    }

    component ParameterCategoryButton: Button {
        id: categoryButton

        property bool expanded: false

        readonly property bool _darkTheme: {
            if (typeof mainWindow !== "undefined" && mainWindow)
                return mainWindow.uiThemeMode === mainWindow.themeBlack
            return categoryPalette.globalTheme === QGCPalette.Dark
        }
        readonly property color _idleFill:     _darkTheme ? categoryPalette.window : "#FFFFFF"
        readonly property color _idleBorder:   _darkTheme ? categoryPalette.windowShade : "#E6E6E6"
        readonly property color _titleColor:   _darkTheme ? "#AEAEB2" : "#3A3A3C"
        readonly property color _bodyColor:    _darkTheme ? "#8E8E93" : "#3A3A3C"
        readonly property color _selectedFill: Qt.rgba(0, 160 / 255, 76 / 255, _darkTheme ? 0.16 : 0.08)

        implicitWidth:   ScreenTools.defaultFontPixelWidth * 25
        implicitHeight:  Math.max(ScreenTools.implicitButtonHeight, ScreenTools.defaultFontPixelHeight * 2.2)
        leftPadding:     ScreenTools.defaultFontPixelWidth * 1.25
        rightPadding:    leftPadding
        focusPolicy:     Qt.ClickFocus
        hoverEnabled:    !ScreenTools.isMobile

        QGCPalette { id: categoryPalette; colorGroupEnabled: categoryButton.enabled }

        background: Rectangle {
            radius:       ScreenTools.defaultBorderRadius * 2
            border.width: 1
            border.color: categoryButton.expanded ? "#00a04c" : categoryButton._idleBorder
            color: {
                if (categoryButton.expanded || categoryButton.down) {
                    return categoryButton._selectedFill
                }
                if (categoryButton.hovered) {
                    return categoryButton._selectedFill
                }
                return categoryButton._idleFill
            }
        }

        contentItem: RowLayout {
            spacing: ScreenTools.defaultFontPixelWidth

            QGCLabel {
                Layout.fillWidth: true
                text:             categoryButton.text
                color:            categoryButton.expanded ? "#00a04c" : categoryButton._titleColor
                font.weight:      categoryButton.expanded ? Font.DemiBold : Font.Normal
                elide:            Text.ElideRight
            }

            QGCColoredImage {
                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 0.55
                Layout.preferredHeight: Layout.preferredWidth
                source:                 "/qmlimages/arrow-down.png"
                color:                  categoryButton.expanded ? "#00a04c" : categoryButton._bodyColor
                fillMode:               Image.PreserveAspectFit
            }
        }
    }

    ColumnLayout {
        id:             header
        anchors.top:    parent.top
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.topMargin:   ScreenTools.defaultFontPixelHeight * 0.35
        anchors.leftMargin:  _pagePad
        anchors.rightMargin: _pagePad
        spacing:        _headerSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing:          _controlSpacing

            QGCTextField {
                id:                     searchText
                Layout.fillWidth:       true
                placeholderText:        qsTr("Search")
                activeFocusBorderColor: _accentGreen
                onDisplayTextChanged:   controller.searchText = displayText

                background: Rectangle {
                    implicitWidth:  ScreenTools.implicitTextFieldWidth
                    implicitHeight: ScreenTools.implicitTextFieldHeight
                    radius:         ScreenTools.defaultBorderRadius * 2
                    color:          _cardIdleFill
                    border.width:   searchText.activeFocus ? 2 : 1
                    border.color:   _accentGreen
                }
            }

            ParameterOutlineButton {
                text: qsTr("Clear")
                onClicked: {
                    if(ScreenTools.isMobile) {
                        Qt.inputMethod.hide();
                    }
                    clearTimer.start()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing:          _controlSpacing

            QGCCheckBox {
                text:                 qsTr("Show modified only")
                textColor:            _titleColor
                checked:              controller.showModifiedOnly
                uncheckedBorderColor: _accentGreen
                onClicked:            controller.showModifiedOnly = checked
                visible:              QGroundControl.multiVehicleManager.activeVehicle.px4Firmware
            }

            Item {
                Layout.fillWidth: true
            }

            ParameterOutlineButton {
                text:      qsTr("Tools")
                onClicked: toolsMenu.popup()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height:           1
            color:            _tableLine
        }
    }

    /// Group buttons
    QGCFlickable {
        id :                groupScroll
        width:              ScreenTools.defaultFontPixelWidth * 25
        anchors.left:       parent.left
        anchors.leftMargin: _pagePad
        anchors.top:        header.bottom
        anchors.topMargin:  _headerSpacing
        anchors.bottom:     parent.bottom
        anchors.bottomMargin: _pagePad
        clip:               true
        pixelAligned:       true
        contentHeight:      groupedViewCategoryColumn.height
        flickableDirection: Flickable.VerticalFlick
        visible:            true

        ColumnLayout {
            id:             groupedViewCategoryColumn
            anchors.left:   parent.left
            anchors.right:  parent.right
            spacing:        Math.ceil(ScreenTools.defaultFontPixelHeight * 0.25)

            Repeater {
                model: controller.categories

                Column {
                    Layout.fillWidth:   true
                    spacing:            Math.ceil(ScreenTools.defaultFontPixelHeight * 0.25)


                    ParameterCategoryButton {
                        id:             categoryHeader
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        text:           object.name
                        expanded:       object == _expandedCategory

                        onClicked: {
                            if (expanded) {
                                _expandedCategory = null
                            } else {
                                _rowWidth = 10
                                _expandedCategory = object
                                controller.currentCategory = object
                            }
                        }
                    }

                    Repeater {
                        model: categoryHeader.expanded ? object.groups : 0

                        ParameterOutlineButton {
                            width:          ScreenTools.defaultFontPixelWidth * 25
                            text:           object.name
                            height:         _rowHeight
                            checked:        object == controller.currentGroup
                            autoExclusive:  true

                            onClicked: {
                                if (!checked) _rowWidth = 10
                                checked = true
                                controller.currentGroup = object
                            }
                        }
                    }
                }
            }
        }
    }

    TableView {
        id:                 tableView
        anchors.leftMargin: ScreenTools.defaultFontPixelWidth
        anchors.top:        header.bottom
        anchors.topMargin:  _headerSpacing
        anchors.bottom:     parent.bottom
        anchors.bottomMargin: _pagePad
        anchors.left:       groupScroll.right
        anchors.right:      parent.right
        anchors.rightMargin: _pagePad
        columnSpacing:      0
        rowSpacing:         ScreenTools.defaultFontPixelHeight / 4
        model:              controller.parameters
        contentWidth:       Math.max(width, _minimumParameterRowWidth)
        flickableDirection: Flickable.HorizontalAndVerticalFlick
        boundsBehavior:     Flickable.StopAtBounds
        clip:               true

        columnWidthProvider: function(column) {
            return column === 0 ? tableView.contentWidth : 0
        }

        ScrollBar.horizontal: ScrollBar {
            id: horizontalParameterScrollBar

            policy: tableView.contentWidth > tableView.width ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
            height: Math.max(12, ScreenTools.defaultFontPixelWidth * 1.35)
            leftPadding:   2
            rightPadding:  2
            topPadding:    2
            bottomPadding: 2
            minimumSize:   0.06

            background: Rectangle {
                radius: horizontalParameterScrollBar.height / 2
                color:  "#F0F0F0"
                border.width: 1
                border.color: "#FFFFFF"
            }

            contentItem: Rectangle {
                implicitWidth:  ScreenTools.defaultFontPixelHeight * 2
                implicitHeight: Math.max(8, ScreenTools.defaultFontPixelWidth)
                radius:         height / 2
                color:          _accentGreen
                border.width:   1
                border.color:   "#FFFFFF"
            }
        }

        // Qt is supposed to adjust column widths automatically when larger widths come into view.
        // But it doesn't work. So we have to do it force a layout manually when we scroll.
        Timer {
            id:             forceLayoutTimer
            interval:       500
            repeat:         false
            onTriggered:    tableView.forceLayout()
        }

        onTopRowChanged: forceLayoutTimer.start()
        onModelChanged: {
            positionViewAtRow(0, TableView.AlignLeft | TableView.AlignTop)
            forceLayoutTimer.start()
        }

        delegate: Item {
            readonly property real _labelHorizontalPadding: ScreenTools.defaultFontPixelWidth

            implicitWidth:  column === 0 ? tableView.contentWidth : 0
            implicitHeight: Math.max(_rowHeight, label.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.8)
            visible:        column === 0
            clip:           true

            Rectangle {
                anchors.fill: parent
                radius:       _cardRadius
                color:        _dataCardFill
                border.width: 1
                border.color: _tableLine
            }

            QGCLabel {
                id:                 label
                anchors.left:       parent.left
                anchors.right:      parent.right
                anchors.leftMargin: _labelHorizontalPadding
                anchors.rightMargin: _labelHorizontalPadding
                anchors.verticalCenter: parent.verticalCenter
                text:               combinedParameterText()
                color:              fact.defaultValueAvailable && !fact.valueEqualsDefault ? qgcPal.warningText : _titleColor
                maximumLineCount:   1
                elide:              Text.ElideRight

                function combinedParameterText() {
                    const parts = [fact.name, parameterValueText()]
                    if (fact.shortDescription && fact.shortDescription.length > 0) {
                        parts.push(fact.shortDescription)
                    }
                    return parts.join("   ")
                }

                function parameterValueText() {
                    if (fact.enumStrings.length === 0) {
                        return fact.units.length > 0 ? fact.valueString + " " + fact.units : fact.valueString
                    }
                    if (fact.bitmaskStrings.length != 0) {
                        return fact.selectedBitmaskStrings.join(',')
                    }
                    return fact.enumStringValue
                }
            }

            QGCMouseArea {
                anchors.fill: parent
                onClicked: mouse => {
                    _editorDialogFact = fact
                    editorDialogComponent.createObject(mainWindow).open()
                }
            }
        }
    }
}
