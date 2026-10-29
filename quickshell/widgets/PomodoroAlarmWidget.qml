// The pomodoro alarm, in the island: a phase just ended. Hidden from the
// widget grid and passive (no keyboard grab), opened by PomodoroService on
// every monitor while the alarm rings, with the quick actions:
//
//   Start <next phase>   +5 min (more of the phase that ended)   Stop
//
// Also over IPC: `qs ipc call pomodoro next | snooze 5 | dismiss`.
import QtQuick
import "../theme"
import "../services"
import "../components"

Item {
    id: root

    property bool active: false

    readonly property string finished: PomodoroService.finishedPhase
    readonly property bool wasFocus: finished === "work"
    readonly property color tint: wasFocus ? Theme.success : Theme.accent

    readonly property int pad: 18

    implicitWidth: 460
    implicitHeight: column.implicitHeight + pad * 2

    // ── Pieces ──────────────────────────────────────────────────────────────
    component ActionButton: Rectangle {
        id: btn
        property string label
        property string glyph
        property bool primary: false
        signal clicked()

        width: btnRow.implicitWidth + 28
        height: 34
        radius: 17
        color: primary ? (area.containsMouse ? Qt.lighter(root.tint, 1.1) : root.tint)
                       : (area.containsMouse ? Theme.hover : Theme.surface)

        Row {
            id: btnRow
            anchors.centerIn: parent
            spacing: 7
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                text: btn.glyph
                color_: btn.primary ? Theme.crust : Theme.text
                font.pixelSize: 11
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: btn.label
                color: btn.primary ? Theme.crust : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.bold: btn.primary
            }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    // ── Layout ──────────────────────────────────────────────────────────────
    Column {
        id: column
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: root.pad }
        spacing: 14

        Row {
            width: parent.width
            spacing: 14

            // Bell, pulsing while it rings.
            Item {
                width: 44
                height: 44

                Rectangle {
                    id: pulse
                    anchors.centerIn: parent
                    width: 44; height: 44; radius: 22
                    color: root.tint
                    opacity: 0.25
                    SequentialAnimation on scale {
                        running: PomodoroService.ringing
                        loops: Animation.Infinite
                        NumberAnimation { from: 1; to: 1.35; duration: 700; easing.type: Easing.OutCubic }
                        NumberAnimation { from: 1.35; to: 1; duration: 700; easing.type: Easing.InCubic }
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 44; height: 44; radius: 22
                    color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.18)
                    Icon {
                        anchors.centerIn: parent
                        text: ""
                        color_: root.tint
                        font.pixelSize: 18
                        SequentialAnimation on rotation {
                            running: PomodoroService.ringing
                            loops: Animation.Infinite
                            NumberAnimation { to: 14; duration: 90 }
                            NumberAnimation { to: -14; duration: 180 }
                            NumberAnimation { to: 0; duration: 90 }
                            PauseAnimation { duration: 900 }
                        }
                    }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 44 - parent.spacing
                spacing: 3

                Text {
                    text: root.wasFocus ? "Focus done" : root.finished === "long" ? "Long break over" : "Break over"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLarge
                    font.bold: true
                }
                Text {
                    width: parent.width
                    text: (root.wasFocus
                           ? PomodoroService.completed + " of " + PomodoroService.longEvery + " focuses done · "
                           : "") + "next: " + PomodoroService.phaseLabel.toLowerCase()
                          + ", " + PomodoroService.minutesFor(PomodoroService.phase) + " min"
                    wrapMode: Text.WordWrap
                    color: Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }

        // Quick actions
        Row {
            anchors.right: parent.right
            spacing: 8

            ActionButton {
                label: "Stop"
                glyph: ""
                // Also halts a phase that auto-started.
                onClicked: { PomodoroService.dismiss(); PomodoroService.pause() }
            }
            ActionButton {
                label: "+5 min"
                glyph: ""
                onClicked: PomodoroService.snooze(5)
            }
            ActionButton {
                primary: true
                visible: !PomodoroService.running        // auto-start already did it
                label: "Start " + PomodoroService.phaseLabel.toLowerCase()
                glyph: ""
                onClicked: PomodoroService.startNext()
            }
            ActionButton {
                primary: true
                visible: PomodoroService.running
                label: "OK"
                glyph: ""
                onClicked: PomodoroService.dismiss()
            }
        }
    }
}
