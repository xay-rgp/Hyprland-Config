// Loads this shell's local monochrome palette, independent of desktop themes.
//
// Not a singleton — instantiated as a property inside Colors.qml. This keeps
// the file-watching machinery out of the singleton itself, which is the same
// split Brain_Shell uses between ColorLoader.qml and Colors.qml.
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // ── Palette (fallback = black and white) ────────────────────────────────
    // Defaults matter: the shell must render something sane before the theme
    // file is read, and must keep rendering if the file is missing entirely.
    property color rosewater: "#ffffff"
    property color flamingo:  "#ffffff"
    property color pink:      "#ffffff"
    property color mauve:     "#ffffff"
    property color red:       "#ffffff"
    property color maroon:    "#ffffff"
    property color peach:     "#ffffff"
    property color yellow:    "#ffffff"
    property color green:     "#ffffff"
    property color teal:      "#ffffff"
    property color sky:       "#ffffff"
    property color sapphire:  "#ffffff"
    property color blue:      "#ffffff"
    property color lavender:  "#ffffff"
    property color text:      "#ffffff"
    property color subtext1:  "#dddddd"
    property color subtext0:  "#bbbbbb"
    property color overlay2:  "#999999"
    property color overlay1:  "#777777"
    property color overlay0:  "#555555"
    property color surface2:  "#333333"
    property color surface1:  "#222222"
    property color surface0:  "#161616"
    property color base:      "#000000"
    property color mantle:    "#000000"
    property color crust:     "#000000"

    property string mode: "dark"

    // True once a theme file has been successfully parsed. The Customise tab
    // uses this to tell "no theme loaded" from "local monochrome palette is loaded".
    property bool loaded: false

    // ── File watcher ────────────────────────────────────────────────────────
    // theme-set.sh repoints ~/.config/theme/current, so the path itself is
    // stable and only the contents change — watchChanges is enough.
    property FileView file: FileView {
        path: Quickshell.shellDir + "/theme/monochrome.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parse(text())
        onLoadFailed: root.loaded = false
    }

    // theme-set.sh repoints the `current` symlink instead of editing this file
    // in place, so the watched inode never changes and no change event fires.
    // The shell calls this over IPC after a switch. Reloading the FileView by
    // toggling the path forces a fresh read of the new target.
    function forceReload() {
        if (!file.path)
            return
        file.path = ""
        file.path = Quickshell.shellDir + "/theme/monochrome.json"
    }

    function parse(raw) {
        if (!raw || raw.trim() === "")
            return

        var obj
        try {
            obj = JSON.parse(raw)
        } catch (e) {
            // Malformed JSON — keep the current palette rather than flashing
            // the fallback over a live theme.
            console.warn("quickshell-colors.json: parse failed:", e)
            return
        }

        // Only overwrite keys actually present, so a partial theme file still
        // leaves sensible values for the rest.
        for (var key in obj) {
            if (key === "mode") {
                root.mode = obj[key]
                continue
            }
            if (root[key] !== undefined && typeof obj[key] === "string")
                root[key] = obj[key]
        }

        root.loaded = true
    }
}
