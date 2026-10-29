// Theme list + switching, for the in-shell theme picker.
//
// Replaces theme-menu.sh, which was a rofi dmenu (rofi is being removed).
// Reads the same directory theme-set.sh uses, so the shell and the CLI agree on
// what a "theme" is.
//
// Actually applying a theme is still theme-set.sh's job: it repoints the
// `~/.config/theme/current` symlink, rewrites the Qt accent, swaps the
// wallpaper and nudges every app. Reimplementing that in QML would mean two
// sources of truth for what "switching a theme" means.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string themesDir:
        Quickshell.env("HOME") + "/.config/theme/themes"
    readonly property string currentLink:
        Quickshell.env("HOME") + "/.config/theme/current"

    // [{ name, label, mode }] sorted by label.
    property var themes: []
    property string current: ""

    property Process _list: Process {
        command: ["bash", "-c",
            "cd \"$1\" 2>/dev/null || exit 0; " +
            "for d in */; do " +
              "d=${d%/}; " +
              "[ -f \"$d/theme.conf\" ] || continue; " +
              "name=$(sed -n 's/^THEME_NAME=\"\\?\\([^\"]*\\)\"\\?$/\\1/p' \"$d/theme.conf\" | head -1); " +
              "mode=$(sed -n 's/^THEME_MODE=\"\\?\\([^\"]*\\)\"\\?$/\\1/p' \"$d/theme.conf\" | head -1); " +
              "printf '%s\\t%s\\t%s\\n' \"$d\" \"${name:-$d}\" \"$mode\"; " +
            "done", "_", root.themesDir]
        stdout: SplitParser {
            onRead: function (line) {
                if (line === "") return
                var f = line.split("\t")
                if (f.length < 3) return
                root._rows.push({ name: f[0], label: f[1], mode: f[2] })
            }
        }
        onExited: function (code) {
            root._rows.sort(function (a, b) {
                return a.label.toLowerCase() < b.label.toLowerCase() ? -1 : 1
            })
            root.themes = root._rows
            root._rows = []
        }
    }

    property var _rows: []

    // `current` is a symlink to the active theme dir; readlink -f gives us the
    // directory name, which is what theme-set.sh takes as its argument.
    property Process _current: Process {
        command: ["bash", "-c",
            "readlink -f \"$1\" 2>/dev/null | xargs -r basename", "_", root.currentLink]
        stdout: StdioCollector {
            onStreamFinished: root.current = text.trim()
        }
    }

    property Process _apply: Process {}

    // Runs theme-set.sh in the background. It is idempotent, and the palette
    // reload it triggers at the end is what actually repaints the shell.
    function apply(name) {
        if (!name || name === root.current)
            return
        _apply.command = ["bash", "-c",
            "exec \"$HOME/.local/bin/theme-set.sh\" \"$1\"", "_", name]
        _apply.running = true
        root.current = name
    }

    function refresh() {
        root._rows = []
        root._list.running = true
        root._current.running = true
    }

    Component.onCompleted: refresh()
}
