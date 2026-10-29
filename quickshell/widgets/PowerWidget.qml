// Session power menu. Reboot and power off use a two-step, in-place
// confirmation: the chosen tile turns green and asks to confirm, while any
// other action or Escape cancels it.
import QtQuick
import "../theme"
import "../services"
import "../state"
import "../components"

Item {
    id: root

    property bool active: false
    property string confirming: ""
    property int selected: 0
    readonly property int pad: 18
    readonly property var actions: [{
        "id": "lock",
        "label": "Lock",
        "glyph": ""
    }, {
        "id": "logout",
        "label": "Log Out",
        "glyph": ""
    }, {
        "id": "reboot",
        "label": "Reboot",
        "glyph": ""
    }, {
        "id": "power-off",
        "label": "Power Off",
        "glyph": ""
    }]

    function invoke(id) {
        if (id === "reboot" || id === "power-off") {
            root.confirming = root.confirming === id ? "" : id;
            return ;
        }
        root.confirming = "";
        if (id === "lock")
            PowerService.lock();
        else if (id === "logout")
            PowerService.logout();
    }

    implicitWidth: 500
    implicitHeight: header.height + 16 + tiles.height + pad * 2
    focus: active
    onActiveChanged: {
        if (active)
            root.forceActiveFocus();
        else
            root.confirming = "";
    }
    Keys.onPressed: function(event) {
        var k = event.key;
        var n = root.actions.length;
        if (k === Qt.Key_H || k === Qt.Key_Left) {
            root.selected = (root.selected + n - 1) % n;
            root.confirming = "";
        } else if (k === Qt.Key_L || k === Qt.Key_Right) {
            root.selected = (root.selected + 1) % n;
            root.confirming = "";
        } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
            root.invoke(root.actions[root.selected].id);
        } else {
            return ;
        }
        event.accepted = true;
    }

    Column {
        id: column

        spacing: 16

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: root.pad
        }

        Item {
            id: header

            width: parent.width
            height: 36

            Text {
                text: "Power"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge + 2
                font.bold: true

                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }

            }

            Text {
                text: root.confirming ? "Press Enter again to confirm" : "Session actions"
                color: root.confirming ? Theme.success : Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.bold: root.confirming !== ""

                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }

            }

        }

        Row {
            id: tiles

            width: parent.width
            spacing: 10

            Repeater {
                model: root.actions

                delegate: Rectangle {
                    id: tile

                    required property var modelData
                    required property int index
                    readonly property bool confirming: root.confirming === modelData.id
                    readonly property bool selected: root.selected === index
                    readonly property bool otherConfirming: root.confirming !== "" && !confirming

                    width: (tiles.width - tiles.spacing * 3) / 4
                    height: 82
                    radius: 20
                    color: confirming ? Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.8) : otherConfirming ? Theme.surface : tileHover.hovered ? Theme.hover : Theme.surface
                    border.width: confirming || selected ? 2 : 0
                    border.color: confirming ? Theme.red : Theme.mauve
                    opacity: otherConfirming ? 0.55 : 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tile.confirming ? "" : tile.modelData.glyph
                            color_: tile.confirming ? Theme.crust : Theme.text
                            font.pixelSize: 20
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tile.confirming ? "Confirm?" : tile.modelData.label
                            color: tile.confirming ? Theme.crust : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                        }

                    }

                    HoverHandler {
                        id: tileHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: {
                            root.selected = tile.index;
                            root.invoke(tile.modelData.id);
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.animFast
                        }

                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.animFast
                        }

                    }

                }

            }

        }

    }

}
