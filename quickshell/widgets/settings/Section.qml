// A titled group of settings. Sections nest: a Section inside a Section
// becomes a sub-section, drawn as a heading within its parent's card rather
// than another card. Depth is worked out from the parent chain, so pages
// just nest them:
//
//   Section { title: "Windows"
//       Section { title: "Gaps"
//           SliderRow { ... }
//       }
//   }
import QtQuick
import "../../theme"

Item {
    id: root

    property string title: ""
    property string description: ""

    // 0 = top-level card; 1+ = nested heading. Set from the parent chain.
    property int level: 0
    readonly property bool isSettingsSection: true

    default property alias content: body.data

    readonly property int pad: level === 0 ? 14 : 0

    width: parent ? parent.width : 0
    implicitHeight: column.implicitHeight + pad * 2

    Component.onCompleted: {
        for (var p = root.parent; p; p = p.parent) {
            if (p.isSettingsSection === true) {
                root.level = p.level + 1
                return
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.level === 0
        radius: Theme.ccCardRadius
        color: Theme.hover
    }

    Column {
        id: column
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: root.pad }
        spacing: 4

        // Nested sections get a little air above their heading.
        Item { width: 1; height: root.level > 0 ? 6 : 0 }

        Text {
            visible: root.title !== ""
            width: parent.width
            text: root.level === 0 ? root.title : root.title.toUpperCase()
            color: root.level === 0 ? Theme.text : Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: root.level === 0 ? Theme.fontSizeLarge : Theme.fontSizeSmall - 1
            font.bold: true
            font.letterSpacing: root.level === 0 ? 0 : 1
        }

        Text {
            visible: root.description !== ""
            width: parent.width
            text: root.description
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.Wrap
        }

        Item { width: 1; height: 4 }

        Column {
            id: body
            width: parent.width
            spacing: root.level === 0 ? 6 : 2
        }
    }
}
