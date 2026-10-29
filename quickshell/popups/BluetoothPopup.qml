// Bluetooth popup: power toggle + paired/known device list.
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
        height: root.height

        customHeader: Item {
            width: parent.width

            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: "Bluetooth"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge
                font.bold: true
            }

            Toggle {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                enabled: BluetoothService.available
                checked: BluetoothService.powered
                onToggled: function (value) { BluetoothService.setPower(value) }
            }
        }

        Item {
            id: content
            width: parent.width
            height: Math.max(64, panel.height - panel.padding * 2 - panel.headerHeight)

            SettingRow {
                id: scanRow
                anchors { top: parent.top; left: parent.left; right: parent.right }
                visible: BluetoothService.available
                label: "Scan for devices"
                hint: "Find nearby Bluetooth devices"
                enabled: BluetoothService.powered
                opacity: BluetoothService.powered ? 1 : 0.45

                Toggle {
                    checked: BluetoothService.scanning
                    onToggled: function (value) { BluetoothService.setScan(value) }
                }
            }

            Text {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                visible: !BluetoothService.available
                text: "No Bluetooth adapter found"
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            Item {
                anchors {
                    top: scanRow.bottom; topMargin: 8
                    left: parent.left; right: parent.right; bottom: parent.bottom
                }
                visible: BluetoothService.available && !BluetoothService.powered

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    CenteredIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: BluetoothService.glyph
                        size: 24
                        color: Theme.overlay1
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Bluetooth is off"
                        color: Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                }
            }

            Column {
                anchors { top: scanRow.bottom; topMargin: 8; left: parent.left; right: parent.right }
                spacing: 6
                visible: BluetoothService.powered && BluetoothService.devices.length > 0

                Repeater {
                    model: BluetoothService.devices
                    delegate: DeviceRow { device: modelData }
                }
            }

            Item {
                anchors {
                    top: scanRow.bottom; topMargin: 8
                    left: parent.left; right: parent.right; bottom: parent.bottom
                }
                visible: BluetoothService.powered && BluetoothService.devices.length === 0

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    CenteredIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "\uf293"
                        size: 24
                        color: Theme.overlay1
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No Bluetooth Devices Found"
                        color: Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                }
            }
        }
    }

    // A device row follows the control-center card language: a quiet fill,
    // a single line of information, and the action on the right.
    component DeviceRow: Rectangle {
        id: deviceRow

        property var device

        width: parent ? parent.width : 0
        height: 36
        radius: Theme.cornerRadiusSmall + 2
        color: device.connected
             ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
             : deviceRowHover.hovered
             ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
             : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.045)
        border.width: 1
        border.color: device.connected
                      ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
                      : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.06)

        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        Text {
            anchors {
                left: parent.left; leftMargin: 14
                right: action.left; rightMargin: 12
                verticalCenter: parent.verticalCenter
            }
            text: deviceRow.device.name || deviceRow.device.mac
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: deviceRow.device.connected
            elide: Text.ElideRight
        }

        Text {
            id: action
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            text: deviceRow.device.connected ? "Connected"
                : deviceRow.device.paired ? "Connect" : "Pair"
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        HoverHandler {
            id: deviceRowHover
            cursorShape: deviceRow.device.connected ? Qt.ArrowCursor : Qt.PointingHandCursor
        }
        TapHandler {
            onTapped: {
                if (deviceRow.device.connected)
                    BluetoothService.disconnectDevice(deviceRow.device.mac)
                else if (deviceRow.device.paired)
                    BluetoothService.connectDevice(deviceRow.device.mac)
                else
                    BluetoothService.pair(deviceRow.device.mac)
            }
        }
    }
}
