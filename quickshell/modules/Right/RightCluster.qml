import QtQuick
import "../../theme"

Row {
    id: root
    readonly property bool statusHovered: status.hovered
    spacing: tray.visible ? 8 : 0
    height: 24

    RightContent {
        id: status
        anchors.verticalCenter: parent.verticalCenter
    }

    Tray {
        id: tray
        visible: implicitWidth > 0
        width: Math.min(implicitWidth, Math.max(24,
            Theme.rNotchMaxWidth - Theme.notchPadding * 2 - status.implicitWidth - 8))
        height: 24
    }
}
