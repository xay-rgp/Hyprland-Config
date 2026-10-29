// Nerd Font glyph in a themed colour. One-liner so widgets don't repeat the
// font/colour boilerplate for every icon.
import QtQuick
import "../theme"

Text {
    id: root

    property color color_: Theme.text

    color: color_
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
}
