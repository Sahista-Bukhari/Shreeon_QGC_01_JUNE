import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// We implement our own TabBar to get around the fact that QtQuick.Controls TabBar does not
// support hiding tabs. This version supports hiding tabs by setting the visible property
// on the QGCTabButton instances.
RowLayout {
    property int currentIndex: 0

    id: control
    spacing: 0

    property bool _preventCurrentIndexBindingLoop: false

    function _tabButtonChildren() {
        const tabButtons = []
        for (var i = 0; i < control.children.length; i++) {
            const child = control.children[i]
            if (child && child.checkable === true && typeof child.checked === "boolean") {
                tabButtons.push(child)
            }
        }
        return tabButtons
    }

    function _selectCurrentIndexButton() {
        // A queued selection may be discarded while this component is being
        // torn down. Do not call a method on a partially destroyed context.
        if (typeof control._tabButtonChildren !== "function") {
            return
        }

        const tabButtons = control._tabButtonChildren()
        if (tabButtons.length > 0) {
            _preventCurrentIndexBindingLoop = true
            if (control.currentIndex == -1) {
                // No tab selected, select none
                for (var i = 0; i < tabButtons.length; i++) {
                    tabButtons[i].checked = false
                }
            } else {
                const filteredCurrentIndex = Math.min(Math.max(control.currentIndex, 0), tabButtons.length - 1)
                if (tabButtons[filteredCurrentIndex].visible) {
                    tabButtons[filteredCurrentIndex].checked = true
                } else {
                    // We select the first visible tab if the current index is not visible
                    for (var j = 0; j < tabButtons.length; j++) {
                        if (tabButtons[j].visible) {
                            tabButtons[j].checked = true
                            break
                        }
                    }
                }
            }
            _preventCurrentIndexBindingLoop = false
        }
    }

    // Defer child selection until RowLayout has finished updating its visual
    // children. Unlike Qt.callLater, this callback is cancelled automatically
    // when the QGCTabBar is destroyed.
    Timer {
        id: selectCurrentIndexTimer
        interval: 0
        repeat: false
        onTriggered: control._selectCurrentIndexButton()
    }

    Component.onCompleted: _selectCurrentIndexButton()
    onCurrentIndexChanged: _selectCurrentIndexButton()
    onChildrenChanged: selectCurrentIndexTimer.restart()
    onVisibleChildrenChanged: _selectCurrentIndexButton()

    ButtonGroup {
        buttons: control._tabButtonChildren()

        onCheckedButtonChanged: {
            const tabButtons = control._tabButtonChildren()
            for (var i = 0; i < tabButtons.length; i++) {
                if (tabButtons[i] === checkedButton) {
                    control.currentIndex = i
                    break
                }
            }
        }
    }
}
