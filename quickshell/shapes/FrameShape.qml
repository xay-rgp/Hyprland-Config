// Full-screen frame: left, right and bottom edges drawn as ONE window per
// monitor, with the screen area punched out via the even-odd fill rule.
//
// The top edge is the bar window's job (it owns the exclusive zone), so this
// frame is inset by notchHeight at the top.
//
// Validated in the Chunk 0 spike: the odd-even fill rule cuts the hole
// correctly because the contours are wound in opposite directions.
import Quickshell
import QtQuick
import "../theme"

PanelWindow {
    id: root

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // Purely decorative: the surface covers the whole monitor, so without an
    // empty input mask it swallows every click meant for the windows below.
    mask: Region {}

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    // Flush with the monitor on left/right/bottom; the bar owns the top.
    margins.top: Theme.notchHeight

    Canvas {
        id: frame
        anchors.fill: parent

        onWidthChanged:  requestPaint()
        onHeightChanged: requestPaint()

        Connections {
            target: Theme
            function onBarBgChanged()  { frame.requestPaint() }
            function onBorderWidthChanged() { frame.requestPaint() }
            function onCornerRadiusChanged() { frame.requestPaint() }
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()

            var w = width
            var h = height
            var t = Theme.borderWidth
            var r = Theme.cornerRadius

            ctx.beginPath()

            // Outer edge: square, flush with the monitor edges.
            ctx.rect(0, 0, w, h)

            // Inner rounded rect, wound the opposite way so it punches a hole
            // under either fill rule. It is open at the top (no top strip):
            // the side edges run straight up into the bar, and the rounded
            // top corners blend them into the corner notches.
            ctx.moveTo(t + r, 0)
            ctx.arcTo(t, 0, t, r, r)
            ctx.lineTo(t, h - t - r)
            ctx.arcTo(t, h - t, t + r, h - t, r)
            ctx.lineTo(w - t - r, h - t)
            ctx.arcTo(w - t, h - t, w - t, h - t - r, r)
            ctx.lineTo(w - t, r)
            ctx.arcTo(w - t, 0, w - t - r, 0, r)
            ctx.closePath()

            ctx.fillRule = Qt.OddEvenFill
            ctx.fillStyle = Theme.barBg
            ctx.fill()
        }
    }
}
