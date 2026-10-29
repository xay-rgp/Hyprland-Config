// App launcher widget — replaces the rofi drun half.
//
// Keyboard-first: typing filters, Up/Down (or Tab/Shift+Tab, Ctrl+J/K) move
// the highlight, Enter launches. The pointer works too.
//
// Results reflow instead of snapping: non-matches fade out, new matches fade
// in, and survivors slide to their new rows. That needs a ListModel changed
// by the smallest set of remove/insert/move calls (see _sync) — assigning a
// fresh JS array as the model would rebuild every row and animate nothing.
import QtQuick
import "../theme"
import "../services"
import "../components"

Item {
    id: root

    property bool active: false
    property string query: ""

    readonly property int fieldHeight: 34
    readonly property int rowHeight: 42
    readonly property int listHeight: Theme.launcherMaxHeight - fieldHeight - Theme.popupPadding * 2 - 10

    // Reflow timings.
    readonly property int fadeIn: 220
    readonly property int fadeOut: 140
    readonly property int slide: 280

    implicitWidth: Theme.launcherWidth
    implicitHeight: Theme.launcherMaxHeight

    // False while (re)filling the list wholesale — on open, or when the app
    // index finishes loading — so that doesn't play as a flood of fade-ins.
    property bool _animate: false

    // AppService entries by id, for launching from a model row.
    property var _byId: ({})

    // Mirror of the model's id order, so _sync can find rows without
    // calling model.get() in a loop.
    property var _order: []

    ListModel { id: shown }

    // Fresh search every time it opens.
    onActiveChanged: {
        if (!active) return
        // Rescan on every open so newly installed apps show up; the list
        // refreshes in place when the scan finishes (onAppsChanged).
        AppService.load()
        root._animate = false
        input.text = ""
        root._sync()
        root._animate = true
    }

    onQueryChanged: {
        root._sync()
        list.currentIndex = 0
        list.positionViewAtBeginning()
    }

    function _index() {
        var map = {}
        for (var i = 0; i < AppService.apps.length; i++)
            map[AppService.apps[i].id] = AppService.apps[i]
        root._byId = map
    }

    Component.onCompleted: root._index()

    Connections {
        target: AppService
        function onAppsChanged() {
            root._index()
            var was = root._animate
            root._animate = false
            root._sync()
            root._animate = was
        }
    }

    // Morph the model into the current results with minimal changes.
    function _sync() {
        var next = AppService.search(root.query)
        var keep = {}
        for (var i = 0; i < next.length; i++)
            keep[next[i].id] = true

        // 1. Drop rows that no longer match (back to front keeps indices valid).
        for (var r = root._order.length - 1; r >= 0; r--) {
            if (!keep[root._order[r]]) {
                shown.remove(r, 1)
                root._order.splice(r, 1)
            }
        }

        // 2. Walk the new order: rows already in place stay, survivors further
        //    down move up, and anything else is inserted.
        for (var n = 0; n < next.length; n++) {
            var id = next[n].id
            if (root._order[n] === id) continue
            var at = root._order.indexOf(id, n + 1)
            if (at !== -1) {
                shown.move(at, n, 1)
                root._order.splice(at, 1)
                root._order.splice(n, 0, id)
            } else {
                shown.insert(n, {
                    appId: id,
                    name: next[n].name,
                    comment: next[n].comment,
                    icon: next[n].icon
                })
                root._order.splice(n, 0, id)
            }
        }
    }

    function _step(delta) {
        if (shown.count === 0) return
        list.currentIndex = (list.currentIndex + delta + shown.count) % shown.count
        list.positionViewAtIndex(list.currentIndex, ListView.Contain)
    }

    function _launchCurrent() {
        if (list.currentIndex < 0 || list.currentIndex >= shown.count) return
        var app = root._byId[shown.get(list.currentIndex).appId]
        if (app) AppService.launch(app)
    }

    // Plain column rather than PopupPanel: the island paints the surface.
    Column {
        anchors.fill: parent
        anchors.margins: Theme.popupPadding
        spacing: 10

        // ── Search field ────────────────────────────────────────────────────
        Rectangle {
            width: parent.width
            height: root.fieldHeight
            radius: Theme.cornerRadiusSmall
            color: Theme.hover

            Icon {
                id: searchGlyph
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                text: "\uf002"
                color_: input.text === "" ? Theme.subtext0 : Theme.accent
                font.pixelSize: 12
                Behavior on color_ { ColorAnimation { duration: Theme.animFast } }
            }

            TextInput {
                id: input
                anchors {
                    fill: parent
                    leftMargin: 34
                    rightMargin: 12
                }
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                selectionColor: Theme.accent
                selectedTextColor: Theme.crust
                clip: true
                focus: root.active
                onTextChanged: root.query = text
                onAccepted: root._launchCurrent()

                Keys.onPressed: function (event) {
                    var ctrl = event.modifiers & Qt.ControlModifier
                    if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N))
                            || (event.key === Qt.Key_Tab)) {
                        root._step(1); event.accepted = true
                    } else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P))
                            || event.key === Qt.Key_Backtab) {
                        root._step(-1); event.accepted = true
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text === ""
                    text: "Search applications…"
                    color: Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
            }
        }

        // ── Results ─────────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: root.listHeight

            ListView {
                id: list
                anchors.fill: parent
                clip: true
                model: shown
                boundsBehavior: Flickable.StopAtBounds
                // Keys stay with the search field; the list only follows it.
                keyNavigationEnabled: false
                currentIndex: 0

                // The selection slides between rows rather than jumping.
                highlightFollowsCurrentItem: true
                highlightMoveDuration: 160
                highlightMoveVelocity: -1
                highlightResizeDuration: 0
                highlight: Rectangle {
                    width: list.width
                    height: root.rowHeight
                    radius: Theme.cornerRadiusSmall
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
                    visible: shown.count > 0
                }

                // ── Reflow ──────────────────────────────────────────────────
                add: Transition {
                    enabled: root._animate
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: root.fadeIn; easing.type: Easing.OutCubic }
                        NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: root.fadeIn; easing.type: Easing.OutCubic }
                    }
                }
                remove: Transition {
                    enabled: root._animate
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; to: 0; duration: root.fadeOut; easing.type: Easing.InCubic }
                        NumberAnimation { property: "scale"; to: 0.94; duration: root.fadeOut; easing.type: Easing.InCubic }
                    }
                }
                move: Transition {
                    enabled: root._animate
                    NumberAnimation { property: "y"; duration: root.slide; easing.type: Easing.OutCubic }
                }
                // Rows pushed around by the above slide into place. Opacity
                // and scale are restored too, in case a row was caught
                // mid-fade when it got displaced.
                displaced: Transition {
                    enabled: root._animate
                    ParallelAnimation {
                        NumberAnimation { property: "y"; duration: root.slide; easing.type: Easing.OutCubic }
                        NumberAnimation { property: "opacity"; to: 1; duration: root.fadeIn }
                        NumberAnimation { property: "scale"; to: 1; duration: root.fadeIn }
                    }
                }

                delegate: Item {
                    id: row

                    required property int index
                    required property string appId
                    required property string name
                    required property string comment
                    required property string icon

                    readonly property bool current: ListView.isCurrentItem

                    width: list.width
                    height: root.rowHeight

                    Row {
                        anchors {
                            left: parent.left;  leftMargin: 10
                            right: parent.right; rightMargin: 10
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 10

                        // .desktop Icon= is a freedesktop icon *name* (e.g.
                        // "firefox"), not a Nerd Font glyph, so it must go
                        // through the icon image provider.
                        Image {
                            id: appIcon
                            anchors.verticalCenter: parent.verticalCenter
                            width: 20
                            height: 20
                            source: row.icon !== "" ? "image://icon/" + row.icon : ""
                            sourceSize.width: 20
                            sourceSize.height: 20
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            visible: status === Image.Ready
                        }

                        // The icon provider renders a placeholder box for names
                        // it cannot resolve, so fall back to a generic glyph
                        // whenever the image did not actually load.
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: appIcon.status !== Image.Ready
                            text: "\uf2d0"
                            color_: Theme.accent
                            font.pixelSize: 16
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 30
                            spacing: 1

                            Text {
                                width: parent.width
                                text: row.name
                                color: row.current ? Theme.accent : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                elide: Text.ElideRight
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            }

                            Text {
                                width: parent.width
                                visible: text !== ""
                                text: row.comment
                                color: Theme.subtext0
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // Pointer and keys share one highlight: hovering a row
                    // selects it.
                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: if (hovered) list.currentIndex = row.index
                    }
                    TapHandler {
                        onTapped: {
                            list.currentIndex = row.index
                            root._launchCurrent()
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                opacity: shown.count === 0 ? 1 : 0
                visible: opacity > 0
                text: AppService.loaded ? "No applications found" : "Loading applications…"
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
            }
        }
    }
}
