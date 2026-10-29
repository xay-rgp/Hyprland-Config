// Label on the left, control on the right. SliderRow / ToggleRow /
// ChoiceRow build on this; a page can also use it directly with any control.
import QtQuick
import "../../theme"

Item {
    id: root

    property string label: ""
    property string hint: ""

    default property alias control: slot.data

    width: parent ? parent.width : 0
    implicitHeight: Math.max(34, labels.implicitHeight + 8, slot.implicitHeight + 8)
    opacity: enabled ? 1 : 0.45

    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

    Column {
        id: labels
        anchors { left: parent.left; right: slot.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
        spacing: 1

        Text {
            width: parent.width
            text: root.label
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            elide: Text.ElideRight
        }

        Text {
            visible: root.hint !== ""
            width: parent.width
            text: root.hint
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
        }
    }

    Item {
        id: slot
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: childrenRect.width
        height: childrenRect.height
        implicitHeight: childrenRect.height
    }
}
