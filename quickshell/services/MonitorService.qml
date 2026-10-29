// Every monitor Hyprland knows about — disabled ones included, which
// Quickshell.screens can't show — plus which monitor each workspace rule
// points at. Feeds the Settings widget's Monitors tab.
//
// Re-read on Hyprland monitor events and after SettingsService rewrites the
// generated config.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

QtObject {
    id: root

    // { name, description, width, height, x, y, refresh, disabled },
    // sorted left to right.
    property var monitors: []
    // Workspace id (string) → output name, from `hyprctl workspacerules`.
    property var workspaceRules: ({})

    readonly property var enabled: monitors.filter(function (m) { return !m.disabled })

    function refresh() {
        if (!_monitors.running) _monitors.running = true
        if (!_rules.running) _rules.running = true
    }

    // After a `hyprctl reload`, give Hyprland a moment to settle.
    function refreshSoon() { _soon.restart() }

    // "Left" / "Right" for a side-by-side pair, else the output name.
    function label(name) {
        if (root.monitors.length === 2) {
            var i = root.monitors.findIndex(function (m) { return m.name === name })
            if (i !== -1) return i === 0 ? "Left" : "Right"
        }
        return name
    }

    property Timer _soon: Timer { interval: 600; onTriggered: root.refresh() }

    property Process _monitors: Process {
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var list = JSON.parse(text).map(function (m) {
                        var w = m.width, h = m.height, r = m.refreshRate || 0
                        // A disabled monitor reports no size: take its
                        // preferred mode, so it can still be drawn.
                        if (m.disabled && (!w || !h)) {
                            var mode = /^(\d+)x(\d+)@([\d.]+)/.exec((m.availableModes || [])[0] || "")
                            if (mode) { w = +mode[1]; h = +mode[2]; r = +mode[3] }
                        }
                        return {
                            name: m.name,
                            description: m.description || "",
                            width: w,
                            height: h,
                            x: m.x,
                            y: m.y,
                            refresh: Math.round(r),
                            disabled: !!m.disabled
                        }
                    })
                    // ...and no position either (Hyprland parks it at -1,0):
                    // put it beside the ones that are on — on their left if
                    // there is room, else past their right edge.
                    var on = list.filter(function (m) { return !m.disabled })
                    var left = on.length ? Math.min.apply(null, on.map(function (m) { return m.x })) : 0
                    var right = on.length ? Math.max.apply(null, on.map(function (m) { return m.x + m.width })) : 0
                    list.forEach(function (m) {
                        if (!m.disabled || m.x >= 0) return
                        if (left >= m.width) { m.x = left - m.width; left = m.x }
                        else { m.x = right; right += m.width }
                        m.y = 0
                    })
                    list.sort(function (a, b) { return a.x - b.x || a.y - b.y })
                    root.monitors = list
                } catch (e) {
                    console.warn("MonitorService: bad monitors json:", e)
                }
            }
        }
    }

    property Process _rules: Process {
        command: ["hyprctl", "workspacerules", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var map = {}
                    JSON.parse(text).forEach(function (r) {
                        if (r.monitor) map[r.workspaceString] = r.monitor
                    })
                    root.workspaceRules = map
                } catch (e) {
                    console.warn("MonitorService: bad workspacerules json:", e)
                }
            }
        }
    }

    property Connections _events: Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name.indexOf("monitor") === 0 || event.name === "configreloaded")
                root.refreshSoon()
        }
    }

    Component.onCompleted: refresh()
}
