import QtQuick

import QGroundControl
import QGroundControl.Controls

/// QGC version of ListVIew control that shows horizontal/vertial scroll indicators
ListView {
    id:             root
    boundsBehavior: Flickable.StopAtBounds
    clip:           true

    property color indicatorColor: qgcPal.text
    property bool showScrollIndicators: typeof mainWindow === "undefined"
                                        || mainWindow.activeMissionEditor !== "customMission"

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    Component.onCompleted: {
        if (!showScrollIndicators)
            return
        var indicatorComponent = Qt.createComponent("QGCFlickableScrollIndicator.qml")
        indicatorComponent.createObject(root, { orientation: QGCFlickableScrollIndicator.Horizontal })
        indicatorComponent = Qt.createComponent("QGCFlickableScrollIndicator.qml")
        indicatorComponent.createObject(root, { orientation: QGCFlickableScrollIndicator.Vertical })
    }
}
