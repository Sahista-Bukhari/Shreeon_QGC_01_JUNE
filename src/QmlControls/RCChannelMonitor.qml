import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Item {
    id:     _root
    height: monitorColumn.height

    property bool twoColumn: false

    QGCPalette { id: qgcPal; colorGroupEnabled: true }
    readonly property color _titleColor: qgcPal.globalTheme === QGCPalette.Dark ? "#AEAEB2" : "#3A3A3C"
    readonly property color _bodyColor:  qgcPal.globalTheme === QGCPalette.Dark ? "#8E8E93" : "#3A3A3C"

    readonly property int _pwmMin:      800
    readonly property int _pwmMax:      2200
    readonly property int _pwmRange:    _pwmMax - _pwmMin

    RCChannelMonitorController {
        id:             controller
    }

    // Live channel monitor control component
    Component {
        id: channelMonitorDisplayComponent

        Item {
            height: ScreenTools.defaultFontPixelHeight

            property int    rcValue:    1500

            property int            __lastRcValue:      1500
            readonly property int   __rcValueMaxJitter: 2
            property color          __barColor:         qgcPal.windowShade

            // Bar
            Rectangle {
                id:                     bar
                anchors.verticalCenter: parent.verticalCenter
                width:                  parent.width
                height:                 parent.height / 2
                color:                  __barColor
            }

            // Center point
            Rectangle {
                anchors.horizontalCenter:   parent.horizontalCenter
                width:                      ScreenTools.defaultFontPixelWidth / 2
                height:                     parent.height
                color:                      qgcPal.window
            }

            // Indicator
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width:                  parent.height * 0.75
                height:                 width
                x:                      (((reversed ? _pwmMax - rcValue : rcValue - _pwmMin) / _pwmRange) * parent.width) - (width / 2)
                radius:                 width / 2
                color:                  qgcPal.text
                visible:                mapped
            }

            QGCLabel {
                anchors.fill:           parent
                horizontalAlignment:    Text.AlignHCenter
                verticalAlignment:      Text.AlignVCenter
                text:                   qsTr("Not Mapped")
                visible:                !mapped
                color:                  _root._bodyColor
                font.family:            ScreenTools.normalFontFamily
            }

            ColorAnimation {
                id:         barAnimation
                target:     bar
                property:   "color"
                from:       "yellow"
                to:         __barColor
                duration:   1500
            }
        }
    } // Component - channelMonitorDisplayComponent

    GridLayout {
        id:         monitorColumn
        width:      parent.width
        columns:    twoColumn ? 2 : 1

        QGCLabel {
            Layout.columnSpan:  parent.columns
            text:               qsTr("Channel Monitor")
            color:              _root._titleColor
            font.bold:          true
            font.pointSize:     ScreenTools.defaultFontPointSize + 1
            font.family:        ScreenTools.normalFontFamily
        }

        Connections {
            target: controller

            function onChannelValueChanged(channel, rcValue) {
                if (channelMonitorRepeater.itemAt(channel)) {
                    channelMonitorRepeater.itemAt(channel).loader.item.rcValue = rcValue
                }
            }
        }

        Repeater {
            id:     channelMonitorRepeater
            model:  controller.channelCount

            RowLayout {
                // Need this to get to loader from Connections above
                property Item loader: theLoader

                QGCLabel {
                    id:             channelLabel
                    text:           modelData + 1
                    color:          _root._titleColor
                    font.family:    ScreenTools.normalFontFamily
                }

                Loader {
                    id:                 theLoader
                    Layout.fillWidth:   true
                    //height:                 ScreenTools.defaultFontPixelHeight
                    //width:                  parent.width - anchors.leftMargin - ScreenTools.defaultFontPixelWidth
                    sourceComponent:        channelMonitorDisplayComponent

                    property bool mapped:               true
                    readonly property bool reversed:    false
                }
            }
        }
    }
}
