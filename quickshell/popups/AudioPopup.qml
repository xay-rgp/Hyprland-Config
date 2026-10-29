// Audio popup: output/input volume + device pickers.
//
// The header's "Per app" switch (SettingsService.audioPerApp) adds a card per
// application stream below that: its own volume and mute, and which output
// (or, for recording apps, which input) it goes to.
import QtQuick
import "../theme"
import "../state"
import "../services"
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
            anchors.fill: parent

            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: "Audio"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge
                font.bold: true
            }

            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Per app"
                    color: Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }

                Toggle {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: SettingsService.audioPerApp
                    onToggled: function (v) {
                        SettingsService.audioPerApp = v
                        SettingsService.save()
                    }
                }
            }

        }

        Column {
            width: parent.width
            spacing: 10

            Item { width: 1; height: 2 }

            // ── Output ──────────────────────────────────────────────────────
            SectionLabel { text: "Output" }

            Row {
                width: parent.width
                spacing: 10

                IconButton {
                    glyph: AudioService.muted ? "" : AudioService.glyph
                    size: 30
                    glyphSize: Theme.fontSizeLarge
                    active: AudioService.muted
                    onActivated: AudioService.toggleMute()
                }

                Slider {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 30 - 44 - 20
                    value: AudioService.volume
                    onMoved: function (v) { AudioService.setVolume(v) }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    horizontalAlignment: Text.AlignRight
                    text: AudioService.volumePercent + "%"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
            }

            // Output device picker
            Column {
                width: parent.width
                spacing: 2

                Repeater {
                    model: AudioService.sinks

                    delegate: ListRow {
                        required property var modelData
                        title: modelData.description || modelData.name || "Unknown"
                        glyph: ""
                        leadingActive: modelData === AudioService.sink
                        selected: modelData === AudioService.sink
                        onActivated: AudioService.setDefaultSink(modelData)
                    }
                }
            }

            Divider { width: parent.width }

            // ── Input ───────────────────────────────────────────────────────
            SectionLabel { text: "Input" }

            Row {
                width: parent.width
                spacing: 10

                IconButton {
                    glyph: AudioService.sourceMuted ? "" : ""
                    size: 30
                    glyphSize: Theme.fontSizeLarge
                    active: AudioService.sourceMuted
                    onActivated: AudioService.toggleSourceMute()
                }

                Slider {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 30 - 44 - 20
                    value: AudioService.sourceVolume
                    onMoved: function (v) { AudioService.setSourceVolume(v) }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    horizontalAlignment: Text.AlignRight
                    text: AudioService.sourcePercent + "%"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
            }

            // Input device picker
            Column {
                width: parent.width
                spacing: 2

                Repeater {
                    model: AudioService.sources

                    delegate: ListRow {
                        required property var modelData
                        title: modelData.description || modelData.name || "Unknown"
                        glyph: ""
                        leadingActive: modelData === AudioService.source
                        selected: modelData === AudioService.source
                        onActivated: AudioService.setDefaultSource(modelData)
                    }
                }
            }

            // ── Applications ────────────────────────────────────────────────
            Column {
                width: parent.width
                spacing: 10
                visible: SettingsService.audioPerApp

                Divider { width: parent.width }

                SectionLabel { text: "Playback" }

                EmptyNote {
                    visible: AudioService.playbackStreams.length === 0
                    text: "No apps playing audio"
                }

                Repeater {
                    model: AudioService.playbackStreams
                    delegate: AppStream {
                        required property var modelData
                        node: modelData
                        kind: "sink"
                        devices: AudioService.sinks
                    }
                }

                SectionLabel {
                    visible: AudioService.recordStreams.length > 0
                    text: "Recording"
                }

                Repeater {
                    model: AudioService.recordStreams
                    delegate: AppStream {
                        required property var modelData
                        node: modelData
                        kind: "source"
                        devices: AudioService.sources
                    }
                }
            }
        }
    }

    component SectionLabel: Text {
        color: Theme.subtext0
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.bold: true
    }

    component EmptyNote: Text {
        color: Theme.subtext1
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

    // One application stream: name + what it's playing, the device it goes
    // to (click to pick another), and its own volume.
    component AppStream: Rectangle {
        id: app

        property var    node
        property string kind: "sink"       // "sink" = playback, "source" = recording
        property var    devices: []
        property bool   expanded: false

        readonly property var    props: (node && node.properties) || ({})
        readonly property string iconName: props["application.icon_name"] || ""
        readonly property string mediaName: props["media.name"] || ""
        readonly property var    audio: node ? node.audio : null
        readonly property int    percent: audio ? Math.round(audio.volume * 100) : 0
        readonly property bool   muted: audio ? audio.muted : false

        // The device this stream is linked to right now.
        readonly property var device: AudioService.deviceOf(node)

        width: parent ? parent.width : 0
        height: body.implicitHeight + 20
        radius: 14
        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.045)
        border.width: 1
        border.color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.06)

        Column {
            id: body
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
            spacing: 8

            // Name, media and device chip.
            Item {
                width: parent.width
                height: 32

                Item {
                    id: appIcon
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    width: 28
                    height: 28

                    Image {
                        id: iconImg
                        anchors.fill: parent
                        source: app.iconName !== "" ? "image://icon/" + app.iconName : ""
                        sourceSize: Qt.size(28, 28)
                        visible: status === Image.Ready
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        visible: !iconImg.visible
                        color: Theme.surface1

                        CenteredIcon {
                            anchors.centerIn: parent
                            text: app.kind === "sink" ? "" : ""
                            size: 12
                            color: Theme.text
                        }
                    }
                }

                Column {
                    anchors { left: appIcon.right; leftMargin: 10; right: chip.left; rightMargin: 8
                              verticalCenter: parent.verticalCenter }

                    Text {
                        width: parent.width
                        text: AudioService.streamName(app.node)
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: app.mediaName
                        color: Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    id: chip
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: chipText.width + 36
                    height: 26
                    radius: 13
                    color: app.expanded || chipHover.hovered ? Theme.hover
                         : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.06)

                    Text {
                        id: chipText
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        width: Math.min(implicitWidth, app.width * 0.45 - 36)
                        text: AudioService.deviceName(app.device) || "Not connected"
                        color: Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                    }

                    CenteredIcon {
                        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        text: app.expanded ? "\uf077" : "\uf078"
                        size: 8
                        color: Theme.subtext0
                    }

                    HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: app.expanded = !app.expanded }
                }
            }

            // Device picker.
            Column {
                width: parent.width
                spacing: 2
                visible: app.expanded

                Repeater {
                    model: app.expanded ? app.devices : []

                    delegate: ListRow {
                        required property var modelData
                        height: 34
                        title: AudioService.deviceName(modelData) || "Unknown"
                        glyph: app.kind === "sink" ? "" : ""
                        leadingActive: modelData === app.device
                        selected: modelData === app.device
                        onActivated: {
                            AudioService.routeStream(app.kind, app.node, modelData)
                            app.expanded = false
                        }
                    }
                }
            }

            // Volume.
            Row {
                width: parent.width
                spacing: 10

                IconButton {
                    glyph: app.kind === "sink" ? (app.muted ? "" : "")
                                               : (app.muted ? "" : "")
                    size: 28
                    glyphSize: Theme.fontSize
                    active: app.muted
                    onActivated: AudioService.toggleStreamMute(app.node)
                }

                Slider {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 28 - 44 - 20
                    value: app.audio ? app.audio.volume : 0
                    fillColor: app.muted ? Theme.overlay1 : Theme.accent
                    onMoved: function (v) { AudioService.setStreamVolume(app.node, v) }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    horizontalAlignment: Text.AlignRight
                    text: app.percent + "%"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
            }
        }
    }
}
