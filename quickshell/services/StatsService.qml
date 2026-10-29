// Local machine usage; refresh host details while stats or a preview is visible.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string script: Quickshell.shellDir + "/scripts/system-stats.py"

    // Set by the widget while it is visible.
    property bool watching: false
    property int previewWatchers: 0
    readonly property bool polling: watching || previewWatchers > 0
    onPollingChanged: if (polling) refresh()

    // Last result per source; see the script for the shape. Kept when a
    // later fetch fails outright, so the widget never blanks.
    property var host: null
    readonly property var primaryGpu: host && host.ok && host.gpus.length > 0 ? host.gpus[0] : null
    readonly property string gpuUsage: primaryGpu && primaryGpu.percent !== null
        && primaryGpu.percent !== undefined ? Math.round(primaryGpu.percent) + "%" : "N/A"

    // Last mount / eject result, for the widget to show on failure.
    property var action: null
    readonly property bool actionBusy: _action.running

    function refresh() {
        _host.fetch()
    }

    function mount(device) { _runAction(["mount", device]) }
    function eject(disk)    { _runAction(["eject", disk]) }

    function _runAction(args) {
        if (_action.running) return
        root.action = null
        _action.command = ["python3", root.script].concat(args)
        _action.running = true
    }

    // ── CPU ─────────────────────────────────────────────────────────────────
    property real cpuPercent: 0
    property var  _cpuPrev: null

    property FileView _cpuStat: FileView {
        path: "/proc/stat"
        // procfs files report size 0, so a blocking read is the reliable way.
        blockLoading: true
        onLoaded: root._parseCpu(text())
    }

    // First line: "cpu  user nice system idle iowait irq softirq steal …"
    function _parseCpu(content) {
        var f = content.split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
        var idle = f[3] + (f[4] || 0)
        var total = 0
        for (var i = 0; i < Math.min(f.length, 8); i++) total += f[i]
        if (_cpuPrev && total > _cpuPrev.total)
            cpuPercent = 100 * (1 - (idle - _cpuPrev.idle) / (total - _cpuPrev.total))
        _cpuPrev = { idle: idle, total: total }
    }

    // ── Script ──────────────────────────────────────────────────────────────
    component Fetch: Process {
        id: proc
        property string source
        function fetch() { if (!running) running = true }

        command: ["python3", root.script, source]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root[proc.source] = JSON.parse(text)
                } catch (e) {
                    console.warn("system-stats:", proc.source, "bad output:", e)
                }
            }
        }
    }

    property Fetch _host: Fetch { source: "host" }

    property Process _action: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.action = JSON.parse(text)
                } catch (e) {
                    root.action = { ok: false, error: "udisksctl failed" }
                }
                root._host.fetch()
            }
        }
    }

    // CPU is read (cheaply) even while closed, so opening the widget shows
    // a real figure straight away instead of waiting for a second sample.
    property Timer _cpuPoll: Timer {
        interval: root.polling ? 2000 : 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root._cpuStat.reload()
    }

    property Timer _hostPoll: Timer {
        interval: 2000
        running: root.polling
        repeat: true
        onTriggered: root._host.fetch()
    }


}
