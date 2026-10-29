// Palette singleton. Reads the active theme via ColorLoader and re-exposes it
// under stable names, so every other file can just say `Colors.red`.
//
// A handful of derived colours (translucent surfaces, hover tints) are computed
// here from the palette rather than hardcoded per-widget, so a theme switch
// carries them along automatically.
pragma Singleton
import QtQuick
import "."

QtObject {
    id: root

    property ColorLoader _loader: ColorLoader {}

    // Called over IPC by theme-set.sh after it repoints the active-theme symlink.
    function reloadTheme() {
        _loader.forceReload()
    }

    // ── Raw palette ─────────────────────────────────────────────────────────
    property color rosewater: _loader.rosewater
    property color flamingo:  _loader.flamingo
    property color pink:      _loader.pink
    property color mauve:     _loader.mauve
    property color red:       _loader.red
    property color maroon:    _loader.maroon
    property color peach:     _loader.peach
    property color yellow:    _loader.yellow
    property color green:     _loader.green
    property color teal:      _loader.teal
    property color sky:       _loader.sky
    property color sapphire:  _loader.sapphire
    property color blue:      _loader.blue
    property color lavender:  _loader.lavender
    property color text:      _loader.text
    property color subtext1:  _loader.subtext1
    property color subtext0:  _loader.subtext0
    property color overlay2:  _loader.overlay2
    property color overlay1:  _loader.overlay1
    property color overlay0:  _loader.overlay0
    property color surface2:  _loader.surface2
    property color surface1:  _loader.surface1
    property color surface0:  _loader.surface0
    property color base:      _loader.base
    property color mantle:    _loader.mantle
    property color crust:     _loader.crust

    property string mode:  _loader.mode
    property bool   loaded: _loader.loaded

    // ── Semantic aliases ────────────────────────────────────────────────────
    // Widgets use these instead of picking a palette key by hand, so the
    // meaning stays consistent across themes.
    property color accent:     blue
    property color urgent:     red
    property color warning:    yellow
    property color success:    green

    // ── Derived (theme-following) ───────────────────────────────────────────
    // Surfaces used by the bar, frame and popups.
    property color barBg:        base
    property color popupBg:      mantle
    property color popupBgSolid: mantle
    property color border:       overlay0

    // Interaction tints — derived from `text` so they invert on light themes
    // instead of assuming a dark background.
    property color hover:    Qt.rgba(text.r, text.g, text.b, 0.08)
    property color pressed:  Qt.rgba(text.r, text.g, text.b, 0.14)
    property color divider:  Qt.rgba(text.r, text.g, text.b, 0.07)
    property color inactive: Qt.rgba(text.r, text.g, text.b, 0.25)

    // Workspace pills
    property color wsActive:   text
    property color wsOccupied: Qt.rgba(text.r, text.g, text.b, 0.45)
    property color wsEmpty:    Qt.rgba(text.r, text.g, text.b, 0.16)
    property color wsUrgent:   urgent
}
