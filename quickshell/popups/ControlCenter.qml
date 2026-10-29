// Control center: the right notch morphs into a panel, on click or on hover
// (SettingsService.ccOpenOnHover).
//
// The window sits over the bar's top-right corner. Collapsed, its body is
// shaped exactly like the bar's right notch and carries the status pill, so
// it *is* the notch as far as the user can tell. On open it grows the body
// out of the corner (left and down) to the current page's size. The body
// stays joined to the bar strip and the right frame edge by concave fillets,
// so the panel reads as part of the frame, not a separate window. Switching
// pages morphs straight to the new page's size.
//
// It stays mapped even when collapsed. Mapping it only on open made
// Hyprland's layersIn fade play over the morph, so the panel grew in
// half-transparent. The surface covers the whole monitor so the animation
// never resizes it; the input mask is just the notch while collapsed, and the
// whole monitor while open, with clicks outside the body closing the panel.
//
// It dismisses itself rather than relying on PopupDismiss. The dismiss layer
// maps when a popup opens, which stacks it above this already-mapped surface,
// so it would swallow every click meant for the panel (verified with
// `hyprctl layers`).
import Quickshell
import Quickshell.Wayland
import QtQuick
import "../theme"
import "../state"
import "../services"
import "../components"
import "../modules/Right"

PanelWindow {
    id: root

    property var  barWindow: null
    property bool active: false          // this layer's monitor is focused

    readonly property bool open: active && ShellState.controlCenterOpen

    // ── Geometry ────────────────────────────────────────────────────────────
    readonly property int collapsedW: barWindow ? barWindow.rWidth : Theme.rNotchMinWidth
    readonly property int collapsedH: Theme.notchHeight

    // Content starts below the bar strip, which the body also covers.
    readonly property int contentTop: Theme.borderWidth + 4


    // One size for every page, so the panel keeps its shape while you move
    // between them; pages scroll inside it instead of resizing it.
    readonly property int targetW: Theme.ccWidth
    readonly property int pageHeight: ShellState.ccPage === "main" ? mainPage.implicitHeight : Theme.ccHeight
    readonly property int targetH: pageHeight + contentTop

    // 0 = the notch, 1 = the page. Open/close eases this.
    property real progress: open ? 1 : 0
    Behavior on progress { NumberAnimation { duration: Theme.ccMorphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: root.emphasized } }

    // Material 3 "emphasized" (two-segment), the curve Caelestia uses: a
    // short wind-up, then a long settle, instead of snapping most of the way
    // open in the first frames.
    readonly property var emphasized: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4,
                                       5 / 24, 0.82, 0.25, 1, 1, 1]

    readonly property real bodyW: collapsedW + (targetW - collapsedW) * progress
    readonly property real bodyH: collapsedH + (Math.min(targetH, maxH) - collapsedH) * progress

    readonly property int maxH: height - Theme.cornerRadius - 40

    // ── Window ──────────────────────────────────────────────────────────────
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // Mapped whenever the bar shows its notch (not in focus mode, where the
    // bar collapses to a strip), or while a collapse is still animating.
    visible: !ShellState.focusMode || root.open || root.progress > 0

    // Keys while open: Escape works straight away.
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive
                                           : WlrKeyboardFocus.None

    // Input region: the body while collapsed, the whole monitor while open
    // (for click-outside and hover-out). Bound as a plain rect so every
    // geometry change re-applies the mask.
    mask: Region {
        x: inputArea.x
        y: inputArea.y
        width: inputArea.width
        height: inputArea.height
    }

    Item {
        id: inputArea
        x: root.open ? 0 : body.x
        y: 0
        width: root.open ? root.width : body.width
        height: root.open ? root.height : body.height
    }

    // Refresh cached lists the main page reads, whenever the panel opens.
    onOpenChanged: {
        if (!open) _pointerSeen = false
    }

    // ── Hover mode: hover to open / leave to close ──────────────────────────
    // Resting on the notch opens the panel; leaving the panel closes it. The
    // close only arms once the pointer has been inside while open, so a panel
    // opened from a keybind (pointer elsewhere) waits for a visit first.
    // In click mode none of this runs: the pill's tap opens it, and a click
    // outside or Escape closes it.
    readonly property bool hoverMode: SettingsService.ccOpenOnHover
    property bool _pointerSeen: false
    readonly property bool _hovered: bodyHover.hovered

    // Switching modes from the footer button happens with the pointer inside
    // the panel: arm hover-out straight away, or cancel a pending close.
    onHoverModeChanged: {
        if (hoverMode && open && _hovered) _pointerSeen = true
        if (!hoverMode) { openTimer.stop(); closeTimer.stop() }
    }

    on_HoveredChanged: {
        if (!hoverMode) return
        if (_hovered) {
            closeTimer.stop()
            if (open) _pointerSeen = true
            else openTimer.restart()
        } else {
            openTimer.stop()
            if (open && _pointerSeen) closeTimer.restart()
        }
    }

    // Short, so passing the pointer across the corner doesn't pop it open.
    Timer {
        id: openTimer
        interval: 120
        onTriggered: if (root.hoverMode && root._hovered && !root.open) {
            root._pointerSeen = true
            ShellState.showPage("main")
        }
    }

    Timer {
        id: closeTimer
        interval: Theme.hoverCloseDelay + 100
        onTriggered: if (root.hoverMode && !root._hovered && root.open) ShellState.closeAll()
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.open
        onActivated: ShellState.ccPage === "main" ? ShellState.closeAll() : ShellState.back()
    }

    // Click-outside dismissal; only reachable while open (see mask).
    //
    // Presses inside the body are declined rather than swallowed by a
    // blocker over the body: a MouseArea taking the press overrides the
    // passive grab of every TapHandler above it, which cancelled all taps
    // in the panel (tiles, footer buttons, the pill itself).
    MouseArea {
        id: backdrop
        anchors.fill: parent
        enabled: root.open
        onPressed: function (mouse) {
            mouse.accepted = !body.contains(mapToItem(body, mouse.x, mouse.y))
        }
        onClicked: ShellState.closeAll()
    }

    // ── Shape ───────────────────────────────────────────────────────────────
    Rectangle {
        id: body
        x: root.width - root.bodyW
        y: 0
        width: root.bodyW
        height: root.bodyH
        color: Theme.barBg
        // Matches the notch corner when collapsed, rounder when open.
        bottomLeftRadius: Theme.notchRadius + (Theme.ccRadius - Theme.notchRadius) * root.progress
    }

    // Joins the body's left edge into the bar strip.
    Fillet {
        x: body.x - size
        y: Theme.borderWidth
        size: Theme.notchRadius
    }

    // Joins the body's bottom edge into the right frame edge. Same radius as
    // the frame's own inner corner, which it sits on top of when collapsed.
    Fillet {
        x: root.width - Theme.borderWidth - size
        y: body.height
        size: Theme.cornerRadius
    }

    // ── Content ─────────────────────────────────────────────────────────────
    Item {
        id: viewport
        anchors.fill: body
        clip: true

        HoverHandler { id: bodyHover }

        // The pill, where the bar draws it, fading out as the notch grows.
        // This is the one the user hovers; the bar's copy sits underneath.
        Item {
            anchors { top: parent.top; right: parent.right }
            width: root.collapsedW
            height: root.collapsedH
            opacity: Math.max(0, 1 - root.progress * 3)
            visible: opacity > 0

            RightContent {
                anchors.right: parent.right
                anchors.rightMargin: Theme.notchPadding
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Pages are pinned to the top-right corner at their full size, so the
        // growing body uncovers them instead of making them reflow each frame.
        Item {
            id: pages
            anchors { top: parent.top; right: parent.right; topMargin: root.contentTop }
            width: root.targetW
            height: root.pageHeight
            opacity: Math.max(0, (root.progress - 0.35) / 0.65)
            // Opacity 0 alone still takes input: collapsed, the invisible top
            // tile row sat over the pill and ate its clicks. Hide it outright,
            // and only accept input once the panel is actually open.
            visible: opacity > 0
            enabled: root.open

            Page { name: "main"; sub: false
                ControlCenterMain { id: mainPage; width: parent.width; height: root.pageHeight }
            }
            Page { name: "network"
                NetworkPopup { width: parent.width; embedded: true }
            }
            Page { name: "bluetooth"; sub: false
                BluetoothPopup {
                    width: parent.width
                    height: root.pageHeight
                    embedded: true
                }
            }
            Page { name: "audio"
                AudioPopup { width: parent.width; embedded: true }
            }



        }
    }

    // ── Pieces ──────────────────────────────────────────────────────────────

    // One page, filling the panel and cross-faded on page switches. Sub-pages
    // get the back row, and their content scrolls if it outgrows the panel.
    component Page: Item {
        id: pg

        property string name
        property bool   sub: true
        readonly property bool current: ShellState.ccPage === name
        default property alias content: flick.flickableData

        anchors.fill: parent
        opacity: current ? 1 : 0
        visible: opacity > 0
        enabled: current

        BackRow { id: back; visible: pg.sub }

        Flickable {
            id: flick
            anchors {
                top: pg.sub ? back.bottom : parent.top
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            clip: true
            contentWidth: width
            // Each page holds one child; childrenRect here is a binding loop,
            // since the content item is itself sized from contentHeight.
            contentHeight: contentItem.children.length > 0
                           ? contentItem.children[0].height : 0
            boundsBehavior: Flickable.StopAtBounds
        }

        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    }

    // Back to the main page, above a sub-page's own header.
    component BackRow: Item {
        width: parent ? parent.width : 0
        height: 30

        Rectangle {
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
            width: backRow.implicitWidth + 20
            height: 26
            radius: height / 2
            color: backHover.hovered ? Theme.hover : "transparent"

            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            Row {
                id: backRow
                anchors.centerIn: parent
                spacing: 8

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf053"
                    color_: Theme.subtext0
                    font.pixelSize: 10
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Control center"
                    color: Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            HoverHandler { id: backHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: ShellState.back() }
        }
    }

    // Concave corner: fills the square's top-right corner outside a circle
    // centred on its bottom-left, which rounds the join between two edges.
    component Fillet: Canvas {
        id: fillet

        property int size: 15

        width: size
        height: size

        onSizeChanged: requestPaint()

        Connections {
            target: Theme
            function onBarBgChanged() { fillet.requestPaint() }
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var r = fillet.size
            ctx.beginPath()
            ctx.moveTo(0, 0)
            ctx.lineTo(r, 0)
            ctx.lineTo(r, r)
            ctx.arcTo(r, 0, 0, 0, r)
            ctx.closePath()
            ctx.fillStyle = Theme.barBg
            ctx.fill()
        }
    }
}
