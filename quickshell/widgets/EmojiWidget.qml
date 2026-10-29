// Emoji picker: favourites pinned on top, then a searchable grid by
// category. Typing always goes to the search field, so movement is on arrows
// or Ctrl + h/j/k/l.
//
// Keys:
//   type               search              Return      copy and close
//   arrows, Ctrl+hjkl  move                Ctrl+F      (un)favourite
//   Tab / Shift+Tab    next / prev category
//   Alt+1…9            copy favourite N
//   Ctrl+Shift+H / L   move a favourite left / right (on the favourites row)
// Mouse: click copies, right-click (un)favourites.
import QtQuick
import "../theme"
import "../state"
import "../services"
import "../components"

Item {
    id: root

    property bool active: false

    readonly property int columns: 12
    readonly property int cell: 46
    readonly property int rows: 6
    readonly property int pad: 18

    implicitWidth: columns * cell + pad * 2
    implicitHeight: column.implicitHeight + pad * 2

    // ── Data ────────────────────────────────────────────────────────────────
    property string query: ""
    property int groupIndex: 0          // 0 = all, else groups[groupIndex - 1]

    readonly property var groups: [""].concat(EmojiService.groups)
    readonly property string group: groups[groupIndex] || ""
    // `search()` is a function, so list what it reads to re-run it.
    readonly property var shown: {
        EmojiService.all
        return EmojiService.search(root.query, root.query !== "" ? "" : root.group)
    }
    readonly property var favs: EmojiService.favoriteEntries

    // Where the selection is: the favourites row or the grid.
    property string zone: "grid"
    property int favIndex: 0

    readonly property var current: zone === "fav" ? favs[favIndex] : shown[grid.currentIndex]

    onShownChanged: grid.currentIndex = 0
    onFavsChanged: {
        favIndex = Math.min(favIndex, favs.length - 1)
        if (favs.length === 0) zone = "grid"
    }

    onActiveChanged: {
        if (!active) return
        search.text = ""
        root.groupIndex = 0
        root.zone = "grid"
        grid.currentIndex = 0
        grid.positionViewAtBeginning()
        search.forceActiveFocus()
    }

    function copy(entry) {
        if (!entry) return
        EmojiService.copy(entry.glyph)
        ShellState.closeAll()
    }

    function selectGroup(i) {
        search.text = ""
        root.groupIndex = (i + root.groups.length) % root.groups.length
        root.zone = "grid"
        grid.positionViewAtBeginning()
    }

    function move(dx, dy) {
        if (root.zone === "fav") {
            if (dy > 0) { root.zone = "grid"; grid.currentIndex = Math.min(root.favIndex, grid.count - 1); return }
            if (dx !== 0) root.favIndex = Math.max(0, Math.min(root.favs.length - 1, root.favIndex + dx))
            return
        }
        if (dy < 0 && grid.currentIndex < root.columns) {
            // Up from the top row goes to the favourites.
            if (root.favs.length > 0) {
                root.zone = "fav"
                root.favIndex = Math.min(grid.currentIndex, root.favs.length - 1)
            }
            return
        }
        if (dx < 0) grid.moveCurrentIndexLeft()
        else if (dx > 0) grid.moveCurrentIndexRight()
        else if (dy < 0) grid.moveCurrentIndexUp()
        else if (dy > 0) grid.moveCurrentIndexDown()
    }

    function onKey(event) {
        var k = event.key
        var ctrl = event.modifiers & Qt.ControlModifier
        var shift = event.modifiers & Qt.ShiftModifier
        var alt = event.modifiers & Qt.AltModifier

        if (alt && k >= Qt.Key_1 && k <= Qt.Key_9) {
            root.copy(root.favs[k - Qt.Key_1])
        } else if (ctrl && shift && (k === Qt.Key_H || k === Qt.Key_L)) {
            if (root.zone !== "fav" || !root.current) return false
            var dir = k === Qt.Key_H ? -1 : 1
            EmojiService.moveFavorite(root.current.glyph, dir)
            root.favIndex = Math.max(0, Math.min(root.favs.length - 1, root.favIndex + dir))
        } else if (k === Qt.Key_Left || (ctrl && k === Qt.Key_H))  root.move(-1, 0)
        else if (k === Qt.Key_Right || (ctrl && k === Qt.Key_L))   root.move(1, 0)
        else if (k === Qt.Key_Up || (ctrl && k === Qt.Key_K))      root.move(0, -1)
        else if (k === Qt.Key_Down || (ctrl && k === Qt.Key_J))    root.move(0, 1)
        else if (ctrl && k === Qt.Key_F) {
            if (root.current) EmojiService.toggleFavorite(root.current.glyph)
        }
        else if (k === Qt.Key_Tab)     root.selectGroup(root.groupIndex + 1)
        else if (k === Qt.Key_Backtab) root.selectGroup(root.groupIndex - 1)
        else if (k === Qt.Key_Return || k === Qt.Key_Enter) root.copy(root.current)
        else return false
        return true
    }

    // ── Pieces ──────────────────────────────────────────────────────────────
    component Glyph: Text {
        font.family: "Noto Color Emoji"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

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

        // Header: title + search
        Item {
            width: parent.width
            height: 36

            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: "Emoji"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge + 2
                font.bold: true
            }

            Rectangle {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 300
                height: 34
                radius: height / 2
                color: Theme.surface
                border.width: 1
                border.color: Theme.accent

                Icon {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    text: ""
                    color_: Theme.accent
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
                    focus: root.active
                    onTextChanged: {
                        root.query = text
                        root.zone = "grid"
                    }
                    Keys.onPressed: function (event) { event.accepted = root.onKey(event) }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: search.text === ""
                        text: "Search emoji…"
                        color: Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall + 1
                    }
                }
            }
        }

        // ── Favourites ──────────────────────────────────────────────────────
        Rectangle {
            width: parent.width
            height: 64
            radius: 14
            color: Theme.surface

            Text {
                anchors.centerIn: parent
                visible: root.favs.length === 0
                text: "No favourites yet · Ctrl+F or right-click an emoji to pin it here"
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }

            ListView {
                id: favList
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                orientation: ListView.Horizontal
                model: root.favs
                clip: true
                interactive: contentWidth > width
                currentIndex: root.favIndex
                highlightMoveDuration: 140
                highlightFollowsCurrentItem: true
                highlight: Rectangle {
                    width: 48
                    height: 56
                    y: 4
                    radius: 12
                    color: "transparent"
                    border.width: 2
                    border.color: root.zone === "fav" ? Theme.accent : "transparent"
                }

                delegate: Item {
                    id: favCell
                    required property var modelData
                    required property int index

                    width: 48
                    height: 64

                    Rectangle {
                        anchors { fill: parent; topMargin: 4; bottomMargin: 4 }
                        radius: 12
                        color: favArea.containsMouse ? Theme.hover : "transparent"
                    }
                    Glyph {
                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 8 }
                        text: favCell.modelData.glyph
                        font.pixelSize: 26
                    }
                    Text {
                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 6 }
                        visible: favCell.index < 9
                        text: favCell.index + 1
                        color: Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall - 3
                    }
                    MouseArea {
                        id: favArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onEntered: { root.zone = "fav"; root.favIndex = favCell.index }
                        onClicked: function (mouse) {
                            if (mouse.button === Qt.RightButton) EmojiService.toggleFavorite(favCell.modelData.glyph)
                            else root.copy(favCell.modelData)
                        }
                    }
                }
            }
        }

        // ── Categories ──────────────────────────────────────────────────────
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            opacity: root.query === "" ? 1 : 0.4

            Repeater {
                model: root.groups

                Rectangle {
                    id: groupTab
                    required property string modelData
                    required property int index
                    readonly property bool chosen: index === root.groupIndex && root.query === ""

                    width: 40
                    height: 32
                    radius: 10
                    color: chosen ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                         : groupArea.containsMouse ? Theme.hover : "transparent"
                    border.width: chosen ? 1 : 0
                    border.color: Theme.accent

                    // "All" gets a star glyph; each group, its first emoji.
                    Glyph {
                        anchors.centerIn: parent
                        visible: groupTab.index > 0
                        text: {
                            var list = EmojiService.all
                            for (var i = 0; i < list.length; i++)
                                if (list[i].group === groupTab.modelData) return list[i].glyph
                            return ""
                        }
                        font.pixelSize: 17
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: groupTab.index === 0
                        text: ""
                        color_: groupTab.chosen ? Theme.accent : Theme.subtext0
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: groupArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectGroup(groupTab.index)
                    }
                }
            }
        }

        // ── Grid ────────────────────────────────────────────────────────────
        GridView {
            id: grid

            width: root.columns * root.cell
            height: root.rows * root.cell
            anchors.horizontalCenter: parent.horizontalCenter
            cellWidth: root.cell
            cellHeight: root.cell
            clip: true
            model: root.shown
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 110
            cacheBuffer: root.cell * 4

            highlight: Rectangle {
                width: root.cell
                height: root.cell
                radius: 12
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, root.zone === "grid" ? 0.2 : 0)
                border.width: root.zone === "grid" ? 2 : 0
                border.color: Theme.accent
            }

            delegate: Item {
                id: emojiCell
                required property var modelData
                required property int index

                width: root.cell
                height: root.cell

                Rectangle {
                    anchors { fill: parent; margins: 2 }
                    radius: 10
                    color: cellArea.containsMouse ? Theme.hover : "transparent"
                }
                Glyph {
                    anchors.centerIn: parent
                    text: emojiCell.modelData.glyph
                    font.pixelSize: 26
                }
                // Star on favourites.
                Text {
                    anchors { right: parent.right; top: parent.top; margins: 3 }
                    visible: EmojiService.favorites.indexOf(emojiCell.modelData.glyph) !== -1
                    text: "★"
                    color: Theme.accent
                    font.pixelSize: 9
                }
                MouseArea {
                    id: cellArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: { root.zone = "grid"; grid.currentIndex = emojiCell.index }
                    onClicked: function (mouse) {
                        if (mouse.button === Qt.RightButton) EmojiService.toggleFavorite(emojiCell.modelData.glyph)
                        else root.copy(emojiCell.modelData)
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: grid.count === 0
                text: !EmojiService.loaded ? "Loading…" : "Nothing matches “" + root.query + "”"
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
        }

        // ── Selection + hints ───────────────────────────────────────────────
        Item {
            width: parent.width
            height: 34

            Row {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                spacing: 10
                visible: !!root.current

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.current ? root.current.glyph : ""
                    font.pixelSize: 24
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: root.current ? root.current.name : ""
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        width: 200
                        elide: Text.ElideRight
                    }
                    Text {
                        text: root.current ? root.current.group : ""
                        color: Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall - 2
                    }
                }
            }

            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 12

                Hint { keys: "⏎";       label: "copy" }
                Hint {
                    keys: "^F"
                    label: root.current && EmojiService.isFavorite(root.current.glyph) ? "unpin" : "pin"
                }
                Hint { keys: "⇥";       label: "category" }
                Hint { keys: "alt 1-9"; label: "favourite" }
            }
        }
    }
}
