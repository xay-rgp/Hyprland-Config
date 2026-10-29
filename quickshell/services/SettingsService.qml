// Runtime settings behind the island's Settings widget.
//
// Three kinds of setting live here:
//
//   * Hyprland knobs (blur, opacities, gaps, animations) — applied live
//     through HyprlandService, which speaks `hyprctl eval` because this
//     machine runs Hyprland with a Lua config (finding F2).
//   * Monitor layout (all monitors, or just one) and which monitor each
//     workspace lives on — applied by rewriting the generated file below,
//     since monitors.lua / workspaces.lua read it. Workspaces re-run
//     workspaces.lua in place (_rerun); monitors need a `hyprctl reload`,
//     because with a Lua config hl.monitor() outside a config load only
//     records the rule. See setMonitorMode for the crash that reload must
//     avoid.
//   * kitty knobs (font_size, cursor_trail, window_margin_width,
//     background_opacity) — written into kitty/user-settings.conf, which
//     kitty.conf includes last. That file is gitignored, exactly like
//     current-theme.conf, so runtime changes never dirty the repo. After a
//     write kitty is signalled with SIGUSR1 to reload.
//
// Everything is mirrored to ~/.local/state/quickshell/settings.json and
// re-applied on startup, so a shell restart restores what you chose. The
// Hyprland side is also written to ~/.config/hypr/conf/generated/
// shell_settings.lua (gitignored; see hypr's conf/shell_settings.lua), so it
// survives a Hyprland restart or `hyprctl reload` too.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."
import "../state"

QtObject {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string stateDir: home + "/.local/state/quickshell"
    readonly property string stateFile: stateDir + "/settings.json"
    readonly property string kittyFile: home + "/.config/kitty/user-settings.conf"
    readonly property string hyprFile: home + "/.config/hypr/conf/generated/shell_settings.lua"

    // ── Hyprland-backed values ──────────────────────────────────────────────
    property bool   blurEnabled: true
    property int    blurSize: 8
    property int    blurPasses: 2
    property real   activeOpacity: 1.0
    property real   inactiveOpacity: 0.9
    property bool   animationsEnabled: true
    property int    gapsIn: 5
    property int    gapsOut: 10
    property int    rounding: 10

    // ── kitty-backed values ─────────────────────────────────────────────────
    property int    cursorTrail: 3
    property real   backgroundOpacity: 0.85
    property real   fontSize: 12
    property int    kittyMargin: 20       // window_margin_width, in pts

    // ── Monitors / workspaces ───────────────────────────────────────────────
    // "all", or the one output name left on (e.g. "DP-3").
    property string monitorMode: "all"
    // Workspace id (string) → output name. Only workspaces the user moved;
    // the rest keep the monitor workspaces.lua gives them.
    property var    workspaceMonitors: ({})

    // ── Shell-only values ───────────────────────────────────────────────────
    // Consumed directly by Metrics/Theme at runtime.
    property int    barHeight: 28
    property int    animDuration: 320
    // Control center opens on hover of the notch (true) or on click (false).
    property bool   ccOpenOnHover: false
    // Audio page: per-application volume and device routing.
    property bool   audioPerApp: false

    // ── Applying ────────────────────────────────────────────────────────────

    function applyHyprland() {
        HyprlandService.setBlur("enabled", blurEnabled)
        HyprlandService.setBlur("size", blurSize)
        HyprlandService.setBlur("passes", blurPasses)
        HyprlandService.setDecoration("active_opacity", activeOpacity.toFixed(2))
        HyprlandService.setDecoration("inactive_opacity", inactiveOpacity.toFixed(2))
        HyprlandService.setDecoration("rounding", rounding)
        HyprlandService.setGeneral("gaps_in", gapsIn)
        HyprlandService.setGeneral("gaps_out", gapsOut)
        HyprlandService.setAnimationsEnabled(animationsEnabled)
        // Our own surfaces need the layerrule re-stated when blur toggles.
        HyprlandService.setLayerBlur(blurEnabled)
    }

    // The Hyprland half of the settings as a Lua table for hypr's
    // conf/shell_settings.lua. Monitors are disabled only if they are known
    // and aren't the chosen one, so a stale name can never switch all off.
    function _hyprLua() {
        var mons = []
        if (root.monitorMode !== "all") {
            var names = MonitorService.monitors.map(function (m) { return m.name })
            if (names.indexOf(root.monitorMode) !== -1)
                for (var i = 0; i < names.length; i++)
                    if (names[i] !== root.monitorMode)
                        mons.push('        ["' + names[i] + '"] = { disabled = true },')
        }
        var ws = []
        for (var k in root.workspaceMonitors)
            ws.push('        ["' + k + '"] = "' + root.workspaceMonitors[k] + '",')

        return "-- Generated by the Quickshell settings widget. Do not edit: it is\n"
             + "-- rewritten on every change. Read by conf/shell_settings.lua.\n"
             + "return {\n"
             + "    config = {\n"
             + "        general = { gaps_in = " + gapsIn + ", gaps_out = " + gapsOut + " },\n"
             + "        decoration = {\n"
             + "            active_opacity = " + activeOpacity.toFixed(2)
             + ", inactive_opacity = " + inactiveOpacity.toFixed(2)
             + ", rounding = " + rounding + ",\n"
             + "            blur = { enabled = " + blurEnabled + ", size = " + blurSize
             + ", passes = " + blurPasses + " },\n"
             + "        },\n"
             + "        animations = { enabled = " + animationsEnabled + " },\n"
             + "    },\n"
             + "    monitors = {\n" + mons.join("\n") + (mons.length ? "\n" : "") + "    },\n"
             + "    workspaces = {\n" + ws.join("\n") + (ws.length ? "\n" : "") + "    },\n"
             + "}\n"
    }

    // Write the Lua file, then run `after` (a shell snippet) once it exists.
    // A write requested while one is running is queued, not dropped (setting
    // `command` on a running Process is silently lost); queued requests
    // collapse into one, which renders the latest values anyway.
    property bool   _hyprQueued: false
    property string _hyprQueuedAfter: ""

    function _writeHypr(after) {
        if (_hyprWrite.running) {
            _hyprQueued = true
            if (after) _hyprQueuedAfter = _hyprQueuedAfter ? _hyprQueuedAfter + "; " + after : after
            return
        }
        _hyprWrite.command = ["bash", "-c",
            "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\" && { " + (after || "true") + "; }",
            "_", root.hyprFile, root._hyprLua()]
        _hyprWrite.running = true
    }

    property Process _hyprWrite: Process {
        onExited: {
            if (root._hyprQueued) {
                var after = root._hyprQueuedAfter
                root._hyprQueued = false
                root._hyprQueuedAfter = ""
                root._writeHypr(after)
            } else {
                MonitorService.refreshSoon()
            }
        }
    }

    // Shell snippet: re-run one hypr conf module so it picks up the freshly
    // written generated file. The module and both settings modules are
    // dropped from Lua's require cache first, or require would no-op.
    function _rerun(module) {
        return "hyprctl eval 'for _, m in ipairs({ \"conf.generated.shell_settings\", "
             + "\"conf.shell_settings\", \"" + module + "\" }) do package.loaded[m] = nil end; "
             + "require(\"" + module + "\")' >/dev/null"
    }

    // monitors.lua restates every monitor's full spec, so a reload brings a
    // disabled monitor back on as well as switching one off.
    //
    // The island (Settings is open in it, holding exclusive keyboard focus)
    // is closed first, and the reload waits for it to let go. Hyprland 0.56.2
    // segfaults (CLayerSurface::onUnmap → CInputManager::refocusLastWindow →
    // ILuaConfigValue::asString) when a layer surface that has keyboard focus
    // is destroyed with its monitor — which is what Quickshell does to every
    // surface on a monitor that goes away. Unfocused surfaces skip that
    // refocus path.
    function setMonitorMode(mode) {
        if (mode === root.monitorMode) return
        root.monitorMode = mode
        save()
        ShellState.closeAll()
        _monitorApply.restart()
    }

    property Timer _monitorApply: Timer {
        interval: 500
        onTriggered: root._writeHypr("hyprctl reload >/dev/null")
    }

    // Record the assignment, re-run workspaces.lua so the rule is current,
    // and move the workspace now if it already exists (rules only apply on
    // creation).
    function setWorkspaceMonitor(ws, output) {
        var map = Object.assign({}, root.workspaceMonitors)
        map[ws] = output
        root.workspaceMonitors = map
        save()
        _writeHypr(_rerun("conf.hyprland.workspaces") + "; hyprctl eval "
                   + "'hl.dispatch(hl.dsp.workspace.move({ workspace = \"" + ws
                   + "\", monitor = \"" + output + "\" }))' >/dev/null")
    }

    // kitty reads this file on SIGUSR1; rewriting the whole thing keeps the
    // file honest rather than appending duplicates on every change.
    function applyKitty() {
        var body = "# Generated by the Quickshell settings widget. Do not edit.\n"
                 + "# kitty.conf includes this file last; it is gitignored.\n"
                 + "cursor_trail " + cursorTrail + "\n"
                 + "background_opacity " + backgroundOpacity.toFixed(2) + "\n"
                 + "font_size " + fontSize.toFixed(1) + "\n"
                 + "window_margin_width " + kittyMargin + "\n"
        _kittyWrite.command = ["bash", "-c",
            "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\" && " +
            "pkill -SIGUSR1 -x kitty 2>/dev/null; true", "_", root.kittyFile, body]
        _kittyWrite.running = true
    }

    property Process _kittyWrite: Process {}

    // ── Persistence ─────────────────────────────────────────────────────────

    function snapshot() {
        return {
            blurEnabled: root.blurEnabled,
            blurSize: root.blurSize,
            blurPasses: root.blurPasses,
            activeOpacity: root.activeOpacity,
            inactiveOpacity: root.inactiveOpacity,
            animationsEnabled: root.animationsEnabled,
            gapsIn: root.gapsIn,
            gapsOut: root.gapsOut,
            rounding: root.rounding,
            cursorTrail: root.cursorTrail,
            backgroundOpacity: root.backgroundOpacity,
            fontSize: root.fontSize,
            kittyMargin: root.kittyMargin,
            monitorMode: root.monitorMode,
            workspaceMonitors: root.workspaceMonitors,
            barHeight: root.barHeight,
            animDuration: root.animDuration,
            ccOpenOnHover: root.ccOpenOnHover,
            audioPerApp: root.audioPerApp
        }
    }

    function save() {
        _save.command = ["bash", "-c",
            "mkdir -p '" + root.stateDir + "' && printf '%s' \"$1\" > '" + root.stateFile + "'",
            "_", JSON.stringify(root.snapshot())]
        _save.running = true
    }

    // Called after every UI change: Hyprland takes the change live straight
    // away; files (state, hypr Lua, kitty) are written once a drag settles,
    // rather than on every slider step.
    function commit() {
        applyHyprland()
        _flush.restart()
    }

    property Timer _flush: Timer {
        interval: 300
        onTriggered: {
            root.save()
            root._writeHypr()
            root.applyKitty()
        }
    }

    property Process _save: Process {}

    property Process _load: Process {
        command: ["cat", root.stateFile]
        stdout: StdioCollector { onStreamFinished: root._restore(text) }
    }

    function _restore(raw) {
        if (!raw)
            return
        try {
            var o = JSON.parse(raw)
            for (var k in o) {
                if (root[k] !== undefined)
                    root[k] = o[k]
            }
            // Standalone: restore widget state without applying desktop settings.
        } catch (e) {
            console.log("SettingsService: bad state file:", e)
        }
    }

    // Restore the compiled-in defaults.
    function reset() {
        blurEnabled = true; blurSize = 8; blurPasses = 2
        activeOpacity = 1.0; inactiveOpacity = 0.9
        animationsEnabled = true; gapsIn = 5; gapsOut = 10; rounding = 10
        cursorTrail = 3; backgroundOpacity = 0.85; fontSize = 12; kittyMargin = 20
        barHeight = 28; animDuration = 320
        ccOpenOnHover = false
        audioPerApp = false
        commit()
    }

    Component.onCompleted: _load.running = true
}
