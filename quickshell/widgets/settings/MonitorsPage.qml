// Settings → Monitors: which monitors are on, and which monitor each
// workspace opens on. Both go through the generated hypr config and a
// `hyprctl reload` (see SettingsService.setMonitorMode / setWorkspaceMonitor).
import QtQuick
import "../../theme"
import "../../services"
import "../../components"

Column {
    id: page

    width: parent ? parent.width : 0
    spacing: 12

    readonly property var monitors: MonitorService.monitors

    // Workspace → monitor: the user's choice, else the rule Hyprland has.
    function monitorFor(ws) {
        return SettingsService.workspaceMonitors[ws] || MonitorService.workspaceRules[ws] || ""
    }

    readonly property var monitorOptions: monitors.map(function (m) {
        return { value: m.name, label: MonitorService.label(m.name) }
    })

    Component.onCompleted: MonitorService.refresh()

    Section {
        title: "Displays"
        description: page.monitors.length < 2
                     ? "Only one monitor is connected."
                     : "Turn a monitor off to work on just one. Its workspaces move to the one left on."

        // ── Layout diagram ──────────────────────────────────────────────────
        Item {
            id: diagram

            width: parent.width
            height: 110

            // Scale the whole desktop into the strip.
            readonly property real span: {
                var right = 0, bottom = 0
                for (var i = 0; i < page.monitors.length; i++) {
                    var m = page.monitors[i]
                    right = Math.max(right, m.x + m.width)
                    bottom = Math.max(bottom, m.y + m.height)
                }
                return Math.max(1, right / (width - 20), bottom / (height - 10))
            }
            readonly property real totalW: {
                var right = 0
                for (var i = 0; i < page.monitors.length; i++)
                    right = Math.max(right, page.monitors[i].x + page.monitors[i].width)
                return right / span
            }

            Repeater {
                model: page.monitors

                Rectangle {
                    required property var modelData

                    readonly property bool on: SettingsService.monitorMode === "all"
                                               || SettingsService.monitorMode === modelData.name

                    x: (diagram.width - diagram.totalW) / 2 + modelData.x / diagram.span + 4
                    y: 5 + modelData.y / diagram.span
                    width: modelData.width / diagram.span - 8
                    height: modelData.height / diagram.span
                    radius: 8
                    color: on ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18) : Theme.surface
                    border.width: 1
                    border.color: on ? Theme.accent : Theme.inactive

                    Behavior on color { ColorAnimation { duration: Theme.animDuration } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animDuration } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: MonitorService.label(modelData.name)
                            color: parent.parent.on ? Theme.text : Theme.subtext0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            font.bold: true
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.name
                            color: Theme.subtext0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall - 1
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.width + "×" + modelData.height
                                  + (modelData.refresh ? " @ " + modelData.refresh + "Hz" : "")
                            color: Theme.subtext0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall - 1
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: parent.parent.on ? "On" : "Off"
                            color: parent.parent.on ? Theme.accent : Theme.subtext0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall - 1
                        }
                    }
                }
            }
        }

        ChoiceRow {
            label: "Active monitors"
            visible: page.monitors.length > 1
            current: SettingsService.monitorMode
            options: [{ value: "all", label: page.monitors.length === 2 ? "Both" : "All" }]
                     .concat(page.monitorOptions.map(function (o) {
                         return { value: o.value, label: o.label + " only" }
                     }))
            onPicked: function (v) { SettingsService.setMonitorMode(v) }
        }
    }

    Section {
        title: "Workspaces"
        description: "Which monitor each workspace opens on. Moving one takes its open windows along."
        visible: page.monitors.length > 1

        Grid {
            width: parent.width
            columns: 2
            columnSpacing: 16
            rowSpacing: 2

            Repeater {
                model: 10

                ChoiceRow {
                    required property int index
                    readonly property string ws: String(index + 1)

                    width: (parent.width - parent.columnSpacing) / 2
                    label: "Workspace " + ws
                    current: page.monitorFor(ws)
                    options: page.monitorOptions
                    onPicked: function (v) { SettingsService.setWorkspaceMonitor(ws, v) }
                }
            }
        }
    }
}
