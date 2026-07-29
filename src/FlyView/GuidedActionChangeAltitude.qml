import QGroundControl
import QGroundControl.FlyView

GuidedToolStripAction {
    text:       _guidedController.changeAltTitle
    iconSource: "/res/altitude.svg"
    visible:    _guidedController.showChangeAlt
    enabled:    _guidedController.showChangeAlt
    actionID:   _guidedController.actionChangeAlt
}
