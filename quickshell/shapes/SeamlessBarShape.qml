// Seamless three-notch bar shape. centerWidth 0 drops the center notch and
// runs the strip straight across.
//
// One Canvas paints all three notches plus the thin strip connecting them, so
// the bar reads as a single object rather than three floating pills.
// Adapted from Brain_Shell (MIT), decoupled from its Theme singleton.
import QtQuick
import "../theme"

Canvas {
    id: root
    anchors.fill: parent

    // Set by TopBar.qml with the real clamped widths.
    property int leftWidth:   Theme.lNotchMinWidth
    property int centerWidth: Theme.cNotchMinWidth
    property int rightWidth:  Theme.rNotchMinWidth
    property bool omitRight: false
    onOmitRightChanged: requestPaint()

    property int notchHeight: Theme.notchHeight
    property int radius:      Theme.notchRadius
    property int topBorder:   Theme.borderWidth
    property color color:     Theme.barBg

    onWidthChanged:       requestPaint()
    onHeightChanged:      requestPaint()
    onLeftWidthChanged:   requestPaint()
    onCenterWidthChanged: requestPaint()
    onRightWidthChanged:  requestPaint()
    onColorChanged:       requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()

        var leftW   = root.leftWidth
        var centerW = root.centerWidth
        var rightW  = root.rightWidth
        var r = root.radius
        var h = root.notchHeight
        var b = root.topBorder
        var w = width

        var centerStart = (w / 2) - (centerW / 2)
        var centerEnd   = (w / 2) + (centerW / 2)
        var rightStart  = w - rightW

        ctx.beginPath()
        ctx.fillStyle = root.color

        // ── Left notch ──────────────────────────────────────────────────────
        ctx.moveTo(0, h)
        ctx.lineTo(leftW - r, h)
        ctx.arcTo(leftW, h, leftW, h - r, r)
        ctx.lineTo(leftW, b + r)
        ctx.arcTo(leftW, b, leftW + r, b, r)

        // ── Gap (left -> center) ────────────────────────────────────────────
        ctx.lineTo(centerStart - r, b)

        // ── Center notch ────────────────────────────────────────────────────
        if (centerW > 0) {
            ctx.arcTo(centerStart, b, centerStart, b + r, r)
            ctx.lineTo(centerStart, h - r)
            ctx.arcTo(centerStart, h, centerStart + r, h, r)
            ctx.lineTo(centerEnd - r, h)
            ctx.arcTo(centerEnd, h, centerEnd, h - r, r)
            ctx.lineTo(centerEnd, b + r)
            ctx.arcTo(centerEnd, b, centerEnd + r, b, r)
        }

        // ── Gap (center -> right) ───────────────────────────────────────────
        ctx.lineTo(rightStart - r, b)

        // The control-center window paints the status notch itself.
        if (root.omitRight) {
            // Carry the top strip through to the control-center body.
            // Its concave fillet starts below the strip, so stopping at
            // rightStart - r exposes a radius-by-borderWidth wallpaper gap.
            ctx.lineTo(rightStart, b)
            ctx.lineTo(rightStart, 0)
            ctx.lineTo(0, 0)
            ctx.closePath()
            ctx.fill()
            return
        }

        // ── Right notch ─────────────────────────────────────────────────────
        ctx.arcTo(rightStart, b, rightStart, b + r, r)
        ctx.lineTo(rightStart, h - r)
        ctx.arcTo(rightStart, h, rightStart + r, h, r)
        ctx.lineTo(w, h)

        // ── Close ───────────────────────────────────────────────────────────
        ctx.lineTo(w, 0)
        ctx.lineTo(0, 0)
        ctx.lineTo(0, h)

        ctx.fill()
    }
}
