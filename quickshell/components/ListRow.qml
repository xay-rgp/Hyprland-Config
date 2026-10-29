// A selectable list row: optional leading glyph, title, optional subtitle,
// optional trailing status text, hover + click.
import QtQuick
import "../theme"
import "../components"

Rectangle {
    id: root

    property string glyph: ""
    property string title: ""
    property string subtitle: ""
    property string trailing: ""
    property bool   selected: false
    property bool   dimmed: false
    property bool   leadingActive: false
    property color  glyphColor: Theme.text

    signal activated()

    width: parent ? parent.width : 0
    height: 44
    radius: Theme.cornerRadiusSmall
    color: selected ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
         : hover.hovered ? Theme.hover
         : "transparent"

    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    Row {
        anchors {
            left: parent.left;  leftMargin: 10
            right: parent.right; rightMargin: 10
            verticalCenter: parent.verticalCenter
        }
        spacing: 10

        Icon {
            visible: root.glyph !== ""
            text: root.glyph
            color_: root.leadingActive ? Theme.accent : root.glyphColor
            font.pixelSize: Theme.fontSizeLarge
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - trailingText.width - 20
            spacing: 1

            Text {
                width: parent.width
                text: root.title
                color: root.dimmed ? Theme.inactive : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: root.subtitle
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }
        }

        Text {
            id: trailingText
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            text: root.trailing
            color: root.selected ? Theme.accent : Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: root.activated() }
}
