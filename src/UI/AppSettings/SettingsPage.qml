import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

Item {
    id: root

    default property alias contentItem: mainLayout.data

    QGCFlickable {
        anchors.fill:   parent
        contentWidth:   width
        contentHeight:  mainLayout.height

        ColumnLayout {
            id:         mainLayout
            x:          Math.max(0, root.width / 2 - width / 2)
            // Wider than the old ~50ch panel — use most of the available page width
            width:      Math.max(implicitWidth,
                                 Math.min(root.width - ScreenTools.defaultFontPixelWidth * 6,
                                          root.width * 0.80))
            spacing:    ScreenTools.defaultFontPixelHeight
        }
    }
}
