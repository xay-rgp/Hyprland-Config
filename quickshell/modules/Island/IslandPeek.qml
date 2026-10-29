import QtQuick
import "../../theme"
import "../../services"

Item {
    id: root
    property date now: new Date()
    property bool active: false
    property bool registered: false
    function updateWatching() {
        if (active === registered) return
        StatsService.previewWatchers += active ? 1 : -1
        registered = active
    }
    onActiveChanged: updateWatching()
    Component.onCompleted: updateWatching()
    Component.onDestruction: {
        if (registered) StatsService.previewWatchers--
    }
    implicitWidth: Theme.islandPeekWidth
    implicitHeight: content.implicitHeight

    Column {
        id: content
        anchors.centerIn: parent
        width: parent.width
        spacing: 6
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(root.now, "ddd, dd MMM  h:mm:ss AP")
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLarge
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "CPU " + Math.round(StatsService.cpuPercent) + "%    GPU " + StatsService.gpuUsage + "    RAM " + MemoryService.label
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }
}
