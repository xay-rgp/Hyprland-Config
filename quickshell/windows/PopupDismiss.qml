// Dismisses every popup on Escape or on a click outside any popup.
//
// A full-screen transparent layer surface that only exists while something is
// open, so it never eats clicks during normal use.
import Quickshell
import QtQuick
import "../state"
import "../services"

PanelWindow {
    id: root

    // Only the focused monitor should carry the dismiss layer — otherwise the
    // overlay also sits over the other display and swallows its clicks.
    readonly property bool onFocused: HyprlandService.isFocused(root.screen)

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    // Only present when a popup is open. The control center dismisses itself:
    // this layer would map above it and eat its clicks.
    visible: root.onFocused && ShellState.anyOpen(true)

    // Sits below popups but above normal windows for input purposes.
    focusable: true

    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.closeAll()
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: ShellState.closeAll()
    }
}
