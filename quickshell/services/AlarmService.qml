// Persistent wall-clock alarms for the island.

// Each alarm is a local HH:mm and either repeats every day or fires once and
// is then removed. The schedule is stored in ~/.local/state/quickshell so a
// shell restart does not lose it. When one fires, the passive "alarm-ringing"
// widget opens on every monitor and the sound loops until the user stops it.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."
import "../state"

QtObject {
    id: root

    // [{ id, hour, minute, repeat, enabled }]
    property var alarms: []
    property string ringingId: ""
    property var _ringingAlarm: null
    property bool sound: true
    property string _lastChecked: ""
    readonly property var ringingAlarm: _ringingAlarm
    readonly property string soundFile: "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
    // ── Schedule checking ───────────────────────────────────────────────────
    property Timer _timer

    _timer: Timer {
        interval: 250
        repeat: true
        running: true
        onTriggered: root._check()
    }

    property Timer _ringTimeout

    _ringTimeout: Timer {
        interval: 5 * 60 * 1000
        onTriggered: root.stop()
    }

    property Connections _islandFree

    _islandFree: Connections {
        function onIslandOpenChanged() {
            if (root.ringingId && !ShellState.islandOpen)
                Qt.callLater(function() {
                ShellState.showPassive("alarm-ringing");
            });

        }

        target: ShellState
    }

    // ── Sound ───────────────────────────────────────────────────────────────
    property Process _sound

    _sound: Process {
        command: ["pw-play", root.soundFile]
        onExited: {
            if (root.ringingId) {
                root._soundGap.restart();
            }
        }
    }

    property Timer _soundGap

    _soundGap: Timer {
        interval: 700
        onTriggered: {
            if (root.ringingId) {
                root._playSound();
            }
        }
    }

    // ── Persistence ─────────────────────────────────────────────────────────
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"
    readonly property string stateFile: stateDir + "/alarms.json"
    property Process _save

    _save: Process {
    }

    property Process _load

    _load: Process {
        command: ["cat", root.stateFile]

        stdout: StdioCollector {
            onStreamFinished: root._restore(text)
        }

    }

    function find(id) {
        for (var i = 0; i < root.alarms.length; i++) if (root.alarms[i].id === id) {
            return root.alarms[i];
        }
        return null;
    }

    function add(hour, minute, repeat) {
        var alarm = {
            "id": "a" + Date.now() + "-" + Math.floor(Math.random() * 10000),
            "hour": Math.max(0, Math.min(23, Math.floor(hour))),
            "minute": Math.max(0, Math.min(59, Math.floor(minute))),
            "repeat": !!repeat,
            "enabled": true
        };
        root.alarms = root.alarms.concat([alarm]);
        root.save();
        return alarm;
    }

    function update(id, hour, minute, repeat) {
        var out = [];
        for (var i = 0; i < root.alarms.length; i++) {
            var alarm = Object.assign({
            }, root.alarms[i]);
            if (alarm.id === id) {
                alarm.hour = Math.max(0, Math.min(23, Math.floor(hour)));
                alarm.minute = Math.max(0, Math.min(59, Math.floor(minute)));
                alarm.repeat = !!repeat;
            }
            out.push(alarm);
        }
        root.alarms = out;
        root.save();
    }

    function remove(id) {
        if (root.ringingId === id)
            root.stop();

        root.alarms = root.alarms.filter(function(alarm) {
            return alarm.id !== id;
        });
        root.save();
    }

    function toggle(id) {
        root.alarms = root.alarms.map(function(alarm) {
            if (alarm.id !== id)
                return alarm;

            return Object.assign({
            }, alarm, {
                "enabled": !alarm.enabled
            });
        });
        root.save();
    }

    function timeFor(alarm) {
        if (!alarm)
            return "--:--";

        return (alarm.hour < 10 ? "0" : "") + alarm.hour + ":" + (alarm.minute < 10 ? "0" : "") + alarm.minute;
    }

    function _check() {
        if (root.ringingId)
            return ;

        var now = new Date();
        var hour = now.getHours();
        var minute = now.getMinutes();
        var minuteKey = now.toDateString() + " " + hour + ":" + minute;
        if (root._lastChecked === minuteKey)
            return ;

        root._lastChecked = minuteKey;
        var due = root.alarms.filter(function(alarm) {
            return alarm.enabled && alarm.hour === hour && alarm.minute === minute;
        });
        if (due.length === 0)
            return ;

        // The first due alarm is shown. One-shots are consumed immediately so
        // restarting the shell in the same minute cannot ring them again.
        var alarm = due[0];
        if (!alarm.repeat)
            root.remove(alarm.id);

        root._ring(alarm);
    }

    function _ring(alarm) {
        root._ringingAlarm = alarm;
        root.ringingId = alarm.id;
        _ringTimeout.restart();
        root._playSound();
        ShellState.showPassive("alarm-ringing");
    }

    function stop() {
        root._ringingAlarm = null;
        root.ringingId = "";
        _ringTimeout.stop();
        _sound.running = false;
        _soundGap.stop();
        ShellState.hidePassive("alarm-ringing");
    }

    function _playSound() {
        if (root.sound && !_sound.running)
            _sound.running = true;

    }

    function save() {
        _save.command = ["bash", "-c", "mkdir -p '" + root.stateDir + "' && printf '%s' \"$1\" > '" + root.stateFile + "'", "_", JSON.stringify({
            "alarms": root.alarms,
            "sound": root.sound
        })];
        _save.running = true;
    }

    function _restore(raw) {
        if (!raw)
            return ;

        try {
            var saved = JSON.parse(raw);
            if (Array.isArray(saved.alarms))
                root.alarms = saved.alarms.filter(function(alarm) {
                return alarm && alarm.id && alarm.hour >= 0 && alarm.hour < 24 && alarm.minute >= 0 && alarm.minute < 60;
            });

            if (saved.sound !== undefined)
                root.sound = !!saved.sound;

        } catch (e) {
            console.warn("AlarmService: bad state file:", e);
        }
    }

    Component.onCompleted: _load.running = true
}
