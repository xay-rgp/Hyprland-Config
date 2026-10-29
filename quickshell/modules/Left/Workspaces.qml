// Workspace pills for one monitor.
//
// Sized to its content; TopBar clamps it. Pills show active / occupied / empty
// / urgent, click to activate, scroll to cycle workspaces.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../../theme"
import "../../services"
import "../../components"

Row {
    id: root

    required property var screen

    spacing: Theme.wsSpacing

    readonly property var _live: HyprlandService.workspacesFor(root.screen)

    // Workspaces assigned to this monitor by rule (settings override wins).
    readonly property var _assigned: {
        var out = []
        var name = root.screen ? root.screen.name : ""
        var rules = MonitorService.workspaceRules
        var over = SettingsService.workspaceMonitors
        for (var k in rules) {
            if ((over[k] || rules[k]) === name)
                out.push(parseInt(k))
        }
        for (var k2 in over) {
            if (over[k2] === name && out.indexOf(parseInt(k2)) === -1)
                out.push(parseInt(k2))
        }
        return out
    }

    // Only this monitor's workspaces: everything live on it, plus its lowest
    // assigned workspace that isn't live yet so there is always somewhere to go.
    readonly property var _ids: {
        var seen = ({})
        var out = []
        for (var j = 0; j < _live.length; j++) {
            seen[_live[j].id] = true
            out.push(_live[j].id)
        }
        var spare = _assigned.filter(function (id) { return !seen[id] })
        spare.sort(function (a, b) { return a - b })
        if (spare.length > 0)
            out.push(spare[0])
        if (out.length === 0)
            out.push(1)
        out.sort(function (a, b) { return a - b })
        return out
    }

    function _wsFor(id) {
        for (var i = 0; i < _live.length; i++)
            if (_live[i].id === id)
                return _live[i]
        return null
    }

    function _go(id) {
        // Lua parser: legacy "workspace N" strings are rejected. focus() also
        // moves focus to the owning monitor, so this works from any bar.
        Hyprland.dispatch('hl.dsp.focus({ workspace = "' + id + '" })')
    }

    Repeater {
        model: root._ids

        delegate: Rectangle {
            id: pill
            required property var modelData

            readonly property var ws: root._wsFor(modelData)
            readonly property bool isActive:   ws ? ws.active   : false
            readonly property bool isUrgent:   ws ? ws.urgent   : false
            readonly property bool isOccupied: ws ? ws.toplevels.values.length > 0 : false

            width: isActive ? Theme.wsActiveWidth : Theme.wsDotSize
            height: Theme.wsDotSize
            radius: 4
            anchors.verticalCenter: parent.verticalCenter

            color: isUrgent   ? Theme.wsUrgent
                 : isActive   ? Theme.wsActive
                 : isOccupied ? Theme.wsOccupied
                 : Theme.wsEmpty
            opacity: hover.hovered && !isActive ? 0.75 : 1

            Behavior on width {
                NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
            }
            Behavior on color {
                ColorAnimation { duration: Theme.animFast }
            }

            HoverHandler {
                id: hover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: root._go(pill.modelData)
            }
        }
    }

    // Scroll cycles through this monitor's own workspaces.
    WheelHandler {
        onWheel: function (event) {
            var ids = root._ids
            var cur = 0
            for (var i = 0; i < ids.length; i++) {
                var w = root._wsFor(ids[i])
                if (w && w.active) { cur = i; break }
            }
            var step = event.angleDelta.y > 0 ? -1 : 1
            root._go(ids[(cur + step + ids.length) % ids.length])
        }
    }
}
