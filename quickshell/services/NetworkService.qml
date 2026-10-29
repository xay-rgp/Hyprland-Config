// Network state via nmcli. Quickshell has no NetworkManager service, so this
// polls `nmcli` — the same source the eww scripts used, just without the
// bash+jq round trip.
//
// Polls only while something is listening: the bar always is, so the interval
// is kept modest and the command is cheap (`-t -f` terse output).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

QtObject {
    id: root

    // wlan | ethernet | none
    property string kind: "none"
    property bool   connected: false
    property string ssid: ""
    property int    strength: 0        // 0-100
    property bool   wifiEnabled: true
    property string ip: ""

    // Per-link state, independent of which one is primary, for the network
    // page's Ethernet / Wi-Fi tiles.
    property string ethDevice: ""       // first NM-managed ethernet device
    property bool   ethConnected: false
    property bool   wifiConnected: false
    property string wifiSsid: ""

    readonly property string glyph: {
        // U+F0200 (md-ethernet) as a surrogate pair; the old FA5 \uf6ff
        // network-wired glyph is not in Nerd Fonts v3 and rendered as a box.
        if (kind === "ethernet") return "\udb80\ude00"    // ethernet
        if (!wifiEnabled)        return "\uf05e"          // disabled
        if (!connected)          return "\uf1eb"          // dimmed via `color`
        if (strength >= 75)      return "\uf1eb"          // full
        if (strength >= 50)      return "\uf1eb"
        if (strength >= 25)      return "\uf1eb"
        return "\uf1eb"
    }

    readonly property color color: connected ? Theme.text : Theme.inactive

    // ── Poll ────────────────────────────────────────────────────────────────
    property string _buf: ""

    property Process _poll: Process {
        command: [
            "bash", "-c",
            // NOTE: `-f ... IN-USE` is NOT a valid field for `dev status` — it
            // makes the whole command fail, which silently reported kind=none
            // while ethernet was connected. Allowed fields are
            // DEVICE,TYPE,STATE,CONNECTION only (verified).
            "nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev status 2>/dev/null; " +
            "echo '---'; " +
            "nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID dev wifi list 2>/dev/null | head -30; " +
            "echo '---'; " +
            "nmcli -t -f WIFI general 2>/dev/null; " +
            "echo '---'; " +
            // Only physical-ish interfaces; docker/bridge/tun noise excluded.
            "ip -4 -o addr show scope global 2>/dev/null | " +
            "grep -E ' (eno|eth|wlan|wlp|enp)[0-9]' | awk '{print $2, $4}'"
        ]
        stdout: SplitParser {
            onRead: function (line) { root._buf += line + "\n" }
        }
        onExited: {
            root._parse(root._buf)
            root._buf = ""
        }
    }

    property Timer _timer: Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!root._poll.running) root._poll.running = true
        }
    }

    function refresh() {
        if (!_poll.running) _poll.running = true
    }

    function _parse(raw) {
        var sections = raw.split("---\n")
        var devs = sections[0] || ""
        var wifi = sections[1] || ""
        var gen  = sections[2] || ""
        var addrs = sections[3] || ""

        // dev status columns: DEVICE:TYPE:STATE:CONNECTION. Match the state
        // exactly — "connected (externally)" is a different string, and the
        // docker/bridge/tun interfaces carry it, so a substring test would
        // wrongly report those as the primary link.
        var eth = false, wlan = false
        var ethDev = "", wlanDev = ""
        var anyEthDev = ""
        var lines = devs.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var parts = lines[i].split(":")
            if (parts.length < 3) continue
            var dev = parts[0], type = parts[1], state = parts[2]
            // Docker's veth* pairs are ethernet too, but "unmanaged"; the
            // tile wants the real NIC even while it's disconnected.
            if (type === "ethernet" && state !== "unmanaged" && anyEthDev === "")
                anyEthDev = dev
            if (state !== "connected") continue
            if (type === "ethernet" && !eth) { eth = true; ethDev = dev }
            if (type === "wifi" && !wlan)     { wlan = true; wlanDev = dev }
        }

        // Ethernet wins when both are up: it's the stable link, and it's what
        // a user means by "the network" on a machine plugged in at a desk.
        if (eth) {
            root.kind = "ethernet"
            root.connected = true
            root.ssid = ""
            root.strength = 100
        } else if (wlan) {
            root.kind = "wifi"
            root.connected = true
        } else {
            root.kind = "none"
            root.connected = false
            root.ssid = ""
            root.strength = 0
        }

        root.ethDevice = eth ? ethDev : anyEthDev
        root.ethConnected = eth
        root.wifiConnected = wlan
        root.wifiSsid = ""
        if (wlan) {
            var rows = wifi.split("\n")
            for (var r = 0; r < rows.length; r++) {
                if (rows[r].charAt(0) !== "*" && !rows[r].startsWith("yes")) continue
                var rc = rows[r].split(":")
                if (rc.length >= 4) root.wifiSsid = rc.slice(3).join(":").trim()
                break
            }
        }

        // Only take the wifi SSID/signal when wifi is the primary link. This
        // previously ran unconditionally, so on an ethernet-primary machine the
        // card read "YDSG / ethernet / 88%" — the SSID and signal bled in
        // from wlan0 while the kind came from eno1.
        if (!eth) {
            // Active wifi row is `IN-USE:SIGNAL:SECURITY:SSID`, e.g. `*:89:WPA2:YDSG`.
            // The SSID is column index 3, NOT 2 — parsing from index 2 previously
            // produced `ssid='WPA2:YDSG'` (security folded into the name).
            var wlines = wifi.split("\n")
            for (var j = 0; j < wlines.length; j++) {
                var wline = wlines[j]
                if (wline.charAt(0) !== "*" && !wline.startsWith("yes"))
                    continue
                var cols = wline.split(":")
                if (cols.length >= 4) {
                    var sig = parseInt(cols[1], 10)
                    if (!isNaN(sig))
                        root.strength = sig
                    // The SSID may itself contain ':' — rejoin everything after
                    // the security column so a colon in the name survives.
                    root.ssid = cols.slice(3).join(":").trim()
                }
                break
            }
        }

        var gl = gen.split("\n")
        for (var k = 0; k < gl.length; k++) {
            if (gl[k].indexOf("enabled") === 0) root.wifiEnabled = true
            else if (gl[k].indexOf("disabled") === 0) root.wifiEnabled = false
        }

        // Prefer the address on the interface we decided is primary.
        var wantDev = eth ? ethDev : wlanDev
        var al = addrs.split("\n")
        root.ip = ""
        for (var m = 0; m < al.length; m++) {
            var bits = al[m].trim().split(/\s+/)
            if (bits.length < 2) continue
            if (wantDev === "" || bits[0] === wantDev) {
                root.ip = bits[1].split("/")[0]
                if (bits[0] === wantDev) break
            }
        }
    }

    // ── Actions ─────────────────────────────────────────────────────────────
    property Process _act: Process {
    }

    function _run(args) {
        _act.command = args
        _act.running = false
        _act.running = true
        refresh()
    }

    function toggleWifi() {
        _run(["nmcli", "radio", "wifi", wifiEnabled ? "off" : "on"])
    }

    // "Disable" ethernet by disconnecting the device; NetworkManager then
    // leaves it down until it is connected again.
    function toggleEthernet() {
        if (ethDevice === "") return
        _run(["nmcli", "device", ethConnected ? "disconnect" : "connect", ethDevice])
    }

    function connect(ssidName, password) {
        if (password && password !== "")
            _run(["nmcli", "dev", "wifi", "connect", ssidName, "password", password])
        else
            _run(["nmcli", "dev", "wifi", "connect", ssidName])
    }

    function disconnect() {
        _run(["nmcli", "dev", "disconnect", "ifname", "*"])
    }

    property var networks: []
    readonly property bool _netPollRunning: _netPoll.running
    property string _netBuf: ""

    property Process _netPoll: Process {
        command: ["bash", "-c",
            "nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID dev wifi list 2>/dev/null"]
        stdout: SplitParser {
            onRead: function (line) { root._netBuf += line + "\n" }
        }
        onExited: {
            var out = []
            var lines = root._netBuf.split("\n")
            var seen = ({})
            for (var i = 0; i < lines.length; i++) {
                if (lines[i].trim() === "") continue
                var c = lines[i].split(":")
                if (c.length < 4) continue
                // Columns: IN-USE:SIGNAL:SECURITY:SSID — name is index 3+.
                var ssidName = c.slice(3).join(":").trim()
                // Empty SSID = hidden network; skip it.
                if (ssidName === "" || seen[ssidName]) continue
                seen[ssidName] = true
                out.push({
                    inUse:    c[0].indexOf("*") !== -1 || c[0] === "yes",
                    strength: parseInt(c[1], 10) || 0,
                    security: c[2].trim(),
                    ssid:     ssidName
                })
            }
            out.sort(function (a, b) { return b.strength - a.strength })
            root.networks = out
            root._netBuf = ""
        }
    }

    function scanNetworks() {
        if (!_netPoll.running) _netPoll.running = true
    }
}
