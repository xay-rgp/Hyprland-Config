import QtQuick
import QtQuick.Controls.Basic
import "../../theme"

MenuItem {
    id: root
    implicitWidth: 240
    implicitHeight: 30
    leftPadding: 32
    rightPadding: 26
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSizeSmall

    background: Rectangle {
        radius: Theme.cornerRadiusSmall / 2
        color: root.highlighted ? Theme.hover : "transparent"
        Behavior on color {
            ColorAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
        }
    }
    contentItem: Text {
        text: root.text.replace(/&&/g, "\u0000").replace(/&/g, "").replace(/\u0000/g, "&")
        textFormat: Text.PlainText
        font: root.font
        color: root.enabled ? Theme.text : Theme.inactive
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: Text {
        x: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.checked ? "✓" : ""
        color: root.enabled ? Theme.text : Theme.inactive
        font: root.font
    }
    Image {
        x: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        source: root.icon.source
        sourceSize: Qt.size(32, 32)
        visible: !root.checkable && source.toString() !== ""
        opacity: root.enabled ? 1 : 0.35
    }
    arrow: Text {
        x: root.width - width - 10
        anchors.verticalCenter: parent.verticalCenter
        text: "›"
        visible: root.subMenu !== null
        color: root.enabled ? Theme.text : Theme.inactive
        font.pixelSize: 18
    }
}
