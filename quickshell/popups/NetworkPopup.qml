// Network page: Ethernet and Wi-Fi tiles (the round glyph or the tile toggles
// each link), then the available Wi-Fi networks while Wi-Fi is on.
//
// The network list is populated on demand — scanNetworks() kicks off nmcli —
// so the page asks for a scan when it opens and when Wi-Fi is switched on.
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

    Connections {
        target: ShellState
        function onNetworkOpenChanged() {
            if (ShellState.networkOpen)
                NetworkService.scanNetworks()
        }
    }

    Connections {
        target: NetworkService
        function onWifiEnabledChanged() {
            if (NetworkService.wifiEnabled && ShellState.networkOpen)
                NetworkService.scanNetworks()
        }
    }

    // The connected network, matched by SSID too: nmcli lists one row per
    // access point and the service keeps the first per name, which need not
    // be the "in use" one.
    function isCurrent(n) {
        return n.inUse || (NetworkService.wifiConnected && n.ssid === NetworkService.wifiSsid)
    }

    // Connected network first, then by signal.
    readonly property var networks: {
        var list = NetworkService.networks.map(function (n) {
            return { ssid: n.ssid, security: n.security, strength: n.strength,
                     inUse: root.isCurrent(n) }
        })
        list.sort(function (a, b) {
            if (a.inUse !== b.inUse) return a.inUse ? -1 : 1
            return b.strength - a.strength
        })
        return list
    }

    PopupPanel {
        id: panel
        embedded: root.embedded
        title: "Network"
        width: parent.width

        Column {
            width: parent.width
            spacing: 12
            topPadding: 12

            // ── Link tiles ──────────────────────────────────────────────────
            Row {
                width: parent.width
                spacing: 10

                readonly property real tileWidth: (width - spacing) / 2

                QuickTile {
                    width: parent.tileWidth
                    glyph: "\udb80\ude00"                     // md-ethernet
                    title: "Ethernet"
                    subtitle: {
                        if (NetworkService.ethDevice === "") return "No adapter"
                        if (!NetworkService.ethConnected) return "Off"
                        return NetworkService.kind === "ethernet" && NetworkService.ip !== ""
                               ? NetworkService.ip : "Connected"
                    }
                    active: NetworkService.ethConnected
                    onToggled: NetworkService.toggleEthernet()
                    onOpened: NetworkService.toggleEthernet()
                }

                QuickTile {
                    width: parent.tileWidth
                    glyph: "\uf1eb"
                    title: "Wi-Fi"
                    subtitle: {
                        if (!NetworkService.wifiEnabled) return "Off"
                        return NetworkService.wifiConnected ? NetworkService.wifiSsid : "Not connected"
                    }
                    active: NetworkService.wifiEnabled
                    onToggled: NetworkService.toggleWifi()
                    onOpened: NetworkService.toggleWifi()
                }
            }

            // ── Wi-Fi networks ──────────────────────────────────────────────
            Item {
                width: parent.width
                height: 22
                visible: NetworkService.wifiEnabled

                Text {
                    anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                    text: "Wi-Fi networks"
                    color: Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }

                Rectangle {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: scanText.implicitWidth + 16
                    height: 22
                    radius: height / 2
                    color: scanHover.hovered ? Theme.hover : "transparent"

                    Text {
                        id: scanText
                        anchors.centerIn: parent
                        text: NetworkService._netPollRunning ? "Scanning…" : "Rescan"
                        color: Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    HoverHandler { id: scanHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: NetworkService.scanNetworks() }
                }
            }

            Column {
                width: parent.width
                spacing: 6
                visible: NetworkService.wifiEnabled

                Repeater {
                    model: root.networks
                    delegate: NetworkRow {}
                }

                Text {
                    visible: root.networks.length === 0
                    width: parent.width
                    height: 60
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "Looking for networks…"
                    color: Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
            }

            Text {
                visible: !NetworkService.wifiEnabled
                width: parent.width
                height: 80
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "Turn on Wi-Fi to see networks"
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
        }
    }

    // One network: signal glyph, name + security, lock and signal strength.
    // Clicking a network that isn't the current one connects to it.
    component NetworkRow: Rectangle {
        id: row

        required property var modelData
        readonly property bool current: modelData.inUse
        readonly property bool secured: modelData.security !== "" && modelData.security !== "--"

        width: parent ? parent.width : 0
        height: 48
        radius: Theme.cornerRadiusSmall + 2
        color: row.current ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
             : rowHover.hovered ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
             : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.045)
        border.width: 1
        border.color: row.current ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
                                  : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.06)

        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        // Signal strength as glyph brightness: one glyph, dimmer when weak.
        CenteredIcon {
            id: signal
            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
            text: "\uf1eb"
            size: 16
            color: row.current ? Theme.accent
                 : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b,
                           0.35 + 0.65 * Math.min(1, row.modelData.strength / 80))
        }

        Column {
            anchors {
                left: signal.right; leftMargin: 12
                right: trailing.left; rightMargin: 10
                verticalCenter: parent.verticalCenter
            }
            spacing: 1

            Text {
                width: parent.width
                text: row.modelData.ssid
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: row.current
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: row.current ? "Connected"
                                  : (row.secured ? row.modelData.security : "Open")
                color: row.current ? Theme.accent : Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }
        }

        Row {
            id: trailing
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 10

            CenteredIcon {
                anchors.verticalCenter: parent.verticalCenter
                visible: row.secured
                text: "\uf023"                                    // lock
                size: 11
                color: Theme.subtext0
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.strength + "%"
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        HoverHandler { id: rowHover; cursorShape: row.current ? Qt.ArrowCursor : Qt.PointingHandCursor }
        TapHandler { onTapped: if (!row.current) NetworkService.connect(row.modelData.ssid, "") }
    }
}
