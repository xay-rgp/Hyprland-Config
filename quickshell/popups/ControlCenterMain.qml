// Control center: network, audio, Bluetooth and volume.
import QtQuick
import "../theme"
import "../state"
import "../services"
import "../components"

Item {
    id: root

    implicitWidth: Theme.ccWidth
    implicitHeight: column.implicitHeight + Theme.ccPadding * 2

    Column {
        id: column
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: Theme.ccPadding
        }
        spacing: 10

        // Three equally sized controls.
        readonly property real cellWidth: (width - spacing * 2) / 3

        // ── Header ──────────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 36

            IconButton {
                id: close
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                size: 34
                glyph: ""
                glyphSize: 14
                color: hovered ? Theme.hover : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.06)
                onActivated: ShellState.closeAll()
            }

            Text {
                anchors { left: close.right; leftMargin: 12; right: parent.right
                          verticalCenter: parent.verticalCenter }
                text: "Control Center"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 17
                elide: Text.ElideRight
            }
        }

        // ── Quick tiles ─────────────────────────────────────────────────────
        Row {
            width: parent.width
            spacing: 10

            QuickTile {
                id: wifi
                width: column.cellWidth
                glyph: NetworkService.glyph
                title: NetworkService.kind === "ethernet" ? "Ethernet" : "Wi-Fi"
                subtitle: {
                    if (NetworkService.kind === "ethernet")
                        return NetworkService.ip !== "" ? NetworkService.ip : "Connected"
                    if (!NetworkService.wifiEnabled) return "Off"
                    return NetworkService.connected ? NetworkService.ssid : "Not connected"
                }
                active: NetworkService.connected
                onToggled: NetworkService.toggleWifi()
                onOpened: ShellState.showPage("network")
            }

            QuickTile {
                width: column.cellWidth
                glyph: AudioService.glyph
                title: "Audio"
                subtitle: AudioService.muted ? "Muted" : (AudioService.sinkName || "No output")
                active: !AudioService.muted
                onToggled: AudioService.toggleMute()
                onOpened: ShellState.showPage("audio")
            }

            QuickTile {
                width: column.cellWidth
                glyph: BluetoothService.glyph
                title: "Bluetooth"
                subtitle: {
                    if (!BluetoothService.powered) return "Off"
                    var c = BluetoothService.connected
                    if (c.length === 0) return "On"
                    return c[0].name + (c.length > 1 ? " +" + (c.length - 1) : "")
                }
                active: BluetoothService.powered
                onToggled: BluetoothService.togglePower()
                onOpened: ShellState.showPage("bluetooth")
            }

        }

        // ── Volume ──────────────────────────────────────────────────────────
        PillSlider {
            width: parent.width
            height: 40
            glyph: AudioService.glyph
            value: AudioService.volume
            fillColor: AudioService.muted ? Theme.overlay1 : Theme.accent
            onMoved: function (v) { AudioService.setVolume(v) }
            onGlyphClicked: AudioService.toggleMute()
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
        }
    }

}
