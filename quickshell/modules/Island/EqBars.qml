// Three little accent bars that bounce while media plays, and settle flat
// when it pauses.
import QtQuick
import "../../theme"

Row {
    id: root

    property bool playing: false
    property int  barHeight: 12

    spacing: 2
    height: barHeight

    Repeater {
        model: [0.55, 1.0, 0.75]      // resting heights, as fractions

        Rectangle {
            id: bar

            required property real modelData
            required property int  index

            property real level: 0.3

            anchors.bottom: parent.bottom
            width: 3
            height: Math.max(3, root.barHeight * level)
            radius: 1.5
            color: Theme.accent

            // Each bar gets its own period so they never move in lockstep.
            SequentialAnimation on level {
                running: root.playing
                loops: Animation.Infinite
                NumberAnimation { to: bar.modelData; duration: 260 + bar.index * 70; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.25;          duration: 300 + bar.index * 50; easing.type: Easing.InOutSine }
            }

            // Paused: ease back to a low, even rest.
            states: State {
                when: !root.playing
                PropertyChanges { bar.level: 0.3 }
            }
            transitions: Transition {
                NumberAnimation { property: "level"; duration: Theme.animFast }
            }
        }
    }
}
