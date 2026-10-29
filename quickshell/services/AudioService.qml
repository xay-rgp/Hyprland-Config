// Audio: default sink/source state, volume and mute.
//
// Uses Quickshell's Pipewire service rather than shelling out to wpctl, so
// values are live with no polling loop.
//
// IMPORTANT: `Pipewire.defaultAudioSink` hands back a node object whose `audio`
// bindings are NOT populated until the object is *tracked*. Reading
// `sink.audio.volume` off the bare default produced a permanent 0% /
// `ready=false` (verified — the node existed, its volume did not). A
// PwObjectTracker is what actually binds the underlying object, so the tracked
// node is the one to read from.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Io

QtObject {
    id: root

    // Binds the objects we read from. Without this, audio bindings stay empty.
    // Application streams are tracked too, for the per-app volume sliders.
    property PwObjectTracker tracker: PwObjectTracker {
        objects: [root.sink, root.source].filter(function (o) { return !!o })
                 .concat(root.playbackStreams, root.recordStreams)
    }

    readonly property var sink:   Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    readonly property bool ready: Pipewire.ready

    // ── Sink (output) ───────────────────────────────────────────────────────
    readonly property var sinkAudio: sink ? sink.audio : null

    readonly property real volume: sinkAudio ? sinkAudio.volume : 0
    readonly property bool muted:  sinkAudio ? sinkAudio.muted  : false
    readonly property int  volumePercent: Math.round(volume * 100)

    readonly property string sinkName:
        sink ? (sink.nickname || sink.description || sink.name || "") : ""

    // ── Source (input / mic) ────────────────────────────────────────────────
    readonly property var sourceAudio: source ? source.audio : null

    readonly property real sourceVolume: sourceAudio ? sourceAudio.volume : 0
    readonly property bool sourceMuted:  sourceAudio ? sourceAudio.muted  : false
    readonly property int  sourcePercent: Math.round(sourceVolume * 100)

    readonly property string sourceName:
        source ? (source.nickname || source.description || source.name || "") : ""

    // ── Glyph, mirroring waybar's wireplumber formatting ────────────────────
    readonly property string glyph: {
        if (muted || volumePercent === 0) return "\uf026"
        if (volumePercent < 34) return "\uf027"
        return "\uf028"
    }

    // Devices for the picker.
    //
    // These cannot be `readonly property var` bound to a helper function:
    // a property whose initializer calls a plain function never re-evaluates,
    // so the list froze at startup (it kept showing a Chrome stream node that
    // had long since gone). Reading instead of caching keeps it live.
    function sinkList() { return _nodes(function (n) { return n.isSink && !n.isStream && n.audio }) }
    function sourceList() { return _nodes(function (n) { return !n.isSink && !n.isStream && n.audio }) }

    // Kept as bindings for QML consumers, but rebuilt on every nodes change.
    readonly property var sinks: {
        // Touch the model so this re-evaluates when nodes appear/disappear.
        var _ = Pipewire.nodes.values.length
        return sinkList()
    }

    readonly property var sources: {
        var _ = Pipewire.nodes.values.length
        return sourceList()
    }

    // ── Application streams ─────────────────────────────────────────────────
    // Playback = an app sending audio to an output; record = an app capturing
    // from an input. Peak-meter monitor streams (pavucontrol and the like)
    // aren't apps, so they're left out.
    readonly property var playbackStreams: {
        var _ = Pipewire.nodes.values.length
        return _nodes(function (n) { return n.type === PwNodeType.AudioOutStream && !root._isMonitor(n) })
    }

    readonly property var recordStreams: {
        var _ = Pipewire.nodes.values.length
        return _nodes(function (n) { return n.type === PwNodeType.AudioInStream && !root._isMonitor(n) })
    }

    // Stream node id -> the device node it is linked to. Built from the global
    // link groups: PwNodeLinkTracker reported no groups for stream nodes.
    readonly property var streamDevices: {
        var groups = Pipewire.linkGroups.values
        var out = {}
        for (var i = 0; i < groups.length; i++) {
            var src = groups[i].source, tgt = groups[i].target
            if (!src || !tgt) continue
            if (src.isStream && !tgt.isStream) out[src.id] = tgt       // playback -> output
            else if (tgt.isStream && !src.isStream) out[tgt.id] = src  // input -> recording
        }
        return out
    }

    function deviceOf(stream) {
        return stream ? (root.streamDevices[stream.id] || null) : null
    }

    function _isMonitor(n) {
        var p = n.properties || {}
        return p["stream.monitor"] === "true" || p["stream.monitor"] === true
    }

    function streamName(n) {
        var p = (n && n.properties) || {}
        return p["application.name"] || n.description || n.name || "Unknown"
    }

    function deviceName(n) {
        return n ? (n.nickname || n.description || n.name || "") : ""
    }

    function setStreamVolume(n, v) {
        if (n && n.audio) n.audio.volume = Math.max(0, Math.min(1.5, v))
    }

    function toggleStreamMute(n) {
        if (n && n.audio) n.audio.muted = !n.audio.muted
    }

    // Move a stream to another device. `kind` is "sink" for a playback
    // stream, "source" for a recording one.
    function routeStream(kind, stream, device) {
        if (!stream || !device) return
        _route.command = [Quickshell.shellDir + "/scripts/audio-route.sh",
                          kind, String(stream.id), device.name]
        _route.running = true
    }

    property Process _route: Process {
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") console.warn("audio-route:", text.trim())
        }
    }

    function _nodes(pred) {
        var out = []
        var nodes = Pipewire.nodes.values
        for (var i = 0; i < nodes.length; i++)
            if (pred(nodes[i]))
                out.push(nodes[i])
        return out
    }

    // ── Actions ─────────────────────────────────────────────────────────────
    function setVolume(v) {
        if (sinkAudio)
            sinkAudio.volume = Math.max(0, Math.min(1.5, v))
    }

    function adjustVolume(delta) {
        if (sinkAudio)
            setVolume(sinkAudio.volume + delta)
    }

    function toggleMute() {
        if (sinkAudio)
            sinkAudio.muted = !sinkAudio.muted
    }

    function toggleSourceMute() {
        if (sourceAudio)
            sourceAudio.muted = !sourceAudio.muted
    }

    function setSourceVolume(v) {
        if (sourceAudio)
            sourceAudio.volume = Math.max(0, Math.min(1.5, v))
    }

    function setDefaultSink(node) {
        if (node) Pipewire.preferredDefaultAudioSink = node
    }

    function setDefaultSource(node) {
        if (node) Pipewire.preferredDefaultAudioSource = node
    }
}
