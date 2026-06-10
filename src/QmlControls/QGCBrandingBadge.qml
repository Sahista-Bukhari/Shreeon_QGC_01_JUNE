import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import QGroundControl
import QGroundControl.Controls

Item {
    id:             root
    implicitWidth:  mainLayout.width + (_margins * 2)
    implicitHeight: mainLayout.height + (_margins * 1.5)

    property real _margins: ScreenTools.defaultFontPixelHeight / 4

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    Rectangle {
        id:             background
        anchors.fill:   parent
        radius:         ScreenTools.defaultFontPixelHeight / 6
        color:          Qt.rgba(qgcPal.window.r, qgcPal.window.g, qgcPal.window.b, 0.8)
        border.color:   Qt.rgba(qgcPal.windowShade.r, qgcPal.windowShade.g, qgcPal.windowShade.b, 0.7)
        border.width:   1

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width:  background.width
                height: background.height
                radius: background.radius
            }
        }
    }

    // Glassmorphism Blur Effect
    GaussianBlur {
        anchors.fill:   background
        source:         background
        radius:         4
        samples:        8
        transparentBorder: true
        visible:        false // Usually implemented via a background item in FlyView
    }

    RowLayout {
        id:                 mainLayout
        anchors.centerIn:   parent
        spacing:            _margins

        Image {
            id:                     logo
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.8
            Layout.preferredWidth:  Layout.preferredHeight
            source:                 "qrc:/res/QGCLogoFull.svg"
            fillMode:               Image.PreserveAspectFit
            mipmap:                 true
        }

        QGCLabel {
            text:               "Shreeon Technologies"
            font.pointSize:     ScreenTools.defaultFontPointHeight * 0.9
            font.weight:        Font.DemiBold
            color:              qgcPal.text
        }
    }
}
