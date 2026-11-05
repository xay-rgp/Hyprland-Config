pragma ComponentBehavior: Bound
import QtQuick
import QtQml.Models
import QtQuick.Controls.Basic
import Quickshell
import "../../theme"

Menu {
    id: root
    property var handle: null
    popupType: Popup.Window
    width: 256
    padding: 6
    margins: 6
    overlap: 2
    cascade: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    delegate: TrayMenuItem {}

    // Match the control center's easing with a compact grow-and-fade.
    readonly property var emphasized: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4,
                                       5 / 24, 0.82, 0.25, 1, 1, 1]
    transformOrigin: Item.TopRight
    enter: Transition {
        NumberAnimation {
            property: "scale"
            from: 0.92
            to: 1
            duration: Theme.animDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.emphasized
        }
        NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.animFast
            easing.type: Easing.OutCubic
        }
    }
    exit: Transition {
        NumberAnimation {
            property: "scale"
            to: 0.96
            duration: Theme.animFast
            easing.type: Easing.InOutCubic
        }
        NumberAnimation {
            property: "opacity"
            to: 0
            duration: Theme.animFast
            easing.type: Easing.InOutCubic
        }
    }

    background: Rectangle {
        color: Theme.barBg
        radius: Theme.cornerRadius
        border.width: 1
        border.color: Theme.divider
    }

    QsMenuOpener {
        id: opener
        menu: root.handle
    }

    Component { id: actionComponent; TrayMenuItem {} }
    Component {
        id: separatorComponent
        MenuSeparator {
            padding: 5
            contentItem: Rectangle {
                implicitWidth: 220
                implicitHeight: 1
                color: Theme.divider
            }
        }
    }

    Instantiator {
        model: opener.children
        // Instantiator exposes delegates as QObject to the static checker.
        // qmllint disable missing-property
        onObjectAdded: (index, object) => object.insert(index)
        onObjectRemoved: (index, object) => object.remove()
        // qmllint enable missing-property
        delegate: QtObject {
            id: entry
            required property QsMenuEntry modelData
            property var control: null
            property bool submenu: false

            function insert(position) {
                if (modelData.isSeparator) {
                    control = separatorComponent.createObject(root.contentItem)
                    root.insertItem(position, control)
                } else if (modelData.hasChildren) {
                    // Load recursively only for actual submenus.
                    const component = Qt.createComponent("TrayMenu.qml")
                    control = component.createObject(root, {
                        handle: modelData,
                        title: Qt.binding(() => entry.modelData.text),
                        enabled: Qt.binding(() => entry.modelData.enabled)
                    })
                    submenu = true
                    root.insertMenu(position, control)
                } else {
                    control = actionComponent.createObject(root.contentItem, {
                        text: Qt.binding(() => entry.modelData.text),
                        enabled: Qt.binding(() => entry.modelData.enabled),
                        checkable: Qt.binding(() => entry.modelData.buttonType !== QsMenuButtonType.None),
                        checked: Qt.binding(() => entry.modelData.checkState !== Qt.Unchecked)
                    })
                    control.icon.source = Qt.binding(() => entry.modelData.icon)
                    control.triggered.connect(() => entry.modelData.triggered())
                    root.insertItem(position, control)
                }
            }

            function remove() {
                if (!control) return
                if (submenu) root.removeMenu(control)
                else root.removeItem(control)
                control.destroy()
                control = null
            }
        }
    }
}
