// Date + time, plus a pomodoro ring while a session runs.
import QtQuick
import "../../theme"
import "../../services"

Row {
    id: root

    spacing: 10

    // ── Pomodoro ring ───────────────────────────────────────────────────────
    // Only present while a session is actually ticking, so the notch stays
    // quiet the rest of the time.
    Item {
        visible: PomodoroService.running
        width: visible ? 22 : 0
        height: 22
        anchors.verticalCenter: parent.verticalCenter

        Canvas {
            id: pomoRing
            anchors.fill: parent

            Connections {
                target: PomodoroService
                function onProgressChanged() { pomoRing.requestPaint() }
                function onRemainingChanged() { pomoRing.requestPaint() }
            }

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var cx = width / 2, cy = height / 2, r = width / 2 - 2.5
                ctx.lineWidth = 2.5
                ctx.lineCap = "round"

                ctx.beginPath()
                ctx.arc(cx, cy, r, 0, Math.PI * 2)
                ctx.strokeStyle = Theme.surface
                ctx.stroke()

                ctx.beginPath()
                ctx.arc(cx, cy, r, -Math.PI / 2,
                        -Math.PI / 2 + Math.PI * 2 * PomodoroService.progress)
                ctx.strokeStyle = Theme.accent
                ctx.stroke()
            }
        }
    }

    property date now: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Text {
        text: Qt.formatDateTime(root.now, "ddd, dd MMM")
        color: Theme.subtext0
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        text: Qt.formatDateTime(root.now, "hh:mm:ss")
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLarge
        font.bold: true
        anchors.verticalCenter: parent.verticalCenter
    }
}
