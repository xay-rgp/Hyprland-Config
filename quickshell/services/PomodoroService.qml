// Pomodoro timer: focus / short break / long break.
//
// Time is kept as an end timestamp (`endsAt`) while running, not a counter,
// so it stays right across a shell reload, a restart or a suspend: a running
// timer comes back running, and one that ran out meanwhile rings.
//
// When a phase ends the alarm rings: a sound on a loop (for up to a minute)
// and the island opens the hidden "pomodoro-alarm" widget on every monitor
// with quick actions — start the next phase, five more minutes, or stop. It
// is passive (no keyboard grab); if another widget is open, it waits until
// that one closes.
// panel.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."
import "../state"

QtObject {
    id: root

    // ── Configuration (saved) ───────────────────────────────────────────────
    property int workMinutes: 25
    property int shortMinutes: 5
    property int longMinutes: 15
    property int longEvery: 4             // a long break after this many focuses
    property bool autoStartNext: false    // roll straight into the next phase
    property bool sound: true

    readonly property string soundFile: "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
    readonly property int ringSeconds: 60

    // ── Session state ───────────────────────────────────────────────────────
    // phase: "work" | "short" | "long"
    property string phase: "work"
    property bool running: false
    property real endsAt: 0               // ms since epoch, while running
    property int remaining: workMinutes * 60
    property int completed: 0             // focuses since the last long break

    // The alarm: which phase just ended, while it rings.
    property bool ringing: false
    property string finishedPhase: ""

    readonly property int totalSeconds: minutesFor(phase) * 60
    function minutesFor(p) {
        return p === "work" ? workMinutes : p === "short" ? shortMinutes : longMinutes
    }

    // A session is underway: running, or paused partway through.
    readonly property bool active: running || remaining < totalSeconds

    // 0..1, for rings.
    readonly property real progress: totalSeconds > 0 ? 1 - remaining / totalSeconds : 0

    readonly property string clock: {
        var m = Math.floor(remaining / 60), s = remaining % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }

    function labelFor(p) {
        return p === "work" ? "Focus" : p === "short" ? "Short break" : "Long break"
    }
    readonly property string phaseLabel: labelFor(phase)

    // ── Tick ────────────────────────────────────────────────────────────────
    property Timer _timer: Timer {
        interval: 250
        repeat: true
        running: root.running
        onTriggered: root._tick()
    }

    function _tick() {
        root.remaining = Math.max(0, Math.ceil((root.endsAt - Date.now()) / 1000))
        if (root.remaining === 0) root._complete(true)
    }

    function _complete(ring) {
        root.running = false
        var finished = root.phase

        if (finished === "work") {
            root.completed++
            root.phase = root.completed % root.longEvery === 0 ? "long" : "short"
        } else {
            if (finished === "long") root.completed = 0
            root.phase = "work"
        }
        root.remaining = root.totalSeconds


        if (root.autoStartNext) root.start()
        else root.save()

        if (ring) {
            root.finishedPhase = finished
            root.ringing = true
            // Rolling on by itself needs only a nudge, not a minute of alarm.
            _ringTimeout.interval = root.autoStartNext ? 8000 : root.ringSeconds * 1000
            _ringTimeout.restart()
            root._playSound()
            ShellState.showPassive("pomodoro-alarm")
        }
    }

    // ── Controls ────────────────────────────────────────────────────────────
    function start() {
        if (root.running) return
        if (root.remaining <= 0) root.remaining = root.totalSeconds
        root.endsAt = Date.now() + root.remaining * 1000
        root.running = true
        root.save()
    }

    function pause() {
        if (!root.running) return
        root._tick()
        root.running = false
        root.save()
    }

    function toggle() { root.running ? root.pause() : root.start() }

    function reset() {
        root.running = false
        root.remaining = root.totalSeconds
        root.save()
    }

    // End the current phase now (no alarm).
    function skip() {
        root.dismiss()
        root._complete(false)
    }

    function setPhase(p) {
        root.dismiss()
        root.running = false
        root.phase = p
        root.remaining = root.totalSeconds
        root.save()
    }

    // ── Alarm actions ───────────────────────────────────────────────────────
    function dismiss() {
        if (!root.ringing) return
        root.ringing = false
        _ringTimeout.stop()
        _sound.running = false
        _soundGap.stop()
        ShellState.hidePassive("pomodoro-alarm")
    }

    // Start the phase that's up next.
    function startNext() {
        root.dismiss()
        root.start()
    }

    // Back to the phase that just ended, for a few more minutes.
    function snooze(minutes) {
        var back = root.finishedPhase
        root.dismiss()
        if (!back) return
        if (back === "work") root.completed = Math.max(0, root.completed - 1)
        root.running = false
        root.phase = back
        root.remaining = (minutes || 5) * 60
        root.start()
    }

    property Timer _ringTimeout: Timer {
        onTriggered: root.dismiss()
    }

    // If the alarm couldn't show (another widget was open), show it as soon
    // as the island is free.
    property Connections _islandFree: Connections {
        target: ShellState
        function onIslandOpenChanged() {
            if (root.ringing && !ShellState.islandOpen)
                Qt.callLater(function () { ShellState.showPassive("pomodoro-alarm") })
        }
    }

    // ── Sound ───────────────────────────────────────────────────────────────
    // Replayed with a short gap while ringing.
    property Process _sound: Process {
        command: ["pw-play", root.soundFile]
        onExited: if (root.ringing && !root.autoStartNext) root._soundGap.restart()
    }
    property Timer _soundGap: Timer {
        interval: 700
        onTriggered: if (root.ringing) root._playSound()
    }
    function _playSound() {
        if (root.sound && !_sound.running) _sound.running = true
    }

    // ── Persistence ─────────────────────────────────────────────────────────
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"
    readonly property string stateFile: stateDir + "/pomodoro.json"

    function save() {
        _save.command = ["bash", "-c",
            "mkdir -p '" + root.stateDir + "' && printf '%s' \"$1\" > '" + root.stateFile + "'",
            "_", JSON.stringify({
                phase: root.phase,
                running: root.running,
                endsAt: root.endsAt,
                remaining: root.remaining,
                completed: root.completed,
                workMinutes: root.workMinutes,
                shortMinutes: root.shortMinutes,
                longMinutes: root.longMinutes,
                longEvery: root.longEvery,
                autoStartNext: root.autoStartNext,
                sound: root.sound
            })]
        _save.running = true
    }

    // Duration changes apply to a phase that hasn't started yet.
    onWorkMinutesChanged:  _durationsChanged()
    onShortMinutesChanged: _durationsChanged()
    onLongMinutesChanged:  _durationsChanged()
    function _durationsChanged() {
        if (!root._loaded) return
        if (!root.running && !root.ringing) root.remaining = root.totalSeconds
        root.save()
    }

    property bool _loaded: false
    property Process _save: Process {}

    property Process _load: Process {
        command: ["cat", root.stateFile]
        stdout: StdioCollector { onStreamFinished: root._restore(text) }
        onExited: root._loaded = true
    }

    function _restore(raw) {
        if (!raw) return
        try {
            var o = JSON.parse(raw)
            var keys = ["workMinutes", "shortMinutes", "longMinutes", "longEvery",
                        "completed", "autoStartNext", "sound", "phase"]
            for (var i = 0; i < keys.length; i++)
                if (o[keys[i]] !== undefined) root[keys[i]] = o[keys[i]]
            root.remaining = o.remaining !== undefined ? o.remaining : root.totalSeconds

            if (o.running && o.endsAt) {
                var left = o.endsAt - Date.now()
                if (left > 0) {
                    root.endsAt = o.endsAt
                    root.running = true
                } else {
                    // Ran out while the shell was away: ring if it was
                    // recent, otherwise just move on quietly.
                    root.remaining = 0
                    root._complete(left > -10 * 60 * 1000)
                }
            }
        } catch (e) {
            console.warn("pomodoro: bad state file:", e)
        }
    }

    Component.onCompleted: _load.running = true
}
