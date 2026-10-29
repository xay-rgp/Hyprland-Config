// Lights page: a brightness slider that applies to whichever OpenRGB
// profile is on, and the profiles saved on the OpenRGB server to pick from.
import QtQuick
import "../theme"
import "../services"
import "../state"
import "../components"

Item {
    id: root

    // Shown as a control-center page rather than a standalone popup.
    property bool embedded: false

    implicitWidth: Theme.popupWidth
    implicitHeight: panel.implicitHeight

    PopupPanel {
        id: panel
        embedded: root.embedded
        width: parent.width

        customHeader: Item {
            width: parent.width

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Lights"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge
                font.bold: true
            }

            IconButton {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                glyph: "\uf08e"
                size: 28
                onActivated: {
                    RgbService.openGui()
                    ShellState.closeAll()
                }
            }
        }

        Column {
            width: parent.width
            spacing: 10

            Item { width: 1; height: 2 }

            Text {
                visible: !RgbService.available
                width: parent.width
                text: "Can't reach the OpenRGB server."
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                wrapMode: Text.WordWrap
            }

            // ── Brightness ──────────────────────────────────────────────────
            Row {
                visible: RgbService.available
                width: parent.width
                spacing: 10

                PillSlider {
                    width: parent.width - 44 - parent.spacing
                    height: 40
                    glyph: ""
                    value: RgbService.brightness / 100
                    fillColor: RgbService.on ? Theme.accent : Theme.overlay1
                    onMoved: function (v) { RgbService.setBrightness(v * 100) }
                    onGlyphClicked: RgbService.toggle()
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    horizontalAlignment: Text.AlignRight
                    text: RgbService.brightness + "%"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
            }

            // ── Profiles ────────────────────────────────────────────────────
            Text {
                visible: RgbService.available
                text: "Profiles"
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
            }

            Column {
                visible: RgbService.available
                width: parent.width
                spacing: 2

                Repeater {
                    model: RgbService.profiles

                    delegate: ListRow {
                        required property string modelData
                        title: modelData
                        glyph: modelData === "off" ? "" : ""
                        leadingActive: modelData === RgbService.active
                        selected: modelData === RgbService.active
                        onActivated: RgbService.setProfile(modelData)
                    }
                }
            }
        }
    }
}
