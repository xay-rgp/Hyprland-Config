// Loads one island widget by Registry id and reports the size it wants.
//
// Widget contract — a widget is a plain QML file in this directory whose root
// item:
//   - sets implicitWidth / implicitHeight: the island morphs to exactly that
//     size (padding is the widget's own business);
//   - may declare `property bool active`: true while the widget is on screen
//     and the island is open. Bind search-field focus and data refreshes to
//     it, not to ShellState, so the widget works however it was opened;
//   - may declare `property var meta`: receives its Registry entry;
//   - closes the island with ShellState.closeAll() when it is done (an app
//     launched, an entry copied), or ShellState.islandBack() to step back.
// Widgets must not assume which monitor or window they are in.
import QtQuick
import "."

Item {
    id: root

    property string widgetId: "stats"
    property bool   active: false

    readonly property var meta: Registry.find(widgetId)
    readonly property Item item: loader.item

    implicitWidth:  loader.item ? loader.item.implicitWidth  : 0
    implicitHeight: loader.item ? loader.item.implicitHeight : 0

    Loader {
        id: loader
        anchors.fill: parent
        focus: true
        source: !root.meta ? "Placeholder.qml"
              : root.meta.source !== "" ? root.meta.source
              : "Placeholder.qml"

        onLoaded: {
            if ("meta" in item)
                item.meta = Qt.binding(function () { return root.meta })
            if ("active" in item)
                item.active = Qt.binding(function () { return root.active })
        }
    }
}
