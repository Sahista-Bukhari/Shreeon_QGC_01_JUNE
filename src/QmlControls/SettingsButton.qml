import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls

Button {
    id:             control
    padding:        ScreenTools.defaultFontPixelWidth * 0.75
    hoverEnabled:   !ScreenTools.isMobile
    autoExclusive:  true
    icon.color:     textColor
    implicitWidth:  200
    implicitHeight: 60

    // Hover/selection highlight tuning
    property real hoverInset:       ScreenTools.defaultFontPixelWidth * 0.5
    property real selectedInset:    ScreenTools.defaultFontPixelWidth * 0.2
    property real highlightRadius:  25
    property real hoverOpacity:     0.15
    property real selectedOpacity:  1.0


    property color textColor: checked || pressed ? qgcPal.buttonHighlightText : qgcPal.buttonText

    QGCPalette {
        id:                 qgcPal
        colorGroupEnabled:  control.enabled
    }

    background: Rectangle {
        anchors.fill:    parent
        anchors.margins: checked || pressed ? control.selectedInset : control.hoverInset
        color:           qgcPal.buttonHighlight
        opacity:         checked || pressed ? control.selectedOpacity
                                           : enabled && hovered ? control.hoverOpacity : 0
        radius:          control.highlightRadius
    }

    contentItem: RowLayout {
        spacing: ScreenTools.defaultFontPixelWidth

        QGCColoredImage {
            Layout.leftMargin: ScreenTools.defaultFontPixelWidth *2
            source: control.icon.source
            color:  control.icon.color
            width:  ScreenTools.defaultFontPixelHeight
            height: ScreenTools.defaultFontPixelHeight
        }
        QGCLabel {
            id:                     displayText
            Layout.fillWidth:       true
            text:                   control.text
            color:                  control.textColor
            horizontalAlignment:    QGCLabel.AlignLeft
        }
    }
}
