// Wallpaper manager: lists candidate images and applies them through awww.
//
// awww replaces hyprpaper (goal #3). It is a daemon (`awww-daemon`) driven at
// runtime by `awww img`, which is what gives us transitions — the "animation"
// for a still image is the cross-fade, and `.gif` wallpapers animate without
// any extra work on our side.
//
// Sources, in the order they appear in the grid:
//   1. ~/Pictures/Wallpapers      — the user's own collection
//   2. <active-theme>/backgrounds — whatever the theme ships
//
// Selection state lives in ~/.local/state/quickshell/wallpaper.json. The theme
// day/night cache (~/.cache/appearance/wallpaper.png, written by
// select_wallpaper.sh) is deliberately NOT touched here: theme switching still
// owns that file, and this service only overrides what is on screen right now.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string userDir: home + "/Pictures/Wallpapers"
    readonly property string themeDir: home + "/.config/theme/current/backgrounds"
    readonly property string stateDir: home + "/.local/state/quickshell"
    readonly property string stateFile: stateDir + "/wallpaper.json"

    // [{ path, name, dir }]
    property var images: []
    property bool loaded: false

    // awww transition settings, mirrored into the popup controls.
    property string transition: "grow"
    property int transitionDuration: 800
    property string applyTarget: "all" // "all" | output name

    property string current: ""

    // ── Discovery ───────────────────────────────────────────────────────────
    // One `find` pass over both directories. Directories that do not exist are
    // skipped silently — ~/Pictures/Wallpapers is expected to be absent on a
    // fresh install and that is not an error.
    property Process _list: Process {
        command: ["bash", "-c",
            "for d in \"$1\" \"$2\"; do " +
              "[ -d \"$d\" ] || continue; " +
              "find \"$d\" -maxdepth 1 -type f " +
                "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' " +
                "-o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' \\) " +
                "-printf '%p\\t%f\\t%h\\n'; " +
            "done", "_", root.userDir, root.themeDir]
        stdout: SplitParser {
            onRead: function (line) {
                if (line === "")
                    return
                var f = line.split("\t")
                if (f.length < 3)
                    return
                root._rows.push({
                    path: f[0],
                    name: f[1],
                    dir: f[2] === root.userDir ? "Pictures" : "Theme"
                })
            }
        }
        onExited: function (code) {
            root._rows.sort(function (a, b) {
                return a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1
            })
            root.images = root._rows
            root._rows = []
            root.loaded = true
        }
    }

    property var _rows: []

    function refresh() {
        root._rows = []
        root._list.running = true
    }

    // ── Applying ────────────────────────────────────────────────────────────

    property Process _apply: Process {
        onExited: function (code) {
            if (code === 0) {
                root.current = root._applying
                root.save()
            }
        }
    }

    property string _applying: ""

    function apply(path, output) {
        if (!path)
            return
        root._applying = path
        // awww-daemon must be alive; starting it is idempotent enough that we
        // just always do it before the first apply.
        var args = ["awww", "img", path,
                    "--transition-type", root.transition,
                    "--transition-duration", String(root.transitionDuration)]
        var target = output !== undefined ? output : root.applyTarget
        if (target !== "all")
            args.push("--outputs", target)
        root._apply.command = args
        root._apply.running = true
    }

    function ensureDaemon() {
        _daemonProbe.running = true
    }

    property Process _daemonProbe: Process {
        command: ["pgrep", "-x", "awww-daemon"]
        onExited: function (code) {
            if (code !== 0)
                _daemonStart.running = true
        }
    }

    property Process _daemonStart: Process {
        command: ["awww-daemon"]
    }

    // ── Persistence ─────────────────────────────────────────────────────────

    function save() {
        _save.command = ["bash", "-c",
            "mkdir -p '" + root.stateDir + "' && printf '%s' \"$1\" > '" + root.stateFile + "'",
            "_", JSON.stringify({
                current: root.current,
                transition: root.transition,
                transitionDuration: root.transitionDuration,
                applyTarget: root.applyTarget
            })]
        _save.running = true
    }

    property Process _save: Process {}

    property Process _load: Process {
        command: ["cat", root.stateFile]
        stdout: StdioCollector {
            onStreamFinished: root._restore(text)
        }
    }

    function _restore(raw) {
        if (!raw)
            return
        try {
            var o = JSON.parse(raw)
            if (o.transition) root.transition = o.transition
            if (o.transitionDuration) root.transitionDuration = o.transitionDuration
            if (o.applyTarget) root.applyTarget = o.applyTarget
            if (o.current) root.current = o.current
        } catch (e) {
            console.log("WallpaperService: bad state file:", e)
        }
    }

    Component.onCompleted: {
        _load.running = true
        refresh()
        // Standalone: only start a wallpaper daemon after an explicit action.
    }
}
