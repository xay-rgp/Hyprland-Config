// The session's polkit authentication agent. Replaces hyprpolkitagent: when
// something asks for elevated privileges (pkexec, systemctl, a GUI settings
// app) the island opens the hidden "polkit" widget with the request.
//
// Only one agent can be registered per session, so no other polkit agent may
// be running alongside the shell — it would win the registration and this one
// would never see a request (check `isRegistered` via `qs ipc call polkit
// status`). With the shell down there is no agent at all and pkexec fails
// with "No authentication agent found".
//
// Fail closed: if the island is closed or switched to another widget while a
// request is pending, the request is cancelled rather than left dangling.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import "../state"

QtObject {
    id: root

    readonly property var  flow: agent.flow
    readonly property bool pending: agent.isActive && !!agent.flow
    readonly property bool registered: agent.isRegistered

    property PolkitAgent _agent: PolkitAgent {
        id: agent
        onAuthenticationRequestStarted: ShellState.openWidget("polkit", false)
    }

    // The request finished (success, cancel, or given up): put the island
    // away if it is still showing the prompt.
    property Connections _done: Connections {
        target: agent
        function onIsActiveChanged() {
            if (!agent.isActive && ShellState.islandOpen && ShellState.islandWidget === "polkit")
                ShellState.closeAll()
        }
    }

    // The prompt went away some other way (Escape, click outside, another
    // widget or popup opened): cancel the request.
    readonly property bool _shown: ShellState.islandOpen && ShellState.islandWidget === "polkit"
    on_ShownChanged: if (!_shown) root.cancel()

    function submit(password) {
        if (root.pending) agent.flow.submit(password)
    }

    function cancel() {
        if (root.pending) agent.flow.cancelAuthenticationRequest()
    }
}
