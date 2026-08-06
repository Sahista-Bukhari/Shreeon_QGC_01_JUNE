import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

QGCPopupDialog {
    id:         root
    title:      fact.componentId > 0 ? fact.name : qsTr("Value Editor")

    buttons:    Dialog.Save | (validate ? 0 : Dialog.Cancel)
    // Compact help dialogs stay tight; non-compact keep natural content height.
    compact:                compactValueDetails
    minimumContentHeight:   -1

    property Fact   fact
    property bool   showRCToParam:  false
    property bool   validate:       false
    property string validateValue
    property bool   setFocus:       true    ///< true: focus is set to text field on display, false: focus not set (works around strange virtual keyboard bug with FactValueSlider
    property bool   compactValueDetails: false

    property real   _editFieldWidth:            ScreenTools.defaultFontPixelWidth * (compactValueDetails ? 14 : 20)
    property bool   _longDescriptionAvailable:  fact.longDescription != ""
    property bool   _editingParameter:          fact.componentId != 0
    property bool   _allowForceSave:            QGroundControl.corePlugin.showAdvancedUI && _editingParameter
    property bool   _allowDefaultReset:         fact.defaultValueAvailable
    property bool   _showCombo:                 fact.enumStrings.length !== 0 && fact.bitmaskStrings.length === 0 && !validate

    // Match RouteMappingTaskSettings form colors on this white popup.
    readonly property color _titleColor:     "#3f3f3f"
    readonly property color _bodyColor:      "#6a6a6a"
    readonly property color _accentGreen:    "#23a800"
    readonly property color _cardBorderIdle: "#e2e2e2"
    readonly property real  _controlRadius:  ScreenTools.defaultFontPixelWidth * 0.75

    ParameterEditorController { id: controller; }

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    onAccepted: {
        if (bitmaskColumn.visible && !manualEntry.checked) {
            fact.value = bitmaskValue();
            fact.valueChanged(fact.value)
        } else if (factCombo.visible && !manualEntry.checked) {
            fact.enumIndex = factCombo.currentIndex
        } else {
            var errorString = fact.validate(valueField.text, forceSave.checked)
            if (errorString === "") {
                fact.value = valueField.text
                fact.valueChanged(fact.value)
            } else {
                validationError.text = errorString
                if (_allowForceSave) {
                    forceSave.visible = true
                }
                preventClose = true
            }
        }
    }

    function bitmaskValue() {
        var value = 0;
        for (var i = 0; i < fact.bitmaskValues.length; ++i) {
            var checkbox = bitmaskRepeater.itemAt(i)
            if (checkbox.checked) {
                value |= fact.bitmaskValues[i];
            }
        }
        return value
    }

    Component.onCompleted: {
        if (validate) {
            valueField.text = validateValue
            validationError.text = fact.validate(validateValue, false /* convertOnly */)
            if (_allowForceSave) {
                forceSave.visible = true
            }
        } else {
            valueField.text = fact.valueString
        }
    }

    ColumnLayout {
        // Fill the dialog content width so text wraps instead of clipping.
        width:      {
            if (compactValueDetails) {
                return parent && parent.width > 0
                       ? parent.width
                       : ScreenTools.defaultFontPixelWidth * 32
            }
            return Math.min(mainWindow.width * .75, Math.max(ScreenTools.defaultFontPixelWidth * 60, editRow.width))
        }
        spacing:    compactValueDetails ? ScreenTools.defaultFontPixelHeight * 0.45 : globals.defaultTextHeight

        QGCLabel {
            id:                 validationError
            Layout.fillWidth:   true
            wrapMode:           Text.WordWrap
            color:              qgcPal.warningText
            visible:            text !== ""
        }

        // Always show what this value is (was hidden in compact mode → empty white gap).
        QGCLabel {
            Layout.fillWidth:   true
            wrapMode:           Text.WordWrap
            text:               {
                if (fact.shortDescription && fact.shortDescription.length) {
                    return fact.shortDescription
                }
                if (fact.name && fact.name.length) {
                    return fact.name
                }
                return qsTr("Edit value")
            }
            color:              root._titleColor
            font.weight:        Font.Medium
            visible:            text !== ""
        }

        ColumnLayout {
            id:                 editRow
            Layout.fillWidth:   true
            spacing:            ScreenTools.defaultFontPixelWidth * 0.6

            RowLayout {
                Layout.fillWidth: true
                spacing:          ScreenTools.defaultFontPixelWidth

                QGCTextField {
                    id:                 valueField
                    Layout.fillWidth:   compactValueDetails
                    Layout.preferredWidth: compactValueDetails ? -1 : _editFieldWidth
                    width:              compactValueDetails ? implicitWidth : _editFieldWidth
                    unitsLabel:         fact.units
                    showUnits:          fact.units != ""
                    focus:              setFocus && visible
                    activeFocusBorderColor: root._accentGreen
                    fieldTextColor:     root._titleColor
                    inputMethodHints:   (fact.typeIsString || ScreenTools.isiOS) ?
                                            Qt.ImhNone :
                                            Qt.ImhFormattedNumbersOnly
                    visible:            !_showCombo || validate || manualEntry.checked
                }

                QGCComboBox {
                    id:             factCombo
                    Layout.fillWidth: compactValueDetails
                    width:          compactValueDetails ? implicitWidth : _editFieldWidth
                    model:          fact.enumStrings
                    sizeToContents: true
                    visible:        _showCombo
                    focus:          setFocus && visible

                    Component.onCompleted: {
                        if (_showCombo) {
                            currentIndex = fact.enumIndex
                        }
                    }

                    onCurrentIndexChanged: {
                        if (currentIndex >=0 && currentIndex < model.length) {
                            valueField.text = fact.enumValues[currentIndex]
                        }
                    }
                }

                // Full editor keeps Reset inline; compact puts it on the next row.
                QGCButton {
                    visible:    _allowDefaultReset && !compactValueDetails
                    text:       qsTr("Reset To Default")
                    primary:    true
                    backgroundColor: root._accentGreen
                    textColor:  "white"
                    showBorder: false
                    backRadius: root._controlRadius

                    onClicked: {
                        fact.value = fact.defaultValue
                        fact.valueChanged(fact.value)
                        close()
                    }
                }
            }

            QGCButton {
                Layout.fillWidth:   true
                visible:            _allowDefaultReset && compactValueDetails
                text:               qsTr("Reset To Default")
                primary:            true
                backgroundColor:    root._accentGreen
                textColor:          "white"
                showBorder:         false
                backRadius:         root._controlRadius

                onClicked: {
                    fact.value = fact.defaultValue
                    fact.valueChanged(fact.value)
                    close()
                }
            }
        }

        Column {
            id:         bitmaskColumn
            spacing:    ScreenTools.defaultFontPixelHeight / 2
            visible:    !compactValueDetails && fact.bitmaskStrings.length > 0

            Repeater {
                id:     bitmaskRepeater
                model:  fact.bitmaskStrings

                delegate : QGCCheckBox {
                    text : modelData
                    textColor: root._titleColor
                    uncheckedBorderColor: root._cardBorderIdle
                    checked : fact.value & fact.bitmaskValues[index]

                    onClicked: {
                        valueField.text = bitmaskValue()
                    }
                }
            }
        }

        QGCLabel {
            id:                 longDescriptionLabel
            Layout.fillWidth:   true
            wrapMode:           Text.WordWrap
            visible:            !compactValueDetails && fact.longDescription != ""
            text:               fact.longDescription
            color:              root._titleColor
        }

        Flow {
            Layout.fillWidth:   true
            spacing:            ScreenTools.defaultFontPixelWidth

            QGCLabel {
                id:         minValueDisplay
                text:       qsTr("Min: ") + fact.minString
                visible:    !fact.minIsDefaultForType
                color:      root._bodyColor
            }

            QGCLabel {
                text:       qsTr("Max: ") + fact.maxString
                visible:    !fact.maxIsDefaultForType
                color:      root._bodyColor
            }

            QGCLabel {
                text:       qsTr("Default: ") + fact.defaultValueString
                visible:    _allowDefaultReset
                color:      root._bodyColor
            }
        }

        QGCLabel {
            visible:    !compactValueDetails && fact.vehicleRebootRequired
            text:       qsTr("Vehicle reboot required after change")
            color:      root._titleColor
        }

        QGCLabel {
            visible:    !compactValueDetails && fact.qgcRebootRequired
            text:       qsTr("Application restart required after change")
            color:      root._titleColor
        }

        QGCLabel {
            Layout.fillWidth:   true
            wrapMode:   Text.WordWrap
            text:       qsTr("Warning: Modifying values while vehicle is in flight can lead to vehicle instability and possible vehicle loss. ") +
                        qsTr("Make sure you know what you are doing and double-check your values before Save!")
            visible:    !compactValueDetails && fact.componentId != -1
            color:      root._titleColor
        }

        QGCCheckBox {
            id:         forceSave
            visible:    false
            text:       qsTr("Force save (dangerous!)")
            textColor:  root._titleColor
            uncheckedBorderColor: root._cardBorderIdle
        }

        QGCCheckBox {
            id:         _advanced
            text:       qsTr("Advanced settings")
            visible:    !compactValueDetails && (showRCToParam || factCombo.visible || bitmaskColumn.visible)
            textColor:  root._titleColor
            uncheckedBorderColor: root._cardBorderIdle
        }

        // Checkbox to allow manual entry of enumerated or bitmask parameters
        QGCCheckBox {
            id:         manualEntry
            visible:    _advanced.checked && (factCombo.visible || bitmaskColumn.visible)
            text:       qsTr("Manual Entry")
            textColor:  root._titleColor
            uncheckedBorderColor: root._cardBorderIdle

            onClicked: {
                valueField.text = fact.valueString
            }
        }

        QGCButton {
            text:       qsTr("Set RC to Param")
            visible:    _advanced.checked && !validate && showRCToParam
            primary:    true
            backgroundColor: root._accentGreen
            textColor:  "white"
            showBorder: false
            backRadius: root._controlRadius
            onClicked:  rcToParamDialog.createObject(mainWindow).open()
        }
    } // Column

    Component {
        id: rcToParamDialog

        RCToParamDialog {
            tuningFact: fact
        }
    }
}
