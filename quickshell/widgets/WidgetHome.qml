// The island's home: a grid of every non-hidden Registry widget. Click, or arrow keys
// + Enter, to open one; Escape from that widget comes back here. Above it, a
// header: the user's ~/.face, user@host, and how long the machine has been up.
import QtQuick
import Quickshell.Widgets
import "../theme"
import "../services"
import "../state"
import "../components"
import "."

Item {
    id: root

    property bool active: false

    readonly property int columns: 5
    readonly property int cellWidth: 176
    readonly property int cellHeight: 88
    readonly property int pad: 14
    readonly property int rows: Math.ceil(Registry.pickable.length / columns)

    implicitWidth:  columns * cellWidth + pad * 2
    implicitHeight: header.height + 8 + 12 + rows * cellHeight + pad * 2

    onActiveChanged: if (active) {
        grid.currentIndex = 0
        grid.forceActiveFocus()
        SystemService.refresh()
    }

    // ── Header ──────────────────────────────────────────────────────────────
    Column {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: root.pad }
        anchors.topMargin: root.pad + 8
        spacing: 4

        ClippingRectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 104
            height: width
            radius: width / 2
            color: Theme.hover

            Image {
                id: face
                anchors.fill: parent
                source: SystemService.face
                sourceSize: Qt.size(208, 208)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            // No ~/.face: fall back to the user's initial.
            Text {
                anchors.centerIn: parent
                visible: face.status !== Image.Ready
                text: SystemService.user.charAt(0).toUpperCase()
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: 40
                font.bold: true
            }
        }

        Item { width: 1; height: 6 }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: SystemService.user + (SystemService.host !== "" ? "@" + SystemService.host : "")
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLarge
            font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Running since " + SystemService.uptime
            visible: SystemService.uptimeSec > 0
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    GridView {
        id: grid
        anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        anchors.margins: root.pad
        anchors.topMargin: 12
        cellWidth: root.cellWidth
        cellHeight: root.cellHeight
        interactive: false
        focus: root.active
        keyNavigationWraps: true
        model: Registry.pickable

        Keys.onPressed: function (event) {
            var k = event.key
            if (k === Qt.Key_H)      moveCurrentIndexLeft()
            else if (k === Qt.Key_L) moveCurrentIndexRight()
            else if (k === Qt.Key_J) moveCurrentIndexDown()
            else if (k === Qt.Key_K) moveCurrentIndexUp()
            else return
            event.accepted = true
        }
        Keys.onReturnPressed: ShellState.openWidget(Registry.pickable[currentIndex].id, true)
        Keys.onEnterPressed:  ShellState.openWidget(Registry.pickable[currentIndex].id, true)

        delegate: Item {
            id: tile

            required property var modelData
            required property int index

            readonly property bool highlighted: tileHover.hovered
                                                || (grid.activeFocus && grid.currentIndex === index)

            width: grid.cellWidth
            height: grid.cellHeight

            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: Theme.ccCardRadius
                color: tile.highlighted
                       ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
                       : Theme.hover

                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tile.modelData.icon
                        color_: tile.highlighted ? Theme.accent : Theme.text
                        font.pixelSize: 22
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tile.modelData.name
                        color: tile.modelData.source !== "" ? Theme.text : Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            HoverHandler {
                id: tileHover
                cursorShape: Qt.PointingHandCursor
                onHoveredChanged: if (hovered) grid.currentIndex = tile.index
            }
            TapHandler { onTapped: ShellState.openWidget(tile.modelData.id, true) }
        }
    }
}
