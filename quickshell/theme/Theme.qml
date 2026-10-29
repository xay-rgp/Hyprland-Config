// Umbrella singleton: `Theme.text`, `Theme.notchHeight`, etc.
//
// Colors and Metrics are separate files so each stays readable; this one is
// the single import every widget uses. Property aliases cannot point at other
// singletons, hence the explicit bindings.
pragma Singleton
import QtQuick
import "."

QtObject {
    // ── Colours ─────────────────────────────────────────────────────────────
    property color rosewater: Colors.rosewater
    property color flamingo:  Colors.flamingo
    property color pink:      Colors.pink
    property color mauve:     Colors.mauve
    property color red:       Colors.red
    property color maroon:    Colors.maroon
    property color peach:     Colors.peach
    property color yellow:    Colors.yellow
    property color green:     Colors.green
    property color teal:      Colors.teal
    property color sky:       Colors.sky
    property color sapphire:  Colors.sapphire
    property color blue:      Colors.blue
    property color lavender:  Colors.lavender

    property color text:      Colors.text
    property color subtext1:  Colors.subtext1
    property color subtext0:  Colors.subtext0
    property color overlay2:  Colors.overlay2
    property color overlay1:  Colors.overlay1
    property color overlay0:  Colors.overlay0
    // Bare `surface` is the general "recessed control" fill (slider tracks,
    // chips, thumbnails). surface0/1/2 are the raw palette steps; this is the
    // one most widgets actually want, and it was missing — every use site was
    // silently binding an undefined colour.
    property color surface:   Colors.surface0
    property color surface2:  Colors.surface2
    property color surface1:  Colors.surface1
    property color surface0:  Colors.surface0
    property color base:      Colors.base
    property color mantle:    Colors.mantle
    property color crust:     Colors.crust

    property color accent:     Colors.accent
    property color urgent:     Colors.urgent
    property color warning:    Colors.warning
    property color success:    Colors.success

    property color barBg:        Colors.barBg
    property color popupBg:      Colors.popupBg
    property color popupBgSolid: Colors.popupBgSolid
    property color border:       Colors.border

    property color hover:    Colors.hover
    property color pressed:  Colors.pressed
    property color divider:  Colors.divider
    property color inactive: Colors.inactive

    property color wsActive:   Colors.wsActive
    property color wsOccupied: Colors.wsOccupied
    property color wsEmpty:    Colors.wsEmpty
    property color wsUrgent:   Colors.wsUrgent

    property string mode:  Colors.mode
    property bool   loaded: Colors.loaded

    // ── Metrics ─────────────────────────────────────────────────────────────
    property int borderWidth:   Metrics.borderWidth
    property int cornerRadius:  Metrics.cornerRadius
    property int notchRadius:   Metrics.notchRadius
    property int notchHeight:   Metrics.notchHeight
    property int exclusionGap:  Metrics.exclusionGap
    property int notchPadding:  Metrics.notchPadding

    property int lNotchMinWidth: Metrics.lNotchMinWidth
    property int lNotchMaxWidth: Metrics.lNotchMaxWidth
    property int cNotchMinWidth: Metrics.cNotchMinWidth
    property int cNotchMaxWidth: Metrics.cNotchMaxWidth
    property int rNotchMinWidth: Metrics.rNotchMinWidth
    property int rNotchMaxWidth: Metrics.rNotchMaxWidth

    property int popupPadding:      Metrics.popupPadding
    property int popupWidth:        Metrics.popupWidth
    property int cornerRadiusSmall: Metrics.cornerRadiusSmall
    property int networkPopupWidth: Metrics.networkPopupWidth
    property int launcherWidth:     Metrics.launcherWidth
    property int launcherMaxHeight: Metrics.launcherMaxHeight

    property int ccWidth:         Metrics.ccWidth
    property int ccHeight:        Metrics.ccHeight
    property int ccPadding:       Metrics.ccPadding
    property int ccRadius:        Metrics.ccRadius
    property int ccCardRadius:    Metrics.ccCardRadius
    property int ccMorphDuration: Metrics.ccMorphDuration

    property int islandTop:           Metrics.islandTop
    property int islandRestHeight:    Metrics.islandRestHeight
    property int islandPeekWidth:     Metrics.islandPeekWidth
    property int islandPeekHeight:    Metrics.islandPeekHeight
    property int islandRadius:        Metrics.islandRadius
    property int islandMorphDuration: Metrics.islandMorphDuration

    property int wsDotSize:     Metrics.wsDotSize
    property int wsActiveWidth: Metrics.wsActiveWidth
    property int wsSpacing:     Metrics.wsSpacing
    property int wsPadding:     Metrics.wsPadding
    property int wsRadius:      Metrics.wsRadius

    property int animDuration:    Metrics.animDuration
    property int animFast:        Metrics.animFast
    property int hoverCloseDelay: Metrics.hoverCloseDelay

    property string fontFamily:     Metrics.fontFamily
    property int    fontSize:       Metrics.fontSize
    property int    fontSizeSmall:  Metrics.fontSizeSmall
    property int    fontSizeLarge:  Metrics.fontSizeLarge

    property bool barEnabled: Metrics.barEnabled
    property bool focusMode:  Metrics.focusMode
}
