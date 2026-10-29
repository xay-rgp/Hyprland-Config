// Clipboard history as a grid of tiles: text, links, colours as swatches,
// images as thumbnails. Anything that looks like an API key or token is
// masked (as is a string that reads like a password), so it never sits on
// screen in full.
//
// Keys (vim-style):
//   h j k l / arrows   move            Return   copy and close
//   /                  search          d / Del  delete the entry
//   g / G              first / last    D        clear all (asks first:
//   Esc                close                       y / Return / D confirms)
// In the search field: type to filter, Return copies the selection, Down or
// Tab goes back to the grid.
import QtQuick
import Quickshell.Widgets
import "../theme"
import "../state"
import "../services"
import "../components"

Item {
    id: root

    property bool active: false

    readonly property int columns: 4
    readonly property int cellW: 188
    readonly property int cellH: 142
    readonly property int rows: 3
    readonly property int pad: 18

    implicitWidth: columns * cellW + pad * 2
    implicitHeight: column.implicitHeight + pad * 2

    // ── Data ────────────────────────────────────────────────────────────────
    property string query: ""

    readonly property var shown: {
        var q = root.query.trim().toLowerCase()
        var all = ClipboardService.entries
        if (q === "") return all
        return all.filter(function (e) {
            // Secrets match on their kind only, never on their text.
            if (e.kind === "secret") return "secret".indexOf(q) === 0
            return e.preview.toLowerCase().indexOf(q) !== -1
                || (e.kind === "image" && "image".indexOf(q) === 0)
        })
    }
    onShownChanged: grid.currentIndex = Math.min(Math.max(0, grid.currentIndex), shown.length - 1)
    onQueryChanged: grid.currentIndex = 0

    // Shift+D arms this; the next key confirms (y, Return, D) or cancels.
    property bool confirmClear: false

    onActiveChanged: {
        root.confirmClear = false
        if (!active) return
        root.query = ""
        search.text = ""
        grid.currentIndex = 0
        grid.positionViewAtBeginning()
        ClipboardService.refresh()
        grid.forceActiveFocus()
    }

    function copyCurrent() {
        var e = root.shown[grid.currentIndex]
        if (!e) return
        ClipboardService.copyEntry(e.id)
        ShellState.closeAll()
    }

    function clearAll() {
        root.confirmClear = false
        ClipboardService.clearAll()
    }

    function deleteCurrent() {
        var e = root.shown[grid.currentIndex]
        if (e) ClipboardService.deleteEntry(e.id)
    }

    // A masked secret: only a key-style prefix ("oc_sk_", "ghp_", "sk-")
    // stays readable, so you can tell keys apart; passwords are all dots.
    function secretLabel(text) {
        var m = text.trim().match(/^([a-z]{2,10}[_-](?:[a-z]{2,4}[_-])?)/)
        return (m ? m[1] : "") + "••••••••••••"
    }

    // ── Pieces ──────────────────────────────────────────────────────────────
    component Hint: Row {
        property string keys
        property string label
        spacing: 5

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: keyText.implicitWidth + 10
            height: 18
            radius: 5
            color: Theme.hover
            Text {
                id: keyText
                anchors.centerIn: parent
                text: parent.parent.keys
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall - 2
                font.bold: true
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: parent.label
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall - 1
        }
    }

    // ── Layout ──────────────────────────────────────────────────────────────
    Column {
        id: column
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: root.pad }
        spacing: 12

        // Header: title, count, search
        Item {
            width: parent.width
            height: 36

            Row {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Clipboard"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLarge + 2
                    font.bold: true
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.query !== ""
                          ? root.shown.length + " of " + ClipboardService.entries.length
                          : ClipboardService.entries.length + " items"
                    color: Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            Rectangle {
                id: searchBox
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 260
                height: 34
                radius: height / 2
                color: Theme.surface
                border.width: search.activeFocus ? 1 : 0
                border.color: Theme.accent

                Icon {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    text: ""
                    color_: search.activeFocus ? Theme.accent : Theme.subtext0
                    font.pixelSize: 12
                }

                TextInput {
                    id: search
                    anchors { fill: parent; leftMargin: 34; rightMargin: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall + 1
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.crust
                    clip: true
                    onTextChanged: root.query = text
                    onAccepted: root.copyCurrent()

                    Keys.onPressed: function (event) {
                        var ctrl = event.modifiers & Qt.ControlModifier
                        if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab
                                || (ctrl && event.key === Qt.Key_J)) {
                            grid.forceActiveFocus()
                            event.accepted = true
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: search.text === ""
                        text: search.activeFocus ? "Filter…" : "Press / to search"
                        color: Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall + 1
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor
                    onClicked: search.forceActiveFocus()
                }
            }
        }

        // ── Grid ────────────────────────────────────────────────────────────
        GridView {
            id: grid

            width: root.columns * root.cellW
            height: root.rows * root.cellH
            anchors.horizontalCenter: parent.horizontalCenter
            cellWidth: root.cellW
            cellHeight: root.cellH
            clip: true
            model: root.shown
            boundsBehavior: Flickable.StopAtBounds
            highlightFollowsCurrentItem: true
            highlightMoveDuration: 140
            keyNavigationWraps: false
            cacheBuffer: root.cellH * 2

            // Keeps the selected row in view, a row of context above/below.
            preferredHighlightBegin: 0
            preferredHighlightEnd: height
            highlightRangeMode: GridView.NoHighlightRange

            highlight: Rectangle {
                width: root.cellW
                height: root.cellH
                radius: 16
                color: "transparent"
                border.width: 2
                border.color: Theme.accent
                z: 2
            }

            Keys.onPressed: function (event) {
                var k = event.key
                var shift = event.modifiers & Qt.ShiftModifier

                if (root.confirmClear) {
                    if (k === Qt.Key_Shift) return      // still reaching for D
                    if (k === Qt.Key_Y || k === Qt.Key_Return || k === Qt.Key_Enter
                            || (k === Qt.Key_D && shift))
                        root.clearAll()
                    else
                        root.confirmClear = false
                    event.accepted = true
                    return
                }

                if (k === Qt.Key_D && shift) {
                    if (grid.count > 0) root.confirmClear = true
                    event.accepted = true
                    return
                }

                if (k === Qt.Key_H || k === Qt.Key_Left)       grid.moveCurrentIndexLeft()
                else if (k === Qt.Key_L || k === Qt.Key_Right) grid.moveCurrentIndexRight()
                else if (k === Qt.Key_J || k === Qt.Key_Down)  grid.moveCurrentIndexDown()
                else if (k === Qt.Key_K || k === Qt.Key_Up) {
                    // Up from the top row goes to the search field.
                    if (grid.currentIndex < root.columns) search.forceActiveFocus()
                    else grid.moveCurrentIndexUp()
                }
                else if (k === Qt.Key_G && shift)              grid.currentIndex = grid.count - 1
                else if (k === Qt.Key_G)                       grid.currentIndex = 0
                else if (k === Qt.Key_Return || k === Qt.Key_Enter) root.copyCurrent()
                else if (k === Qt.Key_D || k === Qt.Key_Delete)     root.deleteCurrent()
                else if (k === Qt.Key_Slash) {
                    search.forceActiveFocus()
                    search.selectAll()
                }
                else return
                event.accepted = true
            }

            delegate: Item {
                id: cell

                required property var modelData
                required property int index

                readonly property bool current: GridView.isCurrentItem
                readonly property string kind: modelData.kind || "text"

                width: root.cellW
                height: root.cellH

                // ClippingRectangle, so thumbnails get the rounded corners too.
                ClippingRectangle {
                    id: tile
                    anchors { fill: parent; margins: 5 }
                    radius: 12
                    color: cell.kind === "color" ? cell.modelData.preview.trim() : Theme.surface
                    clip: true
                    scale: cell.current ? 1.0 : 0.97
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                    // Image: the thumbnail, cropped to fill.
                    Image {
                        anchors.fill: parent
                        visible: cell.kind === "image"
                        source: cell.kind === "image" && cell.modelData.thumb && ClipboardService.thumbsReady
                                ? "file://" + cell.modelData.thumb + "?r=" + ClipboardService.thumbsRevision
                                : ""
                        sourceSize.width: root.cellW * 2
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        smooth: true
                    }

                    // Text, links and secrets.
                    Column {
                        visible: cell.kind !== "image" && cell.kind !== "color"
                        anchors { fill: parent; margins: 12 }
                        spacing: 6

                        Row {
                            spacing: 6
                            visible: cell.kind === "url" || cell.kind === "secret"
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: cell.kind === "url" ? "" : ""
                                color_: cell.kind === "secret" ? Theme.warning : Theme.accent
                                font.pixelSize: 11
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: cell.kind === "url" ? "Link" : "Hidden · looks like a key"
                                color: Theme.subtext0
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall - 2
                            }
                        }

                        Text {
                            width: parent.width
                            height: parent.height - (parent.children[0].visible ? parent.children[0].height + 6 : 0)
                            text: cell.kind === "secret"
                                  ? root.secretLabel(cell.modelData.preview)
                                  : cell.modelData.preview
                            color: cell.kind === "url" ? Theme.accent : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.WrapAnywhere
                            elide: Text.ElideRight
                            lineHeight: 1.1
                        }
                    }

                    // Colour: the swatch is the tile; the value on a chip.
                    Rectangle {
                        visible: cell.kind === "color"
                        anchors { left: parent.left; bottom: parent.bottom; margins: 8 }
                        width: colorText.implicitWidth + 12
                        height: 20
                        radius: 6
                        color: Qt.rgba(0, 0, 0, 0.45)
                        Text {
                            id: colorText
                            anchors.centerIn: parent
                            text: cell.modelData.preview.trim()
                            color: "white"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall - 1
                        }
                    }

                    // Image metadata on a strip across the bottom.
                    Rectangle {
                        visible: cell.kind === "image"
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: 24
                        color: Qt.rgba(0, 0, 0, 0.55)
                        Text {
                            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                            text: cell.modelData.preview
                            color: "white"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall - 2
                            elide: Text.ElideRight
                            width: parent.width - 16
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: grid.currentIndex = cell.index
                    onClicked: {
                        grid.currentIndex = cell.index
                        root.copyCurrent()
                    }
                }
            }

            // Empty state.
            Text {
                anchors.centerIn: parent
                visible: grid.count === 0
                text: !ClipboardService.available ? "cliphist isn't available"
                    : root.query !== "" ? "Nothing matches “" + root.query + "”"
                    : "Clipboard history is empty"
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
        }

        // ── Key hints / clear-all confirmation ──────────────────────────────
        Rectangle {
            width: parent.width
            height: 30
            radius: 10
            visible: root.confirmClear
            color: Qt.rgba(Theme.urgent.r, Theme.urgent.g, Theme.urgent.b, 0.14)
            border.width: 1
            border.color: Qt.rgba(Theme.urgent.r, Theme.urgent.g, Theme.urgent.b, 0.5)

            Row {
                anchors.centerIn: parent
                spacing: 16

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Clear all " + ClipboardService.entries.length + " items? This can't be undone."
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                }
                Hint { keys: "y"; label: "clear" }
                Hint { keys: "any key"; label: "cancel" }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16
            visible: !root.confirmClear

            Hint { keys: "hjkl"; label: "move" }
            Hint { keys: "⏎";    label: "copy" }
            Hint { keys: "/";    label: "search" }
            Hint { keys: "d";    label: "delete" }
            Hint { keys: "D";    label: "clear all" }
            Hint { keys: "g G";  label: "first / last" }
            Hint { keys: "esc";  label: "close" }
        }
    }
}
