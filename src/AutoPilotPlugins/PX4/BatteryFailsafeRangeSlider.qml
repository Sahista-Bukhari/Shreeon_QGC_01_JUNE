import QtQuick
import QtQuick.Effects

import QGroundControl
import QGroundControl.Controls

Item {
    id: root

    property Fact warnFact
    property Fact critFact
    property Fact emergFact

    readonly property color warnColor:   "#F2C94C"
    readonly property color failColor:   "#F2994A"
    readonly property color emergColor:  "#EB5757"
    readonly property color labelColor:  qgcPal.globalTheme === QGCPalette.Dark ? "#AEAEB2" : "#3A3A3C"

    property real warnVal:  warnFact  ? warnFact.value  : 15
    property real critVal:  critFact  ? critFact.value  : 7
    property real emergVal: emergFact ? emergFact.value : 5

    property bool _dragging: false

    readonly property real _rangeMin: 0
    readonly property real _rangeMax: Math.max(22, warnVal)
    readonly property real _handleSize: ScreenTools.defaultFontPixelHeight * 1.2
    readonly property real _trackHeight: ScreenTools.defaultFontPixelHeight * 0.22
    readonly property real _bubbleH: ScreenTools.defaultFontPixelHeight * 1.45
    readonly property real _labelH: ScreenTools.defaultFontPixelHeight * 1.35
    readonly property real _minGap: 1

    implicitHeight: _bubbleH + ScreenTools.defaultFontPixelHeight * 0.35 + _handleSize + _labelH
    implicitWidth: ScreenTools.defaultFontPixelWidth * 40

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    function _clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, v))
    }

    function _roundPct(v) {
        return Math.round(v)
    }

    function _factMin(fact, fallback) {
        return fact && !fact.minIsDefaultForType ? fact.min : fallback
    }

    function _factMax(fact, fallback) {
        return fact && !fact.maxIsDefaultForType ? fact.max : fallback
    }

    function valueAt(x) {
        var travel = Math.max(1, track.width - _handleSize)
        var t = (x - track.x - _handleSize / 2) / travel
        t = _clamp(t, 0, 1)
        return _rangeMax - t * (_rangeMax - _rangeMin)
    }

    function xAt(v) {
        var travel = Math.max(1, track.width - _handleSize)
        var t = (_rangeMax - v) / Math.max(0.001, _rangeMax - _rangeMin)
        t = _clamp(t, 0, 1)
        return track.x + t * travel
    }

    function setWarn(v) {
        var lo = Math.max(_factMin(warnFact, 12), critVal + _minGap)
        var hi = _factMax(warnFact, 50)
        warnVal = _clamp(_roundPct(v), lo, hi)
        commitTimer.restart()
    }

    function setCrit(v) {
        var lo = Math.max(_factMin(critFact, 5), emergVal + _minGap)
        var hi = Math.min(_factMax(critFact, 50), warnVal - _minGap)
        critVal = _clamp(_roundPct(v), lo, hi)
        commitTimer.restart()
    }

    function setEmerg(v) {
        var lo = _factMin(emergFact, 3)
        var hi = Math.min(_factMax(emergFact, 50), critVal - _minGap)
        emergVal = _clamp(_roundPct(v), lo, hi)
        commitTimer.restart()
    }

    function _commit() {
        if (warnFact && Math.abs(warnFact.value - warnVal) > 0.01)
            warnFact.value = warnVal
        if (critFact && Math.abs(critFact.value - critVal) > 0.01)
            critFact.value = critVal
        if (emergFact && Math.abs(emergFact.value - emergVal) > 0.01)
            emergFact.value = emergVal
    }

    Timer {
        id:             commitTimer
        interval:       400
        repeat:         false
        onTriggered:    root._commit()
    }

    Connections {
        target: warnFact
        function onValueChanged() {
            if (!root._dragging)
                root.warnVal = warnFact.value
        }
    }

    Connections {
        target: critFact
        function onValueChanged() {
            if (!root._dragging)
                root.critVal = critFact.value
        }
    }

    Connections {
        target: emergFact
        function onValueChanged() {
            if (!root._dragging)
                root.emergVal = emergFact.value
        }
    }

    Rectangle {
        id:                     trackGlow
        anchors.fill:           track
        anchors.leftMargin:     -ScreenTools.defaultFontPixelHeight * 0.06
        anchors.rightMargin:    -ScreenTools.defaultFontPixelHeight * 0.06
        anchors.topMargin:      -ScreenTools.defaultFontPixelHeight * 0.04
        anchors.bottomMargin:   -ScreenTools.defaultFontPixelHeight * 0.14
        radius:                 height / 2
        color:                  Qt.rgba(0, 0, 0, 0.10)
        z:                      0
        layer.enabled:          true
        layer.smooth:           true
        layer.effect: MultiEffect {
            shadowEnabled:          true
            shadowColor:            "#000000"
            shadowOpacity:          0.28
            shadowBlur:             1.0
            shadowScale:            1.22
            shadowHorizontalOffset: 0
            shadowVerticalOffset:   ScreenTools.defaultFontPixelHeight * 0.22
        }
    }

    Rectangle {
        id:     track
        anchors.left:           parent.left
        anchors.right:          parent.right
        anchors.leftMargin:     ScreenTools.defaultFontPixelWidth * 1.2
        anchors.rightMargin:    ScreenTools.defaultFontPixelWidth * 1.2
        anchors.top:            parent.top
        anchors.topMargin:      root._bubbleH + ScreenTools.defaultFontPixelHeight * 0.28 + (root._handleSize - root._trackHeight) / 2
        height:                 root._trackHeight
        radius:                 height / 2
        color:                  root.emergColor
        clip:                   true
        z:                      1

        Rectangle {
            width:  Math.max(0, warnHandle.x + root._handleSize / 2 - track.x)
            height: parent.height
            color:  root.warnColor
        }

        Rectangle {
            x:      Math.max(0, warnHandle.x + root._handleSize / 2 - track.x)
            width:  Math.max(0, (critHandle.x + root._handleSize / 2) - (warnHandle.x + root._handleSize / 2))
            height: parent.height
            color:  root.failColor
        }
    }

    component PctBubble: Item {
        property color bubbleColor
        property string bubbleText
        width:  bubbleBox.width
        height: root._bubbleH

        Rectangle {
            id:                         bubbleBox
            anchors.top:                parent.top
            anchors.horizontalCenter:   parent.horizontalCenter
            width:                      bubbleLabel.implicitWidth + ScreenTools.defaultFontPixelWidth * 1.8
            height:                     root._bubbleH * 0.78
            radius:                     height * 0.42
            color:                      bubbleColor
            z:                          1
            layer.enabled:              true
            layer.smooth:               true
            layer.effect: MultiEffect {
                shadowEnabled:          true
                shadowColor:            "#000000"
                shadowOpacity:          0.22
                shadowBlur:             0.9
                shadowScale:            1.12
                shadowHorizontalOffset: 0
                shadowVerticalOffset:   ScreenTools.defaultFontPixelHeight * 0.12
            }

            QGCLabel {
                id:                     bubbleLabel
                anchors.centerIn:       parent
                text:                   bubbleText
                color:                  "white"
                font.bold:              true
                font.family:            ScreenTools.normalFontFamily
            }
        }

        Rectangle {
            width:                      ScreenTools.defaultFontPixelWidth * 0.75
            height:                     width
            rotation:                   45
            color:                      bubbleColor
            z:                          0
            anchors.horizontalCenter:   parent.horizontalCenter
            anchors.top:                bubbleBox.bottom
            anchors.topMargin:          -height * 0.55
        }
    }

    component RangeHandle: Item {
        id: handleRoot
        property color handleColor
        property int   handleIndex
        width:  root._handleSize
        height: root._handleSize

        Rectangle {
            anchors.centerIn: parent
            width:            parent.width * 0.82
            height:           width
            radius:           width / 2
            color:            handleRoot.handleColor
            border.width:     3
            border.color:     "white"
            layer.enabled:    true
            layer.smooth:     true
            layer.effect: MultiEffect {
                shadowEnabled:          true
                shadowColor:            "#000000"
                shadowOpacity:          0.2
                shadowBlur:             0.7
                shadowScale:            1.1
                shadowHorizontalOffset: 0
                shadowVerticalOffset:   ScreenTools.defaultFontPixelHeight * 0.08
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape:  Qt.PointingHandCursor
            preventStealing: true
            onPressed: {
                root._dragging = true
            }
            onPositionChanged: (mouse) => {
                if (!pressed)
                    return
                var x = handleRoot.mapToItem(root, mouse.x, mouse.y).x
                var v = root.valueAt(x)
                if (handleRoot.handleIndex === 0)
                    root.setWarn(v)
                else if (handleRoot.handleIndex === 1)
                    root.setCrit(v)
                else
                    root.setEmerg(v)
            }
            onReleased: {
                root._commit()
                commitTimer.stop()
                root._dragging = false
            }
        }
    }

    PctBubble {
        x:           warnHandle.x + warnHandle.width / 2 - width / 2
        y:           0
        bubbleColor: root.warnColor
        bubbleText:  Math.round(root.warnVal) + "%"
        z:           3
    }

    PctBubble {
        x:           critHandle.x + critHandle.width / 2 - width / 2
        y:           0
        bubbleColor: root.failColor
        bubbleText:  Math.round(root.critVal) + "%"
        z:           4
    }

    PctBubble {
        x:           emergHandle.x + emergHandle.width / 2 - width / 2
        y:           0
        bubbleColor: root.emergColor
        bubbleText:  Math.round(root.emergVal) + "%"
        z:           5
    }

    RangeHandle {
        id:          warnHandle
        x:           root.xAt(root.warnVal)
        y:           root._bubbleH + ScreenTools.defaultFontPixelHeight * 0.28
        handleColor: root.warnColor
        handleIndex: 0
        z:           3
    }

    RangeHandle {
        id:          critHandle
        x:           root.xAt(root.critVal)
        y:           root._bubbleH + ScreenTools.defaultFontPixelHeight * 0.28
        handleColor: root.failColor
        handleIndex: 1
        z:           4
    }

    RangeHandle {
        id:          emergHandle
        x:           root.xAt(root.emergVal)
        y:           root._bubbleH + ScreenTools.defaultFontPixelHeight * 0.28
        handleColor: root.emergColor
        handleIndex: 2
        z:           5
    }

    QGCLabel {
        x:                  track.x + (warnHandle.x + root._handleSize / 2 - track.x) / 2 - width / 2
        y:                  warnHandle.y + warnHandle.height
        width:              implicitWidth
        text:               qsTr("Warn")
        color:              root.labelColor
        font.family:        ScreenTools.normalFontFamily
        font.pointSize:     ScreenTools.smallFontPointSize
        horizontalAlignment: Text.AlignHCenter
    }

    QGCLabel {
        x:                  (warnHandle.x + critHandle.x + root._handleSize) / 2 - width / 2
        y:                  warnHandle.y + warnHandle.height
        text:               qsTr("Failsafe")
        color:              root.labelColor
        font.family:        ScreenTools.normalFontFamily
        font.pointSize:     ScreenTools.smallFontPointSize
    }

    QGCLabel {
        x:                  (critHandle.x + track.x + track.width) / 2 - width / 2
        y:                  warnHandle.y + warnHandle.height
        text:               qsTr("Emergency")
        color:              root.labelColor
        font.family:        ScreenTools.normalFontFamily
        font.pointSize:     ScreenTools.smallFontPointSize
    }
}
