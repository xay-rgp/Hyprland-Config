// Screen brightness via brightnessctl.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property int percent: 0
    property bool available: false

    readonly property string glyph: {
        if (percent >= 67) return "\uf185"
        if (percent >= 34) return "\uf185"
        return "\uf186"
    }

    property string _buf: ""

    property Process _poll: Process {
        // `-c backlight` scopes to the backlight class. Without it,
        // brightnessctl lists every led device, and `head -1` picked
        // `input15::scrolllock` (0%) on this desktop — which has no backlight
        // at all. With the class filter it exits non-zero, so the module hides
        // itself, which is the correct outcome on a desktop.
        command: ["bash", "-c",
            "command -v brightnessctl >/dev/null || exit 1; " +
            "brightnessctl -c backlight -m 2>/dev/null | head -1"]
        stdout: SplitParser {
            onRead: function (line) { root._buf = line }
        }
        onExited: function (code) {
            if (code !== 0 || root._buf === "") {
                root.available = false
                return
            }
            // brightnessctl -m format: name,class,current,percent%,max
            var m = root._buf.match(/,([0-9]+)%/)
            if (m) {
                root.percent = parseInt(m[1], 10)
                root.available = true
            } else {
                root.available = false
            }
        }
    }

    property Timer _timer: Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!root._poll.running) root._poll.running = true
    }

    property Process _act: Process {}

    function set(v) {
        if (!available) return
        _act.command = ["brightnessctl", "-c", "backlight", "-e4", "-n2",
                        "set", Math.round(v) + "%"]
        _act.running = false
        _act.running = true
        _poll.running = true
    }

    function adjust(delta) {
        set(Math.max(1, Math.min(100, percent + delta)))
    }
}
