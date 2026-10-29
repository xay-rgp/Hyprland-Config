// Stand-in for a Registry entry whose widget isn't built yet.
import QtQuick
import "../theme"
import "../components"

Item {
    id: root

    property var meta: null

    implicitWidth: 360
    implicitHeight: 180

    Column {
        anchors.centerIn: parent
        spacing: 10

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.meta ? root.meta.icon : "\uf128"
            color_: Theme.accent
            font.pixelSize: 30
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.meta ? root.meta.name : "Unknown widget"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLarge
            font.bold: true
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Not built yet"
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
