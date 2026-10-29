// Password prompt for polkit requests (pkexec, systemctl, …). Hidden from
// the widget grid: PolkitService opens it when a request arrives.
//
// Shows the real request — the message and the action id — so a fake prompt
// can't pass itself off as something else. The password goes straight to
// polkit through the agent's flow and is cleared from the field right after.
// Escape, Cancel or clicking away cancels the request.
import QtQuick
import Quickshell
import "../theme"
import "../state"
import "../services"
import "../components"

Item {
    id: root

    property bool active: false

    readonly property var  flow: PolkitService.flow
    readonly property bool pending: PolkitService.pending
    // Submitted and waiting for polkit's verdict.
    property bool checking: false

    readonly property int pad: 20

    implicitWidth: 440
    implicitHeight: column.implicitHeight + pad * 2

    onActiveChanged: if (active) { field.text = ""; root.checking = false }

    // Focus the field whenever polkit wants input: on open and again after a
    // wrong password.
    function _focusField() {
        if (root.active && root.flow && root.flow.isResponseRequired) {
            root.checking = false
            field.forceActiveFocus()
        }
    }
    onFlowChanged: _focusField()
    Component.onCompleted: _focusField()

    Connections {
        target: root.flow
        ignoreUnknownSignals: true
        function onIsResponseRequiredChanged() { root._focusField() }
        function onAuthenticationFailed() {
            root.checking = false
            field.text = ""
            shake.restart()
        }
    }

    function _submit() {
        if (!root.pending || root.checking) return
        root.checking = true
        PolkitService.submit(field.text)
        field.text = ""
    }

    Column {
        id: column
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: root.pad }
        spacing: 14

        // ── Header ──────────────────────────────────────────────────────────
        Row {
            spacing: 12

            Rectangle {
                width: 38
                height: 38
                radius: 12
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)

                Icon {
                    anchors.centerIn: parent
                    text: "\uf023"
                    color_: Theme.accent
                    font.pixelSize: 16
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: "Authentication required"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLarge
                    font.bold: true
                }
                Text {
                    text: "as " + (Quickshell.env("USER") || "you")
                    color: Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }

        // ── What is being asked ─────────────────────────────────────────────
        Text {
            width: parent.width
            text: root.flow ? root.flow.message : "No pending request"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            wrapMode: Text.Wrap
        }

        Rectangle {
            visible: root.flow && root.flow.actionId !== ""
            width: parent.width
            height: actionText.implicitHeight + 12
            radius: Theme.cornerRadiusSmall
            color: Theme.hover

            Text {
                id: actionText
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 10 }
                text: root.flow ? root.flow.actionId : ""
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideMiddle
            }
        }

        // ── Password ────────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 38

            Rectangle {
                id: fieldBox
                width: parent.width
                height: parent.height
                radius: Theme.cornerRadiusSmall
                color: Theme.hover
                border.width: 1
                border.color: root.flow && root.flow.failed ? Theme.urgent
                            : field.activeFocus ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.6)
                            : "transparent"
                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                // Wrong password: a quick horizontal shake.
                SequentialAnimation {
                    id: shake
                    NumberAnimation { target: fieldBox; property: "x"; to: -9; duration: 45 }
                    NumberAnimation { target: fieldBox; property: "x"; to: 8;  duration: 70 }
                    NumberAnimation { target: fieldBox; property: "x"; to: -5; duration: 60 }
                    NumberAnimation { target: fieldBox; property: "x"; to: 3;  duration: 50 }
                    NumberAnimation { target: fieldBox; property: "x"; to: 0;  duration: 40 }
                }

                Icon {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    text: "\uf084"
                    color_: Theme.subtext0
                    font.pixelSize: 12
                }

                TextInput {
                    id: field
                    anchors { fill: parent; leftMargin: 34; rightMargin: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: root.flow && root.flow.responseVisible ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "\u2022"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.crust
                    enabled: !root.checking
                    focus: root.active
                    clip: true
                    onAccepted: root._submit()

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: field.text === ""
                        text: root.checking ? "Checking…"
                            : root.flow && root.flow.inputPrompt !== ""
                              ? root.flow.inputPrompt.replace(/:\s*$/, "")
                              : "Password"
                        color: Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                }
            }
        }

        // polkit's own feedback ("Authentication failed", info lines).
        Text {
            width: parent.width
            visible: text !== ""
            text: root.flow ? root.flow.supplementaryMessage : ""
            color: root.flow && root.flow.supplementaryIsError ? Theme.urgent : Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.Wrap
        }

        // ── Actions ─────────────────────────────────────────────────────────
        Row {
            anchors.right: parent.right
            spacing: 8

            PromptButton {
                label: "Cancel"
                onClicked: ShellState.closeAll()
            }
            PromptButton {
                label: root.checking ? "Checking…" : "Authenticate"
                primary: true
                enabled: !root.checking && root.pending
                onClicked: root._submit()
            }
        }
    }

    component PromptButton: Rectangle {
        id: btn

        property string label
        property bool   primary: false
        signal clicked

        width: btnText.implicitWidth + 28
        height: 32
        radius: height / 2
        opacity: enabled ? 1 : 0.5
        color: primary
               ? (btnHover.hovered ? Qt.lighter(Theme.accent, 1.1) : Theme.accent)
               : (btnHover.hovered ? Theme.pressed : Theme.hover)
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        Text {
            id: btnText
            anchors.centerIn: parent
            text: btn.label
            color: btn.primary ? Theme.crust : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: btn.primary
        }

        HoverHandler { id: btnHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: btn.clicked() }
    }
}
