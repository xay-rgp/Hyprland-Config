// Top bar window: left and right content-sized notches painted by
// SeamlessBarShape. The center belongs to the island (Island.qml), which
// floats over the bar strip instead of living in a notch.
//
// IMPORTANT (Chunk 0 finding F1): do NOT declare a `screen` property here.
// PanelWindow already provides one, and shadowing it duplicates the window on
// one monitor and drops it from the other. Only ever read `screen`.
import Quickshell
import QtQuick
import "../theme"
import "../state"
import "../shapes"
import "../modules/Left"
import "../modules/Right"

PanelWindow {
    id: root

    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: ShellState.focusMode ? Theme.borderWidth : Theme.notchHeight
    exclusiveZone: ShellState.focusMode ? 0 : Theme.exclusionGap

    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
    }
    Behavior on exclusiveZone {
        NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
    }

    // ── Notch widths, sized to content and clamped ──────────────────────────
    readonly property int lWidth: Math.max(
        Theme.lNotchMinWidth,
        Math.min(Theme.lNotchMaxWidth, leftContent.implicitWidth + Theme.notchPadding * 2))

    readonly property int rWidth: Math.max(
        Theme.rNotchMinWidth,
        Math.min(Theme.rNotchMaxWidth, rightContent.implicitWidth + Theme.notchPadding * 2))

    // ── Border strip, shown when the bar collapses in focus mode ────────────
    Rectangle {
        anchors.fill: parent
        color: Theme.barBg
        opacity: ShellState.focusMode ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
        }
    }

    // ── Notch content, fades out in focus mode ──────────────────────────────
    Item {
        anchors.fill: parent
        opacity: ShellState.focusMode ? 0 : 1
        Behavior on opacity {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
        }

        SeamlessBarShape {
            anchors.fill: parent
            leftWidth:   root.lWidth
            centerWidth: 0
            rightWidth:  root.rWidth
            omitRight: true
        }

        // Left notch — read-only now playing
        Item {
            width: root.lWidth
            height: Theme.notchHeight
            anchors.left: parent.left

            NowPlaying {
                id: leftContent
                width: parent.width - Theme.notchPadding * 2
                height: Math.min(implicitHeight, parent.height - 6)
                anchors.centerIn: parent
            }
        }

        // Right notch — status cluster
        Item {
            width: root.rWidth
            height: Theme.notchHeight
            anchors.right: parent.right
            clip: true

            RightContent {
                id: rightContent
                visible: false // Measurement only; ControlCenter owns the status pill.
                anchors.right: parent.right
                anchors.rightMargin: Theme.notchPadding
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
