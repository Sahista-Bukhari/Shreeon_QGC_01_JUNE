import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.FlyView
import QGroundControl.FlightMap
import QGroundControl.Controls

Item {
    id:     root
    clip:   true

    property bool useSmallFont: true

    property double _ar:                QGroundControl.videoManager.gstreamerEnabled
                                            ? QGroundControl.videoManager.videoSize.width / QGroundControl.videoManager.videoSize.height
                                            : QGroundControl.videoManager.aspectRatio
    property bool   _showGrid:          QGroundControl.settingsManager.videoSettings.gridLines.rawValue
    property var    _dynamicCameras:    globals.activeVehicle ? globals.activeVehicle.cameraManager : null
    property bool   _connected:         globals.activeVehicle ? !globals.activeVehicle.communicationLost : false
    property int    _curCameraIndex:    _dynamicCameras ? _dynamicCameras.currentCamera : 0
    property bool   _isCamera:          _dynamicCameras ? _dynamicCameras.cameras.count > 0 : false
    property var    _camera:            _isCamera ? _dynamicCameras.cameras.get(_curCameraIndex) : null
    property bool   _hasZoom:           _camera && _camera.hasZoom
    property int    _fitMode:           QGroundControl.settingsManager.videoSettings.videoFit.rawValue

    property bool   _isMode_FIT_WIDTH:  _fitMode === 0
    property bool   _isMode_FIT_HEIGHT: _fitMode === 1
    property bool   _isMode_FILL:       _fitMode === 2
    property bool   _isMode_NO_CROP:    _fitMode === 3

    function getWidth() {
        return videoBackground.getWidth()
    }
    function getHeight() {
        return videoBackground.getHeight()
    }

    property double _thermalHeightFactor: 0.85 //-- TODO

    Image {
        id:             noVideo
        anchors.fill:   parent
        source:         "/res/NoVideoBackground.jpg"
        fillMode:       Image.PreserveAspectCrop
        visible:        !QGroundControl.videoManager.decoding

        readonly property bool streamEnabled: QGroundControl.settingsManager.videoSettings.streamEnabled.rawValue

        // Keep the placeholder legible over both bright and dark parts of the image.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Qt.rgba(0.06, 0.08, 0.07, 0.08) }
                GradientStop { position: 1.0; color: Qt.rgba(0.03, 0.04, 0.04, 0.34) }
            }
        }

        Rectangle {
            id:                 noVideoStatus
            anchors.bottom:     parent.bottom
            anchors.bottomMargin: useSmallFont
                                  ? ScreenTools.defaultFontPixelHeight * 0.45
                                  : ScreenTools.defaultFontPixelHeight * 1.5
            anchors.horizontalCenter: parent.horizontalCenter
            width:              useSmallFont
                                ? parent.width - ScreenTools.defaultFontPixelHeight * 0.9
                                : Math.min(parent.width - ScreenTools.defaultFontPixelHeight * 3,
                                           ScreenTools.defaultFontPixelWidth * 34)
            height:             useSmallFont
                                ? ScreenTools.defaultFontPixelHeight * 2.45
                                : ScreenTools.defaultFontPixelHeight * 3.1
            radius:             ScreenTools.defaultFontPixelHeight * 0.48
            color:              "transparent"
            border.width:       1
            border.color:       Qt.rgba(0.86, 0.90, 0.88, 0.48)

            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Qt.rgba(0.10, 0.12, 0.11, 0.70) }
                GradientStop { position: 1.0; color: Qt.rgba(0.035, 0.045, 0.04, 0.54) }
            }

            Rectangle {
                id:                 cameraIconTile
                anchors.left:       parent.left
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                anchors.verticalCenter: parent.verticalCenter
                width:              parent.height * 0.66
                height:             width
                radius:             width * 0.32
                color:              noVideo.streamEnabled
                                    ? Qt.rgba(0, 0.68, 0.36, 0.14)
                                    : Qt.rgba(1, 1, 1, 0.07)
                border.width:       1
                border.color:       noVideo.streamEnabled
                                    ? Qt.rgba(0, 0.82, 0.44, 0.72)
                                    : Qt.rgba(1, 1, 1, 0.30)

                QGCColoredImage {
                    anchors.centerIn: parent
                    width:            parent.width * 0.54
                    height:           width
                    source:           "qrc:/InstrumentValueIcons/camera.svg"
                    color:            noVideo.streamEnabled ? "#00d26f" : "#b9b9b9"
                    fillMode:         Image.PreserveAspectFit
                }
            }

            Column {
                anchors.left:           cameraIconTile.right
                anchors.leftMargin:     ScreenTools.defaultFontPixelWidth
                anchors.right:          statusDot.left
                anchors.rightMargin:    ScreenTools.defaultFontPixelWidth
                anchors.verticalCenter: parent.verticalCenter
                spacing:                -1

                QGCLabel {
                    text:           qsTr("CAMERA FEED")
                    color:          Qt.rgba(1, 1, 1, 0.62)
                    font.bold:      true
                    font.pointSize: useSmallFont
                                    ? Math.max(6, ScreenTools.smallFontPointSize - 2)
                                    : ScreenTools.smallFontPointSize
                }

                QGCLabel {
                    id:                 noVideoLabel
                    width:              parent.width
                    text:               noVideo.streamEnabled ? qsTr("Waiting for video") : qsTr("Video disabled")
                    font.bold:          true
                    color:              "white"
                    font.pointSize:     useSmallFont ? ScreenTools.smallFontPointSize : ScreenTools.largeFontPointSize
                    elide:              Text.ElideRight
                }
            }

            Rectangle {
                id:                 statusDot
                anchors.right:      parent.right
                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 1.1
                anchors.verticalCenter: parent.verticalCenter
                width:              Math.max(6, ScreenTools.smallFontPixelHeight * 0.42)
                height:             width
                radius:             width / 2
                color:              noVideo.streamEnabled ? "#00d26f" : "#9b9b9b"

                SequentialAnimation on opacity {
                    running:    noVideo.visible && noVideo.streamEnabled
                    loops:      Animation.Infinite
                    NumberAnimation { to: 0.32; duration: 800; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
                }
            }
        }
    }

    Rectangle {
        id:             videoBackground
        anchors.fill:   parent
        color:          "black"
        visible:        QGroundControl.videoManager.decoding
        function getWidth() {
            if(_ar != 0.0){
                if(_isMode_FIT_HEIGHT
                        || (_isMode_FILL && (root.width/root.height < _ar))
                        || (_isMode_NO_CROP && (root.width/root.height > _ar))){
                    // This return value has different implications depending on the mode
                    // For FIT_HEIGHT and FILL
                    //    makes so the video width will be larger than (or equal to) the screen width
                    // For NO_CROP Mode
                    //    makes so the video width will be smaller than (or equal to) the screen width
                    return root.height * _ar
                }
            }
            return root.width
        }
        function getHeight() {
            if(_ar != 0.0){
                if(_isMode_FIT_WIDTH
                        || (_isMode_FILL && (root.width/root.height > _ar))
                        || (_isMode_NO_CROP && (root.width/root.height < _ar))){
                    // This return value has different implications depending on the mode
                    // For FIT_WIDTH and FILL
                    //    makes so the video height will be larger than (or equal to) the screen height
                    // For NO_CROP Mode
                    //    makes so the video height will be smaller than (or equal to) the screen height
                    return root.width * (1 / _ar)
                }
            }
            return root.height
        }
        Component {
            id: videoBackgroundComponent
            QGCVideoBackground {
                id:             videoContent
                objectName:     "videoContent"

                Connections {
                    target: QGroundControl.videoManager
                    function onImageFileChanged(filename) {
                        videoContent.grabToImage(function(result) {
                            if (!result.saveToFile(filename)) {
                                console.error('Error capturing video frame');
                            }
                        });
                    }
                }

                Rectangle {
                    color:  Qt.rgba(1,1,1,0.5)
                    height: parent.height
                    width:  1
                    x:      parent.width * 0.33
                    visible: _showGrid && !QGroundControl.videoManager.fullScreen
                }
                Rectangle {
                    color:  Qt.rgba(1,1,1,0.5)
                    height: parent.height
                    width:  1
                    x:      parent.width * 0.66
                    visible: _showGrid && !QGroundControl.videoManager.fullScreen
                }
                Rectangle {
                    color:  Qt.rgba(1,1,1,0.5)
                    width:  parent.width
                    height: 1
                    y:      parent.height * 0.33
                    visible: _showGrid && !QGroundControl.videoManager.fullScreen
                }
                Rectangle {
                    color:  Qt.rgba(1,1,1,0.5)
                    width:  parent.width
                    height: 1
                    y:      parent.height * 0.66
                    visible: _showGrid && !QGroundControl.videoManager.fullScreen
                }
            }
        }
        Loader {
            // GStreamer is causing crashes on Lenovo laptop OpenGL Intel drivers. In order to workaround this
            // we don't load a QGCVideoBackground object when video is disabled. This prevents any video rendering
            // code from running. Hence the Loader to completely remove it.
            height:             parent.getHeight()
            width:              parent.getWidth()
            anchors.centerIn:   parent
            visible:            QGroundControl.videoManager.decoding
            sourceComponent:    videoBackgroundComponent

            property bool videoDisabled: QGroundControl.settingsManager.videoSettings.videoSource.rawValue === QGroundControl.settingsManager.videoSettings.disabledVideoSource
        }

        //-- Thermal Image
        Item {
            id:                 thermalItem
            width:              height * QGroundControl.videoManager.thermalAspectRatio
            height:             _camera ? (_camera.thermalMode === MavlinkCameraControl.THERMAL_FULL ? parent.height : (_camera.thermalMode === MavlinkCameraControl.THERMAL_PIP ? ScreenTools.defaultFontPixelHeight * 12 : parent.height * _thermalHeightFactor)) : 0
            anchors.centerIn:   parent
            visible:            QGroundControl.videoManager.hasThermal && _camera.thermalMode !== MavlinkCameraControl.THERMAL_OFF
            function pipOrNot() {
                if(_camera) {
                    if(_camera.thermalMode === MavlinkCameraControl.THERMAL_PIP) {
                        anchors.centerIn    = undefined
                        anchors.top         = parent.top
                        anchors.topMargin   = mainWindow.header.height + (ScreenTools.defaultFontPixelHeight * 0.5)
                        anchors.left        = parent.left
                        anchors.leftMargin  = ScreenTools.defaultFontPixelWidth * 12
                    } else {
                        anchors.top         = undefined
                        anchors.topMargin   = undefined
                        anchors.left        = undefined
                        anchors.leftMargin  = undefined
                        anchors.centerIn    = parent
                    }
                }
            }
            Connections {
                target:                 _camera
                function onThermalModeChanged() { thermalItem.pipOrNot() }
            }
            onVisibleChanged: {
                thermalItem.pipOrNot()
            }
            QGCVideoBackground {
                id:             thermalVideo
                objectName:     "thermalVideo"
                anchors.fill:   parent
                opacity:        _camera ? (_camera.thermalMode === MavlinkCameraControl.THERMAL_BLEND ? _camera.thermalOpacity / 100 : 1.0) : 0
            }
        }
        //-- Zoom
        PinchArea {
            id:             pinchZoom
            enabled:        _hasZoom
            anchors.fill:   parent
            onPinchStarted: pinchZoom.zoom = 0
            onPinchUpdated: {
                if(_hasZoom) {
                    var z = 0
                    if(pinch.scale < 1) {
                        z = Math.round(pinch.scale * -10)
                    } else {
                        z = Math.round(pinch.scale)
                    }
                    if(pinchZoom.zoom != z) {
                        _camera.stepZoom(z)
                    }
                }
            }
            property int zoom: 0
        }
    }
}
