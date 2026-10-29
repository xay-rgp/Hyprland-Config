// RAM usage from /proc/meminfo, polled every few seconds.
//
// "Used" is MemTotal - MemAvailable, the same figure `free` and htop report;
// buffers/cache don't count because the kernel hands them back on demand.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property real totalKb: 0
    property real availableKb: 0

    readonly property real usedKb: Math.max(0, totalKb - availableKb)
    readonly property real fraction: totalKb > 0 ? usedKb / totalKb : 0
    readonly property int  percent: Math.round(fraction * 100)

    readonly property real usedGiB:  usedKb / 1048576
    readonly property real totalGiB: totalKb / 1048576

    // "7.4 / 31 GiB"
    readonly property string label: usedGiB.toFixed(1) + " / " + Math.round(totalGiB) + " GiB"

    property FileView _meminfo: FileView {
        path: "/proc/meminfo"
        // procfs files report size 0, so a blocking read is the reliable way.
        blockLoading: true
        onLoaded: root._parse(text())
    }

    property Timer _poll: Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root._meminfo.reload()
    }

    function _parse(content) {
        var lines = content.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var m = lines[i].match(/^(MemTotal|MemAvailable):\s+(\d+)/)
            if (!m) continue
            if (m[1] === "MemTotal") root.totalKb = Number(m[2])
            else root.availableKb = Number(m[2])
        }
    }
}
