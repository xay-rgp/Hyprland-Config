// Themes: pick a wallpaper and the whole desktop takes its colours — a
// curated palette for the wallpapers that ship with a theme, one generated
// from the image for the rest (see theme/bin/wallpaper.py). Kitty, Hyprland,
// Qt and the shell all follow; the picker stays open so you can compare.
//
// Search matches names and tags (every word must match); the chips filter
// by tag too, and combine.
//
// Keys:
//   h l / arrows       scroll (wraps)  Return   apply
//   k / Up             to search
//   /                  search          t        edit tags
//   g / G              first / last    Esc      close
//   wheel              scroll
import QtQuick
import Quickshell.Widgets
import "../theme"
import "../state"
import "../services"
import "../components"

Item {
    id: root

    property bool active: false

    readonly property int columns: 3
    readonly property int cardW: 272
    readonly property int thumbH: 153           // 16:9
    readonly property int cardH: thumbH + 64
    readonly property int pad: 18

    implicitWidth: columns * cardW + pad * 2
    implicitHeight: column.implicitHeight + pad * 2

    // ── Filtering ───────────────────────────────────────────────────────────
    property string query: ""
    property var chosenTags: []                  // chips switched on

    readonly property var shown: {
        var words = root.query.toLowerCase().split(/\s+/).filter(function (w) { return w !== "" })
        var need = root.chosenTags
        return WallpaperLibrary.wallpapers.filter(function (w) {
            for (var i = 0; i < need.length; i++)
                if (w.tags.indexOf(need[i]) === -1) return false
            var hay = [w.name.toLowerCase()].concat(w.tags)
            return words.every(function (word) {
                return hay.some(function (h) { return h.indexOf(word) !== -1 })
            })
        })
    }
    onShownChanged: grid.currentIndex = Math.min(Math.max(0, grid.currentIndex), shown.length - 1)

    function toggleTag(t) {
        var i = root.chosenTags.indexOf(t)
        root.chosenTags = i === -1 ? root.chosenTags.concat([t])
                                   : root.chosenTags.filter(function (x) { return x !== t })
    }

    readonly property var selected: shown[grid.currentIndex] || null

    // ── Lifecycle ───────────────────────────────────────────────────────────
    property bool editing: false                 // tag editor open

    onActiveChanged: {
        if (!active) { root.editing = false; return }
        WallpaperLibrary.refresh()
        search.text = ""
        root.chosenTags = []
        root.editing = false
        // Start on the wallpaper in use, once the fresh list is in.
        root._jumpPending = true
        if (WallpaperLibrary.loaded) root.selectCurrent()
        grid.forceActiveFocus()
    }

    property bool _jumpPending: false
    Connections {
        target: WallpaperLibrary
        function onWallpapersChanged() {
            if (root._jumpPending) Qt.callLater(root.selectCurrent)
        }
    }

    function selectCurrent() {
        root._jumpPending = false
        for (var i = 0; i < root.shown.length; i++)
            if (root.shown[i].id === WallpaperLibrary.current) {
                grid.currentIndex = i
                grid.positionViewAtIndex(i, PathView.Center)
                return
            }
        grid.currentIndex = 0
    }

    function applySelected() {
        if (root.selected) WallpaperLibrary.apply(root.selected.id)
    }

    function editTags() {
        if (!root.selected) return
        tagInput.text = root.selected.tags.filter(function (t) {
            return t !== "light" && t !== "dark"
        }).join(", ")
        root.editing = true
        tagInput.forceActiveFocus()
        tagInput.selectAll()
    }

    function saveTags() {
        if (root.selected) WallpaperLibrary.setTags(root.selected.id, tagInput.text)
        root.editing = false
        grid.forceActiveFocus()
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
                    text: "Themes"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLarge + 2
                    font.bold: true
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.shown.length === WallpaperLibrary.wallpapers.length
                          ? WallpaperLibrary.wallpapers.length + " wallpapers"
                          : root.shown.length + " of " + WallpaperLibrary.wallpapers.length
                    color: Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            Rectangle {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 280
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
                    onTextChanged: { root.query = text; grid.currentIndex = 0 }
                    onAccepted: { root.applySelected(); grid.forceActiveFocus() }

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
                        text: search.activeFocus ? "Name or tag…" : "Press / to search"
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

        // ── Tag chips ───────────────────────────────────────────────────────
        Flickable {
            width: parent.width
            height: 28
            contentWidth: chips.width
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: chips
                spacing: 6

                Repeater {
                    model: WallpaperLibrary.tags

                    Rectangle {
                        id: chip
                        required property string modelData
                        readonly property bool on: root.chosenTags.indexOf(modelData) !== -1

                        width: chipText.implicitWidth + 20
                        height: 26
                        radius: 13
                        color: on ? Theme.accent : chipArea.containsMouse ? Theme.hover : Theme.surface

                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: chip.modelData
                            color: chip.on ? Theme.crust : Theme.subtext1
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall - 1
                            font.bold: chip.on
                        }
                        MouseArea {
                            id: chipArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleTag(chip.modelData)
                        }
                    }
                }
            }
        }

        // ── Grid ────────────────────────────────────────────────────────────
        // One row that wraps around forever: the current card stays centred
        // and the ones either side slide past it. `slots` cards sit on the
        // path (odd, so one is centred); with fewer wallpapers than that it
        // just shows them all.
        PathView {
            id: grid

            readonly property int slots: Math.min(5, Math.max(1, count))

            width: root.columns * root.cardW
            height: root.cardH
            anchors.horizontalCenter: parent.horizontalCenter
            clip: true
            model: root.shown
            pathItemCount: slots
            preferredHighlightBegin: 0.5
            preferredHighlightEnd: 0.5
            highlightRangeMode: PathView.StrictlyEnforceRange
            highlightMoveDuration: 200
            snapMode: PathView.SnapOneItem
            focus: true

            path: Path {
                startX: grid.width / 2 - grid.slots * root.cardW / 2
                startY: grid.height / 2
                PathLine {
                    x: grid.width / 2 + grid.slots * root.cardW / 2
                    y: grid.height / 2
                }
            }

            // Mouse wheel / trackpad steps one card at a time.
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: function (event) {
                    var d = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y)
                             ? event.angleDelta.x : event.angleDelta.y
                    if (d < 0) grid.incrementCurrentIndex()
                    else if (d > 0) grid.decrementCurrentIndex()
                }
            }

            Keys.onPressed: function (event) {
                var k = event.key
                var shift = event.modifiers & Qt.ShiftModifier
                if (k === Qt.Key_H || k === Qt.Key_Left)       grid.decrementCurrentIndex()
                else if (k === Qt.Key_L || k === Qt.Key_Right) grid.incrementCurrentIndex()
                else if (k === Qt.Key_K || k === Qt.Key_Up)    search.forceActiveFocus()
                else if (k === Qt.Key_J || k === Qt.Key_Down)  { /* single row: nothing below */ }
                else if (k === Qt.Key_G && shift)              grid.currentIndex = grid.count - 1
                else if (k === Qt.Key_G)                       grid.currentIndex = 0
                else if (k === Qt.Key_Return || k === Qt.Key_Enter) root.applySelected()
                else if (k === Qt.Key_T)                       root.editTags()
                else if (k === Qt.Key_Slash) { search.forceActiveFocus(); search.selectAll() }
                else return
                event.accepted = true
            }

            delegate: Item {
                id: card

                required property var modelData
                required property int index

                readonly property bool isCurrent: modelData.id === WallpaperLibrary.current
                readonly property bool isApplying: modelData.id === WallpaperLibrary.applying

                width: root.cardW
                height: root.cardH

                // Selection ring.
                Rectangle {
                    anchors.fill: parent
                    radius: 18
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.accent
                    visible: card.PathView.isCurrentItem
                    z: 2
                }

                Rectangle {
                    anchors { fill: parent; margins: 6 }
                    radius: 14
                    color: Theme.surface

                    ClippingRectangle {
                        id: thumbBox
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: root.thumbH - 12
                        topLeftRadius: 14
                        topRightRadius: 14
                        color: Theme.mantle

                        Image {
                            anchors.fill: parent
                            source: "file://" + card.modelData.thumb
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: root.cardW * 2
                        }

                        // In use.
                        Rectangle {
                            visible: card.isCurrent
                            anchors { top: parent.top; left: parent.left; margins: 8 }
                            width: activeRow.implicitWidth + 14
                            height: 22
                            radius: 11
                            color: Theme.accent
                            Row {
                                id: activeRow
                                anchors.centerIn: parent
                                spacing: 5
                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: ""
                                    color_: Theme.crust
                                    font.pixelSize: 10
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Active"
                                    color: Theme.crust
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall - 2
                                    font.bold: true
                                }
                            }
                        }

                        // Applying.
                        Rectangle {
                            anchors.fill: parent
                            visible: card.isApplying
                            color: Qt.rgba(0, 0, 0, 0.5)
                            Icon {
                                id: spinner
                                anchors.centerIn: parent
                                text: ""
                                color_: "white"
                                font.pixelSize: 22
                                RotationAnimation on rotation {
                                    running: card.isApplying
                                    loops: Animation.Infinite
                                    from: 0; to: 360; duration: 900
                                }
                            }
                        }
                    }

                    // Name, palette, tags
                    Column {
                        anchors { top: thumbBox.bottom; left: parent.left; right: parent.right; margins: 10 }
                        spacing: 4

                        Item {
                            width: parent.width
                            height: 18

                            Text {
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                width: parent.width - swatch.width - 8
                                text: card.modelData.name
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            // The palette, or a note that it will be generated.
                            Row {
                                id: swatch
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                spacing: -3
                                visible: card.modelData.swatch.length > 0
                                Repeater {
                                    model: card.modelData.swatch
                                    Rectangle {
                                        required property string modelData
                                        width: 12; height: 12; radius: 6
                                        color: modelData
                                        border.width: 1
                                        border.color: Theme.surface
                                    }
                                }
                            }
                            Text {
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                visible: card.modelData.swatch.length === 0
                                text: "✦ from image"
                                color: Theme.subtext0
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall - 2
                            }
                        }

                        Text {
                            width: parent.width
                            text: card.modelData.tags.join(" · ")
                            color: Theme.subtext0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall - 2
                            elide: Text.ElideRight
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { grid.currentIndex = card.index; root.applySelected() }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: grid.count === 0
                text: !WallpaperLibrary.loaded ? "Loading…" : "No wallpaper matches"
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
        }

        // ── Tag editor / status / hints ─────────────────────────────────────
        Rectangle {
            width: parent.width
            height: 34
            radius: 10
            visible: root.editing
            color: Theme.surface
            border.width: 1
            border.color: Theme.accent

            Row {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Tags for " + (root.selected ? root.selected.name : "")
                    color: Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
                TextInput {
                    id: tagInput
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 260
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall + 1
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.crust
                    clip: true
                    onAccepted: root.saveTags()
                    Keys.onPressed: function (event) {
                        // Tab cancels (Esc closes the island).
                        if (event.key === Qt.Key_Tab) {
                            root.editing = false
                            grid.forceActiveFocus()
                            event.accepted = true
                        }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "⏎ save · ⇥ cancel"
                    color: Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall - 2
                }
            }
        }

        Text {
            width: parent.width
            visible: !root.editing && WallpaperLibrary.error !== ""
            text: WallpaperLibrary.error
            color: Theme.urgent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16
            visible: !root.editing

            Hint { keys: "hjkl"; label: "move" }
            Hint { keys: "⏎";    label: "apply" }
            Hint { keys: "/";    label: "search" }
            Hint { keys: "t";    label: "edit tags" }
            Hint { keys: "g G";  label: "first / last" }
            Hint { keys: "esc";  label: "close" }
        }
    }
}
