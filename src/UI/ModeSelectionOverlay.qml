import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects

import QGroundControl
import QGroundControl.Controls

Item {
    id: control

    property bool isOpen: false
    property point startPoint: Qt.point(0, 0)

    readonly property color _pageBackground: "#FFFFFF"
    readonly property color _pillGreen: "#2ECC71"
    readonly property color _titleColor: "#1C1C1E"
    readonly property color _closeColor: "#AEAEB2"
    readonly property real _cardRadius: ScreenTools.defaultFontPixelHeight * 0.85
    readonly property real _contentMargin: ScreenTools.defaultFontPixelHeight * 1.2
    readonly property real _cardGap: ScreenTools.defaultFontPixelWidth * 1.4
    readonly property real _footerHeight: ScreenTools.defaultFontPixelHeight * 2.4
    readonly property real _cornerIconSize: ScreenTools.defaultFontPixelHeight * 1.4

    // Card background images — resources/ModeSelection/
    readonly property var _modeImages: ({
        "agricultureSpraying": "qrc:/ModeSelection/agriculture_spraying.png",
        "manual":               "qrc:/ModeSelection/manual_mode.png",
        "seedSpreader":         "qrc:/ModeSelection/seed_spreader.png",
        "routeMapping":         "qrc:/ModeSelection/route_mapping.png",
        "customMission":        "qrc:/ModeSelection/custom_mission.png"
    })

    // Corner icon PNGs — add files to resources/ModeSelection/ and update paths here
    readonly property var _modeCornerIcons: ({
        "agricultureSpraying": "qrc:/ModeSelection/spray.png",
        "manual":               "qrc:/ModeSelection/menual.png",
        "seedSpreader":         "qrc:/ModeSelection/seeds.png",
        "routeMapping":         "qrc:/ModeSelection/routemapping.png",
        "customMission":        "qrc:/ModeSelection/custommission.png"
    })

    anchors.fill: parent
    visible: false
    z: QGroundControl.zOrderTopMost + 100

    onIsOpenChanged: {
        if (control.isOpen) {
            control.visible = true
            panel.opacity = 1
            contentContainer.opacity = 1
        } else {
            control.visible = false
            panel.opacity = 0
            contentContainer.opacity = 0
        }
    }

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
        opacity: 1
        visible: control.isOpen

        // --- Header ---
        Item {
            id: topHeader
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: ScreenTools.defaultFontPixelHeight * 2.8

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
                        anchors.verticalCenter: parent.verticalCenter
                        color: "white"
                        font.pointSize: ScreenTools.defaultFontPointSize
                        font.weight: Font.Medium
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
                    onClicked: { /* reserved for mode picker */ }
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
                    anchors.centerIn: parent
                    color: control._closeColor
                    height: parent.height * 0.5
                    opacity: closeMouseArea.containsMouse ? 1.0 : 0.85
                    source: "/res/XDeleteBlack.svg"
                    width: height
                }

                MouseArea {
                    id: closeMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: control.isOpen = false
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

            Row {
                id: settingsRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: ScreenTools.defaultFontPixelWidth * 0.55

                QGCColoredImage {
                    anchors.verticalCenter: parent.verticalCenter
                    color: control._titleColor
                    height: ScreenTools.defaultFontPixelHeight * 1.35
                    opacity: settingsMouseArea.containsMouse ? 1.0 : 0.6
                    source: "/res/gear-black.svg"
                    width: height
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
                QGCLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    color: control._titleColor
                    font.pointSize: ScreenTools.defaultFontPointSize
                    font.weight: Font.Medium
                    opacity: settingsMouseArea.containsMouse ? 1.0 : 0.6
                    text: qsTr("Settings")
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
            }

            MouseArea {
                id: settingsMouseArea
                anchors.fill: parent
                anchors.margins: -ScreenTools.defaultFontPixelHeight * 0.4
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    mainWindow.showSettingsTool()
                    control.isOpen = false
                }
            }
        }

        // --- Card area ---
        Item {
            id: centerContent
            anchors.bottom: settingsFooter.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: topHeader.bottom
            anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.2
            anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.35

            readonly property real gridWidth: centerContent.width
            readonly property real colRouteW: centerContent.gridWidth * 0.255
            readonly property real colMidW: (centerContent.gridWidth - centerContent.colRouteW - control._cardGap * 2) * 0.52
            readonly property real colRightW: centerContent.gridWidth - centerContent.colRouteW - centerContent.colMidW - control._cardGap * 2
            readonly property real cardsHeight: centerContent.height
            readonly property real stackHeight: centerContent.cardsHeight - control._cardGap
            // Agriculture column: Manual shorter, Fruit Tree taller (~38% / 62%)
            readonly property real manualRowH: centerContent.stackHeight * 0.38
            readonly property real fruitTreeRowH: centerContent.stackHeight - centerContent.manualRowH
            // Mapping column: Route Mapping taller, Fruit Tree Mapping shorter (~68% / 32%)
            readonly property real routeMappingRowH: centerContent.stackHeight * 0.68
            readonly property real fruitTreeMappingRowH: centerContent.stackHeight - centerContent.routeMappingRowH

            Row {
                id: cardGrid
                anchors.fill: parent
                spacing: control._cardGap
                width: centerContent.gridWidth

                // Agriculture Spraying — tall card
                ModeCard {
                    cornerIconSource: control._modeCornerIcons.agricultureSpraying
                    desaturated: false
                    height: parent.height
                    imageSource: control._modeImages.agricultureSpraying
                    title: qsTr("Agriculture Spraying")
                    width: centerContent.colRouteW
                    onClicked: {
                        mainWindow.showPlanView()
                        control.isOpen = false
                    }
                }

                Column {
                    spacing: control._cardGap
                    width: centerContent.colMidW

                    ModeCard {
                        cornerIconSource: control._modeCornerIcons.manual
                        desaturated: true
                        height: centerContent.manualRowH
                        imageSource: control._modeImages.manual
                        title: qsTr("Manual")
                        width: centerContent.colMidW
                        onClicked: {
                            mainWindow.showFlyView()
                            control.isOpen = false
                        }
                    }

                    ModeCard {
                        cornerIconSource: control._modeCornerIcons.seedSpreader
                        desaturated: true
                        height: centerContent.fruitTreeRowH
                        imageSource: control._modeImages.seedSpreader
                        title: qsTr("Seed Spreader")
                        width: centerContent.colMidW
                        onClicked: {
                            mainWindow.showPlanView()
                            control.isOpen = false
                        }
                    }
                }

                Column {
                    spacing: control._cardGap
                    width: centerContent.colRightW

                    ModeCard {
                        cornerIconSource: control._modeCornerIcons.routeMapping
                        desaturated: false
                        height: centerContent.routeMappingRowH
                        imageSource: control._modeImages.routeMapping
                        title: qsTr("Route Mapping")
                        width: centerContent.colRightW

                        onClicked: {
                            mainWindow.showPlanView()
                            control.isOpen = false
                        }
                    }

                    ModeCard {
                        cornerIconSource: control._modeCornerIcons.customMission
                        desaturated: true
                        height: centerContent.fruitTreeMappingRowH
                        imageSource: control._modeImages.customMission
                        title: qsTr("Custom Mission")
                        width: centerContent.colRightW
                        onClicked: {
                            mainWindow.showPlanView()
                            control.isOpen = false
                        }
                    }
                }
            }
        }
    }

    // Zig-zag flight path schematic for Route card
    component RouteSchematic: Item {
        anchors.fill: parent
        Canvas {
            id: gridCanvas
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)

                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.07)
                ctx.lineWidth = 1
                const step = Math.max(14, width / 10)
                for (let x = step; x < width; x += step) {
                    ctx.beginPath()
                    ctx.moveTo(x, 0)
                    ctx.lineTo(x, height)
                    ctx.stroke()
                }
                for (let y = step; y < height; y += step) {
                    ctx.beginPath()
                    ctx.moveTo(0, y)
                    ctx.lineTo(width, y)
                    ctx.stroke()
                }

                const margin = width * 0.12
                const top = height * 0.22
                const bottom = height * 0.78
                const cols = 4
                const colW = (width - margin * 2) / (cols - 1)
                const points = []
                for (let i = 0; i < cols; i++) {
                    const x = margin + i * colW
                    const y = (i % 2 === 0) ? top : bottom
                    points.push({ x: x, y: y })
                }

                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.55)
                ctx.lineWidth = 2
                ctx.lineJoin = "round"
                ctx.lineCap = "round"
                ctx.beginPath()
                ctx.moveTo(points[0].x, points[0].y)
                for (let i = 1; i < points.length; i++) {
                    ctx.lineTo(points[i].x, points[i].y)
                }
                ctx.stroke()

                ctx.fillStyle = Qt.rgba(1, 1, 1, 0.9)
                for (let i = 0; i < points.length; i++) {
                    ctx.beginPath()
                    ctx.arc(points[i].x, points[i].y, 4, 0, Math.PI * 2)
                    ctx.fill()
                }
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }
    }

    // Cyan scan cone overlay for mapping cards
    component ScanOverlay: Item {
        anchors.fill: parent

        Canvas {
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)

                const cx = width * 0.5
                const cy = height * 0.62
                const spread = width * 0.42

                const grad = ctx.createLinearGradient(cx, cy - spread * 0.2, cx, cy + spread)
                grad.addColorStop(0, Qt.rgba(0.18, 0.82, 0.95, 0.55))
                grad.addColorStop(0.55, Qt.rgba(0.12, 0.72, 0.88, 0.28))
                grad.addColorStop(1, Qt.rgba(0.08, 0.55, 0.72, 0.05))

                ctx.fillStyle = grad
                ctx.beginPath()
                ctx.moveTo(cx, cy - spread * 0.15)
                ctx.lineTo(cx - spread, cy + spread * 0.85)
                ctx.lineTo(cx + spread, cy + spread * 0.85)
                ctx.closePath()
                ctx.fill()

                ctx.strokeStyle = Qt.rgba(0.35, 0.92, 1.0, 0.35)
                ctx.lineWidth = 1
                for (let i = 1; i <= 4; i++) {
                    const t = i / 5
                    const y = cy - spread * 0.15 + (spread * t)
                    const half = spread * t * 0.95
                    ctx.beginPath()
                    ctx.moveTo(cx - half, y)
                    ctx.lineTo(cx + half, y)
                    ctx.stroke()
                }
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }
    }

    component ModeCard: Item {
        id: cardRoot

        property string imageSource: ""
        property string title: ""
        property string cornerIconSource: ""
        property bool desaturated: false
        property bool useSchematic: false
        property bool showScanOverlay: false

        signal clicked

        Rectangle {
            anchors.fill: parent
            antialiasing: true
            color: "transparent"
            radius: control._cardRadius
            z: 0

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowBlur: 0.45
                shadowColor: "#22000000"
                shadowEnabled: true
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 3
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

            RouteSchematic {
                visible: cardRoot.useSchematic
            }

            Item {
                id: imageContainer
                anchors.fill: parent
                visible: !cardRoot.useSchematic

                layer.enabled: true
                layer.smooth: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        height: imageContainer.height
                        radius: control._cardRadius
                        width: imageContainer.width
                        color: "white"
                    }
                }

                Image {
                    anchors.fill: parent
                    antialiasing: true
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    horizontalAlignment: Image.AlignHCenter
                    mipmap: true
                    smooth: true
                    source: cardRoot.imageSource
                    verticalAlignment: Image.AlignVCenter

                    layer.enabled: cardRoot.desaturated
                    layer.effect: Desaturate {
                        desaturation: 0.9
                    }
                }
            }

            ScanOverlay {
                visible: cardRoot.showScanOverlay
                z: 2
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.48) }
                    GradientStop { position: 0.22; color: Qt.rgba(0, 0, 0, 0.05) }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.28) }
                }
                radius: control._cardRadius
                z: 3
            }

            QGCLabel {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 1.0
                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 1.0
                anchors.topMargin: ScreenTools.defaultFontPixelHeight * 1.0
                color: "white"
                font.pointSize: ScreenTools.mediumFontPointSize
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                text: cardRoot.title
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
                Behavior on opacity { NumberAnimation { duration: 160 } }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                z: 7
                onClicked: cardRoot.clicked()
            }
        }
    }
}
