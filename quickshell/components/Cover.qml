// Cover art clipped to a rounded rectangle (or a circle, for artists), with a
// glyph placeholder while it loads or when there's no image.
import QtQuick
import QtQuick.Effects
import "../theme"

Item {
    id: root

    property string source: ""
    property real   radius: 8
    property bool   round: false           // circle, e.g. for artists
    property string placeholder: ""

    readonly property real _radius: round ? Math.min(width, height) / 2 : radius

    Rectangle {
        anchors.fill: parent
        radius: root._radius
        color: Theme.surface1
        visible: img.status !== Image.Ready

        CenteredIcon {
            anchors.centerIn: parent
            text: root.placeholder
            size: Math.max(10, Math.min(root.width, root.height) * 0.35)
            color: Theme.overlay1
        }
    }

    Image {
        id: img
        anchors.fill: parent
        source: root.source
        sourceSize: Qt.size(root.width * 2, root.height * 2)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: img
        visible: img.status === Image.Ready
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }

    Rectangle {
        id: mask
        anchors.fill: parent
        radius: root._radius
        visible: false
        layer.enabled: true
    }
}
