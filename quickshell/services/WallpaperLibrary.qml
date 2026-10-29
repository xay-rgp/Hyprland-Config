// The wallpaper library, for the Themes widget: every wallpaper is a theme.
//
// All the work is theme/bin/wallpaper.py's — listing (with thumbnails and
// palette swatches), applying (curated palette, or one generated from the
// image with matugen, then theme-set.sh), and tagging. This only runs it and
// holds the results.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string tool: Quickshell.env("HOME") + "/.local/bin/wallpaper.py"

    // [{ id, name, path, thumb, tags, mode, theme, swatch }]
    property var wallpapers: []
    property string current: ""
    property bool loaded: false

    // The wallpaper being applied right now, "" when idle.
    property string applying: ""
    property string error: ""

    // Every tag in use, most common first (then alphabetical).
    readonly property var tags: {
        var count = {}
        for (var i = 0; i < wallpapers.length; i++)
            for (var j = 0; j < wallpapers[i].tags.length; j++) {
                var t = wallpapers[i].tags[j]
                count[t] = (count[t] || 0) + 1
            }
        return Object.keys(count).sort(function (a, b) {
            return count[b] - count[a] || a.localeCompare(b)
        })
    }

    function refresh() {
        if (!_list.running) _list.running = true
    }

    function apply(id) {
        if (_apply.running || id === "") return
        root.applying = id
        root.error = ""
        _apply.command = [root.tool, "apply", id]
        _apply.running = true
    }

    // Replace a wallpaper's tags ("anime, cityscape"). light/dark are
    // derived from its colours and can't be set.
    function setTags(id, csv) {
        _edit.command = [root.tool, "tag", id, csv]
        _edit.running = true
    }

    property Process _list: Process {
        command: [root.tool, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var out = JSON.parse(text)
                    root.wallpapers = out.wallpapers
                    root.current = out.current
                    root.loaded = true
                } catch (e) {
                    console.warn("wallpapers: bad list output:", e)
                }
            }
        }
    }

    property Process _apply: Process {
        stderr: StdioCollector { id: applyErr }
        onExited: function (code) {
            if (code === 0) root.current = root.applying
            else root.error = "Couldn't apply: " + (applyErr.text.trim().split("\n").pop() || "exit " + code)
            root.applying = ""
            // A generated palette now exists, so its swatch can show.
            root.refresh()
        }
    }

    property Process _edit: Process {
        onExited: root.refresh()
    }
}
