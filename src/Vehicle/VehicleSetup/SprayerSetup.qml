import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Rectangle {
    id:     root
    anchors.fill: parent
    color:  _pageBackground

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    readonly property bool _darkTheme: {
        if (typeof mainWindow !== "undefined" && mainWindow)
            return mainWindow.uiThemeMode === mainWindow.themeBlack
        return qgcPal.globalTheme === QGCPalette.Dark
    }

    readonly property color _pageBackground:    _darkTheme ? qgcPal.window : "#F3F4F3"
    readonly property color _titleColor:        _darkTheme ? "#F2F2F2" : "#333333"
    readonly property color _bodyColor:         _darkTheme ? "#B8B8B8" : "#6B6B6B"
    readonly property real  _titlePointSize:    ScreenTools.defaultFontPointSize + 1
    readonly property real  _labelPointSize:    ScreenTools.defaultFontPointSize
    readonly property real  _bodyPointSize:     ScreenTools.smallFontPointSize
    readonly property color _dividerColor:      _darkTheme ? Qt.rgba(1, 1, 1, 0.14) : "#E5E5E5"
    readonly property color _accentGreen:       "#00A651"
    readonly property color _accentGreenPressed:"#008F46"
    readonly property color _cardIdleBorder:    _darkTheme ? Qt.rgba(1, 1, 1, 0.22) : "#D9D9D9"
    readonly property color _cardIdleFill:      _darkTheme ? Qt.rgba(1, 1, 1, 0.06) : "#FFFFFF"
    readonly property color _cardSelectedFill:  Qt.rgba(0, 160 / 255, 76 / 255, _darkTheme ? 0.16 : 0.08)
    readonly property color _innerIdleFill:     _darkTheme ? Qt.rgba(1, 1, 1, 0.10) : "#EEEEEE"
    readonly property color _innerSelectedFill: Qt.rgba(0, 160 / 255, 76 / 255, _darkTheme ? 0.22 : 0.12)
    readonly property color _dataCardFill:      _darkTheme ? Qt.rgba(1, 1, 1, 0.10) : "#EEEEEE"
    readonly property color _tableLine:         _darkTheme ? Qt.rgba(1, 1, 1, 0.14) : "#E5E5E5"
    readonly property color _radioIdle:         "#C7C7CC"
    readonly property real  _pagePad:           ScreenTools.defaultFontPixelWidth * 2.2
    readonly property real  _sectionGap:        ScreenTools.defaultFontPixelHeight * 1.15
    readonly property real  _cardRadius:        ScreenTools.defaultFontPixelWidth * 0.9

    readonly property var  _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    readonly property bool _paramsReady: _activeVehicle
                                         && _activeVehicle.parameterManager
                                         && _activeVehicle.parameterManager.parametersReady

    readonly property real _flowRateLpm: {
        if (!_activeVehicle || !_activeVehicle.tank || !_activeVehicle.tank.flowRateLpm)
            return 0
        var v = Number(_activeVehicle.tank.flowRateLpm.rawValue)
        return isFinite(v) ? v : 0
    }
    readonly property real _payloadKg: {
        if (!_activeVehicle || !_activeVehicle.tank || !_activeVehicle.tank.weightKg)
            return 0
        var v = Number(_activeVehicle.tank.weightKg.rawValue)
        return isFinite(v) ? v : 0
    }
    property real _amountSprayedL: 0
    readonly property string _floatStatus: _payloadKg > 0.15 ? qsTr("Floating") : qsTr("Sunk down")

    property Fact _sprayEnFact: null
    property Fact _sprayNozRateFact: null
    property Fact _sprayPumpRateFact: null
    property Fact _sprayRcNozFact: null
    property Fact _sprayRcPumpFact: null
    property bool _sprayParamsRequested: false

    readonly property bool _sprayingEnabled: _sprayEnFact !== null
                                             ? Number(_sprayEnFact.value) !== 0
                                             : sprayerSettings.sprayingEnabled
    readonly property bool _sprayParamsAvailable: _sprayNozRateFact !== null
                                                  || _sprayPumpRateFact !== null
                                                  || _sprayRcNozFact !== null
                                                  || _sprayRcPumpFact !== null

    Settings {
        id:       sprayerSettings
        category: "SprayerSetup"
        property bool sprayingEnabled: true
        property bool atomizedSpray:   true
        property int  sprinklerMode:   0   // 0 = Alternate
        property real remainingLiquidL: 0
    }

    Loader {
        id: paramControllerLoader
        active: true
        sourceComponent: FactPanelController { }
        onLoaded: root._refreshSprayFacts()
    }

    Connections {
        target: QGroundControl.multiVehicleManager
        function onActiveVehicleChanged(vehicle) { root._reloadParamController() }
        function onParameterReadyVehicleAvailableChanged(ready) { root._refreshSprayFacts() }
    }

    function _lookupFact(name) {
        var controller = paramControllerLoader.item
        if (!controller || !root._paramsReady || !controller.parameterExists(-1, name))
            return null
        return controller.getParameterFact(-1, name, false)
    }

    function _refreshSprayFacts() {
        root._sprayEnFact = root._lookupFact("SPRAY_EN")
        root._sprayNozRateFact = root._lookupFact("SPRAY_NOZ_RATE")
        root._sprayPumpRateFact = root._lookupFact("SPRAY_PUMP_RATE")
        root._sprayRcNozFact = root._lookupFact("SPRAY_RC_NOZ")
        root._sprayRcPumpFact = root._lookupFact("SPRAY_RC_PUMP")
        if (!root._paramsReady || !paramControllerLoader.item)
            return
        var missing = []
        if (!root._sprayNozRateFact)
            missing.push("SPRAY_NOZ_RATE")
        if (!root._sprayPumpRateFact)
            missing.push("SPRAY_PUMP_RATE")
        if (!root._sprayRcNozFact)
            missing.push("SPRAY_RC_NOZ")
        if (!root._sprayRcPumpFact)
            missing.push("SPRAY_RC_PUMP")
        if (!root._sprayEnFact)
            missing.push("SPRAY_EN")
        if (missing.length > 0 && !root._sprayParamsRequested) {
            root._sprayParamsRequested = true
            paramControllerLoader.item.getMissingParameters(missing)
            sprayFactRefreshTimer.restart()
        }
    }

    function _reloadParamController() {
        root._sprayParamsRequested = false
        paramControllerLoader.active = false
        paramControllerLoader.active = true
    }

    function _setEnableDisableFact(fact, enabled) {
        if (!fact)
            return
        var strings = fact.enumStrings
        if (strings && strings.length > 0) {
            var want = enabled ? "enabled" : "disabled"
            for (var i = 0; i < strings.length; i++) {
                if (String(strings[i]).toLowerCase().indexOf(want) >= 0) {
                    fact.value = fact.enumValues[i]
                    return
                }
            }
        }
        fact.value = enabled ? 1 : 0
    }

    function _setSprayingEnabled(enabled) {
        sprayerSettings.sprayingEnabled = enabled
        root._setEnableDisableFact(root._sprayEnFact, enabled)
    }

    function _factNumber(fact) {
        if (!fact)
            return NaN
        var v = Number(fact.value)
        return isFinite(v) ? v : NaN
    }

    function _rateText(fact) {
        var v = root._factNumber(fact)
        return isFinite(v) ? v.toFixed(2) : "—"
    }

    function _rcText(fact) {
        var v = root._factNumber(fact)
        return isFinite(v) ? String(Math.round(v)) : "—"
    }

    function _openSprayParamsDialog() {
        sprayParamsDialogComponent.createObject(mainWindow).open()
    }

    component HeadingLabel: QGCLabel {
        color:          root._titleColor
        font.bold:      true
        font.pointSize: root._titlePointSize
        font.family:    ScreenTools.normalFontFamily
    }

    component SettingLabel: QGCLabel {
        color:          root._titleColor
        font.bold:      false
        font.pointSize: root._labelPointSize
        font.family:    ScreenTools.normalFontFamily
    }

    component BodyLabel: QGCLabel {
        color:          root._bodyColor
        font.bold:      false
        font.pointSize: root._bodyPointSize
        font.family:    ScreenTools.normalFontFamily
        wrapMode:       Text.WordWrap
    }

    component RateRow: Column {
        id: rateRow

        property string title
        property var    fact: null
        property real   localValue: 0.33
        property real   step: 0.01

        readonly property real minVal: (fact && fact.minIsDefaultForType === false) ? Number(fact.min) : 0
        readonly property real maxVal: (fact && fact.maxIsDefaultForType === false) ? Number(fact.max) : 1
        readonly property real current: fact ? Number(fact.value) : localValue

        function setValue(v) {
            var clamped = Math.max(rateRow.minVal, Math.min(rateRow.maxVal, Number(v)))
            clamped = Math.round(clamped * 1000) / 1000
            if (rateRow.fact)
                rateRow.fact.value = clamped
            else
                rateRow.localValue = clamped
        }

        width:   parent.width
        spacing: ScreenTools.defaultFontPixelHeight * 0.28

        SettingLabel {
            text: rateRow.title
        }

        RowLayout {
            width:   parent.width
            spacing: ScreenTools.defaultFontPixelWidth * 0.75

            QGCSlider {
                Layout.fillWidth:  true
                Layout.alignment:  Qt.AlignVCenter
                from:              rateRow.minVal
                to:                rateRow.maxVal
                value:             rateRow.current
                stepSize:          rateRow.step
                onMoved:           rateRow.setValue(value)
            }

            Rectangle {
                Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 13.5
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.75
                Layout.alignment:       Qt.AlignVCenter
                radius:                 height * 0.22
                color:                  root._cardIdleFill
                border.width:           1
                border.color:           root._tableLine

                Row {
                    anchors.fill: parent

                    Item {
                        width:  parent.width / 3
                        height: parent.height

                        QGCLabel {
                            anchors.centerIn: parent
                            text:             "−"
                            color:            root._titleColor
                            font.pointSize:   root._labelPointSize
                            font.bold:        true
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape:  Qt.PointingHandCursor
                            onClicked:    rateRow.setValue(rateRow.current - rateRow.step)
                        }
                    }

                    Item {
                        width:  parent.width / 3
                        height: parent.height

                        QGCLabel {
                            anchors.centerIn:     parent
                            text:                 rateRow.current.toFixed(3)
                            color:                root._titleColor
                            font.pointSize:       root._labelPointSize
                            font.family:          ScreenTools.normalFontFamily
                            horizontalAlignment:  Text.AlignHCenter
                        }
                    }

                    Item {
                        width:  parent.width / 3
                        height: parent.height

                        QGCLabel {
                            anchors.centerIn: parent
                            text:             "+"
                            color:            root._titleColor
                            font.pointSize:   root._labelPointSize
                            font.bold:        true
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape:  Qt.PointingHandCursor
                            onClicked:    rateRow.setValue(rateRow.current + rateRow.step)
                        }
                    }
                }
            }
        }
    }

    component InlineSprayerParams: Rectangle {
        id: paramsPanel

        signal closed()

        color:          root._cardIdleFill
        radius:         ScreenTools.defaultFontPixelWidth * 0.7
        border.width:   1
        border.color:   root._tableLine
        implicitHeight: paramsCol.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.85

        Column {
            id:              paramsCol
            anchors.left:    parent.left
            anchors.right:   parent.right
            anchors.top:     parent.top
            anchors.margins: ScreenTools.defaultFontPixelWidth * 0.85
            spacing:         ScreenTools.defaultFontPixelHeight * 0.85

            RateRow {
                title:      qsTr("Nozzle rate")
                fact:       root._sprayNozRateFact
                localValue: 0.330
            }

            RateRow {
                title:      qsTr("Pump rate")
                fact:       root._sprayPumpRateFact
                localValue: 0.340
            }

            Item {
                width:  parent.width
                height: okButton.height

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter:   parent.verticalCenter
                    anchors.verticalCenterOffset: 2
                    width:   okButton.width
                    height:  okButton.height
                    radius:  okButton.radius
                    color:   "#7A7A7A"
                    opacity: root._darkTheme ? 0.25 : 0.20
                    z:       -1
                }

                Rectangle {
                    id: okButton
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: ScreenTools.defaultFontPixelHeight * 2.15
                    width:  parent.width
                    radius: height / 2
                    color:  okMouse.pressed ? root._accentGreenPressed : root._accentGreen
                    border.width: 0
                    scale:  okMouse.pressed ? 0.96 : 1.0

                    Behavior on scale { NumberAnimation { duration: 50 } }

                    QGCLabel {
                        id:                       okLabel
                        anchors.centerIn:         parent
                        text:                     qsTr("Ok")
                        color:                    "#FFFFFF"
                        font.weight:              Font.DemiBold
                        font.pointSize:           root._labelPointSize
                        font.family:              ScreenTools.normalFontFamily
                        verticalAlignment:        Text.AlignVCenter
                    }

                    MouseArea {
                        id:           okMouse
                        anchors.fill: parent
                        cursorShape:  Qt.PointingHandCursor
                        onClicked:    paramsPanel.closed()
                    }
                }
            }
        }
    }

    component SprayCorner: Item {
        id: corner

        clip: false
        z:    2

        property bool pulsing: false

        signal activated()

        function _resetRings() {
            ring0.opacity = 0; ring0.scale = 1
            ring1.opacity = 0; ring1.scale = 1
            ring2.opacity = 0; ring2.scale = 1
        }

        function stopRipple() {
            pulsing = false
            rippleAnim.stop()
            rippleAnim.running = false
            _resetRings()
        }

        function startRipple() {
            if (pulsing)
                return
            pulsing = true
            rippleAnim.restart()
        }

        Rectangle {
            id: ring0
            anchors.centerIn: parent
            width: parent.width
            height: width
            radius: width / 2
            color: "transparent"
            border.width: Math.max(1.5, parent.width * 0.08)
            border.color: root._accentGreen
            opacity: 0
            scale: 1
            z: -1
        }

        Rectangle {
            id: ring1
            anchors.centerIn: parent
            width: parent.width
            height: width
            radius: width / 2
            color: "transparent"
            border.width: Math.max(1.5, parent.width * 0.08)
            border.color: root._accentGreen
            opacity: 0
            scale: 1
            z: -1
        }

        Rectangle {
            id: ring2
            anchors.centerIn: parent
            width: parent.width
            height: width
            radius: width / 2
            color: "transparent"
            border.width: Math.max(1.5, parent.width * 0.07)
            border.color: root._accentGreen
            opacity: 0
            scale: 1
            z: -1
        }

        Rectangle {
            anchors.fill: parent
            radius:       width / 2
            color:        root._accentGreen
            z:            1
        }

        ParallelAnimation {
            id: rippleAnim
            loops: Animation.Infinite
            SequentialAnimation {
                ParallelAnimation {
                    NumberAnimation { target: ring0; property: "scale"; from: 1; to: 3.4; duration: 900; easing.type: Easing.OutCubic }
                    NumberAnimation { target: ring0; property: "opacity"; from: 0.95; to: 0; duration: 900; easing.type: Easing.OutQuad }
                }
            }
            SequentialAnimation {
                PauseAnimation { duration: 150 }
                ParallelAnimation {
                    NumberAnimation { target: ring1; property: "scale"; from: 1; to: 3.4; duration: 900; easing.type: Easing.OutCubic }
                    NumberAnimation { target: ring1; property: "opacity"; from: 0.8; to: 0; duration: 900; easing.type: Easing.OutQuad }
                }
            }
            SequentialAnimation {
                PauseAnimation { duration: 300 }
                ParallelAnimation {
                    NumberAnimation { target: ring2; property: "scale"; from: 1; to: 3.4; duration: 900; easing.type: Easing.OutCubic }
                    NumberAnimation { target: ring2; property: "opacity"; from: 0.65; to: 0; duration: 900; easing.type: Easing.OutQuad }
                }
            }
        }

        MouseArea {
            anchors.fill:    parent
            anchors.margins: -parent.width * 0.35
            cursorShape:     Qt.PointingHandCursor
            z:               2
            onClicked: {
                if (dirRow.editingParams)
                    dirRow.closeParams()
                else {
                    corner.startRipple()
                    dirRow.editingParams = true
                }
            }
        }
    }

    component DirectionRow: Item {
        id: dirRow

        property string description
        property bool   editingParams: false

        readonly property real _droneSize: ScreenTools.defaultFontPixelHeight * 4.2
        readonly property real _gap:       ScreenTools.defaultFontPixelWidth * 0.8

        function closeParams() {
            editingParams = false
            leftSprayCorner.stopRipple()
            rightSprayCorner.stopRipple()
        }

        onEditingParamsChanged: {
            if (!editingParams) {
                leftSprayCorner.stopRipple()
                rightSprayCorner.stopRipple()
            }
        }

        implicitHeight: Math.max(_droneSize, editingParams ? paramsEditor.implicitHeight : descLabel.implicitHeight)
        height:         implicitHeight

        Behavior on implicitHeight {
            NumberAnimation { duration: 480; easing.type: Easing.OutCubic }
        }

        BodyLabel {
            id:                     descLabel
            x:                      0
            width:                  Math.max(0, parent.width - dirRow._droneSize - dirRow._gap)
            anchors.verticalCenter: parent.verticalCenter
            text:                   dirRow.description
            opacity:                dirRow.editingParams ? 0 : 1
            visible:                !dirRow.editingParams || opacity > 0
            Behavior on opacity {
                NumberAnimation { duration: 360; easing.type: Easing.OutCubic }
            }
        }

        InlineSprayerParams {
            id:               paramsEditor
            x:                dirRow.editingParams
                              ? dirRow._droneSize + dirRow._gap
                              : dirRow._droneSize + dirRow._gap + ScreenTools.defaultFontPixelWidth * 2.2
            width:            Math.max(0, parent.width - (dirRow._droneSize + dirRow._gap))
            y:                dirRow.editingParams ? 0 : ScreenTools.defaultFontPixelHeight * 0.35
            opacity:          dirRow.editingParams ? 1 : 0
            scale:            dirRow.editingParams ? 1 : 0.96
            transformOrigin:  Item.Right
            visible:          dirRow.editingParams || opacity > 0
            enabled:          dirRow.editingParams

            Behavior on opacity {
                NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: 480; easing.type: Easing.OutCubic }
            }
            Behavior on y {
                NumberAnimation { duration: 480; easing.type: Easing.OutCubic }
            }
            Behavior on x {
                NumberAnimation { duration: 480; easing.type: Easing.OutCubic }
            }

            onClosed: dirRow.closeParams()
        }

        Item {
            id: droneIcon
            width:  dirRow._droneSize
            height: dirRow._droneSize
            y:      (parent.height - height) / 2
            x:      dirRow.editingParams ? 0 : Math.max(0, parent.width - width)
            z:      2
            clip:   false

            Behavior on x {
                NumberAnimation { duration: 480; easing.type: Easing.OutCubic }
            }

            QGCColoredImage {
                anchors.fill: parent
                source:       "/res/drone.png"
                fillMode:     Image.PreserveAspectFit
                mipmap:       true
                color:        root._titleColor
            }

            SprayCorner {
                id:     rightSprayCorner
                width:  droneIcon.width * 0.20
                height: width
                x:      droneIcon.width * 0.82 - width / 2
                y:      droneIcon.height * 0.82 - height / 2
                onActivated: dirRow.closeParams()
            }

            SprayCorner {
                id:     leftSprayCorner
                width:  droneIcon.width * 0.20
                height: width
                x:      droneIcon.width * 0.18 - width / 2
                y:      droneIcon.height * 0.82 - height / 2
                onActivated: dirRow.closeParams()
            }
        }
    }

    component AlternateModeCard: Rectangle {
        id: card

        property bool selected: true

        radius:         ScreenTools.defaultFontPixelWidth * 0.75
        color:          root._cardIdleFill
        border.width:   1
        border.color:   root._cardIdleBorder
        implicitHeight: cardColumn.implicitHeight + ScreenTools.defaultFontPixelHeight * 1.2

        Column {
            id:              cardColumn
            anchors.left:    parent.left
            anchors.right:   parent.right
            anchors.top:     parent.top
            anchors.margins: ScreenTools.defaultFontPixelWidth * 1.05
            spacing:         ScreenTools.defaultFontPixelHeight * 0.45

            Row {
                spacing: ScreenTools.defaultFontPixelWidth * 0.55

                Item {
                    width:  ScreenTools.defaultFontPixelHeight * 1.05
                    height: width
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius:       width / 2
                        color:        "transparent"
                        border.width: 1.5
                        border.color: card.selected ? root._accentGreen : root._radioIdle
                    }

                    Rectangle {
                        visible:          card.selected
                        anchors.centerIn: parent
                        width:            parent.width * 0.46
                        height:           width
                        radius:           width / 2
                        color:            root._accentGreen
                    }
                }

                SettingLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text:                   qsTr("Alternate Mode")
                }
            }

            Rectangle {
                width:  parent.width
                height: 1
                color:  root._tableLine
            }

            Rectangle {
                width:  parent.width
                height: innerColumn.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.9
                radius: ScreenTools.defaultFontPixelWidth * 0.75
                color:  root._innerIdleFill
                border.width: 1
                border.color: root._tableLine
                clip:   false

                Column {
                    id:              innerColumn
                    anchors.left:    parent.left
                    anchors.right:   parent.right
                    anchors.top:     parent.top
                    anchors.margins: ScreenTools.defaultFontPixelWidth * 0.85
                    spacing:         ScreenTools.defaultFontPixelHeight * 0.45

                    DirectionRow {
                        width:       parent.width
                        description: qsTr("When flying forward, 2 sprinklers on rear of aircraft spray")
                    }
                }
            }
        }
    }

    component RealtimeDataCell: Item {
        id: cell

        property string valueText
        property string labelText
        property color  valueColor: root._titleColor
        property bool   editable:   false

        signal editClicked()

        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        implicitHeight:   cellColumn.implicitHeight

        Column {
            id:      cellColumn
            width:   parent.width
            spacing: ScreenTools.defaultFontPixelHeight * 0.12

            Row {
                spacing: ScreenTools.defaultFontPixelWidth * 0.35

                SettingLabel {
                    text:  cell.valueText
                    color: cell.valueColor
                }

                QGCColoredImage {
                    visible:                cell.editable
                    anchors.verticalCenter: parent.verticalCenter
                    width:                  ScreenTools.defaultFontPixelHeight * 0.85
                    height:                 width
                    source:                 "/res/pencil.svg"
                    color:                  root._accentGreen
                    fillMode:               Image.PreserveAspectFit
                }
            }

            BodyLabel {
                width: parent.width
                text:  cell.labelText
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled:      cell.editable
            cursorShape:  cell.editable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked:    cell.editClicked()
        }
    }

    component SectionDivider: Rectangle {
        width:  parent ? parent.width : 0
        height: 1
        color:  root._tableLine
    }

    component InfoNote: RowLayout {
        property string note

        width:   parent ? parent.width : 0
        spacing: ScreenTools.defaultFontPixelWidth * 0.4

        QGCColoredImage {
            Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 0.9
            Layout.preferredHeight: Layout.preferredWidth
            Layout.alignment:       Qt.AlignTop
            source:                 "/InstrumentValueIcons/information-outline.svg"
            color:                  root._bodyColor
            fillMode:               Image.PreserveAspectFit
        }

        BodyLabel {
            Layout.fillWidth: true
            text:             note
        }
    }

    component HardwareTable: Rectangle {
        id: tableRoot

        property var headers: []   // [{ title, unit, flex }]
        property var rows: []      // [["1","0","0.0"], ...]

        signal clicked()

        readonly property real _rowH: ScreenTools.defaultFontPixelHeight * 2.15
        readonly property real _headH: ScreenTools.defaultFontPixelHeight * 2.55

        width:          parent ? parent.width : 0
        implicitHeight: tableCol.implicitHeight
        height:         implicitHeight
        color:          root._cardIdleFill
        border.width:   1
        border.color:   root._tableLine

        function _colWidth(flex) {
            var total = 0
            for (var i = 0; i < headers.length; i++)
                total += Number(headers[i].flex)
            if (total <= 0)
                return width / Math.max(1, headers.length)
            return width * (Number(flex) / total)
        }

        Column {
            id:    tableCol
            width: parent.width

            Row {
                width:  parent.width
                height: tableRoot._headH

                Repeater {
                    model: tableRoot.headers

                    Rectangle {
                        width:  tableRoot._colWidth(modelData.flex)
                        height: parent.height
                        color:  root._dataCardFill
                        border.width: 1
                        border.color: root._tableLine

                        Column {
                            anchors.centerIn: parent
                            spacing:          1

                            SettingLabel {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text:                     modelData.title
                            }

                            BodyLabel {
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible:                  modelData.unit && modelData.unit !== ""
                                text:                     modelData.unit ? modelData.unit : ""
                            }
                        }
                    }
                }
            }

            Repeater {
                model: tableRoot.rows

                Item {
                    id:     tableRowItem
                    width:  tableCol.width
                    height: tableRoot._rowH

                    property var rowValues: modelData

                    Row {
                        id:     dataRow
                        anchors.fill: parent

                        Repeater {
                            model: tableRoot.headers.length

                            Rectangle {
                                width:  tableRoot._colWidth(tableRoot.headers[index].flex)
                                height: parent.height
                                color:  root._cardIdleFill
                                border.width: 1
                                border.color: root._tableLine

                                SettingLabel {
                                    anchors.centerIn: parent
                                    text:             tableRowItem.rowValues[index]
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape:  Qt.PointingHandCursor
                        onClicked:    tableRoot.clicked()
                    }
                }
            }
        }
    }

    Timer {
        id:       sprayFactRefreshTimer
        interval: 800
        repeat:   false
        onTriggered: root._refreshSprayFacts()
    }

    Timer {
        interval: 1000
        repeat:   true
        running:  root.visible && root._sprayingEnabled && root._flowRateLpm > 0
        onTriggered: root._amountSprayedL += root._flowRateLpm / 60.0
    }

    Dialog {
        id:     remainingDialog
        title:  qsTr("Remaining Liquid Payload")
        modal:  true
        parent: Overlay.overlay
        x:      Math.round((parent.width - width) / 2)
        y:      Math.round((parent.height - height) / 2)
        standardButtons: Dialog.Ok | Dialog.Cancel

        onAboutToShow: remainingField.text = Number(sprayerSettings.remainingLiquidL).toFixed(2)
        onAccepted: {
            var v = parseFloat(remainingField.text)
            if (isFinite(v) && v >= 0)
                sprayerSettings.remainingLiquidL = v
        }

        QGCTextField {
            id:                 remainingField
            width:              ScreenTools.defaultFontPixelWidth * 18
            numericValuesOnly:  true
            unitsLabel:         qsTr("L")
            showUnits:          true
            placeholderText:    qsTr("Liters")
        }
    }

    Component {
        id: sprayParamsDialogComponent

        QGCPopupDialog {
            title:   qsTr("Sprayer Parameters")
            buttons: Dialog.Ok
            compact: true

            ColumnLayout {
                spacing: ScreenTools.defaultFontPixelHeight * 0.7
                width:   ScreenTools.defaultFontPixelWidth * 42

                BodyLabel {
                    Layout.fillWidth: true
                    visible:          !root._sprayParamsAvailable
                    text:             qsTr("Connect a vehicle with spray parameters to edit these values.")
                }

                Repeater {
                    model: [
                        { fact: root._sprayNozRateFact,  name: "SPRAY_NOZ_RATE",  desc: qsTr("Spray nozzle output rate") },
                        { fact: root._sprayPumpRateFact, name: "SPRAY_PUMP_RATE", desc: qsTr("Spray pump output rate") },
                        { fact: root._sprayRcNozFact,    name: "SPRAY_RC_NOZ",    desc: qsTr("RC AUX channel for nozzle") },
                        { fact: root._sprayRcPumpFact,   name: "SPRAY_RC_PUMP",   desc: qsTr("RC AUX channel for pump") }
                    ]

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing:          ScreenTools.defaultFontPixelHeight * 0.15

                        RowLayout {
                            Layout.fillWidth: true
                            spacing:          ScreenTools.defaultFontPixelWidth

                            SettingLabel {
                                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 16
                                text:                  modelData.name
                            }

                            FactTextField {
                                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10
                                fact:                  modelData.fact
                                visible:               modelData.fact !== null
                                enabled:               modelData.fact !== null
                            }

                            BodyLabel {
                                visible: modelData.fact === null
                                text:    "—"
                            }
                        }

                        BodyLabel {
                            Layout.fillWidth: true
                            text:             modelData.desc
                        }
                    }
                }
            }
        }
    }

    QGCFlickable {
        anchors.fill:       parent
        contentWidth:       width
        contentHeight:      contentColumn.height + ScreenTools.defaultFontPixelHeight
        flickableDirection: Flickable.VerticalFlick
        clip:               true

        Column {
            id:         contentColumn
            x:          root._pagePad
            width:      parent.width - root._pagePad * 2
            topPadding:    ScreenTools.defaultFontPixelHeight * 0.35
            bottomPadding: ScreenTools.defaultFontPixelHeight * 1.2
            spacing:       root._sectionGap

            HeadingLabel {
                text: qsTr("Task Settings")
            }

            Rectangle {
                width:          parent.width
                height:         sprayingSystemColumn.implicitHeight + ScreenTools.defaultFontPixelHeight * 1.25
                radius:         root._cardRadius
                color:          root._cardIdleFill
                border.width:   1
                border.color:   root._cardIdleBorder

                Column {
                    id:              sprayingSystemColumn
                    anchors.left:    parent.left
                    anchors.right:   parent.right
                    anchors.top:     parent.top
                    anchors.margins: ScreenTools.defaultFontPixelWidth * 1.15
                    spacing:         ScreenTools.defaultFontPixelHeight * 0.6

                    RowLayout {
                        width:   parent.width
                        spacing: ScreenTools.defaultFontPixelWidth

                        SettingLabel {
                            Layout.fillWidth: true
                            text:             qsTr("Spraying and Spreading Systems")
                            wrapMode:         Text.WordWrap
                        }

                        QGCCheckBoxSlider {
                            Layout.alignment: Qt.AlignVCenter
                            checked:          root._sprayingEnabled
                            onClicked:        root._setSprayingEnabled(checked)
                        }
                    }

                    Rectangle {
                        width:  parent.width
                        height: 1
                        color:  root._dividerColor
                    }

                    BodyLabel {
                        width: parent.width
                        text:  qsTr("Once Spraying and Spreading Systems are turned off, aircraft is unable to spray or spread. Flight route tasks can still be performed.")
                    }
                }
            }

            Rectangle {
                width:          parent.width
                height:         atomizedSprayColumn.implicitHeight + ScreenTools.defaultFontPixelHeight * 1.25
                radius:         root._cardRadius
                color:          root._cardIdleFill
                border.width:   1
                border.color:   root._cardIdleBorder

                Column {
                    id:              atomizedSprayColumn
                    anchors.left:    parent.left
                    anchors.right:   parent.right
                    anchors.top:     parent.top
                    anchors.margins: ScreenTools.defaultFontPixelWidth * 1.15
                    spacing:         ScreenTools.defaultFontPixelHeight * 0.6

                    RowLayout {
                        width:   parent.width
                        spacing: ScreenTools.defaultFontPixelWidth

                        SettingLabel {
                            Layout.fillWidth: true
                            text:             qsTr("Atomized Spray")
                        }

                        QGCCheckBoxSlider {
                            Layout.alignment: Qt.AlignVCenter
                            checked:          sprayerSettings.atomizedSpray
                            onClicked:        sprayerSettings.atomizedSpray = checked
                        }
                    }

                    Rectangle {
                        width:  parent.width
                        height: 1
                        color:  root._dividerColor
                    }

                    BodyLabel {
                        width: parent.width
                        text:  qsTr("When disabled, centrifugal motors will stop working when spraying. Sprinkler will spray liquid jets without atomization.")
                    }
                }
            }

            HeadingLabel {
                width: parent.width
                text:  qsTr("Sprinkler Operating Mode")
            }

            AlternateModeCard {
                width:    parent.width
                selected: true
            }

            SectionDivider { }

            Column {
                width:   parent.width
                spacing: ScreenTools.defaultFontPixelHeight * 0.35

                HeadingLabel {
                    text: qsTr("Management and Calibration")
                }

                SettingLabel {
                    text: qsTr("Spraying System Real-time Data")
                }

                Rectangle {
                    width:  parent.width
                    height: dataGrid.implicitHeight + ScreenTools.defaultFontPixelHeight * 1.8
                    radius: root._cardRadius
                    color:  root._dataCardFill
                    border.width: 1
                    border.color: root._tableLine

                    GridLayout {
                        id:              dataGrid
                        anchors.left:    parent.left
                        anchors.right:   parent.right
                        anchors.top:     parent.top
                        anchors.margins: ScreenTools.defaultFontPixelWidth * 1.2
                        columns:         3
                        columnSpacing:   ScreenTools.defaultFontPixelWidth * 1.4
                        rowSpacing:      ScreenTools.defaultFontPixelHeight * 1.15

                        RealtimeDataCell {
                            valueText: qsTr("%1 L/min").arg(root._flowRateLpm.toFixed(1))
                            labelText: qsTr("Flow rate")
                        }

                        RealtimeDataCell {
                            valueText: qsTr("%1 L").arg(root._amountSprayedL.toFixed(2))
                            labelText: qsTr("Amount Sprayed")
                        }

                        RealtimeDataCell {
                            valueText:  qsTr("%1 L").arg(Number(sprayerSettings.remainingLiquidL).toFixed(2))
                            labelText:  qsTr("Remaining Liquid Payload")
                            valueColor: root._accentGreen
                            editable:   true
                            onEditClicked: remainingDialog.open()
                        }

                        RealtimeDataCell {
                            valueText: qsTr("%1 kg").arg(root._payloadKg.toFixed(1))
                            labelText: qsTr("Payload in tank")
                        }

                        RealtimeDataCell {
                            valueText: root._floatStatus
                            labelText: qsTr("Float status")
                        }
                    }
                }
            }

            SectionDivider { }

            Column {
                width:   parent.width
                spacing: ScreenTools.defaultFontPixelHeight * 0.45

                HeadingLabel {
                    text: qsTr("Pump")
                }

                InfoNote {
                    note: qsTr("Pump numbers are located on both sides in bottom of tank. Tap a row to edit spray parameters.")
                }

                HardwareTable {
                    headers: [
                        { title: qsTr("No."), unit: "", flex: 0.16 },
                        { title: qsTr("RC Channel"), unit: "", flex: 0.34 },
                        { title: qsTr("Output Rate"), unit: "", flex: 0.50 }
                    ]
                    rows: [
                        [ "1", root._sprayRcPumpFact ? String(Math.round(Number(root._sprayRcPumpFact.value))) : "—",
                          root._sprayPumpRateFact ? Number(root._sprayPumpRateFact.value).toFixed(2) : "—" ],
                        [ "2", root._sprayRcPumpFact ? String(Math.round(Number(root._sprayRcPumpFact.value))) : "—",
                          root._sprayPumpRateFact ? Number(root._sprayPumpRateFact.value).toFixed(2) : "—" ]
                    ]
                    onClicked: root._openSprayParamsDialog()
                }
            }

            SectionDivider { }

            Column {
                width:   parent.width
                spacing: ScreenTools.defaultFontPixelHeight * 0.45

                HeadingLabel {
                    text: qsTr("Centrifugal Sprinkler")
                }

                InfoNote {
                    note: qsTr("Sprinklers are numbered the same as aircraft arms they are installed on. Tap a sprinkler to edit spray parameters.")
                }

                HardwareTable {
                    headers: [
                        { title: qsTr("No."), unit: "", flex: 0.16 },
                        { title: qsTr("RC Channel"), unit: "", flex: 0.34 },
                        { title: qsTr("Output Rate"), unit: "", flex: 0.50 }
                    ]
                    rows: [
                        [ "1", root._sprayRcNozFact ? String(Math.round(Number(root._sprayRcNozFact.value))) : "—",
                          root._sprayNozRateFact ? Number(root._sprayNozRateFact.value).toFixed(2) : "—" ],
                        [ "2", root._sprayRcNozFact ? String(Math.round(Number(root._sprayRcNozFact.value))) : "—",
                          root._sprayNozRateFact ? Number(root._sprayNozRateFact.value).toFixed(2) : "—" ]
                    ]
                    onClicked: root._openSprayParamsDialog()
                }
            }
        }
    }
}
