// Quickshell entrypoint.
//
// One bar + one frame + one dismiss layer per monitor. Popups are added in
// Chunk 4 via PopupLayer.qml; until then the bar's triggers toggle state that
// nothing renders yet, which is intentional — the wiring is testable first.
import Quickshell
import QtQuick
import "windows"
import "shapes"
import "services"
import "popups"

ShellRoot {
    // Force-instantiate the singleton that registers the IPC handlers, so
    // `qs ipc call theme reload` works even before any popup is opened.
    property var _ipc: Ipc

    Variants {
        model: Quickshell.screens

        delegate: Component {
            Scope {
                required property var modelData

                TopBar { id: topBar; screen: modelData }
                FrameShape    { screen: modelData }
                PopupDismiss  { screen: modelData }

                PopupLayer { barWindow: topBar; screen: modelData }
                Island        { screen: modelData }
            }
        }
    }
}
