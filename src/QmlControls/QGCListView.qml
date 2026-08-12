import QtQuick

import QGroundControl
import QGroundControl.Controls

/// QGC version of ListView control (scroll indicators disabled app-wide)
ListView {
    id:             root
    boundsBehavior: Flickable.StopAtBounds
    clip:           true

    property color indicatorColor: qgcPal.text
    property bool showScrollIndicators: false

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }
}
