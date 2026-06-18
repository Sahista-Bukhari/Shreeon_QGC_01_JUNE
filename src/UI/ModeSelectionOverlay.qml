import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects

import QGroundControl
import QGroundControl.Controls

Item {
    id: control

    readonly property real _cardGap: ScreenTools.defaultFontPixelWidth * 1.4
    readonly property real _cardRadius: ScreenTools.defaultFontPixelHeight * 0.85
    readonly property color _closeColor: "#AEAEB2"
    readonly property real _contentMargin: ScreenTools.defaultFontPixelHeight * 1.2
    readonly property real _cornerIconSize: ScreenTools.defaultFontPixelHeight * 1.6
    readonly property real _footerHeight: ScreenTools.defaultFontPixelHeight * 2.4

    // Corner icon PNGs — add files to resources/ModeSelection/ and update paths here
    readonly property var _modeCornerIcons: ({
                                                 "agricultureSpraying": "qrc:/ModeSelection/spray.png",
                                                 "manual": "qrc:/ModeSelection/menual.png",
                                                 "seedSpreader": "qrc:/ModeSelection/seeds.png",
                                                 "routeMapping": "qrc:/ModeSelection/routemapping.png",
                                                 "customMission": "qrc:/ModeSelection/custommission.png"
                                             })

    // Card background images — resources/ModeSelection/
    readonly property var _modeImages: ({
                                            "agricultureSpraying": "qrc:/ModeSelection/agriculture_spraying.png",
                                            "manual": "qrc:/ModeSelection/manual_mode.png",
                                            "seedSpreader": "qrc:/ModeSelection/seed_spreader.png",
                                            "routeMapping": "qrc:/ModeSelection/route_mapping.png",
                                            "customMission": "qrc:/ModeSelection/custom_mission.png"
                                        })
    readonly property color _pageBackground: "white"
    readonly property color _pillGreen: "#008000"
    readonly property color _titleColor: "#1C1C1E"
    // Apple-like motion: fixed-duration curves (springs were too slow for toolbar handoff)
    readonly property int _overlayAnimDuration: 420
    readonly property int _modeLaunchDuration: 360
    readonly property real _cardEnterScaleFrom: 0.96
    readonly property real _contentScaleFrom: 0.975
    readonly property real _textSlideDistance: ScreenTools.defaultFontPixelWidth * 5
    readonly property real _cardEnterYOffset: ScreenTools.defaultFontPixelHeight * 0.85
    readonly property int _cardStaggerMs: 58
    readonly property int _textAnimDelay: 80
    readonly property list<real> _appleEase: [0.25, 0.1, 0.25, 1.0]

    property bool isOpen: false
    property bool _selectingMode: false
    property bool _skipCloseAnimation: false
    property point startPoint: Qt.point(0, 0)
    property real _panelSlideY: 0
    property real _textSlideX: 0
    property real _contentScale: 1

    anchors.fill: parent
    visible: false
    z: QGroundControl.zOrderTopMost + 100

    Component.onCompleted: _resetToClosedState()

    onIsOpenChanged: {
        if (control.isOpen)
            control._playOpenAnimation()
        else if (control.visible && !control._skipCloseAnimation)
            control._playCloseAnimation()
    }

    function _slideDistance() {
        if (control.height > 0)
            return control.height
        if (control.parent && control.parent.height > 0)
            return control.parent.height
        return Screen.height
    }

    function _resetToClosedState() {
        _panelSlideY = -control._slideDistance() * 0.08
        _textSlideX = -control._textSlideDistance
        _contentScale = control._contentScaleFrom
        _selectingMode = false
        panel.opacity = 0
        contentContainer.opacity = 0
        modeLaunchHero.visible = false
        modeLaunchHero.opacity = 1
    }

    function _zigOffsetForIndex(index) {
        var dir = (index % 2 === 0) ? -1 : 1
        return {
            "x": dir * ScreenTools.defaultFontPixelWidth * 3,
            "y": ((index % 4) < 2) ? -control._cardEnterYOffset * 0.35 : control._cardEnterYOffset * 0.2
        }
    }

    function _selectMode(card, navigateFn) {
        if (control._selectingMode || !control.isOpen)
            return

        control._selectingMode = true

        var cardPos = card.mapToItem(control, 0, 0)

        modeLaunchHero.imageSource = card.imageSource
        modeLaunchHero.x = cardPos.x
        modeLaunchHero.y = cardPos.y
        modeLaunchHero.width = card.width
        modeLaunchHero.height = card.height
        modeLaunchHero.cornerRadius = control._cardRadius
        modeLaunchHero.opacity = 1
        modeLaunchHero.visible = true

        contentContainer.opacity = 0
        panel.opacity = 1

        // Switch view and release toolbar immediately; hero fade runs on top briefly
        navigateFn()
        control._skipCloseAnimation = true
        control.isOpen = false

        modeLaunchAnimation.restart()
    }

    function _playOpenAnimation() {
        control.visible = true
        control._panelSlideY = -control._slideDistance() * 0.08
        control._textSlideX = -control._textSlideDistance
        control._contentScale = control._contentScaleFrom
        panel.opacity = 0
        contentContainer.opacity = 0
        openAnimation.restart()
    }

    function _playCloseAnimation() {
        closeAnimation.restart()
    }

    ParallelAnimation {
        id: openAnimation

        NumberAnimation {
            duration: control._overlayAnimDuration
            easing.bezierCurve: control._appleEase
            easing.type: Easing.BezierSpline
            property: "_panelSlideY"
            target: control
            to: 0
        }
        NumberAnimation {
            duration: control._overlayAnimDuration
            easing.bezierCurve: control._appleEase
            easing.type: Easing.BezierSpline
            property: "_contentScale"
            target: control
            to: 1
        }
        SequentialAnimation {
            PauseAnimation {
                duration: control._textAnimDelay
            }
            NumberAnimation {
                duration: control._overlayAnimDuration * 0.9
                easing.bezierCurve: control._appleEase
                easing.type: Easing.BezierSpline
                property: "_textSlideX"
                target: control
                to: 0
            }
        }
        NumberAnimation {
            duration: control._overlayAnimDuration * 0.85
            easing.bezierCurve: control._appleEase
            easing.type: Easing.BezierSpline
            property: "opacity"
            target: panel
            to: 1
        }
        SequentialAnimation {
            PauseAnimation {
                duration: control._textAnimDelay * 0.5
            }
            NumberAnimation {
                duration: control._overlayAnimDuration * 0.85
                easing.bezierCurve: control._appleEase
                easing.type: Easing.BezierSpline
                property: "opacity"
                target: contentContainer
                to: 1
            }
        }
    }

    ParallelAnimation {
        id: closeAnimation

        NumberAnimation {
            duration: control._overlayAnimDuration * 0.8
            easing.bezierCurve: control._appleEase
            easing.type: Easing.BezierSpline
            property: "_panelSlideY"
            target: control
            to: -control._slideDistance() * 0.08
        }
        NumberAnimation {
            duration: control._overlayAnimDuration * 0.8
            easing.bezierCurve: control._appleEase
            easing.type: Easing.BezierSpline
            property: "_contentScale"
            target: control
            to: control._contentScaleFrom
        }
        NumberAnimation {
            duration: control._overlayAnimDuration * 0.75
            easing.bezierCurve: control._appleEase
            easing.type: Easing.BezierSpline
            property: "_textSlideX"
            target: control
            to: -control._textSlideDistance
        }
        NumberAnimation {
            duration: control._overlayAnimDuration * 0.7
            easing.bezierCurve: control._appleEase
            easing.type: Easing.BezierSpline
            property: "opacity"
            target: panel
            to: 0
        }
        NumberAnimation {
            duration: control._overlayAnimDuration * 0.7
            easing.bezierCurve: control._appleEase
            easing.type: Easing.BezierSpline
            property: "opacity"
            target: contentContainer
            to: 0
        }

        onStopped: {
            if (!control.isOpen) {
                control.visible = false
                control._resetToClosedState()
            }
        }
    }

    ParallelAnimation {
        id: modeLaunchAnimation

        NumberAnimation {
            duration: control._modeLaunchDuration
            easing.bezierCurve: control._appleEase
            easing.type: Easing.BezierSpline
            property: "x"
            target: modeLaunchHero
            to: 0
        }
        NumberAnimation {
            duration: control._modeLaunchDuration
            easing.bezierCurve: control._appleEase
            easing.type: Easing.BezierSpline
            property: "y"
            target: modeLaunchHero
            to: 0
        }
        NumberAnimation {
            duration: control._modeLaunchDuration
            easing.bezierCurve: control._appleEase
            easing.type: Easing.BezierSpline
            property: "width"
            target: modeLaunchHero
            to: control.width
        }
        NumberAnimation {
            duration: control._modeLaunchDuration
            easing.bezierCurve: control._appleEase
            easing.type: Easing.BezierSpline
            property: "height"
            target: modeLaunchHero
            to: control.height
        }
        NumberAnimation {
            duration: control._modeLaunchDuration
            easing.bezierCurve: control._appleEase
            easing.type: Easing.BezierSpline
            property: "cornerRadius"
            target: modeLaunchHero
            to: 0
        }
        NumberAnimation {
            duration: control._modeLaunchDuration * 0.85
            easing.bezierCurve: control._appleEase
            easing.type: Easing.BezierSpline
            property: "opacity"
            target: panel
            to: 0
        }
        NumberAnimation {
            duration: control._modeLaunchDuration
            easing.bezierCurve: [0.4, 0.0, 1.0, 1.0]
            easing.type: Easing.BezierSpline
            property: "opacity"
            target: modeLaunchHero
            to: 0
        }

        onStopped: {
            modeLaunchHero.visible = false
            control._selectingMode = false
            control.visible = false
            control._resetToClosedState()
            control._skipCloseAnimation = false
        }
    }

    Item {
        id: modeLaunchHero

        property string imageSource: ""
        property real cornerRadius: control._cardRadius

        clip: true
        visible: false
        z: 300

        Rectangle {
            anchors.fill: parent
            clip: true
            color: "#111111"
            radius: modeLaunchHero.cornerRadius

            Image {
                anchors.fill: parent
                antialiasing: true
                fillMode: Image.PreserveAspectCrop
                horizontalAlignment: Image.AlignHCenter
                mipmap: true
                smooth: true
                source: modeLaunchHero.imageSource
                verticalAlignment: Image.AlignVCenter
            }
        }
    }

    Item {
        id: overlayRoot
        anchors.fill: parent
        transform: Translate {
            y: control._panelSlideY
        }
        visible: control.visible

        Rectangle {
            id: panel

            anchors.fill: parent
            color: control._pageBackground
            opacity: 0
        }
        Item {
            id: contentContainer

            anchors.fill: panel
            anchors.margins: control._contentMargin
            layer.enabled: true
            layer.smooth: true
            opacity: 0
            transform: Scale {
                origin.x: contentContainer.width / 2
                origin.y: contentContainer.height / 2
                xScale: control._contentScale
                yScale: control._contentScale
            }

            // --- Header ---
            Item {
                id: topHeader

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: ScreenTools.defaultFontPixelHeight * 2.8
                transform: Translate {
                    x: control._textSlideX
                }

                Rectangle {
                    id: standardModePill

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: control._pillGreen
                    height: ScreenTools.defaultFontPixelHeight * 2.0
                    radius: height / 2
                    width: standardModeRow.implicitWidth + ScreenTools.defaultFontPixelWidth * 2.4

                    Row {
                        id: standardModeRow

                        anchors.centerIn: parent
                        spacing: ScreenTools.defaultFontPixelWidth * 0.5

                        QGCLabel {
                            id: themeArrow
                            anchors.verticalCenter: parent.verticalCenter
                            color: "white"
                            font.pointSize: ScreenTools.defaultFontPointSize
                            font.weight: Font.Medium
                            padding: 10
                            text: qsTr("Choose Your Theme")
                        }
                        QGCColoredImage {
                            anchors.verticalCenter: parent.verticalCenter
                            color: "white"
                            height: ScreenTools.defaultFontPixelHeight * 0.75
                            source: "/res/chevron-down.svg"
                            width: height

                        }

                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: themeArrow.open()
                    }
                }
                QGCLabel {
                    anchors.centerIn: parent
                    color: control._titleColor
                    font.pointSize: ScreenTools.largeFontPointSize
                    font.weight: Font.DemiBold
                    text: qsTr("Select task mode")
                }
                Item {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: ScreenTools.defaultFontPixelHeight * 2.2
                    width: height

                    QGCColoredImage {
                        id: closethewindow
                        anchors.centerIn: parent
                        color: control._closeColor
                        height: parent.height * 0.4
                        opacity: closeMouseArea.containsMouse ? 1.0 : 0.85
                        source: "/res/XDeleteBlack.svg"
                        width: height
                    }
                    MouseArea {
                        id: closeMouseArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        // onClicked: control.isOpen = false
                        onClicked: {
                            mainWindow.close()
                            console.log("Window close properly")
                            }
                    }
                }
            }

            // --- Settings (bottom-left, QGC style) ---
            Item {
                id: settingsFooter

                anchors.bottom: parent.bottom
                anchors.left: parent.left
                height: control._footerHeight
                width: settingsRow.implicitWidth + ScreenTools.defaultFontPixelWidth
                transform: Translate {
                    x: control._textSlideX
                }

                Row {
                    id: settingsRow

                    anchors.verticalCenter: parent.verticalCenter
                    spacing: ScreenTools.defaultFontPixelWidth * 0.55

                    QGCColoredImage {
                        anchors.verticalCenter: parent.verticalCenter
                        color: control._titleColor
                        height: ScreenTools.defaultFontPixelHeight * 1.35
                        opacity: settingsMouseArea.containsMouse ? 1.0 : 0.6
                        source: "qrc:/qmlimages/HamburgerThin.svg"
                        width: height

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 150
                            }
                        }
                    }
                    QGCLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        color: control._titleColor
                        font.pointSize: ScreenTools.defaultFontPointSize
                        font.weight: Font.Medium
                        opacity: settingsMouseArea.containsMouse ? 1.0 : 0.6
                        text: qsTr("Settings")

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 150
                            }
                        }
                    }
                }
                MouseArea {
                    id: settingsMouseArea

                    anchors.fill: parent
                    anchors.margins: -ScreenTools.defaultFontPixelHeight * 0.4
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: {
                        mainWindow.showSettingsTool();
                        control.isOpen = false;
                    }
                }
            }

            // --- Card area ---
            Item {
                id: centerContent

                readonly property real cardsHeight: centerContent.height
                readonly property real colMidW: (centerContent.gridWidth - centerContent.colRouteW - control._cardGap * 2) * 0.52
                readonly property real colRightW: centerContent.gridWidth - centerContent.colRouteW - centerContent.colMidW - control._cardGap * 2
                readonly property real colRouteW: centerContent.gridWidth * 0.255
                readonly property real fruitTreeMappingRowH: centerContent.stackHeight - centerContent.routeMappingRowH
                readonly property real fruitTreeRowH: centerContent.stackHeight - centerContent.manualRowH
                readonly property real gridWidth: centerContent.width
                // Agriculture column: Manual shorter, Fruit Tree taller (~38% / 62%)
                readonly property real manualRowH: centerContent.stackHeight * 0.38
                // Mapping column: Route Mapping taller, Fruit Tree Mapping shorter (~68% / 32%)
                readonly property real routeMappingRowH: centerContent.stackHeight * 0.68
                readonly property real stackHeight: centerContent.cardsHeight - control._cardGap

                anchors.bottom: settingsFooter.top
                anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.2
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: topHeader.bottom
                anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.35

                Row {
                    id: cardGrid

                    anchors.fill: parent
                    spacing: control._cardGap
                    width: centerContent.gridWidth

                    // Agriculture Spraying — tall card
                    ModeCard {
                        animationIndex: 0
                        cornerIconSource: control._modeCornerIcons.agricultureSpraying
                        desaturated: false
                        height: parent.height
                        imageSource: control._modeImages.agricultureSpraying
                        title: qsTr("Agriculture Spraying")
                        width: centerContent.colRouteW

                        onClicked: control._selectMode(this, function() { mainWindow.showPlanView() })
                    }
                    Column {
                        spacing: control._cardGap
                        width: centerContent.colMidW

                        ModeCard {
                            animationIndex: 1
                            cornerIconSource: control._modeCornerIcons.manual
                            desaturated: true
                            height: centerContent.manualRowH
                            imageSource: control._modeImages.manual
                            title: qsTr("Manual")
                            width: centerContent.colMidW

                            onClicked: control._selectMode(this, function() { mainWindow.showFlyView() })
                        }
                        ModeCard {
                            animationIndex: 2
                            cornerIconSource: control._modeCornerIcons.seedSpreader
                            desaturated: true
                            height: centerContent.fruitTreeRowH
                            imageSource: control._modeImages.seedSpreader
                            title: qsTr("Seed Spreader")
                            width: centerContent.colMidW

                            onClicked: control._selectMode(this, function() { mainWindow.showPlanView() })
                        }
                    }
                    Column {
                        spacing: control._cardGap
                        width: centerContent.colRightW
                        ModeCard {
                            animationIndex: 3
                            cornerIconSource: control._modeCornerIcons.routeMapping
                            desaturated: false
                            height: centerContent.routeMappingRowH
                            imageSource: control._modeImages.routeMapping
                            title: qsTr("Route Mapping")
                            width: centerContent.colRightW

                            onClicked: control._selectMode(this, function() { mainWindow.showRouteMappingView() })
                        }
                        ModeCard {
                            animationIndex: 4
                            cornerIconSource: control._modeCornerIcons.customMission
                            desaturated: true
                            height: centerContent.fruitTreeMappingRowH
                            imageSource: control._modeImages.customMission
                            title: qsTr("Custom Mission")
                            width: centerContent.colRightW

                            onClicked: control._selectMode(this, function() { mainWindow.showPlanView() })
                        }
                    }
                }
            }
        }
    }
    component ModeCard: Item {
        id: cardRoot

        property int animationIndex: 0
        property string cornerIconSource: ""
        property bool desaturated: false
        property string imageSource: ""
        property bool showScanOverlay: false
        property string title: ""
        property bool useSchematic: false
        property real enterX: 0
        property real enterY: 0
        property real enterScale: 1
        property real enterOpacity: 1

        signal clicked

        layer.enabled: true
        layer.smooth: true
        opacity: enterOpacity
        transform: [
            Translate {
                x: enterX
                y: enterY
            },
            Scale {
                origin.x: cardRoot.width / 2
                origin.y: cardRoot.height / 2
                xScale: enterScale
                yScale: enterScale
            }
        ]

        Component.onCompleted: cardRoot._resetEnterState()

        Connections {
            function onIsOpenChanged() {
                if (control.isOpen)
                    cardRoot._playEnterAnimation()
                else if (!control._selectingMode)
                    cardRoot._playExitAnimation()
            }

            target: control
        }

        function _resetEnterState() {
            var zig = control._zigOffsetForIndex(animationIndex)
            enterScale = control._cardEnterScaleFrom
            enterX = zig.x
            enterY = control._cardEnterYOffset + zig.y
            enterOpacity = 0
        }

        function _playEnterAnimation() {
            _resetEnterState()
            cardEnterAnimation.restart()
        }

        function _playExitAnimation() {
            cardExitAnimation.restart()
        }

        SequentialAnimation {
            id: cardEnterAnimation

            PauseAnimation {
                duration: control._textAnimDelay + cardRoot.animationIndex * control._cardStaggerMs
            }
            ParallelAnimation {
                NumberAnimation {
                    duration: control._overlayAnimDuration * 0.95
                    easing.bezierCurve: control._appleEase
                    easing.type: Easing.BezierSpline
                    property: "enterScale"
                    target: cardRoot
                    to: 1
                }
                NumberAnimation {
                    duration: control._overlayAnimDuration * 0.95
                    easing.bezierCurve: control._appleEase
                    easing.type: Easing.BezierSpline
                    property: "enterX"
                    target: cardRoot
                    to: 0
                }
                NumberAnimation {
                    duration: control._overlayAnimDuration * 0.95
                    easing.bezierCurve: control._appleEase
                    easing.type: Easing.BezierSpline
                    property: "enterY"
                    target: cardRoot
                    to: 0
                }
                NumberAnimation {
                    duration: control._overlayAnimDuration * 0.85
                    easing.bezierCurve: control._appleEase
                    easing.type: Easing.BezierSpline
                    property: "enterOpacity"
                    target: cardRoot
                    to: 1
                }
            }
        }

        SequentialAnimation {
            id: cardExitAnimation

            PauseAnimation {
                duration: (4 - cardRoot.animationIndex) * control._cardStaggerMs * 0.45
            }
            ParallelAnimation {
                NumberAnimation {
                    duration: control._overlayAnimDuration * 0.65
                    easing.bezierCurve: control._appleEase
                    easing.type: Easing.BezierSpline
                    property: "enterScale"
                    target: cardRoot
                    to: control._cardEnterScaleFrom
                }
                NumberAnimation {
                    duration: control._overlayAnimDuration * 0.6
                    easing.bezierCurve: control._appleEase
                    easing.type: Easing.BezierSpline
                    property: "enterOpacity"
                    target: cardRoot
                    to: 0
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            antialiasing: true
            color: "transparent"
            layer.enabled: true
            radius: control._cardRadius
            z: 0
            layer.effect: MultiEffect {
                shadowBlur: 0.45
                shadowColor: "#22000000"
                shadowEnabled: true
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 5
            }
        }
        Rectangle {
            id: cardBackground

            anchors.fill: parent
            antialiasing: true
            clip: true
            color: cardRoot.useSchematic ? "#141414" : "#1a1a1a"
            radius: control._cardRadius
            smooth: true
            z: 1

            Item {
                id: imageContainer

                anchors.fill: parent
                layer.enabled: true
                layer.smooth: true
                visible: !cardRoot.useSchematic

                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        color: "white"
                        height: imageContainer.height
                        radius: control._cardRadius
                        width: imageContainer.width
                    }
                }

                Image {
                    anchors.fill: parent
                    antialiasing: true
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    horizontalAlignment: Image.AlignHCenter
                    layer.enabled: cardRoot.desaturated
                    mipmap: true
                    smooth: true
                    source: cardRoot.imageSource
                    verticalAlignment: Image.AlignVCenter

                    layer.effect: Desaturate {
                        desaturation: 0.9
                    }
                }
            }
            Rectangle {
                anchors.fill: parent
                radius: control._cardRadius
                z: 3

                gradient: Gradient {
                    GradientStop {
                        color: Qt.rgba(0, 0, 0, 0.48)
                        position: 0.0
                    }
                    GradientStop {
                        color: Qt.rgba(0, 0, 0, 0.05)
                        position: 0.22
                    }
                    GradientStop {
                        color: Qt.rgba(0, 0, 0, 0.28)
                        position: 1.0
                    }
                }
            }
            QGCLabel {
                anchors.left: parent.left
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 1.0
                anchors.right: parent.right
                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 1.0
                anchors.top: parent.top
                anchors.topMargin: ScreenTools.defaultFontPixelHeight * 1.0
                color: "white"
                font.pointSize: ScreenTools.mediumFontPointSize
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                text: cardRoot.title
                transform: Translate {
                    x: control._textSlideX
                }
                wrapMode: Text.WordWrap
                z: 4
            }
            Image {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.7
                anchors.right: parent.right
                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 1.1
                antialiasing: true
                fillMode: Image.PreserveAspectFit
                height: control._cornerIconSize
                mipmap: true
                smooth: true
                source: cardRoot.cornerIconSource
                visible: cardRoot.cornerIconSource !== ""
                width: height
                z: 5
            }
            Rectangle {
                anchors.fill: parent
                color: "white"
                opacity: mouseArea.containsMouse ? 0.07 : 0
                radius: control._cardRadius
                z: 6

                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                    }
                }
            }
            MouseArea {
                id: mouseArea
                anchors.fill: parent
                cursorShape: control._selectingMode ? Qt.ArrowCursor : Qt.PointingHandCursor
                enabled: !control._selectingMode
                hoverEnabled: true
                z: 7

                onClicked: cardRoot.clicked()
            }
        }
    }
}
