import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

Item {
    id:         _root
    width:      ScreenTools.defaultFontPixelWidth * 7
    height:     Math.min(maxHeight, toolStripColumn.height + (flickable.anchors.margins * 2))

    property alias  model:              repeater.model
    property real   maxHeight           ///< Maximum height for control, determines whether text is hidden to make control shorter
    property var    fontSize:           ScreenTools.smallFontPointSize
    property bool   dropLeft:           false   ///< If true, dropdown panels appear to the left of the toolbar
    property var    glassBackgroundSource: null

    property var _dropPanel: dropPanel
    readonly property real _stripRadius: ScreenTools.defaultFontPixelWidth / 2

    LiquidGlassSurface {
        anchors.fill: parent
        backgroundSource: _root.glassBackgroundSource
        cornerRadius: _root._stripRadius
        blurAmount: 18
        tintColor: Qt.rgba(0.07, 0.09, 0.09, 0.30)
        rimColor: Qt.rgba(1, 1, 1, 0.26)
        accentColor: Qt.rgba(0.14, 0.69, 0.36, 0.08)
        showGlint: false
    }

    function simulateClick(buttonIndex) {
        var button = toolStripColumn.children[buttonIndex]
        if (button.checkable) {
            button.checked = !button.checked
        }
        button.clicked()
    }

    signal dropped(int index)

    DeadMouseArea {
        anchors.fill: parent
    }

    QGCFlickable {
        id:                 flickable
        anchors.margins:    ScreenTools.defaultFontPixelWidth * 0.4
        anchors.fill:       parent
        contentHeight:      toolStripColumn.height
        flickableDirection: Flickable.VerticalFlick
        clip:               true

        Column {
            id:             toolStripColumn
            anchors.left:   parent.left
            anchors.right:  parent.right
            spacing:        ScreenTools.defaultFontPixelWidth * 0.25

            Repeater {
                id: repeater

                ToolStripHoverButton {
                    id:                 buttonTemplate
                    anchors.left:       toolStripColumn.left
                    anchors.right:      toolStripColumn.right
                    height:             width
                    radius:             ScreenTools.defaultFontPixelWidth / 2
                    fontPointSize:      _root.fontSize
                    toolStripAction:    modelData
                    dropPanel:          _dropPanel
                    buttonIndex:        index
                    onDropped: (index) => _root.dropped(index)

                    onCheckedChanged: {
                        // We deal with exclusive check state manually since usinug autoExclusive caused all sorts of crazt problems
                        if (checked) {
                            for (var i=0; i<repeater.count; i++) {
                                if (i != index) {
                                    var button = repeater.itemAt(i)
                                    if (button && button.checked) {
                                        button.checked = false
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    ToolStripDropPanel {
        id:         dropPanel
        toolStrip:  _root
    }
}
