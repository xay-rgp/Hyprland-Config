// Nerd Font glyph centred by its ink, not its text box, at a uniform size.
//
// A plain Text centres the font's line box (ascent + descent + side
// bearings), so icons sit visibly off-centre in round buttons. Nerd Font
// glyphs also vary wildly in drawn size: a thin rune next to a wide icon at
// the same pixelSize looks like two different sizes. This measures the glyph's
// tight bounding box, scales it so its larger side is `size` px, and places
// that box in the middle of the item.
import QtQuick
import "../theme"

Item {
    id: root

    property string text: ""
    property color  color: Theme.text
    property real   size: 16          // visual size of the glyph's larger side

    implicitWidth: size
    implicitHeight: size

    // Measured once at a large reference size; proportions scale linearly.
    readonly property real _ref: 100

    TextMetrics {
        id: ref
        font.family: Theme.fontFamily
        font.pixelSize: root._ref
        text: root.text
    }

    readonly property rect _box: ref.tightBoundingRect
    readonly property real _scale: {
        var m = Math.max(_box.width, _box.height)
        return m > 0 ? root.size / m : root.size / root._ref
    }

    Text {
        id: glyph

        text: root.text
        color: root.color
        font.family: Theme.fontFamily
        font.pixelSize: Math.max(1, Math.round(root._ref * root._scale))

        // Pixel-size rounding shifts the ratio slightly; use the real one.
        readonly property real _s: font.pixelSize / root._ref

        // tightBoundingRect is relative to the baseline origin, so the ink's
        // top is baseline + box.y.
        x: Math.round((root.width - root._box.width * _s) / 2 - root._box.x * _s)
        y: Math.round((root.height - root._box.height * _s) / 2 - root._box.y * _s - baselineOffset)
    }
}
