import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtCore

import QGroundControl
import QGroundControl.Controls

Item {
    property Window window

    property bool _enabled: !ScreenTools.isMobile && !ScreenTools.fakeMobile && QGroundControl.corePlugin.options.enableSaveMainWindowPosition

    Settings {
        id:         s
        category:   "MainWindowState"

        property int x
        property int y
        property int width
        property int height
        property int visibility
    }

    function _setDefaultDesktopWindowSize() {
        window.width = Math.min(800, Screen.width)
        window.height = Math.min(400, Screen.height)
    }

    Component.onCompleted: {
        if (ScreenTools.fakeMobile) {
            window.width = ScreenTools.screenWidth
            window.height = ScreenTools.screenHeight
        } else if (ScreenTools.isMobile) {
            window.showFullScreen();
        } else if (QGroundControl.corePlugin.options.enableSaveMainWindowPosition) {
            window.minimumWidth = Math.min(800, Screen.width)
            window.minimumHeight = Math.min(400, Screen.height)
            if (s.width && s.height) {
                // A window size saved on a larger monitor must not overflow a
                // compact 800x400 display.
                window.width = Math.min(s.width, Screen.width)
                window.height = Math.min(s.height, Screen.height)
                window.x = Math.max(0, Math.min(s.x, Screen.width - window.width))
                window.y = Math.max(0, Math.min(s.y, Screen.height - window.height))
                window.visibility = s.visibility
            } else {
                _setDefaultDesktopWindowSize()
            }
        } else {
            _setDefaultDesktopWindowSize()
        }
    }

    Connections {
        target:                         window
        function onXChanged()           { if(_enabled) saveSettingsTimer.restart() }
        function onYChanged()           { if(_enabled) saveSettingsTimer.restart() }
        function onWidthChanged()       { if(_enabled) saveSettingsTimer.restart() }
        function onHeightChanged()      { if(_enabled) saveSettingsTimer.restart() }
        function onVisibilityChanged()  { if(_enabled) saveSettingsTimer.restart() }
    }

    Timer {
        id:             saveSettingsTimer
        interval:       500
        repeat:         false
        onTriggered:    saveSettings()
    }

    function saveSettings() {
        if (_enabled) {
            switch(window.visibility) {
            case ApplicationWindow.Windowed:
                s.x = window.x;
                s.y = window.y;
                s.width = window.width;
                s.height = window.height;
                s.visibility = window.visibility;
                break;
            case ApplicationWindow.FullScreen:
                s.visibility = window.visibility;
                break;
            case ApplicationWindow.Maximized:
                s.visibility = window.visibility;
                break;
            }
        }
    }
}
