// Pick one of a few values: a segmented control whose highlight slides to
// the chosen option.
//
//   ChoiceRow {
//       label: "Mode"
//       options: [{ value: "a", label: "A" }, { value: "b", label: "B" }]
//       current: "a"
//       onPicked: function (v) { ... }
//   }
import QtQuick
import "../../theme"

SettingRowBase {
    id: root

    property var    options: []
    property var    current: undefined
    property int    segmentWidth: 0          // 0 = size to each label

    signal picked(var value)

    readonly property int _index: {
        for (var i = 0; i < options.length; i++)
            if (options[i].value === current) return i
        return -1
    }

    Rectangle {
        width: segments.width + 6
        height: 30
        radius: height / 2
        color: Theme.surface

        // Sliding highlight behind the chosen segment.
        Rectangle {
            readonly property Item target: segRepeater.count > 0 && root._index >= 0 ? segRepeater.itemAt(root._index) : null
            visible: !!target
            x: target ? segments.x + target.x : 0
            y: 3
            width: target ? target.width : 0
            height: parent.height - 6
            radius: height / 2
            color: Theme.accent

            Behavior on x     { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }
        }

        Row {
            id: segments
            anchors.centerIn: parent

            Repeater {
                id: segRepeater
                model: root.options

                Item {
                    required property var modelData
                    required property int index

                    readonly property bool chosen: index === root._index

                    width: root.segmentWidth > 0 ? root.segmentWidth : segText.implicitWidth + 22
                    height: 24

                    Text {
                        id: segText
                        anchors.centerIn: parent
                        text: modelData.label
                        color: parent.chosen ? Theme.crust : segHover.hovered ? Theme.text : Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: parent.chosen
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }

                    HoverHandler { id: segHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: if (!parent.chosen) root.picked(modelData.value) }
                }
            }
        }
    }
}
