// RGB lighting: OpenRGB profiles + a brightness that works whatever the
// profile is, through the `rgb` script (dotfiles-bin). The script talks
// to the OpenRGB server over its SDK; see its header for how brightness is
// applied (a scaled copy of the profile, loaded as `_live`).
//
// Every brightness change reloads the profile, which restarts its effect, so
// slider moves are coalesced and only the last one is sent.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property var    profiles: []
    property string active: ""
    property string lastOn: ""
    property int    brightness: 100
    property bool   available: false

    readonly property bool on: active !== "" && active !== "off"

    readonly property string tool: Quickshell.env("HOME") + "/.local/bin/rgb"

    function refresh() {
        if (!_status.running) _status.running = true
    }

    function setProfile(name) {
        root.active = name
        _run([root.tool, "set", name])
    }

    function toggle() {
        if (root.on) root.active = "off"
        else if (root.lastOn !== "") root.active = root.lastOn
        _run([root.tool, "toggle"])
    }

    // Shows the running OpenRGB GUI's window rather than starting another.
    function openGui() {
        Quickshell.execDetached([root.tool, "gui"])
    }

    function setBrightness(pct) {
        root.brightness = Math.round(pct)
        _brightnessDebounce.restart()
    }

    // One command at a time: killing `rgb` mid-upload would leave the
    // server half-switched, so a command issued meanwhile waits its turn
    // (replacing any other that was waiting).
    property var _pending: null

    function _run(cmd) {
        if (_act.running) { root._pending = cmd; return }
        _act.command = cmd
        _act.running = true
    }

    property Timer _brightnessDebounce: Timer {
        interval: 250
        onTriggered: root._run([root.tool, "brightness", String(root.brightness)])
    }

    property Process _act: Process {
        onExited: {
            var next = root._pending
            root._pending = null
            if (next) root._run(next)
            else root.refresh()
        }
    }

    property Process _status: Process {
        command: [root.tool, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var s = JSON.parse(text)
                    root.profiles = s.profiles
                    root.active = s.active
                    root.lastOn = s.lastOn
                    // Don't yank the slider back while a change is pending.
                    if (!root._brightnessDebounce.running && !root._act.running && !root._pending)
                        root.brightness = s.brightness
                    root.available = true
                } catch (e) {
                    root.available = false
                }
            }
        }
        onExited: function (code) { if (code !== 0) root.available = false }
    }
}
