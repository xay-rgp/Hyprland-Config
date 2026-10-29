// Pomodoro: the timer ring, controls, and its settings. The timer itself is
// PomodoroService — it keeps running with this closed, shows in the resting
// pill, and rings (sound + the alarm in the island) when a phase ends.
//
// Keys:
//   Space   start / pause        1 2 3   focus / short / long break
//   r       reset the phase      s       skip to the next phase
import QtQuick
import "../theme"
import "../services"
import "../components"
import "settings"

Item {
    id: root

    property bool active: false

    readonly property var phases: [
        { id: "work",  name: "Focus",       icon: "" },
        { id: "short", name: "Short break", icon: "" },
        { id: "long",  name: "Long break",  icon: "" }
    ]
    readonly property int phaseIndex: Math.max(0, phases.findIndex(function (p) {
        return p.id === PomodoroService.phase
    }))
    readonly property color tint: PomodoroService.phase === "work" ? Theme.accent : Theme.success

    readonly property int pad: 18

    implicitWidth: 540
    implicitHeight: column.implicitHeight + pad * 2

    focus: active
    onActiveChanged: if (active) root.forceActiveFocus()

    Keys.onPressed: function (event) {
        var k = event.key
        if (k === Qt.Key_Space)      PomodoroService.toggle()
        else if (k === Qt.Key_R)     PomodoroService.reset()
        else if (k === Qt.Key_S)     PomodoroService.skip()
        else if (k === Qt.Key_1)     PomodoroService.setPhase("work")
        else if (k === Qt.Key_2)     PomodoroService.setPhase("short")
        else if (k === Qt.Key_3)     PomodoroService.setPhase("long")
        else return
        event.accepted = true
    }

    component RoundButton: Rectangle {
        id: rb
        property string glyph
        property int size: 44
        property bool primary: false
        signal clicked()

        width: size
        height: size
        radius: size / 2
        color: primary ? (rbArea.containsMouse ? Qt.lighter(root.tint, 1.1) : root.tint)
                       : (rbArea.containsMouse ? Theme.hover : Theme.surface)
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        Icon {
            anchors.centerIn: parent
            // Nudge ▶ right so it looks centred.
            anchors.horizontalCenterOffset: rb.glyph === "" ? 2 : 0
            text: rb.glyph
            color_: rb.primary ? Theme.crust : Theme.text
            font.pixelSize: rb.size * 0.34
        }
        MouseArea {
            id: rbArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: rb.clicked()
        }
    }

    Column {
        id: column
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: root.pad }
        spacing: 16

        // ── Header: title + phase tabs ──────────────────────────────────────
        Item {
            width: parent.width
            height: 36

            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: "Pomodoro"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge + 2
                font.bold: true
            }
            TabBar {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                tabs: root.phases
                current: root.phaseIndex
                onSelected: function (i) { PomodoroService.setPhase(root.phases[i].id) }
            }
        }

        // ── Ring ────────────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 220

            Canvas {
                id: ring
                anchors.centerIn: parent
                width: 210
                height: 210

                property real value: PomodoroService.progress
                property color tint: root.tint
                onValueChanged: requestPaint()
                onTintChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d")
                    var c = width / 2, r = c - 8
                    ctx.reset()
                    ctx.lineCap = "round"
                    ctx.lineWidth = 10
                    ctx.strokeStyle = Theme.hover
                    ctx.beginPath()
                    ctx.arc(c, c, r, 0, Math.PI * 2)
                    ctx.stroke()
                    if (value > 0) {
                        ctx.strokeStyle = tint
                        ctx.beginPath()
                        ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * value)
                        ctx.stroke()
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 4

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: PomodoroService.clock
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 44
                    font.bold: true
                    opacity: PomodoroService.running ? 1 : 0.75
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: PomodoroService.running ? PomodoroService.phaseLabel
                        : PomodoroService.active ? "Paused" : "Ready"
                    color: root.tint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                }

                // Focuses done towards the long break.
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 6
                    spacing: 6
                    Repeater {
                        model: PomodoroService.longEvery
                        Rectangle {
                            required property int index
                            width: 8; height: 8; radius: 4
                            color: index < PomodoroService.completed ? Theme.accent : Theme.hover
                        }
                    }
                }
            }
        }

        // ── Controls ────────────────────────────────────────────────────────
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 18

            RoundButton {
                anchors.verticalCenter: parent.verticalCenter
                glyph: ""
                onClicked: PomodoroService.reset()
            }
            RoundButton {
                size: 60
                primary: true
                glyph: PomodoroService.running ? "" : ""
                onClicked: PomodoroService.toggle()
            }
            RoundButton {
                anchors.verticalCenter: parent.verticalCenter
                glyph: ""
                onClicked: PomodoroService.skip()
            }
        }

        // ── Settings ────────────────────────────────────────────────────────
        Section {
            width: parent.width
            title: "Timer"

            SliderRow {
                label: "Focus"
                from: 5; to: 90; step: 5; unit: " min"
                value: PomodoroService.workMinutes
                onMoved: function (v) { PomodoroService.workMinutes = v }
            }
            SliderRow {
                label: "Short break"
                from: 1; to: 30; step: 1; unit: " min"
                value: PomodoroService.shortMinutes
                onMoved: function (v) { PomodoroService.shortMinutes = v }
            }
            SliderRow {
                label: "Long break"
                from: 5; to: 60; step: 5; unit: " min"
                value: PomodoroService.longMinutes
                onMoved: function (v) { PomodoroService.longMinutes = v }
            }
            SliderRow {
                label: "Long break every"
                from: 2; to: 8; step: 1; unit: " focuses"
                value: PomodoroService.longEvery
                onMoved: function (v) { PomodoroService.longEvery = v; PomodoroService.save() }
            }
            ToggleRow {
                label: "Start the next phase automatically"
                checked: PomodoroService.autoStartNext
                onToggled: function (v) { PomodoroService.autoStartNext = v; PomodoroService.save() }
            }
            ToggleRow {
                label: "Alarm sound"
                checked: PomodoroService.sound
                onToggled: function (v) { PomodoroService.sound = v; PomodoroService.save() }
            }
        }

        // Key hints
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "space start/pause · r reset · s skip · 1 2 3 phase"
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall - 1
        }
    }
}
