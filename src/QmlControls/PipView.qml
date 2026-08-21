import QtQuick
import QtQuick.Window
import Qt5Compat.GraphicalEffects

import QGroundControl
import QGroundControl.Controls

Item {
    id:         _root
    width:      _pipSize
    height:     _pipSize * (9/16)
    visible:    item2 && item2.pipState !== item2.pipState.window && show

    property real cornerRadius: 0

    readonly property color _accentColor:  "#00ad5b"
    readonly property color _controlColor: Qt.rgba(0.08, 0.10, 0.09, 0.82)

    property var    item1:                  null    // Required
    property var    item2:                  null    // Optional, may come and go
    property string item1IsFullSettingsKey          // Settings key to save whether item1 was saved in full mode
    property bool   show:                   true

    readonly property string _pipExpandedSettingsKey: "IsPIPVisible"

    property var    _fullItem
    property var    _pipOrWindowItem
    property alias  _windowContentItem: window.contentItem
    property alias  _pipContentItem:    pipContent
    property bool   _isExpanded:        true
    property real   _pipSize:           parent.width * 0.2
    property real   _maxSize:           0.75                // Percentage of parent control size
    property real   _minSize:           0.10
    property bool   _componentComplete: false

    Component.onCompleted: {
        _initForItems()
        _componentComplete = true
    }

    onItem2Changed: _initForItems()

    function showWindow() {
        window.width = _root.width
        window.height = _root.height
        window.show()
    }

    function _initForItems() {
        var item1IsFull = QGroundControl.loadBoolGlobalSetting(item1IsFullSettingsKey, true)
        if (item1 && item2) {
            item1.pipState.state = item1IsFull ? item1.pipState.fullState : item1.pipState.pipState
            item2.pipState.state = item1IsFull ? item2.pipState.pipState : item2.pipState.fullState
            _fullItem = item1IsFull ? item1 : item2
            _pipOrWindowItem = item1IsFull ? item2 : item1
        } else {
            item1.pipState.state = item1.pipState.fullState
            _fullItem = item1
            _pipOrWindowItem = null
        }
        _setPipIsExpanded(QGroundControl.loadBoolGlobalSetting(_pipExpandedSettingsKey, true))
    }

    function _swapPip() {
        var item1IsFull = false
        if (item1.pipState.state === item1.pipState.fullState) {
            item1.pipState.state = item1.pipState.pipState
            item2.pipState.state = item2.pipState.fullState
            _fullItem = item2
            _pipOrWindowItem = item1
            item1IsFull = false
        } else {
            item1.pipState.state = item1.pipState.fullState
            item2.pipState.state = item2.pipState.pipState
            _fullItem = item1
            _pipOrWindowItem = item2
            item1IsFull = true
        }
        QGroundControl.saveBoolGlobalSetting(item1IsFullSettingsKey, item1IsFull)
    }

    function _setPipIsExpanded(isExpanded) {
        QGroundControl.saveBoolGlobalSetting(_pipExpandedSettingsKey, isExpanded)
        _isExpanded = isExpanded
    }

    Window {
        id:         window
        visible:    false
        onClosing: {
            var item = contentItem.children[0]
            if (item) {
                item.pipState.windowAboutToClose()
                item.pipState.state = item.pipState.pipState
            }
        }
    }

    Rectangle {
        id:             pipShadowSource
        anchors.fill:   parent
        visible:        _isExpanded
        radius:         _root.cornerRadius
        color:          Qt.rgba(0.03, 0.04, 0.04, 0.65)
        z:              -1
    }

    DropShadow {
        anchors.fill:       pipShadowSource
        source:             pipShadowSource
        visible:            _isExpanded
        horizontalOffset:   0
        verticalOffset:     4
        radius:             12
        samples:            25
        color:              Qt.rgba(0, 0, 0, 0.62)
        transparentBorder:  true
        z:                  -2
    }

    Item {
        id:             pipContentWrapper
        anchors.fill:   parent
        visible:        _isExpanded

        Item {
            id:             pipContent
            anchors.fill:   parent
            visible:        _isExpanded
            layer.enabled:  _root.cornerRadius > 0
            layer.effect:   OpacityMask {
                maskSource: Rectangle {
                    width:  pipContent.width
                    height: pipContent.height
                    radius: _root.cornerRadius
                }
            }
        }
    }

    MouseArea {
        id:             pipMouseArea
        anchors.fill:   parent
        enabled:        _isExpanded
        preventStealing: true
        hoverEnabled:   true
        onClicked:      _swapPip()
    }

    // Soft glass frame with a restrained green accent.
    Rectangle {
        anchors.fill:   parent
        visible:        _isExpanded
        radius:         _root.cornerRadius
        color:          "transparent"
        border.width:   1
        border.color:   Qt.rgba(1, 1, 1, 0.48)
        z:              1
    }

    Rectangle {
        anchors.left:       parent.left
        anchors.leftMargin: _root.cornerRadius * 0.78
        anchors.bottom:     parent.bottom
        width:              parent.width * 0.22
        height:             2
        visible:            _isExpanded
        radius:             1
        color:              _root._accentColor
        z:                  2
    }

    // MouseArea to drag in order to resize the PiP area
    MouseArea {
        id:                 pipResize
        anchors.fill:       pipResizeIcon
        preventStealing:    true
        cursorShape:        Qt.PointingHandCursor
        enabled:            false // Disabled as per user request

        property real initialX:     0
        property real initialWidth: 0

        onPressed: (mouse) => {
            // Remove the anchor so the our mouse coordinates stay in the same original place for drag tracking
            pipResize.anchors.fill = undefined
            pipResize.initialX = mouse.x
            pipResize.initialWidth = _root.width
        }

        onReleased: pipResize.anchors.fill = pipResizeIcon

        // Drag
        onPositionChanged: (mouse) => {
            if (pipResize.pressed) {
                var parentWidth = _root.parent.width
                var newWidth = pipResize.initialWidth + mouse.x - pipResize.initialX
                if (newWidth < parentWidth * _maxSize && newWidth > parentWidth * _minSize) {
                    _pipSize = newWidth
                }
            }
        }
    }

    // Resize icon
    Image {
        id:             pipResizeIcon
        source:         "/qmlimages/pipResize.svg"
        fillMode:       Image.PreserveAspectFit
        mipmap:         true
        anchors.right:  parent.right
        anchors.top:    parent.top
        visible:        false // Hidden as per user request
        height:         ScreenTools.defaultFontPixelHeight * 2.5
        width:          ScreenTools.defaultFontPixelHeight * 2.5
        sourceSize.height:  height
    }

    // Check min/max constraints on pip size when when parent is resized
    Connections {
        target: _root.parent

        function onWidthChanged() {
            if (!_componentComplete) {
                // Wait until first time setup is done
                return
            }
            var parentWidth = _root.parent.width
            if (_root.width > parentWidth * _maxSize) {
                _pipSize = parentWidth * _maxSize
            } else if (_root.width < parentWidth * _minSize) {
                _pipSize = parentWidth * _minSize
            }
        }
    }

    // Compact glass control group. Keeping both actions together prevents
    // controls from covering opposite sides of the preview.
    Rectangle {
        id:                 pipControls
        anchors.right:      parent.right
        anchors.top:        parent.top
        anchors.margins:    ScreenTools.defaultFontPixelHeight * 0.38
        visible:            _isExpanded && (ScreenTools.isMobile || pipMouseArea.containsMouse)
        width:              pipControlsRow.implicitWidth + ScreenTools.defaultFontPixelWidth * 0.8
        height:             Math.max(28, ScreenTools.defaultFontPixelHeight * 1.42)
        radius:             height / 2
        color:              _root._controlColor
        border.width:       1
        border.color:       Qt.rgba(1, 1, 1, 0.34)
        z:                  3

        Row {
            id:             pipControlsRow
            anchors.centerIn: parent
            height:         parent.height - 4
            spacing:        2

            Item {
                id:             popupPIP
                visible:        !ScreenTools.isMobile
                width:          pipControlsRow.height
                height:         width

                Rectangle {
                    anchors.fill:       parent
                    radius:             width / 2
                    color:              popupMouseArea.containsMouse ? _root._accentColor : "transparent"

                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                Rectangle {
                    x:              parent.width * 0.27
                    y:              parent.height * 0.39
                    width:          parent.width * 0.36
                    height:         parent.height * 0.28
                    radius:         1
                    color:          "transparent"
                    border.width:   1
                    border.color:   "white"
                }

                Rectangle {
                    x:              parent.width * 0.40
                    y:              parent.height * 0.27
                    width:          parent.width * 0.36
                    height:         parent.height * 0.28
                    radius:         1
                    color:          "transparent"
                    border.width:   1
                    border.color:   "white"
                }

                MouseArea {
                    id:             popupMouseArea
                    anchors.fill:   parent
                    hoverEnabled:   true
                    cursorShape:    Qt.PointingHandCursor
                    onClicked:      function(mouse) {
                        mouse.accepted = true
                        _pipOrWindowItem.pipState.state = _pipOrWindowItem.pipState.windowState
                    }
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible:                !ScreenTools.isMobile
                width:                  1
                height:                 parent.height * 0.48
                color:                  Qt.rgba(1, 1, 1, 0.20)
            }

            Item {
                id:             hidePIP
                width:          pipControlsRow.height
                height:         width

                Rectangle {
                    anchors.fill:       parent
                    radius:             width / 2
                    color:              hidePipMouseArea.containsMouse ? _root._accentColor : "transparent"

                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                QGCColoredImage {
                    anchors.centerIn:   parent
                    width:              parent.width * 0.42
                    height:             width
                    source:             "qrc:/InstrumentValueIcons/arrow-thin-left.svg"
                    color:              "white"
                    fillMode:           Image.PreserveAspectFit
                }

                MouseArea {
                    id:             hidePipMouseArea
                    anchors.fill:   parent
                    hoverEnabled:   true
                    cursorShape:    Qt.PointingHandCursor
                    onClicked:      function(mouse) {
                        mouse.accepted = true
                        _root._setPipIsExpanded(false)
                    }
                }
            }
        }
    }

    Rectangle {
        id:                     showPip
        anchors.left :          parent.left
        anchors.bottom:         parent.bottom
        height:                 Math.max(28, ScreenTools.defaultFontPixelHeight * 1.42)
        width:                  height
        radius:                 width / 2
        visible:                !_isExpanded
        color:                  showPipMouseArea.containsMouse ? _root._accentColor : _root._controlColor
        border.width:           1
        border.color:           showPipMouseArea.containsMouse ? "white" : _root._accentColor
        z:                      3

        QGCColoredImage {
            anchors.centerIn:   parent
            width:              parent.width * 0.46
            height:             width
            source:             "qrc:/InstrumentValueIcons/arrow-thin-left.svg"
            mirror:             true
            color:              "white"
            fillMode:           Image.PreserveAspectFit
        }

        MouseArea {
            id:             showPipMouseArea
            anchors.fill:   parent
            hoverEnabled:   true
            cursorShape:    Qt.PointingHandCursor
            onClicked:      _root._setPipIsExpanded(true)
        }

        Behavior on color { ColorAnimation { duration: 140 } }
    }
}
