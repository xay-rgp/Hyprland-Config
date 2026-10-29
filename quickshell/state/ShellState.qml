// Global UI state: which popup is open, plus transient bar modes.
//
// One place decides "what is open", so opening anything closes everything
// else and there is no way for two popups to end up stacked.
pragma Singleton
import QtQuick

QtObject {
    id: root

    // ── Popups ──────────────────────────────────────────────────────────────
    // Exactly one of these is true at a time (enforced by open()).
    property bool audioOpen:         false
    property bool bluetoothOpen:     false
    property bool networkOpen:       false
    property bool controlCenterOpen: false

    // Which control-center page is showing: "main" or one of the _ccPages.
    property string ccPage: "main"

    // ── Island (the center pill) ────────────────────────────────────────────
    // Open means it has morphed into a widget. `islandWidget` is a Registry
    // id, or "home" for the grid of every widget. `islandFromHome` records
    // whether the current widget was picked from that grid, so Escape goes
    // back to it rather than closing a widget a keybind opened directly.
    property bool   islandOpen:     false
    property string islandWidget:   "stats"
    property bool   islandFromHome: false

    // Last tab shown in the Settings widget (a tab id from SettingsWidget).
    property string settingsTab: "hyprland"

    // Last tab shown in the Agents widget (a tab id from AgentsWidget).
    property string agentsTab: "claude"

    // ── Transient state ─────────────────────────────────────────────────────
    // Collapses the bar to an edge strip, for fullscreen-ish focus.
    property bool focusMode: false

    // Hover flags for hover-to-open popups, set by the trigger widgets.
    property bool audioTriggerHovered:       false
    property bool userTriggerHovered:        false

    readonly property var _all: ({
        audio:         "audioOpen",
        bluetooth:     "bluetoothOpen",
        network:       "networkOpen",
        controlCenter: "controlCenterOpen",
        island:        "islandOpen"
    })

    // Popups that no longer have a window of their own: they are pages inside
    // the control center. Toggling one of these names opens the control center
    // on that page (so IPC and keybinds keep working); the page's own *Open
    // bool is still set, because the page content hooks off it (scan on open,
    // search-box focus).
    readonly property var _ccPages: ({
        network:       "network",
        bluetooth:     "bluetooth",
        audio:         "audio",
    })

    // Open the control center on `page`, closing every other popup. Done by
    // writing each bool once, not closeAll() + reopen, so the open bool never
    // blips false and restarts the morph animation.
    function showPage(page) {
        for (var k in root._all) {
            if (k === "controlCenter") continue
            root[root._all[k]] = page !== "main" && k === page
        }
        root.ccPage = page
        root.controlCenterOpen = true
    }

    function back() {
        root.showPage("main")
    }

    // Open the island on `widget`, closing every other popup.
    function openWidget(widget, fromHome) {
        if (widget !== "stats" && widget !== "home") return
        widget = "stats"
        root.closeAll("island")
        root.islandFromHome = false
        root.islandWidget = widget
        root.islandOpen = true
    }

    // Passive widgets (Registry `passive`): shown without closing anything
    // else, and only if the island isn't busy with a widget you opened. The
    // pomodoro alarm may replace a notification, never the other way round.
    readonly property var _passiveRank: ({ "pomodoro-alarm": 2, "alarm-ringing": 3 })

    // Passive widgets are disabled for the stats-only island.
    function showPassive(widget) {}

    // Hide a passive widget, leaving any other widget alone.
    function hidePassive(widget) {
        if (root.islandOpen && root.islandWidget === widget)
            root.islandOpen = false
    }


    // Same widget again closes the island; anything else switches to it.
    function toggleWidget(widget) {
        if (root.islandOpen && root.islandWidget === widget)
            root.closeAll()
        else
            root.openWidget(widget, false)
    }

    // Escape inside the island: back to the grid, or close.
    function islandBack() {
        if (root.islandFromHome) root.openWidget("home", false)
        else root.closeAll()
    }

    // `exceptControlCenter` skips the control center, its pages and the
    // island, which all handle their own click-outside dismissal.
    function anyOpen(exceptControlCenter) {
        for (var k in root._all) {
            if (exceptControlCenter
                    && (k === "controlCenter" || k === "island"
                        || root._ccPages[k] !== undefined))
                continue
            if (root[root._all[k]])
                return true
        }
        return false
    }

    // Close everything, optionally leaving one popup open.
    function closeAll(except) {
        for (var k in root._all) {
            if (k === except) continue
            root[root._all[k]] = false
        }
    }

    // Open one popup, closing the rest. Toggling the same one closes it.
    function toggle(name) {
        var page = root._ccPages[name]
        if (page !== undefined) {
            if (root.controlCenterOpen && root.ccPage === page)
                root.closeAll()
            else
                root.showPage(page)
            return
        }
        if (name === "controlCenter" && !root.controlCenterOpen) {
            root.showPage("main")
            return
        }

        var prop = root._all[name]
        if (prop === undefined) {
            console.warn("ShellState.toggle: unknown popup", name)
            return
        }
        var next = !root[prop]
        root.closeAll(next ? name : undefined)
        root[prop] = next
    }

    function open(name) {
        var page = root._ccPages[name]
        if (page !== undefined || name === "controlCenter") {
            root.showPage(page !== undefined ? page : "main")
            return
        }
        var prop = root._all[name]
        if (prop === undefined) return
        root.closeAll(name)
        root[prop] = true
    }

    function close(name) {
        // A page closing itself is done
        // with the whole control center, not just that page.
        if (root._ccPages[name] !== undefined || name === "controlCenter") {
            if (root.controlCenterOpen) root.closeAll()
            return
        }
        var prop = root._all[name]
        if (prop !== undefined) root[prop] = false
    }

    function isOpen(name) {
        var prop = root._all[name]
        return prop !== undefined && root[prop]
    }
}
