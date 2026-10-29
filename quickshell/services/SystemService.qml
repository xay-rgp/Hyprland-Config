// Who's logged in and for how long the machine has been up, for the island's
// home header. Call refresh() when the header is shown; uptime is also
// re-read once a minute.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string user: Quickshell.env("USER") || ""
    readonly property string face: "file://" + (Quickshell.env("HOME") || "") + "/.face"

    property string host: ""
    property real uptimeSec: 0

    // Largest whole unit: "12 mins", "11 hours", "3 days".
    readonly property string uptime: {
        var m = Math.floor(uptimeSec / 60)
        var n, unit
        if (m < 60)        { n = m;                      unit = "min" }
        else if (m < 1440) { n = Math.floor(m / 60);     unit = "hour" }
        else               { n = Math.floor(m / 1440);   unit = "day" }
        return n + " " + unit + (n === 1 ? "" : "s")
    }

    // procfs files report size 0, so blocking reads are the reliable way.
    property FileView _host: FileView {
        path: "/proc/sys/kernel/hostname"
        blockLoading: true
        onLoaded: root.host = text().trim()
    }

    property FileView _uptime: FileView {
        path: "/proc/uptime"
        blockLoading: true
        onLoaded: root.uptimeSec = parseFloat(text()) || 0
    }

    function refresh() {
        root._uptime.reload()
    }

    property Timer _poll: Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root._uptime.reload()
    }
}
