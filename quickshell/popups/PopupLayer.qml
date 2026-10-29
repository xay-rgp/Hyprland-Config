// Instantiates the popup windows for one monitor. Today that is just the
// control center, which grows out of the right notch and hosts every panel
// (network, bluetooth, audio, lights) as a page.
import QtQuick
import Quickshell
import "../theme"
import "../state"
import "../services"
import "../components"
import "../shapes"

Item {
    id: root

    // Bar window to anchor against, supplied by shell.qml.
    property var barWindow: null

    // This layer's monitor. Popups must only appear on the focused display;
    // without the guard each popup would render on every monitor at once.
    property var screen: null

    readonly property bool active: HyprlandService.isFocused(root.screen)

    // ── Control center ──────────────────────────────────────────────────────
    // Hosts network, bluetooth, audio and lights as
    // pages; those names route here through ShellState._ccPages.
    ControlCenter {
        screen: root.screen
        barWindow: root.barWindow
        active: root.active
    }
}
