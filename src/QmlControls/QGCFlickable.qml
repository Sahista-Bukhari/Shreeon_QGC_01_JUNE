import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

/// QGC version of Flickable control (scroll indicators disabled app-wide)
Flickable {
    id:                     root
    boundsBehavior:         Flickable.StopAtBounds
    clip:                   true
    maximumFlickVelocity:   (ScreenTools.realPixelDensity * 25.4) * 8   // About two inches per second

    property color indicatorColor: "#00a04c"
    property bool  showScrollIndicators: false
}
