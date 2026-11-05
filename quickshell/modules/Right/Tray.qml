pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell.Services.SystemTray
import "../../theme"

Flickable {
    id: root
    implicitWidth: icons.implicitWidth
    implicitHeight: 24
    contentWidth: icons.implicitWidth
    contentHeight: height
    flickableDirection: Flickable.HorizontalFlick
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    Row {
        id: icons
        spacing: 4

        Repeater {
            model: SystemTray.items

            Rectangle {
                id: button
                required property SystemTrayItem modelData
                width: 24
                height: 24
                radius: 6
                color: mouse.containsMouse ? Theme.hover : "transparent"

                function showMenu() {
                    if (!modelData.hasMenu) return
                    menu.popup(button, 0, button.height + 4)
                }

                TrayMenu {
                    id: menu
                    handle: button.modelData.menu
                }

                Image {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    source: button.modelData.icon
                    sourceSize: Qt.size(32, 32)
                    fillMode: Image.PreserveAspectFit
                }

                ToolTip.visible: mouse.containsMouse
                ToolTip.delay: 600
                ToolTip.text: modelData.tooltipTitle || modelData.title || modelData.id

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onClicked: function(event) {
                        if (event.button === Qt.RightButton) button.showMenu()
                        else if (event.button === Qt.MiddleButton) button.modelData.secondaryActivate()
                        else if (button.modelData.onlyMenu) button.showMenu()
                        else button.modelData.activate()
                    }
                    onWheel: function(event) {
                        const horizontal = event.angleDelta.y === 0
                        button.modelData.scroll(horizontal ? event.angleDelta.x : event.angleDelta.y, horizontal)
                        event.accepted = true
                    }
                }
            }
        }
    }
}
