import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls

Item {
    id: root
    anchors.fill: parent
    readonly property color _green:        "#1FAF5B"
    readonly property color _greenDeep:    "#148A45"
    readonly property color _red:          "#E53935"
    readonly property color _redDeep:      "#C62828"
    readonly property color _white:        "#FFFFFF"
    readonly property real  _margins:      ScreenTools.defaultFontPixelWidth * 1.8
    readonly property real  _topIconSize:  ScreenTools.defaultFontPixelHeight * 1.7
    readonly property real  _panelRadius:  ScreenTools.defaultFontPixelHeight * 0.85
    readonly property real  _bottomBarH:   Math.max(height * 0.17, ScreenTools.defaultFontPixelHeight * 5.4)
    readonly property color _panelFill:    Qt.rgba(1, 1, 1, 0.22)
    readonly property color _panelBorder:  Qt.rgba(1, 1, 1, 0.45)

    property var  _activeVehicle:    QGroundControl.multiVehicleManager.activeVehicle
    property bool _vehicleConnected: _activeVehicle && !_activeVehicle.vehicleLinkManager.communicationLost
    property bool _welcomeAnnouncementPlayed: false

    readonly property string _connectionAlertTitle: qsTr("Device Connection")
    readonly property string _connectionAlertText: _vehicleConnected
                                                   ? qsTr("Device connected successfully.")
                                                   : qsTr("Device not connected.")

    signal startClicked
    signal notificationsClicked
    signal userManualClicked
    signal deviceConnectorClicked

    function resetStartControl() {
        startHost.knobX = startHost.trackPad
        startHost.startOn = false
    }

    function showConnectionNotification() {
        connectionAlertPopup.open()
        root.notificationsClicked()
    }

    function announceWelcomeOnce() {
        if (!root.visible || root._welcomeAnnouncementPlayed) {
            return
        }

        root._welcomeAnnouncementPlayed = true
        welcomeAnnouncementTimer.restart()
    }

    onVisibleChanged: announceWelcomeOnce()
    Component.onCompleted: announceWelcomeOnce()

    Timer {
        id:       welcomeAnnouncementTimer
        interval: 500
        repeat:   false
        onTriggered: QGroundControl.speak(qsTr("Welcome to Shreeon Technologies."))
    }

    // Background photo
    Image {
        id: backgroundImage
        anchors.fill: parent
        source: "qrc:/res/drone_tea_plantation_hires.png"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        mipmap: true
        cache: true
    }

    // Soft white/green atmosphere overlay
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.10) }
            GradientStop { position: 0.45; color: Qt.rgba(0.12, 0.55, 0.32, 0.10) }
            GradientStop { position: 1.0; color: Qt.rgba(0.06, 0.35, 0.20, 0.38) }
        }
    }

    // Top bar — logo + icons only
    Item {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: root._margins
        anchors.rightMargin: root._margins
        anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.85
        height: root._topIconSize * 1.2
        z: 5

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: ScreenTools.defaultFontPixelWidth * 0.8

            Item {
                width: root._topIconSize * 1.15
                height: root._topIconSize * 1.15

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: root._panelFill
                    border.color: root._panelBorder
                    border.width: 1
                }

                Image {
                    anchors.centerIn: parent
                    width: parent.width * 0.62
                    height: parent.height * 0.62
                    source: "qrc:/ModeSelection/shreeon_logo.png"
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                    z: 1
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("SHREEON TECHNOLOGIES")
                color: root._white
                font.family: ScreenTools.normalFontFamily
                font.pointSize: ScreenTools.defaultFontPointSize * 1.05
                font.weight: Font.Light
                style: Text.Outline
                styleColor: Qt.rgba(0, 0, 0, 0.25)
            }
        }

        Row {
            id: topRightIcons
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: ScreenTools.defaultFontPixelWidth * 1.0

            Item {
                id:     homeThemeButton
                width:  root._topIconSize * 1.2
                height: root._topIconSize * 1.2

                readonly property bool blackSelected: mainWindow.uiThemeMode === mainWindow.themeBlack

                Rectangle {
                    anchors.fill: parent
                    radius:       width / 2
                    color:        homeThemeMouse.pressed
                                  ? Qt.rgba(1, 1, 1, 0.32)
                                  : root._panelFill
                    border.width: 1
                    border.color: homeThemeMouse.containsMouse
                                  ? root._green
                                  : root._panelBorder

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }

                QGCColoredImage {
                    anchors.centerIn: parent
                    width:            parent.width * 0.46
                    height:           width
                    source:           homeThemeButton.blackSelected
                                      ? "qrc:/InstrumentValueIcons/moon.svg"
                                      : "qrc:/InstrumentValueIcons/brightness-up.svg"
                    color:            homeThemeButton.blackSelected
                                      ? root._white
                                      : root._green
                    fillMode:         Image.PreserveAspectFit

                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    id:           homeThemeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        themeRipple.tap(mouse.x, mouse.y)
                        mainWindow.setUiThemeMode(homeThemeButton.blackSelected
                                                  ? mainWindow.themeDefault
                                                  : mainWindow.themeBlack)
                    }
                }

                RippleEffect {
                    id:          themeRipple
                    rippleColor: Qt.rgba(1, 1, 1, 0.40)
                    clipRadius:  parent.width / 2
                }
            }

            Item {
                width: root._topIconSize * 1.2
                height: root._topIconSize * 1.2

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: topIconMouse.pressed ? Qt.rgba(1, 1, 1, 0.32) : root._panelFill
                    border.color: root._panelBorder
                    border.width: 1
                }

                // Connection status dot on notification bell
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.rightMargin: parent.width * 0.12
                    anchors.topMargin: parent.height * 0.12
                    width: parent.width * 0.22
                    height: width
                    radius: width / 2
                    color: root._vehicleConnected ? root._green : root._red
                    border.width: 1
                    border.color: root._white
                    z: 2
                }

                Canvas {
                    z: 1
                    anchors.centerIn: parent
                    width: parent.width * 0.46
                    height: parent.height * 0.46
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        ctx.fillStyle = "#FFFFFF"
                        ctx.strokeStyle = "#FFFFFF"
                        ctx.lineWidth = Math.max(1.4, width * 0.1)
                        ctx.lineCap = "round"
                        var w = width
                        var h = height
                        ctx.beginPath()
                        ctx.moveTo(w * 0.18, h * 0.40)
                        ctx.quadraticCurveTo(w * 0.18, h * 0.14, w * 0.50, h * 0.14)
                        ctx.quadraticCurveTo(w * 0.82, h * 0.14, w * 0.82, h * 0.40)
                        ctx.lineTo(w * 0.82, h * 0.58)
                        ctx.lineTo(w * 0.92, h * 0.72)
                        ctx.lineTo(w * 0.08, h * 0.72)
                        ctx.lineTo(w * 0.18, h * 0.58)
                        ctx.closePath()
                        ctx.fill()
                        ctx.beginPath()
                        ctx.arc(w * 0.50, h * 0.80, w * 0.10, 0, Math.PI * 2)
                        ctx.fill()
                    }
                }
                MouseArea {
                    id: topIconMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        bellRipple.tap(mouse.x, mouse.y)
                        root.showConnectionNotification()
                    }
                }
                RippleEffect {
                    id: bellRipple
                    rippleColor: Qt.rgba(1, 1, 1, 0.40)
                    clipRadius: parent.width / 2
                }
            }
        }

        // Notification alert under the bell icon
        Popup {
            id: connectionAlertPopup
            x: topRightIcons.x + topRightIcons.width - width
            y: topBar.height + ScreenTools.defaultFontPixelHeight * 0.45
            width: ScreenTools.defaultFontPixelWidth * 28
            padding: ScreenTools.defaultFontPixelWidth * 1.1
            modal: false
            focus: true
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

            background: Rectangle {
                radius: ScreenTools.defaultFontPixelHeight * 0.55
                color: Qt.rgba(0.08, 0.10, 0.10, 0.92)
                border.width: 1
                border.color: root._vehicleConnected
                              ? Qt.rgba(0.12, 0.69, 0.36, 0.75)
                              : Qt.rgba(0.90, 0.22, 0.21, 0.75)
            }
            Column {
                width: parent.width
                spacing: ScreenTools.defaultFontPixelHeight * 0.45

                Row {
                    spacing: ScreenTools.defaultFontPixelWidth * 0.7
                    width: parent.width

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: ScreenTools.defaultFontPixelHeight * 0.7
                        height: width
                        radius: width / 2
                        color: root._vehicleConnected ? root._green : root._red
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - ScreenTools.defaultFontPixelHeight * 1.4
                        text: root._connectionAlertTitle
                        color: root._white
                        font.family: ScreenTools.normalFontFamily
                        font.pointSize: ScreenTools.defaultFontPointSize
                        font.weight: Font.DemiBold
                        wrapMode: Text.WordWrap
                    }
                }

                Text {
                    width: parent.width
                    text: root._connectionAlertText
                    color: Qt.rgba(1, 1, 1, 0.90)
                    font.family: ScreenTools.normalFontFamily
                    font.pointSize: ScreenTools.defaultFontPointSize * 0.95
                    wrapMode: Text.WordWrap
                }

                Text {
                    visible: root._vehicleConnected && root._activeVehicle
                    width: parent.width
                    text: root._activeVehicle
                          ? qsTr("Vehicle: %1").arg(root._activeVehicle.id)
                          : ""
                    color: Qt.rgba(1, 1, 1, 0.65)
                    font.family: ScreenTools.normalFontFamily
                    font.pointSize: ScreenTools.smallFontPointSize
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    // Info card
    Item {
        anchors.right: parent.right
        anchors.rightMargin: root._margins
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -parent.height * 0.02
        width: Math.min(parent.width * 0.28, ScreenTools.defaultFontPixelWidth * 28)
        height: infoCol.implicitHeight + ScreenTools.defaultFontPixelHeight * 1.8
        z: 4

        Rectangle {
            anchors.fill: parent
            radius: root._panelRadius
            color: root._panelFill
            border.color: root._panelBorder
            border.width: 1
        }

        Column {
            id: infoCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: ScreenTools.defaultFontPixelWidth * 1.4
            spacing: ScreenTools.defaultFontPixelHeight * 0.35
            z: 1

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: qsTr("One drone. Endless possibilities for precision agriculture.")
                color: root._white
                font.family: ScreenTools.normalFontFamily
                font.pointSize: ScreenTools.defaultFontPointSize * 0.95
                font.weight: Font.DemiBold
                style: Text.Outline
                styleColor: Qt.rgba(0, 0, 0, 0.18)
            }

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: qsTr("Plan, spray, and map with Shreeon Ground Control Station.")
                color: Qt.rgba(1, 1, 1, 0.88)
                font.family: ScreenTools.normalFontFamily
                font.pointSize: ScreenTools.defaultFontPointSize * 0.85
            }
        }
    }

    // Bottom cards + Start swipe
    Item {
        id: bottomSection
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root._bottomBarH + ScreenTools.defaultFontPixelHeight * 1.4
        z: 5

        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: root._margins
            anchors.rightMargin: root._margins
            anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 1.0
            height: root._bottomBarH
            spacing: ScreenTools.defaultFontPixelWidth * 1.1

            Repeater {
                model: [
                    { title: qsTr("User Manual"), kind: "manual",  action: "manual" },
                    { title: "",                  kind: "connect", action: "connect" }
                ]

                delegate: Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1

                    readonly property bool isConnect: modelData.kind === "connect"
                    readonly property bool connected: isConnect && root._vehicleConnected

                    Rectangle {
                        anchors.fill: parent
                        radius: root._panelRadius
                        color: cardMouse.pressed ? Qt.rgba(1, 1, 1, 0.30) : root._panelFill
                        border.color: root._panelBorder
                        border.width: 1
                    }

                    RippleEffect {
                        id: homeCardRipple
                        rippleColor: Qt.rgba(1, 1, 1, 0.40)
                        clipRadius: root._panelRadius
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: ScreenTools.defaultFontPixelHeight * 0.35
                        z: 1

                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: ScreenTools.defaultFontPixelHeight * 2.3
                            height: width

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: {
                                    if (!isConnect)
                                        return Qt.rgba(1, 1, 1, 0.20)
                                    return connected ? root._green : root._red
                                }
                                border.color: {
                                    if (!isConnect)
                                        return Qt.rgba(1, 1, 1, 0.55)
                                    return connected ? root._greenDeep : root._redDeep
                                }
                                border.width: isConnect ? 0 : 1

                                Behavior on color { ColorAnimation { duration: 160 } }
                            }

                            Canvas {
                                anchors.centerIn: parent
                                width: parent.width * 0.48
                                height: parent.height * 0.48
                                z: 1
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    ctx.strokeStyle = "#FFFFFF"
                                    ctx.fillStyle = "#FFFFFF"
                                    ctx.lineWidth = Math.max(1.5, width * 0.09)
                                    ctx.lineCap = "round"
                                    ctx.lineJoin = "round"
                                    var w = width
                                    var h = height
                                    if (modelData.kind === "manual") {
                                        ctx.beginPath()
                                        ctx.moveTo(w * 0.28, h * 0.12)
                                        ctx.lineTo(w * 0.62, h * 0.12)
                                        ctx.lineTo(w * 0.82, h * 0.32)
                                        ctx.lineTo(w * 0.82, h * 0.88)
                                        ctx.lineTo(w * 0.28, h * 0.88)
                                        ctx.closePath()
                                        ctx.stroke()
                                        ctx.beginPath()
                                        ctx.moveTo(w * 0.62, h * 0.12)
                                        ctx.lineTo(w * 0.62, h * 0.32)
                                        ctx.lineTo(w * 0.82, h * 0.32)
                                        ctx.stroke()
                                        ctx.beginPath()
                                        ctx.moveTo(w * 0.4, h * 0.48)
                                        ctx.lineTo(w * 0.7, h * 0.48)
                                        ctx.moveTo(w * 0.4, h * 0.62)
                                        ctx.lineTo(w * 0.7, h * 0.62)
                                        ctx.stroke()
                                    } else {
                                        // Same tick icon; green circle only when connected
                                        ctx.lineWidth = Math.max(2.5, width * 0.16)
                                        ctx.beginPath()
                                        ctx.moveTo(w * 0.18, h * 0.52)
                                        ctx.lineTo(w * 0.40, h * 0.74)
                                        ctx.lineTo(w * 0.82, h * 0.28)
                                        ctx.stroke()
                                    }
                                }
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: {
                                if (!isConnect)
                                    return modelData.title
                                return connected ? qsTr("Device Connected") : qsTr("Not Connected")
                            }
                            color: root._white
                            font.family: ScreenTools.normalFontFamily
                            font.pointSize: ScreenTools.defaultFontPointSize * 0.9
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        id: cardMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            homeCardRipple.tap(mouse.x, mouse.y)
                            if (modelData.action === "manual")
                                root.userManualClicked()
                            else
                                root.deviceConnectorClicked()
                        }
                    }
                }
            }

            // Swipeable Start control
            Item {
                id: startHost
                Layout.preferredWidth: Math.max(ScreenTools.defaultFontPixelWidth * 18, ScreenTools.defaultFontPixelHeight * 10)
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.2
                Layout.alignment: Qt.AlignVCenter

                property bool startOn: false
                property real knobX: 3
                readonly property real trackPad: 3
                readonly property real knobSize: startTrack.height - 6
                readonly property real maxKnobX: Math.max(trackPad, startTrack.width - knobSize - trackPad)

                function _setProgress(px) {
                    knobX = Math.max(trackPad, Math.min(maxKnobX, px))
                    startOn = knobX > maxKnobX * 0.55
                }

                function _snapFromRelease() {
                    if (knobX >= maxKnobX * 0.65) {
                        knobX = maxKnobX
                        startOn = true
                        root.startClicked()
                    } else {
                        knobX = trackPad
                        startOn = false
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: root._panelFill
                    border.color: root._panelBorder
                    border.width: 1
                }

                Row {
                    anchors.centerIn: parent
                    spacing: ScreenTools.defaultFontPixelWidth * 0.8
                    z: 1

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Start")
                        color: root._white
                        font.family: ScreenTools.normalFontFamily
                        font.pointSize: ScreenTools.defaultFontPointSize * 1.1
                        font.weight: Font.Bold
                    }

                    // Swipe track
                    Rectangle {
                        id: startTrack
                        anchors.verticalCenter: parent.verticalCenter
                        width: ScreenTools.defaultFontPixelHeight * 5.6
                        height: ScreenTools.defaultFontPixelHeight * 1.95
                        radius: height / 2
                        color: startHost.startOn ? root._green : root._white
                        border.color: startHost.startOn ? root._greenDeep : Qt.rgba(0, 0, 0, 0.10)
                        border.width: 1
                        clip: true

                        Behavior on color {
                            ColorAnimation {
                                duration: 160 }
                        }

                        Rectangle {
                            id: startKnob
                            width: startHost.knobSize
                            height: width
                            radius: width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            x: startHost.knobX
                            color: startHost.startOn ? root._white : root._green
                            border.color: Qt.rgba(0, 0, 0, 0.08)
                            border.width: 1
                            z: 2

                            Behavior on x {
                                enabled: !startSwipe.pressed
                                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                            }
                            Behavior on color { ColorAnimation { duration: 160 } }

                            // Chevron hint on knob
                            Canvas {
                                id: startChevron
                                anchors.centerIn: parent
                                width: parent.width * 0.42
                                height: parent.height * 0.42
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    ctx.strokeStyle = startHost.startOn ? root._green : "#FFFFFF"
                                    ctx.lineWidth = Math.max(2, width * 0.18)
                                    ctx.lineCap = "round"
                                    ctx.lineJoin = "round"
                                    ctx.beginPath()
                                    ctx.moveTo(width * 0.28, height * 0.2)
                                    ctx.lineTo(width * 0.72, height * 0.5)
                                    ctx.lineTo(width * 0.28, height * 0.8)
                                    ctx.stroke()
                                }
                                Connections {
                                    target: startHost
                                    function onStartOnChanged() { startChevron.requestPaint() }
                                }
                            }
                        }

                        MouseArea {
                            id: startSwipe
                            anchors.fill: parent
                            preventStealing: true
                            cursorShape: Qt.PointingHandCursor
                            property real _grabOffset: 0

                            onPressed: function(mouse) {
                                // Grab at press point; if tap is outside knob, center knob under finger
                                var inKnob = mouse.x >= startKnob.x && mouse.x <= startKnob.x + startKnob.width
                                if (inKnob)
                                    _grabOffset = mouse.x - startKnob.x
                                else
                                    _grabOffset = startHost.knobSize / 2
                                startHost._setProgress(mouse.x - _grabOffset)
                            }
                            onPositionChanged: function(mouse) {
                                if (pressed)
                                    startHost._setProgress(mouse.x - _grabOffset)
                            }
                            onReleased: startHost._snapFromRelease()
                            onCanceled: startHost._snapFromRelease()
                        }
                    }
                }
            }
        }
    }
}
