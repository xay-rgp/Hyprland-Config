// Shared chrome for every popup: rounded, themed, with an optional header.
//
// Layout is a Column, not anchors — header and content can never overlap.
// Two ways to supply a header:
//   title: "Audio"          -> built-in header (title + divider)
//   customHeader: Item{...} -> full control (counts, bulk actions, ...)
// `customHeader` wins when both are set.
//
// Background defaults to the SOLID palette colour: these popups live in
// PopupWindows, which Hyprland cannot blur (finding F3). Large PanelWindow
// popups pass `background: Theme.popupBg` to get the translucent version.
//
// `embedded: true` drops the fill and border, for popups shown as a page
// inside the control center, which already paints the surface behind them.
import QtQuick
import "../theme"

Rectangle {
    id: root

    property string title: ""
    property int    padding: Theme.popupPadding
    property color  background: Theme.popupBgSolid
    property alias  customHeader: headerSlot.data
    property int    headerHeight: 46
    property bool   embedded: false

    readonly property bool hasHeader: title !== "" || customHeader.length > 0

    default property alias content: body.data

    radius: Theme.cornerRadius
    color: root.embedded ? "transparent" : root.background
    border.width: root.embedded ? 0 : 1
    border.color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.07)

    implicitWidth: column.implicitWidth + padding * 2
    implicitHeight: column.implicitHeight + padding * 2

    Column {
        id: column
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: root.padding
        }
        spacing: 0

        // ── Header ──────────────────────────────────────────────────────────
        Item {
            id: headerSlot
            width: parent.width
            height: root.hasHeader ? root.headerHeight : 0
            visible: root.hasHeader

            Text {
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }
                visible: root.title !== ""
                text: root.title
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge
                font.bold: true
            }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                height: 1
                color: Theme.divider
            }
        }

        // ── Content ─────────────────────────────────────────────────────────
        Column {
            id: body
            width: parent.width
            spacing: 0
        }
    }
}
