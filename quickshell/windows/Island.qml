// The island: a floating pill at the top center that morphs between three
// shapes.
//
//   rest   — a small clock pill (EQ bars while music plays)
//   peek   — on hover: now playing / clock + date / RAM
//   widget — on click or keybind: one Registry widget, "home" being the
//            grid of all of them (see widgets/Registry.qml). The shell also
//            opens hidden ones itself: the polkit prompt, and new
//            notifications (passive: no keyboard grab, no backdrop)
//
// Like the control center, the surface covers the whole monitor and stays
// mapped, so the morph never resizes the window and Hyprland's layersIn fade
// never plays over it. The input mask is just the pill until a widget opens,
// then the whole monitor, so a click outside closes it. It dismisses itself
// for the same reason the control center does: PopupDismiss would map above
// it and swallow its clicks.
//
// Only the focused monitor's island opens a widget (passive ones show on
// all); every monitor shows its own rest/peek pill.
import Quickshell
import Quickshell.Wayland
import QtQuick
import "../theme"
import "../state"
import "../services"
import "../modules/Island"
import "../widgets"

PanelWindow {
    id: root

    readonly property bool active: HyprlandService.isFocused(root.screen)
    // A passive widget (a notification) shows on every monitor, without the
    // keyboard or a click-outside backdrop, so it never interrupts what
    // you're doing. Other widgets open on the focused monitor only.
    readonly property bool passive: {
        var meta = Registry.find(ShellState.islandWidget)
        return !!meta && !!meta.passive
    }
    readonly property bool open: ShellState.islandOpen && (active || passive)
    readonly property bool modal: open && !passive

    readonly property string mode: open ? "widget" : peeking ? "peek" : "rest"

    // ── Target size per mode ────────────────────────────────────────────────
    readonly property int targetW: mode === "widget" ? host.implicitWidth
                                 : mode === "peek"   ? Theme.islandPeekWidth
                                 : rest.implicitWidth + 28
    readonly property int targetH: mode === "widget" ? Math.min(host.implicitHeight, maxH)
                                 : mode === "peek"   ? Theme.islandPeekHeight
                                 : Theme.islandRestHeight

    readonly property int maxH: height - Theme.islandTop - 40

    // Material 3 "emphasized", same curve as the control center's morph.
    readonly property var emphasized: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4,
                                       5 / 24, 0.82, 0.25, 1, 1, 1]

    // ── Window ──────────────────────────────────────────────────────────────
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    visible: !ShellState.focusMode || root.open

    // Widgets with search fields (launcher) need keys the moment they open.
    WlrLayershell.keyboardFocus: root.modal ? WlrKeyboardFocus.Exclusive
                                           : WlrKeyboardFocus.None

    mask: Region {
        x: root.modal ? 0 : body.x
        y: root.modal ? 0 : body.y
        width: root.modal ? root.width : body.width
        height: root.modal ? root.height : body.height
    }

    // One clock for both the rest and peek faces.
    property date now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    // ── Hover → peek ────────────────────────────────────────────────────────
    // A short open delay so sweeping the pointer across the top doesn't flash
    // it, and a close delay so the growing edge doesn't flicker it shut.
    property bool peeking: false
    readonly property bool _hovered: bodyHover.hovered

    on_HoveredChanged: {
        if (_hovered) { unpeekTimer.stop(); peekTimer.restart() }
        else          { peekTimer.stop();   unpeekTimer.restart() }
    }
    onOpenChanged: if (!open && !_hovered) peeking = false

    Timer { id: peekTimer;   interval: 90;                    onTriggered: root.peeking = true }
    Timer { id: unpeekTimer; interval: Theme.hoverCloseDelay; onTriggered: root.peeking = false }

    // ── Dismissal ───────────────────────────────────────────────────────────
    Shortcut {
        sequence: "Escape"
        enabled: root.modal
        onActivated: ShellState.islandBack()
    }

    // Click outside closes; presses on the body are declined so the widget's
    // own handlers get them (see ControlCenter.qml for why this isn't a
    // blocker item over the body).
    MouseArea {
        anchors.fill: parent
        enabled: root.modal
        onPressed: function (mouse) {
            mouse.accepted = !body.contains(mapToItem(body, mouse.x, mouse.y))
        }
        onClicked: ShellState.closeAll()
    }

    // ── Body ────────────────────────────────────────────────────────────────
    Rectangle {
        id: body

        x: Math.round((root.width - width) / 2)
        y: Theme.islandTop
        width: root.targetW
        height: root.targetH
        radius: Math.min(height / 2, Theme.islandRadius)
        color: Theme.barBg
        clip: true

        Behavior on width  { NumberAnimation { duration: Theme.islandMorphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: root.emphasized } }
        Behavior on height { NumberAnimation { duration: Theme.islandMorphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: root.emphasized } }

        HoverHandler { id: bodyHover }

        // Click the pill (rest or peek) to open machine stats. Controls in
        // the peek face take their own presses and cancel this.
        TapHandler {
            enabled: !root.open
            onTapped: ShellState.openWidget("stats", false)
        }

        // Each face sits centered at its natural size, so the body uncovers
        // it as it grows rather than making it reflow every frame.
        IslandRest {
            id: rest
            anchors.centerIn: parent
            now: root.now
            opacity: root.mode === "rest" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        }

        IslandPeek {
            active: root.mode === "peek"
            anchors.centerIn: parent
            width: implicitWidth
            height: implicitHeight
            now: root.now
            opacity: root.mode === "peek" ? 1 : 0
            visible: opacity > 0
            enabled: root.mode === "peek"
            Behavior on opacity { NumberAnimation { duration: Theme.animFast * 2 } }
        }

        WidgetHost {
            id: host
            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
            width: implicitWidth
            height: Math.min(implicitHeight, root.maxH)
            widgetId: ShellState.islandWidget
            active: root.open
            opacity: root.mode === "widget" ? 1 : 0
            visible: opacity > 0
            enabled: root.open
            Behavior on opacity { NumberAnimation { duration: Theme.animFast * 2 } }
        }
    }
}
