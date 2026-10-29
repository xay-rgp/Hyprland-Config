// A wall-clock alarm is ringing. Passive, so it appears on every monitor and
// does not steal the keyboard; the one obvious action is Stop.
import QtQuick
import "../theme"
import "../services"
import "../components"

Item {
    id: root

    property bool active: false
    readonly property string time: AlarmService.timeFor(AlarmService.ringingAlarm)
    readonly property int pad: 18

    implicitWidth: 380
    implicitHeight: row.implicitHeight + pad * 2

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 14

        Item {
            width: 46
            height: 46

            Rectangle {
                anchors.centerIn: parent
                width: 46
                height: 46
                radius: 23
                color: Theme.accent
                opacity: 0.25

                SequentialAnimation on scale {
                    running: AlarmService.ringingId !== ""
                    loops: Animation.Infinite

                    NumberAnimation {
                        from: 1
                        to: 1.35
                        duration: 700
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        from: 1.35
                        to: 1
                        duration: 700
                        easing.type: Easing.InCubic
                    }

                }

            }

            Rectangle {
                anchors.centerIn: parent
                width: 46
                height: 46
                radius: 23
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)

                Icon {
                    anchors.centerIn: parent
                    text: ""
                    color_: Theme.accent
                    font.pixelSize: 19

                    SequentialAnimation on rotation {
                        running: AlarmService.ringingId !== ""
                        loops: Animation.Infinite

                        NumberAnimation {
                            to: 14
                            duration: 90
                        }

                        NumberAnimation {
                            to: -14
                            duration: 180
                        }

                        NumberAnimation {
                            to: 0
                            duration: 90
                        }

                        PauseAnimation {
                            duration: 900
                        }

                    }

                }

            }

        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: stopButton.width + 18
            spacing: 3

            Text {
                text: "Alarm · " + root.time
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge
                font.bold: true
            }

            Text {
                text: "Time is up"
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }

        }

        Rectangle {
            id: stopButton

            anchors.verticalCenter: parent.verticalCenter
            width: stopLabel.implicitWidth + 40
            height: 38
            radius: 19
            color: stopHover.hovered ? Qt.lighter(Theme.accent, 1.08) : Theme.accent

            Row {
                anchors.centerIn: parent
                spacing: 7

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    color_: Theme.crust
                    font.pixelSize: 11
                }

                Text {
                    id: stopLabel

                    anchors.verticalCenter: parent.verticalCenter
                    text: "Stop"
                    color: Theme.crust
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                }

            }

            HoverHandler {
                id: stopHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: AlarmService.stop()
            }

        }

    }

}
