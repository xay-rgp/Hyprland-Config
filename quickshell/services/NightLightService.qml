// Night light: hyprsunset's colour temperature, toggled over its IPC socket
// (`hyprctl hyprsunset ...`). hyprsunset itself is started by Hyprland's
// autostart and runs its own day/night profiles (hypr/config/hyprsunset.conf);
// this flips it by hand until the next profile boundary takes over again.
//
// hyprsunset can't report whether it is actually on: after `identity` it
// still answers `temperature` with the old value. So the state is ours —
// seeded from the active profile (`hyprctl hyprsunset profile`), changed by
// toggle(), and re-seeded whenever a different profile becomes active.
pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    readonly property int warmTemperature: 4500

    property bool on: false
    property bool available: false

    property string _profileKey: ""

    function refresh() {
        if (!_read.running) _read.running = true
    }

    function toggle() {
        _set.command = ["bash", "-c", root.on
            ? "hyprctl hyprsunset identity && hyprctl hyprsunset gamma 100"
            : "hyprctl hyprsunset temperature " + root.warmTemperature]
        _set.running = true
        root.on = !root.on
    }

    // Output looks like: Time: 19:00 / Temperature: 5500 / Gamma: 0.8 /
    // Identity: false
    function _parse(raw) {
        var t = /Time:\s*(\S+)/.exec(raw)
        var k = /Temperature:\s*(\d+)/.exec(raw)
        var id = /Identity:\s*(\w+)/.exec(raw)
        root.available = !!t
        if (!t) return
        var key = t[1]
        if (key === root._profileKey) return
        root._profileKey = key
        root.on = !(id && id[1] === "true") && !!k && Number(k[1]) < 6000
    }

    property Process _read: Process {
        command: ["hyprctl", "hyprsunset", "profile"]
        stdout: StdioCollector { onStreamFinished: root._parse(text) }
    }

    property Process _set: Process {}

    // Profiles switch at fixed times; catch that without a tight loop.
    property Timer _poll: Timer {
        interval: 60000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
