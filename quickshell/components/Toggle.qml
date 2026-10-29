// Pill switch used by the Customise tab.
import QtQuick
import "../theme"

Rectangle {
    id: root

    property bool checked: false
    property color accentColor: Theme.accent

    signal toggled(bool value)

    implicitWidth: 40
    implicitHeight: 22
    radius: height / 2
    color: checked ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.85)
         : hover.hovered ? Theme.hover
         : Theme.surface
    border.width: 1
    border.color: checked ? "transparent"
                : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.10)

    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    Rectangle {
        id: knob
        width: 16
        height: 16
        radius: height / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - width - 3 : 3
        color: root.checked ? Theme.base : Theme.subtext0

        Behavior on x { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }

    TapHandler {
        onTapped: root.toggled(!root.checked)
    }
}
