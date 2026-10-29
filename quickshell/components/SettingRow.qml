// One row in the Customise tab: label on the left, control on the right.
//
// The control is supplied by the caller through the default property, so the
// same row can hold a Toggle, a Slider, a value chip group or plain text.
import QtQuick
import "../theme"

Rectangle {
    id: root

    property string label: ""
    property string hint: ""
    property int    labelWidth: 150

    default property alias control: slot.data

    width: parent ? parent.width : 0
    implicitHeight: Math.max(30, slot.implicitHeight + 8)
    radius: Theme.cornerRadiusSmall
    color: hover.hovered ? Theme.hover : "transparent"

    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    Text {
        id: labelText
        anchors {
            left: parent.left
            leftMargin: 8
            verticalCenter: parent.verticalCenter
        }
        width: root.labelWidth
        text: root.label
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        elide: Text.ElideRight
    }

    Text {
        visible: root.hint !== ""
        anchors {
            left: labelText.right
            leftMargin: 8
            right: slot.left
            rightMargin: 8
            verticalCenter: parent.verticalCenter
        }
        text: root.hint
        color: Theme.subtext0
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        elide: Text.ElideRight
    }

    Item {
        id: slot
        anchors {
            right: parent.right
            rightMargin: 8
            verticalCenter: parent.verticalCenter
        }
        implicitWidth: childrenRect.width
        implicitHeight: Math.max(childrenRect.height, 22)
        width: childrenRect.width
        height: implicitHeight
    }

    HoverHandler { id: hover }
}
