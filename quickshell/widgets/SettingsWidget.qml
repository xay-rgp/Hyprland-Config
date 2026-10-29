// Settings: a tab bar over a scrolling page. Each tab is one QML file in
// settings/, built from Section (nestable), SliderRow, ToggleRow and
// ChoiceRow. Adding a tab = a new page file + an entry in `tabs`.
//
// Tab / Shift+Tab (or Ctrl+PageDown / PageUp, or h / l) switch tabs;
// j / k scroll the page.
import QtQuick
import "../theme"
import "../state"
import "../components"
import "settings"

Item {
    id: root

    property bool active: false

    readonly property var tabs: [
        { id: "hyprland", name: "Hyprland", icon: "\uf2d2", source: "settings/HyprlandPage.qml" },
        { id: "monitors", name: "Monitors", icon: "\uf108", source: "settings/MonitorsPage.qml" },
        { id: "kitty",    name: "Kitty",    icon: "\uf120", source: "settings/KittyPage.qml" }
    ]

    // Remembered in ShellState, so Settings reopens on the last tab and
    // `qs ipc call island settings <tab>` can open it on a given one.
    readonly property int current: Math.max(0, tabs.findIndex(function (t) {
        return t.id === ShellState.settingsTab
    }))
    function select(i) { ShellState.settingsTab = root.tabs[i].id }

    readonly property int pad: 16

    implicitWidth: 600
    implicitHeight: 600

    onActiveChanged: if (active) root.forceActiveFocus()
    focus: active

    Keys.onPressed: function (event) {
        var ctrl = event.modifiers & Qt.ControlModifier
        if (event.key === Qt.Key_Tab || (ctrl && event.key === Qt.Key_PageDown)) {
            root.select((root.current + 1) % root.tabs.length)
            event.accepted = true
        } else if (event.key === Qt.Key_Backtab || (ctrl && event.key === Qt.Key_PageUp)) {
            root.select((root.current - 1 + root.tabs.length) % root.tabs.length)
            event.accepted = true
        } else if (event.key === Qt.Key_L) {
            root.select((root.current + 1) % root.tabs.length)
            event.accepted = true
        } else if (event.key === Qt.Key_H) {
            root.select((root.current - 1 + root.tabs.length) % root.tabs.length)
            event.accepted = true
        } else if (event.key === Qt.Key_J || event.key === Qt.Key_K) {
            var max = Math.max(0, flick.contentHeight - flick.height)
            var dy = event.key === Qt.Key_J ? 60 : -60
            flick.contentY = Math.max(0, Math.min(max, flick.contentY + dy))
            event.accepted = true
        }
    }

    // ── Header: title + tabs ────────────────────────────────────────────────
    Item {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: root.pad }
        height: 36

        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: "Settings"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLarge + 2
            font.bold: true
        }

        TabBar {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            tabs: root.tabs
            current: root.current
            onSelected: function (i) { root.select(i) }
        }
    }

    // ── Page ────────────────────────────────────────────────────────────────
    Flickable {
        id: flick
        anchors {
            top: header.bottom
            topMargin: 14
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: root.pad
            rightMargin: root.pad
            bottomMargin: root.pad
        }
        clip: true
        contentWidth: width
        contentHeight: page.item ? page.item.implicitHeight : 0
        boundsBehavior: Flickable.StopAtBounds

        Loader {
            id: page
            width: flick.width
            source: root.tabs[root.current].source

            // New tab: fade and nudge up into place, from the top.
            onLoaded: {
                flick.contentY = 0
                enter.restart()
            }
        }

        ParallelAnimation {
            id: enter
            NumberAnimation { target: page; property: "opacity"; from: 0; to: 1; duration: Theme.animDuration; easing.type: Easing.OutCubic }
            NumberAnimation { target: page; property: "y"; from: 10; to: 0; duration: Theme.animDuration; easing.type: Easing.OutCubic }
        }
    }
}
