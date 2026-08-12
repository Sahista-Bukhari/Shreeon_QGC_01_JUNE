import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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

    readonly property color _pageBackground:    _darkTheme ? qgcPal.window : "#FFFFFF"
    readonly property color _titleColor:        _darkTheme ? "#AEAEB2" : "#1C1C1E"
    readonly property color _bodyColor:         _darkTheme ? "#8E8E93" : "#8E8E93"
    readonly property color _dividerColor:      _darkTheme ? qgcPal.windowShade : "#EFEFEF"
    readonly property color _accentGreen:       "#00a04c"
    readonly property color _cardIdleBorder:    _darkTheme ? qgcPal.windowShade : "#E6E6E6"
    readonly property color _cardIdleFill:      _darkTheme ? qgcPal.window : "#FFFFFF"
    readonly property color _cardSelectedFill:  Qt.rgba(0, 160 / 255, 76 / 255, _darkTheme ? 0.16 : 0.08)
    readonly property color _innerIdleFill:     _darkTheme ? qgcPal.windowShade : "#F4F4F4"
    readonly property color _innerSelectedFill: Qt.rgba(0, 160 / 255, 76 / 255, _darkTheme ? 0.22 : 0.12)
    readonly property color _dataCardFill:      _darkTheme ? qgcPal.windowShade : "#F5F5F5"
    readonly property color _tableLine:         _darkTheme ? qgcPal.windowShade : "#E5E5E5"
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

    readonly property bool _sprayingEnabled: _sprayEnFact !== null
                                             ? Number(_sprayEnFact.value) !== 0
                                             : sprayerSettings.sprayingEnabled

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
    }

    function _reloadParamController() {
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

    component SprinklerDiagram: Canvas {
        id: diagram

        property bool highlightFront: true
        property bool highlightRear:  true
        property bool arrowForward:   true
        property color frameColor:    root._titleColor
        property color arrowColor:    root._accentGreen

        onHighlightFrontChanged: requestPaint()
        onHighlightRearChanged:  requestPaint()
        onArrowForwardChanged:   requestPaint()
        onFrameColorChanged:     requestPaint()
        onWidthChanged:          requestPaint()
        onHeightChanged:         requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var w = width
            var h = height
            var cx = w * 0.50
            var cy = diagram.arrowForward ? h * 0.58 : h * 0.46
            var arm = Math.min(w, h) * 0.26
            var r = Math.min(w, h) * 0.145
            var motors = [
                { x: cx - arm, y: cy - arm, front: true  },
                { x: cx + arm, y: cy - arm, front: true  },
                { x: cx - arm, y: cy + arm, front: false },
                { x: cx + arm, y: cy + arm, front: false }
            ]

            var i
            for (i = 0; i < 4; i++) {
                var m = motors[i]
                if (!(m.front ? diagram.highlightFront : diagram.highlightRear))
                    continue
                ctx.beginPath()
                ctx.fillStyle = "rgba(78, 195, 232, 0.40)"
                ctx.arc(m.x, m.y, r * 1.42, 0, Math.PI * 2)
                ctx.fill()
            }

            ctx.strokeStyle = diagram.frameColor
            ctx.lineWidth = Math.max(2, Math.min(w, h) * 0.045)
            ctx.lineCap = "round"
            ctx.beginPath()
            ctx.moveTo(motors[0].x, motors[0].y)
            ctx.lineTo(motors[3].x, motors[3].y)
            ctx.moveTo(motors[1].x, motors[1].y)
            ctx.lineTo(motors[2].x, motors[2].y)
            ctx.stroke()

            var bw = r * 0.85
            var bh = r * 1.15
            ctx.fillStyle = diagram.frameColor
            ctx.fillRect(cx - bw * 0.5, cy - bh * 0.5, bw, bh)

            for (i = 0; i < 4; i++) {
                ctx.beginPath()
                ctx.fillStyle = diagram.frameColor
                ctx.arc(motors[i].x, motors[i].y, r * 0.26, 0, Math.PI * 2)
                ctx.fill()
            }

            var aw = r * 0.40
            ctx.fillStyle = diagram.arrowColor
            ctx.beginPath()
            if (diagram.arrowForward) {
                var ay = h * 0.08
                ctx.moveTo(cx, ay)
                ctx.lineTo(cx - aw, ay + aw * 1.55)
                ctx.lineTo(cx + aw, ay + aw * 1.55)
            } else {
                var by = h * 0.92
                ctx.moveTo(cx, by)
                ctx.lineTo(cx - aw, by - aw * 1.55)
                ctx.lineTo(cx + aw, by - aw * 1.55)
            }
            ctx.closePath()
            ctx.fill()
        }
    }

    component DirectionRow: RowLayout {
        id: dirRow

        property string description
        property bool highlightFront: false
        property bool highlightRear:  false
        property bool arrowForward:   true

        spacing: ScreenTools.defaultFontPixelWidth * 0.6

        QGCLabel {
            Layout.fillWidth:   true
            Layout.alignment:   Qt.AlignVCenter
            text:               dirRow.description
            color:              root._bodyColor
            wrapMode:           Text.WordWrap
            font.pointSize:     ScreenTools.smallFontPointSize
        }

        SprinklerDiagram {
            Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 5.6
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 5.6
            Layout.alignment:       Qt.AlignVCenter
            highlightFront:         dirRow.highlightFront
            highlightRear:          dirRow.highlightRear
            arrowForward:           dirRow.arrowForward
        }
    }

    component AlternateModeCard: Rectangle {
        id: card

        property bool selected: true

        radius:       root._cardRadius
        color:        selected ? root._cardSelectedFill : root._cardIdleFill
        border.width: 1.5
        border.color: selected ? root._accentGreen : root._cardIdleBorder
        implicitHeight: cardColumn.implicitHeight + ScreenTools.defaultFontPixelHeight * 1.15

        Column {
            id:              cardColumn
            anchors.left:    parent.left
            anchors.right:   parent.right
            anchors.top:     parent.top
            anchors.margins: ScreenTools.defaultFontPixelWidth * 0.95
            spacing:         ScreenTools.defaultFontPixelHeight * 0.5

            Row {
                spacing: ScreenTools.defaultFontPixelWidth * 0.55

                Item {
                    width:  ScreenTools.defaultFontPixelHeight * 1.15
                    height: width
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius:       width / 2
                        color:        "transparent"
                        border.width: card.selected ? 2 : 1.5
                        border.color: card.selected ? root._accentGreen : root._radioIdle
                    }

                    Rectangle {
                        visible:          card.selected
                        anchors.centerIn: parent
                        width:            parent.width * 0.48
                        height:           width
                        radius:           width / 2
                        color:            root._accentGreen
                    }
                }

                QGCLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text:                   qsTr("Alternate Mode")
                    color:                  card.selected ? root._accentGreen : root._titleColor
                    font.bold:              true
                    font.pointSize:         ScreenTools.defaultFontPointSize
                }
            }

            Rectangle {
                width:  parent.width
                height: innerColumn.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.9
                radius: root._cardRadius * 0.75
                color:  card.selected ? root._innerSelectedFill : root._innerIdleFill

                Column {
                    id:              innerColumn
                    anchors.left:    parent.left
                    anchors.right:   parent.right
                    anchors.top:     parent.top
                    anchors.margins: ScreenTools.defaultFontPixelWidth * 0.75
                    spacing:         ScreenTools.defaultFontPixelHeight * 0.55

                    DirectionRow {
                        width:          parent.width
                        description:    qsTr("When flying forward, 2 sprinklers on rear of aircraft spray")
                        highlightFront: false
                        highlightRear:  true
                        arrowForward:   true
                    }

                    DirectionRow {
                        width:          parent.width
                        description:    qsTr("When flying backward, 2 sprinklers on front of aircraft spray")
                        highlightFront: true
                        highlightRear:  false
                        arrowForward:   false
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

                QGCLabel {
                    text:           cell.valueText
                    color:          cell.valueColor
                    font.bold:      true
                    font.pointSize: ScreenTools.mediumFontPointSize
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

            QGCLabel {
                width:          parent.width
                text:           cell.labelText
                color:          root._bodyColor
                wrapMode:       Text.WordWrap
                font.pointSize: ScreenTools.smallFontPointSize
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

        QGCLabel {
            Layout.fillWidth: true
            text:             note
            color:            root._bodyColor
            wrapMode:         Text.WordWrap
            font.pointSize:   ScreenTools.smallFontPointSize
        }
    }

    component HardwareTable: Rectangle {
        id: tableRoot

        property var headers: []   // [{ title, unit, flex }]
        property var rows: []      // [["1","0","0.0"], ...]

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

                            QGCLabel {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text:                     modelData.title
                                color:                    root._titleColor
                                font.bold:                true
                                font.pointSize:           ScreenTools.smallFontPointSize
                            }

                            QGCLabel {
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible:                  modelData.unit && modelData.unit !== ""
                                text:                     modelData.unit ? modelData.unit : ""
                                color:                    root._bodyColor
                                font.pointSize:           ScreenTools.smallFontPointSize * 0.9
                            }
                        }
                    }
                }
            }

            Repeater {
                model: tableRoot.rows

                Row {
                    id:     dataRow
                    width:  tableCol.width
                    height: tableRoot._rowH

                    property var rowValues: modelData

                    Repeater {
                        model: tableRoot.headers.length

                        Rectangle {
                            width:  tableRoot._colWidth(tableRoot.headers[index].flex)
                            height: parent.height
                            color:  root._cardIdleFill
                            border.width: 1
                            border.color: root._tableLine

                            QGCLabel {
                                anchors.centerIn: parent
                                text:             dataRow.rowValues[index]
                                color:            root._titleColor
                                font.pointSize:   ScreenTools.defaultFontPointSize
                            }
                        }
                    }
                }
            }
        }
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

            QGCLabel {
                text:           qsTr("Task Settings")
                color:          root._bodyColor
                font.pointSize: ScreenTools.smallFontPointSize
            }

            Column {
                width:   parent.width
                spacing: ScreenTools.defaultFontPixelHeight * 0.35

                RowLayout {
                    width:   parent.width
                    spacing: ScreenTools.defaultFontPixelWidth

                    QGCLabel {
                        Layout.fillWidth: true
                        text:             qsTr("Spraying and Spreading Systems")
                        color:            root._titleColor
                        font.bold:        true
                        font.pointSize:   ScreenTools.defaultFontPointSize
                        wrapMode:         Text.WordWrap
                    }

                    QGCCheckBoxSlider {
                        Layout.alignment: Qt.AlignVCenter
                        checked:          root._sprayingEnabled
                        onClicked:        root._setSprayingEnabled(checked)
                    }
                }

                QGCLabel {
                    width:          parent.width - ScreenTools.defaultFontPixelWidth * 8
                    text:           qsTr("Once Spraying and Spreading Systems are turned off, aircraft is unable to spray or spread. Flight route tasks can still be performed.")
                    color:          root._bodyColor
                    wrapMode:       Text.WordWrap
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }

            SectionDivider { }

            Column {
                width:   parent.width
                spacing: ScreenTools.defaultFontPixelHeight * 0.35

                RowLayout {
                    width:   parent.width
                    spacing: ScreenTools.defaultFontPixelWidth

                    QGCLabel {
                        Layout.fillWidth: true
                        text:             qsTr("Atomized Spray")
                        color:            root._titleColor
                        font.bold:        true
                        font.pointSize:   ScreenTools.defaultFontPointSize
                    }

                    QGCCheckBoxSlider {
                        Layout.alignment: Qt.AlignVCenter
                        checked:          sprayerSettings.atomizedSpray
                        onClicked:        sprayerSettings.atomizedSpray = checked
                    }
                }

                QGCLabel {
                    width:          parent.width - ScreenTools.defaultFontPixelWidth * 8
                    text:           qsTr("When disabled, centrifugal motors will stop working when spraying. Sprinkler will spray liquid jets without atomization.")
                    color:          root._bodyColor
                    wrapMode:       Text.WordWrap
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }

            SectionDivider { }

            QGCLabel {
                width:               parent.width
                text:                qsTr("Sprinkler Operating Mode")
                color:               root._titleColor
                font.bold:           true
                font.pointSize:      ScreenTools.defaultFontPointSize
                horizontalAlignment: Text.AlignHCenter
            }

            AlternateModeCard {
                width:    Math.min(parent.width, Math.max(ScreenTools.defaultFontPixelWidth * 36, parent.width * 0.55))
                selected: true
            }

            SectionDivider { }

            Column {
                width:   parent.width
                spacing: ScreenTools.defaultFontPixelHeight * 0.35

                QGCLabel {
                    text:           qsTr("Management and Calibration")
                    color:          root._bodyColor
                    font.pointSize: ScreenTools.smallFontPointSize
                }

                QGCLabel {
                    text:           qsTr("Spraying System Real-time Data")
                    color:          root._titleColor
                    font.bold:      true
                    font.pointSize: ScreenTools.defaultFontPointSize
                }

                Rectangle {
                    width:  parent.width
                    height: dataGrid.implicitHeight + ScreenTools.defaultFontPixelHeight * 1.8
                    radius: root._cardRadius
                    color:  root._dataCardFill

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

                QGCLabel {
                    text:           qsTr("Pump")
                    color:          root._titleColor
                    font.bold:      true
                    font.pointSize: ScreenTools.largeFontPointSize
                }

                InfoNote {
                    note: qsTr("Pump numbers are located on both sides in bottom of tank")
                }

                HardwareTable {
                    headers: [
                        { title: qsTr("No."), unit: "", flex: 0.18 },
                        { title: qsTr("Rotational Speed"), unit: qsTr("(rev/min)"), flex: 0.50 },
                        { title: qsTr("Flow"), unit: qsTr("(L/min)"), flex: 0.32 }
                    ]
                    rows: [
                        [ "1", "0", "0.0" ],
                        [ "2", "0", "0.0" ]
                    ]
                }
            }

            SectionDivider { }

            Column {
                width:   parent.width
                spacing: ScreenTools.defaultFontPixelHeight * 0.45

                QGCLabel {
                    text:           qsTr("Centrifugal Sprinkler")
                    color:          root._titleColor
                    font.bold:      true
                    font.pointSize: ScreenTools.largeFontPointSize
                }

                InfoNote {
                    note: qsTr("Sprinklers are numbered the same as aircraft arms they are installed on")
                }

                HardwareTable {
                    headers: [
                        { title: qsTr("No."), unit: "", flex: 0.22 },
                        { title: qsTr("Rotational Speed"), unit: qsTr("(rev/min)"), flex: 0.78 }
                    ]
                    rows: [
                        [ "1", "0" ],
                        [ "2", "0" ]
                    ]
                }
            }
        }
    }
}
