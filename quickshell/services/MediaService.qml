// Now-playing and transport for standard MPRIS players.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

QtObject {
    id: root

    // Prefer an MPRIS player that is actually playing, so a paused browser
    // tab doesn't hide a playing one.
    readonly property var player: {
        var players = Mpris.players.values
        if (players.length === 0)
            return null
        for (var i = 0; i < players.length; i++)
            if (players[i].isPlaying)
                return players[i]
        return players[0]
    }

    readonly property bool active: !!player && player.trackTitle !== ""
    readonly property string title: player ? (player.trackTitle || "") : ""
    readonly property string artist: player ? (player.trackArtist || "") : ""
    readonly property string album: player ? (player.trackAlbum || "") : ""
    readonly property string artUrl: player ? (player.trackArtUrl || "") : ""
    readonly property bool playing: player ? player.isPlaying : false

    readonly property string glyph: playing ? "" : ""   // play / pause

    // Truncated "title · artist" for the bar.
    readonly property string label: {
        var t = title
        var a = artist
        if (t === "") return ""
        return a === "" ? t : t + "  ·  " + a
    }

    readonly property bool canToggle: (player ? player.canTogglePlaying : false)
    readonly property bool canNext:   (player ? player.canGoNext       : false)
    readonly property bool canPrev:   (player ? player.canGoPrevious   : false)

    function toggle() {
        if (player && player.canTogglePlaying)
            player.togglePlaying()
    }

    function next() {
        if (player && player.canGoNext)
            player.next()
    }

    function previous() {
        if (player && player.canGoPrevious)
            player.previous()
    }
}
