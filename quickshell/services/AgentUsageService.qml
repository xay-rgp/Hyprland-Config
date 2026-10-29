// Usage for the Agents widget: Claude and OpenCode Go subscription limits,
// and Bifrost gateway stats, from scripts/agent-usage.py. Credentials stay in
// the script — this only ever sees the numbers. Claude can have several
// accounts, through `claude-account` (dotfiles-bin): useClaudeAccount()
// switches which one Claude Code signs in with, addClaudeAccount() saves the
// one it's signed in with now.
//
// Each source is fetched on its own: the subscriptions (Claude, OpenCode)
// are quick and polled every minute while the widget is on screen
// (`watching`), every few minutes otherwise. Bifrost's 7-day queries take ~15 s, so it is never
// fetched on open: the last result is kept on disk (~/.cache/quickshell/
// bifrost.json, written by the script), loaded on start, and refreshed every
// 30 minutes — at start only when that copy is older. refresh() fetches all
// of them now.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string script: Quickshell.shellDir + "/scripts/agent-usage.py"

    // Last result per source; see the script for the shape. Kept when a
    // later fetch fails outright, so the widget never blanks.
    property var claude: null
    property var opencode: null
    property var bifrost: null
    property date fetchedAt: new Date(0)
    property date bifrostFetchedAt: new Date(0)
    readonly property bool claudeBusy: _claude.running
    readonly property bool opencodeBusy: _opencode.running
    readonly property bool bifrostBusy: _bifrost.running
    readonly property bool busy: claudeBusy || opencodeBusy || bifrostBusy
    // "use" or "add" while `claude-account` runs one.
    readonly property string accountAction: _account.running ? _account.action : ""
    // Why the last one failed, until the next one.
    property string accountError: ""

    // Set by the widget while it is visible.
    property bool watching: false
    onWatchingChanged: if (watching && Date.now() - fetchedAt.getTime() > 30000) _fetchSubscriptions()

    function refresh() {
        _fetchSubscriptions()
        _bifrost.fetch()
    }

    function useClaudeAccount(uuid) { _runAccount(["use", uuid]) }
    function addClaudeAccount() { _runAccount(["add"]) }

    function _runAccount(args) {
        if (_account.running) return
        accountError = ""
        _account.args = args
        _account.running = true
    }

    function _fetchSubscriptions() {
        _claude.fetch()
        _opencode.fetch()
    }

    component Fetch: Process {
        id: proc
        property string source
        // A fetch asked for mid-run (say, after a switch) runs once this one
        // ends, rather than being dropped for results that are already stale.
        property bool again: false
        function fetch() { if (running) again = true; else running = true }
        onExited: if (again) { again = false; running = true }

        command: ["python3", root.script, source]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var out = JSON.parse(text)
                    root[proc.source] = out[proc.source]
                    root.fetchedAt = new Date(out.fetched_at)
                    if (proc.source === "bifrost" && out.bifrost.ok)
                        root.bifrostFetchedAt = root.fetchedAt
                } catch (e) {
                    console.warn("agent-usage:", proc.source, "bad output:", e)
                }
            }
        }
    }

    property Fetch _claude: Fetch { source: "claude" }
    property Fetch _opencode: Fetch { source: "opencode" }
    property Fetch _bifrost: Fetch { source: "bifrost" }

    property Process _account: Process {
        property var args: []
        readonly property string action: args.length ? args[0] : ""
        command: [Quickshell.env("HOME") + "/.local/bin/claude-account"].concat(args)

        // stderr carries notes on success too, so it's only an error with a
        // non-zero exit. Either may arrive first; settle() runs on both.
        property int code: 0
        property string err: ""
        function settle() {
            root.accountError = code !== 0 ? err.trim().replace(/^claude-account: /, "") : ""
        }
        onStarted: { code = 0; err = "" }
        stderr: StdioCollector {
            onStreamFinished: { root._account.err = text; root._account.settle() }
        }
        onExited: function (exitCode) {
            code = exitCode
            settle()
            root._claude.fetch()
        }
    }

    property Timer _subscriptionPoll: Timer {
        interval: root.watching ? 60000 : 300000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root._fetchSubscriptions()
    }

    readonly property int bifrostInterval: 30 * 60000

    // Last good Bifrost result, from before this shell started.
    property FileView _bifrostCache: FileView {
        path: Quickshell.env("HOME") + "/.cache/quickshell/bifrost.json"
        onLoaded: {
            try {
                var out = JSON.parse(text())
                if (root.bifrost === null && out.bifrost && out.bifrost.ok) {
                    root.bifrost = out.bifrost
                    root.bifrostFetchedAt = new Date(out.fetched_at)
                }
            } catch (e) {
                console.warn("agent-usage: bad bifrost cache:", e)
            }
            root._bifrostStart()
        }
        onLoadFailed: root._bifrostStart()
    }

    // Fetch on start only if the cached copy is stale or missing.
    function _bifrostStart() {
        if (Date.now() - bifrostFetchedAt.getTime() >= bifrostInterval) _bifrost.fetch()
        _bifrostPoll.running = true
    }

    property Timer _bifrostPoll: Timer {
        interval: root.bifrostInterval
        repeat: true
        onTriggered: root._bifrost.fetch()
    }
}
