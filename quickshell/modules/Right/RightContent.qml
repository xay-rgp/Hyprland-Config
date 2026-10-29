// Network and volume status; no avatar or placeholder slot.
import QtQuick
import Quickshell
import "../../theme"
import "../../state"
import "../../services"
import "../../components"

Item {
    id: root

    readonly property bool active: ShellState.controlCenterOpen

    implicitWidth: row.implicitWidth
    implicitHeight: 24

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
             : hover.hovered ? Theme.hover
             : "transparent"

        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 10

        // ── Network: ethernet or wifi glyph, dimmed when offline ────────────
        Glyph {
            text: NetworkService.kind === "ethernet" ? "LAN" : NetworkService.glyph
            font.pixelSize: NetworkService.kind === "ethernet" ? Theme.fontSizeSmall : Theme.fontSizeLarge
            color_: NetworkService.color
        }

        // ── Volume + percentage ─────────────────────────────────────────────
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Glyph {
                text: AudioService.glyph
                color_: AudioService.muted ? Theme.inactive : Theme.text
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: AudioService.volumePercent + "%"
                color: AudioService.muted ? Theme.inactive : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
        }

    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: ShellState.toggle("controlCenter")
    }

    // Scroll anywhere on the pill for volume.
    WheelHandler {
        onWheel: function (e) { AudioService.adjustVolume(e.angleDelta.y > 0 ? 0.05 : -0.05) }
    }

    component Glyph: Icon {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        font.pixelSize: Theme.fontSizeLarge
    }
}
