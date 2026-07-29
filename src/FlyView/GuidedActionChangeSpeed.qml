import QGroundControl
import QGroundControl.FlyView

GuidedToolStripAction {
    text:       _guidedController.changeSpeedTitle
    iconSource: "/res/speed.svg"
    visible:    _guidedController.showChangeSpeed
    enabled:    _guidedController.showChangeSpeed
    actionID:   _guidedController.actionChangeSpeed
}
