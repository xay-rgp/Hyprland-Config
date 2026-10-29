// A pill of tabs whose accent highlight slides to the current one.
//
//   TabBar {
//       tabs: [{ name: "One", icon: "" }, { name: "Two", icon: "" }]
//       current: 0
//       onSelected: function (i) { ... }
//   }
//
// `icon` is optional, and may be any glyph (Nerd Font or plain Unicode).
import QtQuick
import "../theme"

Rectangle {
    id: root

    property var tabs: []
    property int current: 0

    signal selected(int index)

    width: tabRow.width + 8
    height: 34
    radius: height / 2
    color: Theme.hover

    // Slides to the current tab.
    Rectangle {
        readonly property Item target: tabRepeater.count > root.current
                                       ? tabRepeater.itemAt(root.current) : null
        visible: !!target
        x: target ? tabRow.x + target.x : 0
        y: 4
        width: target ? target.width : 0
        height: parent.height - 8
        radius: height / 2
        color: Theme.accent

        Behavior on x     { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }
    }

    Row {
        id: tabRow
        anchors.centerIn: parent

        Repeater {
            id: tabRepeater
            model: root.tabs

            Item {
                required property var modelData
                required property int index

                readonly property bool chosen: index === root.current

                width: tabContent.implicitWidth + 26
                height: 26

                Row {
                    id: tabContent
                    anchors.centerIn: parent
                    spacing: 7

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !!modelData.icon
                        text: modelData.icon || ""
                        color_: parent.parent.chosen ? Theme.crust : Theme.subtext0
                        font.pixelSize: 12
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name
                        color: parent.parent.chosen ? Theme.crust
                             : tabHover.hovered ? Theme.text : Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: parent.parent.chosen
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }
                }

                HoverHandler { id: tabHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.selected(index) }
            }
        }
    }
}
