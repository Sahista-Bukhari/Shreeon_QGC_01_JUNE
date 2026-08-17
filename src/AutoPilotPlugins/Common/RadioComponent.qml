import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls
import QGroundControl.VehicleSetup

SetupPage {
    id: radioPage
    pageComponent: pageComponent

    Component {
        id: pageComponent

        RemoteControlCalibration {
            // AUX/PARAM channel maps + Spektrum/CRSF Bind + Copy Trims hidden from Radio page
            additionalSetupComponent: null
        }
    }
}
