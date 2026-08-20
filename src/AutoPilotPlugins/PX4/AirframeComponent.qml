import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

SetupPage {
    id:             airframePage
    pageComponent:  (controller && controller.showCustomConfigPanel) ? customFrame : pageComponent

    AirframeComponentController {
        id:         controller
    }
    Component {
        id: customFrame
        Column {
            width:          availableWidth
            spacing:        ScreenTools.defaultFontPixelHeight * 4
            Item {
                width:      1
                height:     1
            }
            QGCLabel {
                anchors.horizontalCenter: parent.horizontalCenter
                width:      parent.width * 0.5
                height:     ScreenTools.defaultFontPixelHeight * 4
                wrapMode:   Text.WordWrap
                text:       qsTr("Your vehicle is using a custom airframe configuration. ") +
                            qsTr("This configuration can only be modified through the Parameter Editor.\n\n") +
                            qsTr("If you want to reset your airframe configuration and select a standard configuration, click 'Reset' below.")
            }
            QGCButton {
                text:       qsTr("Reset")
                enabled:    sys_autostart
                anchors.horizontalCenter: parent.horizontalCenter
                property Fact sys_autostart: controller.getParameterFact(-1, "SYS_AUTOSTART")
                onClicked: {
                    if(sys_autostart) {
                        sys_autostart.value = 0
                    }
                }
            }
        }
    }

    Component {
        id: pageComponent

        Column {
            id:     mainColumn
            x:      _pagePadding
            width:  Math.max(0, airframePage.availableWidth - _pagePadding - _rightPadding)
            // Use two fluid cards per row with a narrow-screen fallback.
            property real _minW:        ScreenTools.defaultFontPixelWidth * 13.5
            property real _boxWidth:    _minW
            property real _boxSpace:    ScreenTools.defaultFontPixelWidth * 1.1
            property int  _columnCount: 1
            property bool _selectionMade: false

            readonly property real  _pagePadding:       Math.max(ScreenTools.defaultFontPixelWidth * 0.9,
                                                                 Math.min(ScreenTools.defaultFontPixelWidth * 2.2,
                                                                          airframePage.availableWidth * 0.04))
            readonly property real  _rightPadding:      Math.max(ScreenTools.defaultFontPixelWidth * 0.6,
                                                                 Math.min(ScreenTools.defaultFontPixelWidth * 1.2,
                                                                          airframePage.availableWidth * 0.02))
            readonly property real  _cardRadius:        ScreenTools.defaultFontPixelWidth * 0.9
            readonly property real  _labelPointSize:    ScreenTools.defaultFontPointSize
            readonly property real  _bodyPointSize:     ScreenTools.smallFontPointSize
            readonly property bool  _darkTheme:         qgcPal.globalTheme === QGCPalette.Dark
            readonly property color _titleColor:        _darkTheme ? "#AEAEB2" : "#3A3A3C"
            readonly property color _bodyColor:         _darkTheme ? "#8E8E93" : "#3A3A3C"
            readonly property color _accentGreen:       "#00a04c"
            readonly property color _cardIdleFill:      _darkTheme ? qgcPal.window : "#FFFFFF"
            readonly property color _cardIdleBorder:    _darkTheme ? qgcPal.windowShade : "#E6E6E6"
            readonly property color _innerIdleFill:     _darkTheme ? qgcPal.windowShade : "#E8E8E8"
            readonly property var   _visibleAirframes: [
                "Hexarotor +",
                "Hexarotor Coaxial",
                "Hexarotor x",
                "Octorotor +",
                "Octorotor Coaxial",
                "Octorotor x",
                "Quadrotor +",
                "Quadrotor H",
                "Quadrotor x",
                "Tricopter Y+"
            ]

            readonly property real spacerHeight: ScreenTools.defaultFontPixelHeight

            onWidthChanged: {
                computeDimensions()
            }

            Component.onCompleted: computeDimensions()

            function computeDimensions() {
                var gap = Math.max(ScreenTools.defaultFontPixelWidth * 0.75,
                                   Math.min(ScreenTools.defaultFontPixelWidth * 1.2,
                                            mainColumn.width * 0.025))
                var columns = Math.floor((mainColumn.width + gap) / (_minW + gap))
                columns = Math.max(1, Math.min(2, columns))
                _columnCount = columns
                _boxSpace = gap
                _boxWidth = (mainColumn.width - (gap * (columns - 1))) / columns
            }

            Item {
                id:             helpApplyRow
                anchors.left:   parent.left
                anchors.right:  parent.right
                height:         helpTextColumn.height
                                + ScreenTools.defaultFontPixelHeight * 0.55
                                + applyButton.height

                Column {
                    id:             helpTextColumn
                    width:          parent.width
                    spacing:        ScreenTools.defaultFontPixelHeight * 0.3

                    QGCLabel {
                        width:          parent.width
                        text:           controller.currentVehicleName !== ""
                                        ? qsTr("You've connected a %1.").arg(controller.currentVehicleName)
                                        : qsTr("Airframe is not set.")
                        font.bold:      false
                        font.pointSize: mainColumn._labelPointSize
                        font.family:    ScreenTools.normalFontFamily
                        color:          mainColumn._titleColor
                        wrapMode:       Text.WordWrap
                    }

                    QGCLabel {
                        width:          parent.width
                        text:           qsTr("To change this configuration, select the desired airframe below then click 'Apply and Restart'.")
                        font.bold:      false
                        font.pointSize: mainColumn._bodyPointSize
                        font.family:    ScreenTools.normalFontFamily
                        color:          mainColumn._bodyColor
                        wrapMode:       Text.WordWrap
                    }
                }

                QGCButton {
                    id:             applyButton
                    anchors.left:   parent.left
                    anchors.top:    helpTextColumn.bottom
                    anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.55
                    text:           qsTr("Apply and Restart")
                    compact:        true
                    pointSize:      mainColumn._labelPointSize
                    heightFactor:   0.35
                    enabled:        mainColumn._selectionMade
                    primary:        mainColumn._selectionMade
                    onClicked:      mainWindow.showMessageDialog(qsTr("Apply and Restart"),
                                                                 qsTr("Clicking 'Apply' will save the changes you have made to your airframe configuration.<br><br>\
                                                                        All vehicle parameters other than Radio Calibration will be reset.<br><br>\
                                                                        Your vehicle will also be restarted in order to complete the process."),
                                                                 Dialog.Apply | Dialog.Cancel,
                                                                 function() { controller.changeAutostart() })

                }
            }

            Item {
                id:             lastSpacer
                height:         parent.spacerHeight * 0.8
                width:          10
            }


            Flow {
                id:         flowView
                anchors.left: parent.left
                width:      Math.min(parent.width,
                                     (_boxWidth * _columnCount) + (_boxSpace * (_columnCount - 1)))
                spacing:    _boxSpace

                ButtonGroup {
                    id: airframeTypeExclusive
                }

                Repeater {
                    model: controller.airframeTypes

                    // Outer summary item rectangle
                    Rectangle {
                        id:     airframeCard
                        readonly property bool requestedAirframe: mainColumn._visibleAirframes.indexOf(modelData.name) !== -1
                        visible: requestedAirframe
                        width:  _boxWidth
                        height: Math.max(ScreenTools.defaultFontPixelHeight * 8.5, width * 1.08)
                        radius: mainColumn._cardRadius
                        color:  mainColumn._cardIdleFill
                        border.width: 1
                        border.color: airframeCheckBox.checked
                                      ? mainColumn._accentGreen
                                      : mainColumn._cardIdleBorder

                        readonly property real innerMargin: ScreenTools.defaultFontPixelWidth * 0.75

                        QGCComboBox {
                            id:                  combo
                            objectName:          modelData.airframeType + "ComboBox"
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top:         parent.top
                            anchors.topMargin:   ScreenTools.defaultFontPixelHeight * 0.35
                            width:               (parent.width - (airframeCard.innerMargin * 2)) * 0.72
                            model:               modelData.airframes
                            textRole:            "text"
                            compact:             false
                            sizeToContents:      true
                            clip:                true
                            alternateText:       optionChosen ? "" : qsTr("Select option")

                            property bool optionChosen: false

                            Component.onCompleted: {
                                if (airframeCheckBox.checked) {
                                    currentIndex = controller.currentVehicleIndex
                                }
                            }

                            onActivated: (index) => {
                                optionChosen = true
                                mainColumn._selectionMade = true
                                airframeCheckBox.checked = true
                                controller.autostartId = modelData.airframes[index].autostartId
                            }

                        }

                        Rectangle {
                            id:                   imagePanel
                            anchors.topMargin:    ScreenTools.defaultFontPixelHeight * 0.3
                            anchors.bottomMargin: airframeCard.innerMargin
                            anchors.leftMargin:   airframeCard.innerMargin
                            anchors.rightMargin:  airframeCard.innerMargin
                            anchors.top:          combo.bottom
                            anchors.bottom:       parent.bottom
                            anchors.left:         parent.left
                            anchors.right:        parent.right
                            radius:               ScreenTools.defaultFontPixelWidth * 0.65
                            color:                mainColumn._innerIdleFill
                            border.width:         1
                            border.color:         mainColumn._cardIdleBorder
                            clip:                 true

                            Image {
                                id:                 image
                                anchors.fill:       parent
                                anchors.margins:    airframeCard.innerMargin * 0.6
                                fillMode:           Image.PreserveAspectFit
                                smooth:             true
                                mipmap:             true
                                source:             modelData.imageResource
                            }

                            RippleEffect {
                                id:          imageRipple
                                rippleColor: Qt.rgba(0, 160 / 255, 76 / 255, 0.24)
                                clipRadius:  imagePanel.radius
                                duration:    440
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape:  Qt.PointingHandCursor
                                onClicked: function(mouse) {
                                    imageRipple.tap(mouse.x, mouse.y)
                                    mainColumn._selectionMade = true
                                    airframeCheckBox.checked = true
                                    if (combo.currentIndex !== -1)
                                        controller.autostartId = modelData.airframes[combo.currentIndex].autostartId
                                }
                            }
                        }

                        QGCCheckBox {
                            // Kept invisible to retain exclusive selection state.
                            id:             airframeCheckBox
                            checked:        modelData.name === controller.currentAirframeType
                            buttonGroup:    airframeTypeExclusive
                            visible:        false

                            onCheckedChanged: {
                                if (checked && combo.currentIndex !== -1) {
                                    console.log("check box change", combo.currentIndex)
                                    controller.autostartId = modelData.airframes[combo.currentIndex].autostartId
                                }
                            }
                        }
                    }
                } // Repeater - summary boxes
            } // Flow - summary boxes
        } // Column
    } // Component
} // SetupPage
