// The middle island offers only local machine usage stats.
pragma Singleton
import QtQuick

QtObject {
    id: root
    readonly property var widgets: [
        { id: "stats", name: "Machine Stats", icon: "\u{f0128}", source: "StatsWidget.qml" }
    ]
    readonly property var pickable: widgets
    readonly property var home: widgets[0]
    function find(id) {
        return id === "stats" || id === "home" ? root.widgets[0] : null
    }
}
