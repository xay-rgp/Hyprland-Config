// Bluetooth via bluetoothctl. Same CLI the eww scripts drove.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

QtObject {
    id: root

    property bool powered: false
    property bool available: true
    property bool scanning: false
    property var  devices: []          // { mac, name, connected, paired }
    property var  connected: []

    readonly property int connectedCount: connected.length

    readonly property string glyph: {
        if (!powered) return "\uf293"
        if (connectedCount > 0) return "\uf293"
        return "\uf293"
    }

    readonly property color color: {
        if (!powered) return Theme.inactive
        if (connectedCount > 0) return Theme.accent
        return Theme.text
    }

    // ── Poll ────────────────────────────────────────────────────────────────
    property string _buf: ""

    property Process _poll: Process {
        command: [
            "bash", "-c",
            "command -v bluetoothctl >/dev/null || exit 0; " +
            "bluetoothctl show 2>/dev/null | grep -E 'Powered|Discoverable' ; " +
            "echo '---'; " +
            "bluetoothctl devices 2>/dev/null; " +
            "echo '---'; " +
            "bluetoothctl devices Connected 2>/dev/null; " +
            "echo '---'; " +
            "bluetoothctl devices Paired 2>/dev/null"
        ]
        stdout: SplitParser {
            onRead: function (line) { root._buf += line + "\n" }
        }
        onExited: { root._parse(root._buf); root._buf = "" }
    }

    property Timer _timer: Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!root._poll.running) root._poll.running = true
    }

    function refresh() {
        if (!_poll.running) _poll.running = true
    }

    function _macs(section) {
        var out = {}
        var lines = section.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var m = lines[i].match(/Device\s+([0-9A-F:]{17})\s*(.*)/i)
            if (m) out[m[1].toUpperCase()] = (m[2] || "").trim()
        }
        return out
    }

    function _parse(raw) {
        var s = raw.split("---\n")
        var show = s[0] || "", all = s[1] || "", conn = s[2] || "", paired = s[3] || ""

        root.powered = /Powered:\s+yes/i.test(show)

        var allDevs = _macs(all)
        var connDevs = _macs(conn)
        var pairDevs = _macs(paired)

        var list = []
        for (var mac in allDevs) {
            list.push({
                mac: mac,
                name: allDevs[mac] || mac,
                connected: connDevs[mac] !== undefined,
                paired: pairDevs[mac] !== undefined
            })
        }
        // Connected first, then paired, then the rest.
        list.sort(function (a, b) {
            if (a.connected !== b.connected) return a.connected ? -1 : 1
            if (a.paired !== b.paired) return a.paired ? -1 : 1
            return a.name.localeCompare(b.name)
        })
        root.devices = list
        root.connected = list.filter(function (d) { return d.connected })
    }

    // ── Actions ─────────────────────────────────────────────────────────────
    property string _action: ""
    property bool _scanStopRequested: false

    property Process _act: Process {
        onExited: {
            if (root._action === "scan" && root._scanStopRequested) {
                root._scanStopRequested = false
                root.scanning = false
            }
            root._action = ""
            root.refresh()
        }
    }

    function _run(args, action) {
        _action = action || ""
        _act.command = args
        _act.running = false
        _act.running = true
    }

    function togglePower() {
        setPower(!powered)
    }

    function setPower(value) {
        if (!available || powered === value) return
        if (!value && scanning) {
            scanning = false
            _scanStopRequested = true
        }
        _run(["bluetoothctl", "power", value ? "on" : "off"])
    }

    function setScan(value) {
        if (!powered || scanning === value) return
        scanning = value
        _scanStopRequested = !value
        _run(["bluetoothctl", "scan", value ? "on" : "off"], "scan")
    }

    function connectDevice(mac) {
        _run(["bluetoothctl", "connect", mac])
    }

    function disconnectDevice(mac) {
        _run(["bluetoothctl", "disconnect", mac])
    }

    function pair(mac) {
        _run(["bash", "-c", "bluetoothctl pair " + mac + " && bluetoothctl trust " + mac])
    }

    function scan() {
        setScan(true)
    }
}
