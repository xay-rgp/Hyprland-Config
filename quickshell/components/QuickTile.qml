// Pill-shaped quick tile: round glyph + title/subtitle, as in the control
// center. The glyph toggles the thing (`toggled`), the rest of the tile opens
// its detail (`opened`); a tile that isn't toggleable opens from both.
import QtQuick
import "../theme"

Rectangle {
    id: tile

    property string glyph
    property bool spinning: false      // rotate the glyph, e.g. while connecting
    property string title
    property string subtitle
    property bool   active: false
    property bool   toggleable: true

    signal toggled()
    signal opened()

    // On, the whole tile fills with the accent; off, it's a quiet card.
    readonly property bool lit: active || !toggleable
    readonly property color ink: lit ? Theme.crust : Theme.text

    height: 60
    radius: height / 2
    color: lit ? (tileHover.hovered ? Qt.lighter(Theme.accent, 1.08) : Theme.accent)
         : tileHover.hovered ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
         : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.045)
    border.width: lit ? 0 : 1
    border.color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.06)

    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: tile.opened() }

    Rectangle {
        id: bubble
        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
        width: 40
        height: 40
        radius: 20
        color: tile.lit ? Qt.rgba(Theme.crust.r, Theme.crust.g, Theme.crust.b, bubbleHover.hovered ? 0.24 : 0.14)
             : bubbleHover.hovered ? Theme.surface2 : Theme.surface1

        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        CenteredIcon {
            anchors.centerIn: parent
            id: tileIcon
            text: tile.glyph
            color: tile.ink
            size: 16

            RotationAnimation on rotation {
                running: tile.spinning
                from: 0; to: 360
                duration: 900
                loops: Animation.Infinite
                onRunningChanged: if (!running) tileIcon.rotation = 0
            }
        }

        HoverHandler { id: bubbleHover }
        // The bubble is the deeper item, so its handler takes the tap first.
        TapHandler { onTapped: tile.toggleable ? tile.toggled() : tile.opened() }
    }

    Column {
        anchors {
            left: bubble.right
            leftMargin: 9
            right: parent.right
            rightMargin: 10
            verticalCenter: parent.verticalCenter
        }
        spacing: 2

        Text {
            width: parent.width
            text: tile.title
            color: tile.ink
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLarge
            font.bold: true
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: tile.subtitle
            color: tile.ink
            opacity: tile.lit ? 0.75 : 0.6
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
        }
    }
}
