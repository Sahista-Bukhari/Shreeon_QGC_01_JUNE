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
    property bool   _parameterGroupOpen: false
    property bool   _parameterEditorOpen: false

    readonly property bool _masterControlsHidden: _parameterGroupOpen || _parameterEditorOpen

    readonly property bool _editorIsParameter:      _editorDialogFact.componentId != 0
    readonly property bool _editorAllowForceSave:   QGroundControl.corePlugin.showAdvancedUI && _editorIsParameter
    readonly property bool _editorAllowDefaultReset: _editorDialogFact.defaultValueAvailable
    readonly property bool _editorShowCombo:        _editorDialogFact.enumStrings.length !== 0
                                                       && _editorDialogFact.bitmaskStrings.length === 0

    function openParameterEditor(selectedFact) {
        _editorDialogFact = selectedFact
        _parameterEditorOpen = true
        Qt.callLater(resetParameterEditor)
    }

    function openParameterGroup(selectedGroup) {
        _rowWidth = 10
        controller.currentGroup = selectedGroup
        _parameterGroupOpen = true
    }

    function closeParameterGroup() {
        _parameterGroupOpen = false
    }

    function closeParameterEditor() {
        if (ScreenTools.isMobile)
            Qt.inputMethod.hide()
        parameterValidationError.text = ""
        _parameterEditorOpen = false
    }

    function resetParameterEditor() {
        parameterValidationError.text = ""
        parameterAdvanced.checked = false
        parameterManualEntry.checked = false
        parameterForceSave.checked = false
        parameterValueField.text = _editorDialogFact.valueString

        if (_editorShowCombo)
            parameterFactCombo.currentIndex = _editorDialogFact.enumIndex

        for (let bitIndex = 0; bitIndex < parameterBitmaskRepeater.count; bitIndex++) {
            const bitCheckBox = parameterBitmaskRepeater.itemAt(bitIndex)
            if (bitCheckBox) {
                bitCheckBox.checked = Boolean(_editorDialogFact.value
                                              & _editorDialogFact.bitmaskValues[bitIndex])
            }
        }
    }

    function editorBitmaskValue() {
        let value = 0
        for (let bitIndex = 0; bitIndex < parameterBitmaskRepeater.count; bitIndex++) {
            const bitCheckBox = parameterBitmaskRepeater.itemAt(bitIndex)
            if (bitCheckBox && bitCheckBox.checked)
                value |= _editorDialogFact.bitmaskValues[bitIndex]
        }
        return value
    }

    function editorParameterValueText() {
        if (_editorDialogFact.enumStrings.length === 0) {
            return _editorDialogFact.units.length > 0
                   ? _editorDialogFact.valueString + " " + _editorDialogFact.units
                   : _editorDialogFact.valueString
        }
        if (_editorDialogFact.bitmaskStrings.length !== 0)
            return _editorDialogFact.selectedBitmaskStrings.join(", ")
        return _editorDialogFact.enumStringValue
    }

    function saveParameterEditor() {
        if (!_editorIsParameter)
            return

        if (parameterBitmaskColumn.visible && !parameterManualEntry.checked) {
            _editorDialogFact.value = editorBitmaskValue()
            _editorDialogFact.valueChanged(_editorDialogFact.value)
        } else if (parameterFactCombo.visible && !parameterManualEntry.checked) {
            _editorDialogFact.enumIndex = parameterFactCombo.currentIndex
        } else {
            const validationMessage = _editorDialogFact.validate(parameterValueField.text,
                                                                  parameterForceSave.checked)
            if (validationMessage !== "") {
                parameterValidationError.text = validationMessage
                return
            }
            _editorDialogFact.value = parameterValueField.text
            _editorDialogFact.valueChanged(_editorDialogFact.value)
        }

        closeParameterEditor()
    }

    function resetParameterToDefault() {
        if (!_editorAllowDefaultReset)
            return
        _editorDialogFact.value = _editorDialogFact.defaultValue
        _editorDialogFact.valueChanged(_editorDialogFact.value)
        closeParameterEditor()
    }

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
        id: parameterDiffDialog

        ParameterDiffDialog {
            paramController: _controller
        }
    }

    Component {
        id: parameterRCToParamDialog

        RCToParamDialog {
            tuningFact: _editorDialogFact
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

    component ParameterCloseButton: Button {
        id: closeButton

        hoverEnabled:   !ScreenTools.isMobile
        focusPolicy:    Qt.ClickFocus
        leftPadding:    ScreenTools.defaultFontPixelWidth * 1.75
        rightPadding:   leftPadding
        topPadding:     ScreenTools.defaultFontPixelHeight * 0.3
        bottomPadding:  topPadding
        font.family:    ScreenTools.normalFontFamily
        font.pointSize: ScreenTools.defaultFontPointSize
        implicitWidth:  Math.max(ScreenTools.implicitButtonWidth,
                                 closeButtonLabel.implicitWidth + leftPadding + rightPadding)
        implicitHeight: Math.max(ScreenTools.implicitButtonHeight,
                                 closeButtonLabel.implicitHeight + topPadding + bottomPadding)

        contentItem: QGCLabel {
            id:                  closeButtonLabel
            text:                closeButton.text
            color:               closeButton.pressed ? "#FFFFFF" : _titleColor
            font:                closeButton.font
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment:   Text.AlignVCenter
        }

        background: Rectangle {
            implicitWidth:  ScreenTools.implicitButtonWidth
            implicitHeight: ScreenTools.implicitButtonHeight
            radius:         closeButton.height / 2
            border.width:   1
            border.color:   _accentGreen
            color: {
                if (closeButton.pressed)
                    return _accentGreen
                if (closeButton.hovered)
                    return _cardSelectedFill
                return _cardIdleFill
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
        height:         _masterControlsHidden ? 0 : implicitHeight
        opacity:        _masterControlsHidden ? 0 : 1
        clip:           true

        Behavior on height {
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
        width:              _masterControlsHidden ? 0 : ScreenTools.defaultFontPixelWidth * 25
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
        opacity:            _masterControlsHidden ? 0 : 1
        enabled:            !_masterControlsHidden

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
                                checked = true
                                openParameterGroup(object)
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        id:                  parameterGroupToolbar
        anchors.top:         parent.top
        anchors.left:        parent.left
        anchors.right:       parent.right
        anchors.topMargin:   ScreenTools.defaultFontPixelHeight * 0.35
        anchors.leftMargin:  _pagePad
        anchors.rightMargin: _pagePad
        height:              _parameterGroupOpen && !_parameterEditorOpen
                             ? parameterGroupToolbarRow.height + _headerSpacing * 0.65 + 1
                             : 0
        opacity:             _parameterGroupOpen && !_parameterEditorOpen ? 1 : 0
        clip:                true
        z:                   10

        RowLayout {
            id:            parameterGroupToolbarRow
            anchors.top:   parent.top
            anchors.left:  parent.left
            anchors.right: parent.right
            height:        ScreenTools.implicitButtonHeight * 0.9
            spacing:       _controlSpacing

            QGCLabel {
                Layout.fillWidth: true
                text:             controller.currentGroup ? controller.currentGroup.name : qsTr("Parameters")
                color:            _titleColor
                font.weight:      Font.DemiBold
                elide:            Text.ElideRight
            }

                ParameterCloseButton {
                    Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 8.5
                    Layout.preferredHeight: parameterGroupToolbarRow.height
                Layout.alignment:       Qt.AlignVCenter
                text:                   qsTr("Close")
                onClicked:              closeParameterGroup()
            }
        }

        Rectangle {
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.bottom: parent.bottom
            height:         1
            color:          _tableLine
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

    TableView {
        id:                 tableView
        anchors.leftMargin: ScreenTools.defaultFontPixelWidth
        anchors.top:        _parameterGroupOpen ? parameterGroupToolbar.bottom : header.bottom
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
        opacity:            _parameterEditorOpen ? 0 : 1
        enabled:            !_parameterEditorOpen

        Behavior on opacity {
            NumberAnimation {
                duration:    180
                easing.type: Easing.InOutQuad
            }
        }

        columnWidthProvider: function(column) {
            return column === 0 ? tableView.contentWidth : 0
        }

        ScrollBar.horizontal: ScrollBar {
            id: horizontalParameterScrollBar

            policy: tableView.contentWidth > tableView.width ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
            height:        Math.max(14, ScreenTools.defaultFontPixelHeight * 0.8)
            leftPadding:   _controlSpacing * 0.5
            rightPadding:  leftPadding
            topPadding:    Math.max(6, _headerSpacing * 0.6)
            bottomPadding: 2
            minimumSize:   0.06

            background: Rectangle {
                color: _pageBackground

                Rectangle {
                    anchors.left:         parent.left
                    anchors.right:        parent.right
                    anchors.bottom:       parent.bottom
                    anchors.leftMargin:   horizontalParameterScrollBar.leftPadding
                    anchors.rightMargin:  horizontalParameterScrollBar.rightPadding
                    anchors.bottomMargin: horizontalParameterScrollBar.bottomPadding
                    height:                horizontalParameterScrollBar.height
                                           - horizontalParameterScrollBar.topPadding
                                           - horizontalParameterScrollBar.bottomPadding
                    radius:                height / 2
                    color:                 _darkTheme ? _dataCardFill : "#F0F0F0"
                }
            }

            contentItem: Rectangle {
                implicitWidth:  ScreenTools.defaultFontPixelHeight * 2
                implicitHeight: Math.max(4, ScreenTools.defaultFontPixelWidth * 0.45)
                radius:         height / 2
                color:          _accentGreen
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
                    openParameterEditor(fact)
                }
            }
        }
    }

    Item {
        id:              parameterDetailPane
        anchors.fill:    parent
        opacity:         _parameterEditorOpen ? 1 : 0
        enabled:         _parameterEditorOpen
        z:               20

        Behavior on opacity {
            NumberAnimation {
                duration:    220
                easing.type: Easing.InOutQuad
            }
        }

        Item {
            id:                  parameterDetailToolbar
            anchors.top:         parent.top
            anchors.left:        parent.left
            anchors.right:       parent.right
            anchors.topMargin:   ScreenTools.defaultFontPixelHeight * 0.35
            anchors.leftMargin:  _pagePad
            anchors.rightMargin: _pagePad
            height:              parameterDetailToolbarRow.height + _headerSpacing * 0.65 + 1

            RowLayout {
                id:            parameterDetailToolbarRow
                anchors.top:   parent.top
                anchors.left:  parent.left
                anchors.right: parent.right
                height:        ScreenTools.implicitButtonHeight * 0.9
                spacing:       _controlSpacing

                QGCLabel {
                    Layout.fillWidth: true
                    text:             _editorIsParameter ? _editorDialogFact.name : qsTr("Parameter")
                    color:            _titleColor
                    font.weight:      Font.DemiBold
                    elide:            Text.ElideRight
                }

                ParameterCloseButton {
                    Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 8.5
                    Layout.preferredHeight: parameterDetailToolbarRow.height
                    Layout.alignment:       Qt.AlignVCenter
                    text:                   qsTr("Close")
                    onClicked:              closeParameterEditor()
                }
            }

            Rectangle {
                anchors.left:   parent.left
                anchors.right:  parent.right
                anchors.bottom: parent.bottom
                height:         1
                color:          _tableLine
            }
        }

        QGCFlickable {
            id:                  parameterDetailScroll
            anchors.top:         parameterDetailToolbar.bottom
            anchors.bottom:      parent.bottom
            anchors.left:        parent.left
            anchors.right:       parent.right
            anchors.topMargin:   _headerSpacing
            anchors.leftMargin:  _pagePad
            anchors.rightMargin: _pagePad
            anchors.bottomMargin: _pagePad
            contentWidth:        width
            contentHeight:       parameterDetailColumn.height
            flickableDirection:  Flickable.VerticalFlick
            clip:                true
            pixelAligned:        true

            ColumnLayout {
                id:      parameterDetailColumn
                width:   parameterDetailScroll.width
                spacing: _headerSpacing

                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: parameterSummaryLayout.implicitHeight + _controlSpacing * 2
                    radius:                 _cardRadius
                    color:                  _dataCardFill
                    border.width:           1
                    border.color:           _tableLine

                    ColumnLayout {
                        id:              parameterSummaryLayout
                        anchors.fill:    parent
                        anchors.margins: _controlSpacing
                        spacing:         _headerSpacing * 0.55

                        RowLayout {
                            Layout.fillWidth: true
                            spacing:          _controlSpacing

                            QGCLabel {
                                text:        qsTr("Parameter")
                                color:       _bodyColor
                                font.weight: Font.DemiBold
                            }

                            QGCLabel {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Layout.preferredWidth: parameterSummaryLayout.width * 0.4
                                Layout.maximumWidth: parameterSummaryLayout.width * 0.4
                                text:             _editorIsParameter ? _editorDialogFact.name : ""
                                color:            _accentGreen
                                font.weight:      Font.DemiBold
                                elide:            Text.ElideRight
                            }

                            QGCLabel {
                                text:        qsTr("Component")
                                color:       _bodyColor
                                font.weight: Font.DemiBold
                            }

                            QGCLabel {
                                text:  _editorIsParameter ? _editorDialogFact.componentId : ""
                                color: _titleColor
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing:          _controlSpacing

                            QGCLabel {
                                text:        qsTr("Current Value")
                                color:       _bodyColor
                                font.weight: Font.DemiBold
                            }

                            QGCLabel {
                                Layout.fillWidth: true
                                text:             _editorIsParameter ? editorParameterValueText() : ""
                                color:            _titleColor
                                elide:            Text.ElideRight
                            }
                        }

                        QGCLabel {
                            Layout.fillWidth: true
                            text:             _editorIsParameter ? _editorDialogFact.shortDescription : ""
                            color:            _bodyColor
                            wrapMode:         Text.WordWrap
                            visible:          text.length > 0
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: parameterFormLayout.implicitHeight + _controlSpacing * 2
                    radius:                 _cardRadius
                    color:                  _cardIdleFill
                    border.width:           1
                    border.color:           _tableLine

                    ColumnLayout {
                        id:              parameterFormLayout
                        anchors.fill:    parent
                        anchors.margins: _controlSpacing
                        spacing:         _headerSpacing

                        QGCLabel {
                            id:               parameterValidationError
                            Layout.fillWidth: true
                            text:             ""
                            color:            qgcPal.warningText
                            wrapMode:         Text.WordWrap
                            visible:          text.length > 0
                        }

                        QGCLabel {
                            text:        qsTr("Value")
                            color:       _titleColor
                            font.weight: Font.DemiBold
                        }

                        QGCTextField {
                            id:                     parameterValueField
                            Layout.fillWidth:       true
                            unitsLabel:             _editorIsParameter ? _editorDialogFact.units : ""
                            showUnits:              unitsLabel.length > 0
                            activeFocusBorderColor: _accentGreen
                            fieldTextColor:         _titleColor
                            inputMethodHints:       (_editorIsParameter && (_editorDialogFact.typeIsString || ScreenTools.isiOS))
                                                    ? Qt.ImhNone
                                                    : Qt.ImhFormattedNumbersOnly
                            visible:                parameterManualEntry.checked
                                                    || (!_editorShowCombo
                                                        && _editorDialogFact.bitmaskStrings.length === 0)
                        }

                        QGCComboBox {
                            id:               parameterFactCombo
                            Layout.fillWidth: true
                            model:            _editorIsParameter ? _editorDialogFact.enumStrings : []
                            visible:          _editorShowCombo && !parameterManualEntry.checked

                            onCurrentIndexChanged: {
                                if (_editorIsParameter && currentIndex >= 0 && currentIndex < model.length)
                                    parameterValueField.text = _editorDialogFact.enumValues[currentIndex]
                            }
                        }

                        ColumnLayout {
                            id:               parameterBitmaskColumn
                            Layout.fillWidth: true
                            spacing:          ScreenTools.defaultFontPixelHeight * 0.35
                            visible:          _editorIsParameter
                                              && _editorDialogFact.bitmaskStrings.length > 0
                                              && !parameterManualEntry.checked

                            Repeater {
                                id:    parameterBitmaskRepeater
                                model: _editorIsParameter ? _editorDialogFact.bitmaskStrings : []

                                QGCCheckBox {
                                    Layout.fillWidth:     true
                                    text:                 modelData
                                    textColor:            _titleColor
                                    uncheckedBorderColor: _accentGreen
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing:          _controlSpacing

                            QGCLabel {
                                text:    qsTr("Min: ") + (_editorIsParameter ? _editorDialogFact.minString : "")
                                color:   _bodyColor
                                visible: _editorIsParameter && !_editorDialogFact.minIsDefaultForType
                            }

                            QGCLabel {
                                text:    qsTr("Max: ") + (_editorIsParameter ? _editorDialogFact.maxString : "")
                                color:   _bodyColor
                                visible: _editorIsParameter && !_editorDialogFact.maxIsDefaultForType
                            }

                            QGCLabel {
                                Layout.fillWidth: true
                                text:             qsTr("Default: ") + (_editorAllowDefaultReset
                                                                       ? _editorDialogFact.defaultValueString
                                                                       : "")
                                color:            _bodyColor
                                visible:          _editorAllowDefaultReset
                                elide:            Text.ElideRight
                            }
                        }

                        QGCLabel {
                            Layout.fillWidth: true
                            text:             _editorIsParameter ? _editorDialogFact.longDescription : ""
                            color:            _titleColor
                            wrapMode:         Text.WordWrap
                            visible:          text.length > 0
                        }

                        QGCLabel {
                            Layout.fillWidth: true
                            text:             qsTr("Vehicle reboot required after change")
                            color:            _bodyColor
                            visible:          _editorIsParameter && _editorDialogFact.vehicleRebootRequired
                            wrapMode:         Text.WordWrap
                        }

                        QGCLabel {
                            Layout.fillWidth: true
                            text:             qsTr("Application restart required after change")
                            color:            _bodyColor
                            visible:          _editorIsParameter && _editorDialogFact.qgcRebootRequired
                            wrapMode:         Text.WordWrap
                        }

                        QGCLabel {
                            Layout.fillWidth: true
                            text:             qsTr("Warning: Modifying values while the vehicle is in flight can lead to vehicle instability or vehicle loss. Verify the value carefully before saving.")
                            color:            _bodyColor
                            visible:          _editorIsParameter && _editorDialogFact.componentId !== -1
                            wrapMode:         Text.WordWrap
                        }

                        QGCCheckBox {
                            id:                   parameterForceSave
                            text:                 qsTr("Force save (dangerous!)")
                            textColor:            _titleColor
                            uncheckedBorderColor: _accentGreen
                            visible:              _editorAllowForceSave && parameterValidationError.text.length > 0
                        }

                        QGCCheckBox {
                            id:                   parameterAdvanced
                            text:                 qsTr("Advanced settings")
                            textColor:            _titleColor
                            uncheckedBorderColor: _accentGreen
                            visible:              _showRCToParam
                                                  || _editorShowCombo
                                                  || (_editorIsParameter && _editorDialogFact.bitmaskStrings.length > 0)
                        }

                        QGCCheckBox {
                            id:                   parameterManualEntry
                            text:                 qsTr("Manual Entry")
                            textColor:            _titleColor
                            uncheckedBorderColor: _accentGreen
                            visible:              parameterAdvanced.checked
                                                  && (_editorShowCombo
                                                      || (_editorIsParameter
                                                          && _editorDialogFact.bitmaskStrings.length > 0))
                            onClicked: {
                                if (checked)
                                    parameterValueField.text = _editorDialogFact.valueString
                            }
                        }

                        ParameterCloseButton {
                            Layout.alignment: Qt.AlignLeft
                            text:             qsTr("Set RC to Param")
                            visible:          parameterAdvanced.checked && _showRCToParam
                            onClicked:        parameterRCToParamDialog.createObject(mainWindow).open()
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height:           1
                            color:            _tableLine
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing:          _controlSpacing

                            Item {
                                Layout.fillWidth: true
                            }

                            ParameterCloseButton {
                                text:      qsTr("Reset To Default")
                                visible:   _editorAllowDefaultReset
                                onClicked: resetParameterToDefault()
                            }

                            QGCButton {
                                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10
                                text:                  qsTr("Save")
                                primary:               true
                                backgroundColor:       _accentGreen
                                textColor:              "#FFFFFF"
                                onClicked:              saveParameterEditor()
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: _controlSpacing
                }
            }
        }
    }
}
