// Chunky slider for the control center: a thick rounded track with the fill
// carrying its glyph, instead of Slider's thin track + handle.
//
// While dragging it shows its own local value, so a service that only reports
// back on its next poll (brightness) doesn't make the fill jump under the
// pointer.
import QtQuick
import "../theme"

Item {
    id: root

    property real   value: 0            // 0..1
    property string glyph: ""
    property color  fillColor: Theme.accent

    signal moved(real v)
    signal glyphClicked()

    implicitWidth: 200
    implicitHeight: 34

    property real _local: 0
    readonly property bool _dragging: drag.active
    readonly property real _frac: Math.max(0, Math.min(1, _dragging ? _local : value))

    function _apply(x) {
        var v = Math.max(0, Math.min(1, x / width))
        root._local = v
        root.moved(v)
    }

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Theme.hover

        Rectangle {
            // Never narrower than the glyph cap, so the icon always has a pill.
            width: Math.max(track.height, root._frac * track.width)
            height: parent.height
            radius: parent.radius
            color: root.fillColor

            Behavior on width {
                enabled: !root._dragging
                NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
            }
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        // Glyph cap, clickable on its own (mute, etc.).
        Item {
            id: cap
            width: track.height
            height: track.height

            CenteredIcon {
                anchors.centerIn: parent
                text: root.glyph
                color: Theme.crust
                size: 14
            }

            TapHandler { onTapped: root.glyphClicked() }
        }
    }

    HoverHandler { cursorShape: Qt.PointingHandCursor }

    TapHandler {
        onTapped: function (e) {
            if (e.position.x > cap.width) root._apply(e.position.x)
        }
    }

    DragHandler {
        id: drag
        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        onActiveChanged: if (active) root._local = root.value
        onCentroidChanged: {
            if (drag.active)
                root._apply(drag.centroid.position.x)
        }
    }

    WheelHandler {
        onWheel: function (e) {
            var v = root.value + (e.angleDelta.y > 0 ? 0.05 : -0.05)
            root.moved(Math.max(0, Math.min(1, v)))
        }
    }
}
