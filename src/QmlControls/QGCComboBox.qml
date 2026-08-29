import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Templates as T

import QGroundControl
import QGroundControl.Controls

T.ComboBox {
    id:             control
    padding:        ScreenTools.comboBoxPadding * (compact ? 0.7 : 1.0)
    spacing:        ScreenTools.defaultFontPixelWidth * (compact ? 0.5 : 0.85)
    font.pointSize: compact ? ScreenTools.smallFontPointSize : ScreenTools.defaultFontPointSize
    font.family:    ScreenTools.normalFontFamily
    implicitWidth:  Math.max(background ? background.implicitWidth : 0,
                             contentItem.implicitWidth + leftPadding + rightPadding + padding)
    implicitHeight: Math.max(ScreenTools.defaultFontPixelHeight * (compact ? 1.45 : 1.75),
                             Math.max(contentItem.implicitHeight, indicator ? indicator.implicitHeight : 0) + topPadding + bottomPadding)
    baselineOffset: contentItem.y + text.baselineOffset
    leftPadding:    padding + (!control.mirrored || !indicator || !indicator.visible ? 0 : indicator.width + spacing)
    rightPadding:   padding + (control.mirrored || !indicator || !indicator.visible ? 0 : indicator.width)

    property bool   centeredLabel:  false
    property bool   sizeToContents: false
    property bool   compact:        false
    property bool   lightStyle:     false
    property string alternateText:  ""

    property real   _popupWidth:    width
    property bool   _onCompleted:   false
    property bool   _showBorder:    qgcPal.globalTheme === QGCPalette.Light
    property bool   _showHighlight: enabled && pressed

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    TextMetrics {
        id:                 textMetrics
        font.family:        control.font.family
        font.pointSize:     control.font.pointSize
    }

    ItemDelegate {
        id:             itemDelegateMetrics
        visible:        false
        font.family:    control.font.family
        font.pointSize: control.font.pointSize
    }

    function _calcPopupWidth() {
        if (_onCompleted && sizeToContents && model) {
            var largestTextWidth = 0
            for (var i = 0; i < model.length; i++){
                textMetrics.text = control.textRole ? model[i][control.textRole] : model[i]
                largestTextWidth = Math.max(textMetrics.width, largestTextWidth)
            }
            _popupWidth = largestTextWidth + itemDelegateMetrics.leftPadding + itemDelegateMetrics.rightPadding
        }
    }

    onModelChanged: _calcPopupWidth()

    Component.onCompleted: {
        _onCompleted = true
        _calcPopupWidth()
    }

    // The items in the popup
    delegate: ItemDelegate {
        width:  _popupWidth
        height: Math.round(popupItemMetrics.height * 1.75)

        property string _text: control.textRole ?
                                    (model.hasOwnProperty(control.textRole) ? model[control.textRole] : modelData[control.textRole]) :
                                    modelData

        TextMetrics {
            id:             popupItemMetrics
            font:           control.font
            text:           _text
        }

        contentItem: Text {
            text:                   _text
            font:                   control.font
            color:                  control.currentIndex === index
                                    ? "#ffffff"
                                    : (control.lightStyle ? "#343434" : qgcPal.buttonText)
            verticalAlignment:      Text.AlignVCenter
        }

        background: Rectangle {
            color:                  control.currentIndex === index
                                    ? "#00a651"
                                    : (control.lightStyle ? "#f3f3f3" : qgcPal.button)
        }

        highlighted:                control.highlightedIndex === index
    }

    // Closed combo: green idle, gray hover on Custom Mission / Light theme
    readonly property bool _customMission: typeof mainWindow !== "undefined"
                                           && mainWindow
                                           && mainWindow.customMissionStyleActive
    readonly property bool _selectedLook: lightStyle || _customMission || qgcPal.globalTheme === QGCPalette.Light
    readonly property color _accentGreen: "#00a651"
    readonly property color _hoverGray: "#e8e8e8"
    readonly property bool _hoverGrayLook: _selectedLook && control.enabled && control.hovered && !control.pressed

    // The label of the button
    contentItem: QGCLabel {
        id:                         text
        verticalAlignment:          Text.AlignVCenter
        horizontalAlignment:        centeredLabel ? Text.AlignHCenter : Text.AlignLeft
        text:                       control.alternateText === "" ? control.currentText : control.alternateText
        font:                       control.font
        color: {
            if (control._hoverGrayLook)
                return "#3f3f3f"
            if (control._selectedLook || control._showHighlight)
                return "#ffffff"
            return qgcPal.buttonText
        }
    }

    background: Item {
        implicitWidth:  ScreenTools.implicitComboBoxWidth
        implicitHeight: ScreenTools.implicitComboBoxHeight

        Rectangle {
            anchors.fill:   parent
            color: {
                if (control._hoverGrayLook)
                    return control._hoverGray
                if (control._showHighlight || control._selectedLook)
                    return control._accentGreen
                return qgcPal.button
            }
            border.width:   0
            radius:         ScreenTools.defaultBorderRadius * 2

            Behavior on color { ColorAnimation { duration: 120 } }
        }

        RippleEffect {
            id: comboRipple
            rippleColor: control._hoverGrayLook
                         ? Qt.rgba(0, 0, 0, 0.14)
                         : Qt.rgba(1, 1, 1, 0.38)
            clipRadius: ScreenTools.defaultBorderRadius * 2
        }

        Connections {
            target: control
            function onPressedChanged() {
                if (control.pressed)
                    comboRipple.tap(control.pressX, control.pressY)
            }
        }
    }

    indicator: QGCColoredImage {
        anchors.rightMargin:    control.padding
        anchors.right:          parent.right
        anchors.verticalCenter: parent.verticalCenter
        height:                 ScreenTools.defaultFontPixelWidth * 1.1
        width:                  height
        source:                 "/qmlimages/arrow-down.png"
        color: {
            if (control._hoverGrayLook)
                return "#3f3f3f"
            if (control._selectedLook || control._showHighlight)
                return "#ffffff"
            return qgcPal.buttonText
        }
    }

    popup: T.Popup {
        x:              control.width - _popupWidth
        y:              control.height
        width:          _popupWidth
        height:         Math.min(contentItem.implicitHeight, control.Window.height - topMargin - bottomMargin)
        topMargin:      6
        bottomMargin:   6

        contentItem: ListView {
            clip:                   true
            implicitHeight:         contentHeight
            model:                  control.delegateModel
            currentIndex:           control.highlightedIndex
            highlightMoveDuration:  0
        }

        background: Rectangle {
            color:          control.lightStyle ? "#ffffff" : qgcPal.window
            border.width:   control.lightStyle ? 1 : 0
            border.color:   control.lightStyle ? "#dedede" : "transparent"
            radius:         ScreenTools.defaultBorderRadius
        }
    }
}
