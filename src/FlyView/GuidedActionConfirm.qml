import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

import QGroundControl
import QGroundControl.Controls
import QGroundControl.UTMSP

Item {
    id:         control
    width:      mainLayout.width
    height:     mainLayout.height
    visible:    false

    property var    guidedController
    property var    guidedValueSlider
    property string title
    property string message
    property int    action
    property var    actionData
    property bool   hideTrigger:        false
    property var    mapIndicator
    property alias  optionText:         optionCheckBox.text
    property alias  optionChecked:      optionCheckBox.checked

    property real _margins:         2
    property bool _emergencyAction: action === guidedController.actionEmergencyStop

    // Properties of UTM adapter
    property bool   utmspSliderTrigger
    property bool   _utmspEnabled:                       QGroundControl.utmspSupported

    Component.onCompleted: guidedController.confirmDialog = this

    onHideTriggerChanged: {
        if (hideTrigger) {
            confirmCancelled()
        }
    }

    function show(immediate) {
        if (immediate) {
            _reallyShow()
        } else {
            // We delay showing the confirmation for a small amount in order for any other state
            // changes to propogate through the system. This way only the final state shows up.
            visibleTimer.restart()
        }
    }

    function confirmCancelled() {
        guidedValueSlider.visible = false
        visible = false
        hideTrigger = false
        visibleTimer.stop()
        descriptionStrip.opacity = 1.0
        messageFadeTimer.stop()
        messageOpacityAnimation.stop()
        pillSlider.reset()
        if (mapIndicator) {
            mapIndicator.actionCancelled()
            mapIndicator = undefined
        }
    }

    function _reallyShow() {
        visible = true
        descriptionStrip.opacity = 1.0
        messageFadeTimer.start()
        pillSlider.reset()
    }

    Timer {
        id:             visibleTimer
        interval:       1000
        repeat:         false
        onTriggered:    _reallyShow()
    }

    PropertyAnimation {
        id:         messageOpacityAnimation
        target:     descriptionStrip
        property:   "opacity"
        from:       1
        to:         0
        duration:   500
    }

    Timer {
        id:             messageFadeTimer
        interval:       4000
        onTriggered:    messageOpacityAnimation.start()
    }

    QGCPalette { id: qgcPal }



    ColumnLayout {
        id:         mainLayout
        spacing:    ScreenTools.defaultFontPixelHeight * 0.8
        anchors.bottom:           parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter

        // --- DESCRIPTION STRIP (Green Gradient) ---
        Rectangle {
            id: descriptionStrip
            Layout.alignment: Qt.AlignHCenter
            height: ScreenTools.defaultFontPixelHeight * 1.5
            width: pillSliderRow.width * 0.85
            radius: height / 2
            visible: control.message !== ""
            clip: true
            
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.2; color: Qt.rgba(0.0, 0.8, 0.3, 0.3) }
                GradientStop { position: 0.5; color: Qt.rgba(0.0, 0.8, 0.3, 0.7) }
                GradientStop { position: 0.8; color: Qt.rgba(0.0, 0.8, 0.3, 0.3) }
                GradientStop { position: 1.0; color: "transparent" }
            }

            // Glass Shine Effect
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                opacity: 0.2
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "white" }
                    GradientStop { position: 0.5; color: "transparent" }
                    GradientStop { position: 1.0; color: "black" }
                }
            }

            QGCLabel {
                anchors.centerIn: parent
                text: control.message
                color: "white"
                font.bold: true
                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.85
                font.family: "Noto Sans"
            }
        }

        // --- SLIDER + CANCEL ROW ---
        RowLayout {
            id: pillSliderRow
            spacing: ScreenTools.defaultFontPixelWidth * 1.5
            Layout.alignment: Qt.AlignHCenter

            QGCPillSlider {
                id:                 pillSlider
                text:               control.action === guidedController.actionSetFlightMode ? qsTr("Set Mode to %1").arg(control.actionData) : control.title
                implicitWidth:      Math.max(400, ScreenTools.defaultFontPixelWidth * 42)
                implicitHeight:     ScreenTools.defaultFontPixelHeight * 3.2
                accentColor:        "#26ad5f"
                enabled:            _utmspEnabled === true ? utmspSliderTrigger : true

                onAccepted: {
                    control.visible = false
                    var sliderOutputValue = 0
                    if (guidedValueSlider.visible) {
                        sliderOutputValue = guidedValueSlider.getOutputValue()
                        guidedValueSlider.visible = false
                    }
                    hideTrigger = false
                    guidedController.executeAction(control.action, control.actionData, sliderOutputValue, control.optionChecked)
                    if (mapIndicator) {
                        mapIndicator.actionConfirmed()
                        mapIndicator = undefined
                    }

                    UTMSPStateStorage.indicatorOnMissionStatus = true
                    UTMSPStateStorage.currentNotificationIndex = 7
                    UTMSPStateStorage.currentStateIndex = 3
                }
            }

            // RED CIRCULAR CANCEL BUTTON (Clean & Simple)
            Rectangle {
                id: cancelCircle
                width: pillSlider.height * 0.95
                height: width
                radius: width / 2
                color: "#ff3333"
                border.color: Qt.rgba(1, 1, 1, 0.2)
                border.width: 1
                
                scale: cancelMouseArea.pressed ? 0.92 : (cancelMouseArea.containsMouse ? 1.05 : 1.0)
                Behavior on scale { NumberAnimation { duration: 100 } }

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "black"
                    shadowOpacity: 0.7
                    shadowBlur: 1.0
                    shadowVerticalOffset: 3
                }

                // Internal gloss
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    opacity: 0.15
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "white" }
                        GradientStop { position: 0.4; color: "transparent" }
                        GradientStop { position: 1.0; color: "black" }
                    }
                }

                QGCColoredImage {
                    anchors.centerIn: parent
                    width: parent.width * 0.45
                    height: width
                    source: "qrc:/res/XDelete.svg"
                    color: "white"
                }

                MouseArea {
                    id: cancelMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: confirmCancelled()
                }
            }
        }

        // --- OPTIONS (IF ANY) ---
        QGCCheckBox {
            id:                 optionCheckBox
            Layout.alignment:   Qt.AlignHCenter
            visible:            text !== ""
            textColor:          "white"
            font.pixelSize:     ScreenTools.defaultFontPixelHeight * 0.75
        }
    }
}
