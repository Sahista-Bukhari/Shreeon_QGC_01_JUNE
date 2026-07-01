import QtQuick
import QtLocation

import QGroundControl
import QGroundControl.Controls

/// Marker for displaying a mission item on the map
MapQuickItem {
    id: _item

    property var missionItem
    property int sequenceNumber
    property bool eventgeneration

    signal clicked

    anchorPoint.x:  sourceItem.anchorPointX
    anchorPoint.y:  sourceItem.anchorPointY

    sourceItem:
        MissionItemIndexLabel {
        id:                 _label
        checked:            _isCurrentItem
        label:              missionItem.abbreviation
        index:              missionItem.abbreviation.charAt(0) > 'A' && missionItem.abbreviation.charAt(0) < 'z' ? -1 : missionItem.sequenceNumber
        gimbalYaw:          missionItem.missionGimbalYaw
        vehicleYaw:         missionItem.missionVehicleYaw
        showGimbalYaw:      !isNaN(missionItem.missionGimbalYaw)
        showSequenceNumbers: false
        highlightSelected:  true
        onClicked:          _item.clicked()
        opacity:            missionItem.isTakeoffItem ? _item.opacity : 0

        property bool _isCurrentItem:   missionItem ? missionItem.isCurrentItem || missionItem.hasCurrentChildItem : false
    }
}
