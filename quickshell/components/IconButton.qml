// Clickable icon button: themed hover/active background with an optional
// glyph and label. Used by popups for mute toggles, power switches and
// similar.
import QtQuick
import "../theme"

Rectangle {
    id: root

    property string glyph: ""
    property string label: ""

    // Fixed square when > 0, otherwise sized to content.
    property int    size: 0

    property bool   hovered: hover.hovered
    property bool   active: false
    property color  activeColor: Theme.accent
    property color  glyphColor: Theme.text
    property int    glyphSize: Theme.fontSize
    property int    radius_: height / 2

    signal activated()

    implicitWidth: size > 0 ? size : content.implicitWidth + 16
    implicitHeight: size > 0 ? size : 26

    radius: radius_
    color: active ? Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.18)
         : hovered ? Theme.hover
         : "transparent"

    Behavior on color {
        ColorAnimation { duration: Theme.animFast }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 6

        Icon {
            visible: root.glyph !== ""
            text: root.glyph
            color_: root.active ? root.activeColor : root.glyphColor
            font.pixelSize: root.glyphSize
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: root.label !== ""
            text: root.label
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: root.activated()
    }
}
