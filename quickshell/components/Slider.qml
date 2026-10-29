// Horizontal slider: themed track, accent fill, draggable handle.
//
// `value` is 0..1 and is written back on drag, so a popup can bind it straight
// to a service property.
import QtQuick
import "../theme"

Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 1
    property color fillColor: Theme.accent

    signal moved(real v)

    implicitHeight: 22
    implicitWidth: 180

    readonly property real _frac: {
        var span = root.to - root.from
        if (span <= 0) return 0
        return Math.max(0, Math.min(1, (root.value - root.from) / span))
    }

    function _apply(x) {
        var frac = Math.max(0, Math.min(1, x / width))
        root.moved(root.from + frac * (root.to - root.from))
    }

    // Track
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: height / 2
        color: Theme.hover

        // Fill
        Rectangle {
            width: root._frac * parent.width
            height: parent.height
            radius: parent.radius
            color: root.fillColor

            Behavior on width {
                enabled: !drag.active
                NumberAnimation { duration: Theme.animFast }
            }
        }
    }

    // Handle
    Rectangle {
        x: Math.round(root._frac * (parent.width - width))
        anchors.verticalCenter: parent.verticalCenter
        width: drag.active ? 18 : 14
        height: width
        radius: width / 2
        color: Theme.text

        Behavior on width { NumberAnimation { duration: Theme.animFast } }
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }

    TapHandler {
        onTapped: function (e) { root._apply(e.position.x) }
    }

    // DragHandler has no positionChanged signal; drive the value off the
    // centroid's own change notification instead.
    DragHandler {
        id: drag
        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        onCentroidChanged: {
            if (drag.active)
                root._apply(drag.centroid.position.x)
        }
    }

    WheelHandler {
        onWheel: function (e) {
            var step = (root.to - root.from) * 0.05
            var v = root.value + (e.angleDelta.y > 0 ? step : -step)
            root.moved(Math.max(root.from, Math.min(root.to, v)))
        }
    }
}
