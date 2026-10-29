// Emoji database, parsed from our own vendored copy of rofi-emoji's data
// (config/data/emoji.tsv).
//
// It is VENDORED deliberately: the upstream data lives in /usr/share/rofi-emoji,
// which the rofi-emoji package owns — and that package depends on `rofi`, which
// is removed along with the rest of the old shell stack. Reading it from the
// system path would leave this picker silently empty once rofi was uninstalled.
// See config/data/README.md.
//
// Format, tab separated:
//   <glyph> <group> <name> <keyword | keyword | ...>
//
// Skin-tone variants (over half the file) and the bare "Component" swatches
// are left out of browsing and plain searches, so the grid isn't five copies
// of every hand; a search mentioning "skin" or "tone" includes them.
//
// Favourites are a list of glyphs, in the order they were added, saved to
// ~/.local/state/quickshell/emoji-favorites.json.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property string source: Quickshell.shellDir + "/data/emoji.tsv"

    property var all: []
    property bool loaded: false

    // Distinct groups, in file order, for the category rail.
    property var groups: []

    // ── Favourites ──────────────────────────────────────────────────────────
    readonly property string favoritesPath:
        Quickshell.env("HOME") + "/.local/state/quickshell/emoji-favorites.json"
    property var favorites: []          // glyphs
    readonly property var _byGlyph: {
        var m = {}
        for (var i = 0; i < root.all.length; i++) m[root.all[i].glyph] = root.all[i]
        return m
    }
    // Favourites as full entries, for display.
    readonly property var favoriteEntries: root.favorites.map(function (g) {
        return root._byGlyph[g] || { glyph: g, group: "", name: "", keywords: "" }
    })

    function isFavorite(glyph) { return root.favorites.indexOf(glyph) !== -1 }

    function toggleFavorite(glyph) {
        var i = root.favorites.indexOf(glyph)
        root.favorites = i === -1 ? root.favorites.concat([glyph])
                                  : root.favorites.filter(function (g) { return g !== glyph })
        _favFile.setText(JSON.stringify(root.favorites))
    }

    // Move a favourite one place left (-1) or right (+1).
    function moveFavorite(glyph, dir) {
        var i = root.favorites.indexOf(glyph), j = i + dir
        if (i === -1 || j < 0 || j >= root.favorites.length) return
        var list = root.favorites.slice()
        list[i] = list[j]
        list[j] = glyph
        root.favorites = list
        _favFile.setText(JSON.stringify(root.favorites))
    }

    property FileView _favFile: FileView {
        path: root.favoritesPath
        watchChanges: false
        atomicWrites: true
        printErrors: false          // missing until the first favourite
        onLoaded: {
            try {
                var list = JSON.parse(text())
                if (Array.isArray(list)) root.favorites = list.filter(function (g) { return typeof g === "string" })
            } catch (e) {
                console.warn("emoji: bad favourites file:", e)
            }
        }
    }

    // ── Copy ────────────────────────────────────────────────────────────────
    property Process _copy: Process {}

    function copy(glyph) {
        _copy.command = ["wl-copy", "--", glyph]
        _copy.running = true
    }

    // ── Load / parse ────────────────────────────────────────────────────────
    property FileView _file: FileView {
        path: root.source
        watchChanges: false
        onLoaded: root._parse(text())
        onLoadFailed: console.warn("emoji: cannot read", root.source)
    }

    function _parse(raw) {
        if (!raw)
            return
        var out = []
        var seen = {}
        var lines = raw.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (line === "")
                continue
            var f = line.split("\t")
            if (f.length < 3)
                continue
            var glyph = f[0]
            // Some emoji are listed twice: fully qualified (with the U+FE0F
            // emoji selector) and bare. Keep the first, the qualified one.
            var key = (f[1] || "") + "\t" + (f[2] || "")
            if (seen[glyph] || seen[key])
                continue
            seen[glyph] = true
            seen[key] = true
            out.push({
                glyph:    glyph,
                group:    f[1] || "",
                name:     f[2] || "",
                keywords: (f[3] || "").toLowerCase(),
                variant:  f[1] === "Component" || (f[2] || "").indexOf("skin tone") !== -1
            })
        }
        var gs = []
        var gseen = {}
        for (var j = 0; j < out.length; j++) {
            var g = out[j].group
            if (!gseen[g] && g !== "Component") {
                gseen[g] = true
                gs.push(g)
            }
        }
        root.all = out
        root.groups = gs
        root.loaded = true
    }

    // Case-insensitive search over name + keywords, restricted to a group.
    function search(query, group) {
        var q = (query || "").toLowerCase()
        var variants = q.indexOf("skin") !== -1 || q.indexOf("tone") !== -1
        var out = []
        for (var i = 0; i < root.all.length; i++) {
            var e = root.all[i]
            if (group && group !== "" && e.group !== group)
                continue
            if (e.variant && !variants)
                continue
            if (q === "" || e.name.toLowerCase().indexOf(q) !== -1
                || e.keywords.indexOf(q) !== -1) {
                out.push(e)
            }
        }
        return out
    }
}
