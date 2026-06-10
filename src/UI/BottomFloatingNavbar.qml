import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Window
import QGroundControl
import QGroundControl.Controls

Item {
    id: root

    //-------------------------------------------------------------------------
    // Configuration
    //-------------------------------------------------------------------------
    property var  mainWindow
    property bool isFlyView: true
    property string activeSection: "Fly"
    property var  activeVehicle: QGroundControl.multiVehicleManager.activeVehicle

    // Signals
    signal showFlyView()
    signal showPlanView()
    signal showAnalyzeTool()
    signal showSettings()
    signal showConfigure()

    function getVehicleMessage() {
        if (activeVehicle && activeVehicle.messageType !== undefined && activeVehicle.messageType !== "") {
             return activeVehicle.formattedMessage
        }
        return "Ready"
    }

    // Responsive Logic: Determine which buttons fit
    // We base this on the available width for the navbar.
    // As the window shrinks, we hide Analyze, then Plan.
    property real availableWidth: mainWindow ? mainWindow.width : ScreenTools.defaultFontPixelWidth * 100

    // Thresholds (approximate pixel widths)
    readonly property real _thresholdFull:    ScreenTools.defaultFontPixelWidth * 60  // All visible
    readonly property real _thresholdMedium: ScreenTools.defaultFontPixelWidth * 40  // Hide Analyze

    property bool showAnalyzeKey: availableWidth > _thresholdFull
    property bool showPlanKey:    availableWidth > _thresholdMedium

    //-------------------------------------------------------------------------
    // Custom Navbar Button Component
    //-------------------------------------------------------------------------
    component NavbarButton : Item {
        property string btnText
        property string btnIconSource
        property bool   isActive: false
        property bool   showIcon: true
        signal clicked()

        visible: true
        width:  visible ? rowLayout.width + (ScreenTools.defaultFontPixelWidth * 2) : 0
        height: parent.height - (ScreenTools.defaultFontPixelHeight * 0.5)
        Layout.alignment: Qt.AlignVCenter

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: isActive ? qgcPal.text : "transparent"
            opacity: isActive ? 0.1 : 0
        }

        RowLayout {
            id: rowLayout
            anchors.centerIn: parent
            spacing: ScreenTools.defaultFontPixelWidth / 2

            QGCColoredImage {
                visible: showIcon
                source: btnIconSource
                width:  ScreenTools.defaultFontPixelHeight
                height: width
                color:  isActive ? "#219C59" : qgcPal.text
                fillMode: Image.PreserveAspectFit
            }

            QGCLabel {
                text:  btnText
                font.pointSize: ScreenTools.mediumFontPointSize
                color: isActive ? "#219C59" : qgcPal.text
                font.bold: isActive
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: parent.clicked()
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
        }
    }

    //-------------------------------------------------------------------------
    // Main Container
    //-------------------------------------------------------------------------

    // We use a container item to manage the centering/anchoring
    // The visual "Pill" is the rectangle inside.

    width:  pillRect.width
    height: pillRect.height
    z:      QGroundControl.zOrderTopMost

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    Rectangle {
        id: pillRect
        height: ScreenTools.defaultFontPixelHeight * 3.0
        width:  contentRow.width + (ScreenTools.defaultFontPixelWidth * 3)
        radius: height / 2

        // Visual
        color:  qgcPal.windowShade // Sleek palette-aware background
        // Shadow for depth (lifted look)
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.5
            shadowBlur: 20
            shadowVerticalOffset: 5
        }

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: ScreenTools.defaultFontPixelWidth

            // 1. Fly
            NavbarButton {
                btnText: "Fly"
                btnIconSource: "/qmlimages/PaperPlane.svg"
                isActive: root.activeSection === "Fly"
                onClicked: { root.showFlyView(); root.isFlyView = true; root.activeSection = "Fly" }
            }

            // 2. Plan (Hide if narrow)
            NavbarButton {
                visible: root.showPlanKey
                btnText: "Plan"
                btnIconSource: "/qmlimages/Plan.svg"
                isActive: root.activeSection === "Plan"
                onClicked: { root.showPlanView(); root.isFlyView = false; root.activeSection = "Plan" }
            }

            // 3. Analyze (Hide if medium narrow)
             NavbarButton {
                visible: root.showAnalyzeKey
                btnText: "Analyze"
                btnIconSource: "/qmlimages/Analyze.svg"
                isActive: root.activeSection === "Analyze"
                onClicked: { root.showAnalyzeTool(); root.isFlyView = false; root.activeSection = "Analyze" }
            }

            // Separator (only if we have buttons to separate from More)
            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: parent.height * 0.5
                color: qgcPal.text
                opacity: 0.2
            }

            // 4. "More" Button (Green Circle with +)
            Rectangle {
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.2
                Layout.preferredWidth:  Layout.preferredHeight
                radius: width / 2
                color: "#219C59"

                Text {
                    anchors.centerIn: parent
                    text: "+"
                    font.pixelSize: parent.height * 0.7
                    color: "white"
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter

                    rotation: moreMenu.opened ? 135 : 0
                    Behavior on rotation { NumberAnimation { duration: 200 } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: moreMenu.opened ? moreMenu.close() : moreMenu.open()
                }
            }
        }
    }

    //-------------------------------------------------------------------------
    // Positioning States
    //-------------------------------------------------------------------------
    states: [
        State {
            name: "flyViewCenter"
            when: root.isFlyView && root.activeVehicle
            AnchorChanges {
                target: root
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.right: undefined
                anchors.bottom: undefined
            }
            PropertyChanges {
                target: root
                // Center vertically in the standard toolbar
                anchors.topMargin: (ScreenTools.toolbarHeight - root.height) / 2
                anchors.rightMargin: 0
            }
        },
        State {
            name: "otherViewRight"
            when: !root.isFlyView || !root.activeVehicle
            AnchorChanges {
                target: root
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.horizontalCenter: undefined
                anchors.bottom: undefined
            }
            PropertyChanges {
                target: root
                // Center vertically in the standard toolbar
                anchors.topMargin: (ScreenTools.toolbarHeight - root.height) / 2
                // Right margin for cushion
                anchors.rightMargin: ScreenTools.defaultFontPixelWidth
            }
        }
    ]

    transitions: Transition {
        AnchorAnimation { duration: 300; easing.type: Easing.OutQuad }
    }

    //-------------------------------------------------------------------------
    // Dropdown Menu
    //-------------------------------------------------------------------------
    QGCMenu {
        id: moreMenu
        // Popups need to be parented or positioned relative to the window for overlay
        y: pillRect.height + 5
        x: pillRect.width - width

        topPadding:     5
        bottomPadding:  5
        spacing:        0

        background: Rectangle {
            implicitWidth: 220
            color: qgcPal.window
            border.color: qgcPal.text
            border.width: 1
            radius: 8
        }

        // Helper component for styled menu items
        component StyledMenuItem : MenuItem {
            id: menuItem
            property string iconSource
            padding: 10

            contentItem: RowLayout {
                spacing: 12
                QGCColoredImage {
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight
                    Layout.preferredWidth:  height
                    source:                 menuItem.iconSource
                    color:                  qgcPal.text
                    fillMode:               Image.PreserveAspectFit
                }
                QGCLabel {
                    text:               menuItem.text
                    color:              qgcPal.text
                    Layout.fillWidth:   true
                }
            }

            background: Rectangle {
                anchors.fill: parent
                color:        menuItem.highlighted ? qgcPal.buttonHighlight : "transparent"
                opacity:      menuItem.highlighted ? 1.0 : 0
            }
        }

        // Dynamic Overflow Items
        StyledMenuItem {
            visible: !root.showPlanKey
            height:  visible ? implicitHeight : 0
            text: qsTr("Plan")
            iconSource: "/qmlimages/Plan.svg"
            onTriggered: { root.showPlanView(); root.isFlyView = false; root.activeSection = "Plan" }
        }
        StyledMenuItem {
            visible: !root.showAnalyzeKey
            height:  visible ? implicitHeight : 0
            text: qsTr("Analyze")
            iconSource: "/qmlimages/Analyze.svg"
            onTriggered: { root.showAnalyzeTool(); root.isFlyView = false; root.activeSection = "Analyze" }
        }

        // Static Items
        QGCMenuSeparator {
            visible: !root.showPlanKey || !root.showAnalyzeKey
            height:  visible ? implicitHeight : 0
        }

        StyledMenuItem {
            text: qsTr("Vehicle Configuration")
            iconSource: "/qmlimages/Gears.svg"
            onTriggered: { root.showConfigure(); root.isFlyView = false; root.activeSection = "Setup" }
        }

        StyledMenuItem {
            text: qsTr("Application Settings")
            iconSource: "/res/QGCLogoWhite"
            onTriggered: { root.showSettings(); root.isFlyView = false; root.activeSection = "Settings" }
        }

        QGCMenuSeparator { }

        StyledMenuItem {
            text: qsTr("Close")
            iconSource: "/res/OpenDoor.svg"
            onTriggered: {
                if (mainWindow.allowViewSwitch()) {
                    mainWindow.finishCloseProcess()
                }
            }
        }
    }
}
