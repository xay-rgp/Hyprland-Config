// Alarm management: set multiple wall-clock alarms, each either daily or
// one-shot. A time dial sets the new alarm; tapping an existing row edits it.
import QtQuick
import "../theme"
import "../services"
import "../components"

Item {
    id: root

    property bool active: false
    property int editHour: new Date().getHours()
    property int editMinute: new Date().getMinutes()
    property bool editRepeat: true
    property string editingId: ""
    readonly property bool editing: editingId !== ""
    readonly property string heading: editing ? "Edit alarm" : "New alarm"
    readonly property int pad: 18
    readonly property int contentWidth: 520

    function edit(alarm) {
        if (!alarm) {
            editingId = "";
            var now = new Date();
            editHour = now.getHours();
            editMinute = now.getMinutes();
            editRepeat = true;
        } else {
            editingId = alarm.id;
            editHour = alarm.hour;
            editMinute = alarm.minute;
            editRepeat = alarm.repeat;
        }
    }

    function reset() {
        root.edit(null);
    }

    implicitWidth: contentWidth + pad * 2
    implicitHeight: column.implicitHeight + pad * 2
    onActiveChanged: {
        if (!active) {
            Qt.callLater(root.reset);
        }
    }

    Column {
        id: column

        spacing: 12

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: root.pad
        }

        Item {
            width: parent.width
            height: 34

            Text {
                text: root.editing ? root.heading : "Alarms"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge + 2
                font.bold: true

                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }

            }

            Row {
                spacing: 6

                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: cancelEdit.implicitWidth + 24
                    height: 30
                    radius: 15
                    color: cancelEdit.hovered ? Theme.hover : Theme.surface
                    visible: root.editing

                    Text {
                        id: cancelEditLabel

                        anchors.centerIn: parent
                        text: "Cancel"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    HoverHandler {
                        id: cancelEdit

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: root.reset()
                    }

                }

                Rectangle {
                    width: saveLabel.implicitWidth + 34
                    height: 34
                    radius: 17
                    color: saveHover.hovered ? Qt.lighter(Theme.accent, 1.08) : Theme.accent

                    Text {
                        id: saveLabel

                        anchors.centerIn: parent
                        text: root.editing ? "Save" : "+ Add alarm"
                        color: Theme.crust
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                    }

                    HoverHandler {
                        id: saveHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: {
                            if (root.editing)
                                AlarmService.update(root.editingId, root.editHour, root.editMinute, root.editRepeat);
                            else
                                AlarmService.add(root.editHour, root.editMinute, root.editRepeat);
                            root.reset();
                        }
                    }

                }

            }

        }

        // ── Time dial ───────────────────────────────────────────────────────
        Rectangle {
            width: parent.width
            height: 150
            radius: Theme.ccCardRadius
            color: Theme.hover

            Row {
                anchors.centerIn: parent
                spacing: 8

                Dial {
                    label: "Hour"
                    hours: root.editHour
                    onChanged: function(value) {
                        root.editHour = value;
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ":"
                    color: Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: 42
                    font.bold: true
                }

                Dial {
                    label: "Minute"
                    hours: root.editMinute
                    onChanged: function(value) {
                        root.editMinute = value;
                    }
                }

                component Dial: Item {
                    id: dial

                    property int hours: root.editHour
                    property string label: ""

                    signal changed(int value)

                    function bump(delta) {
                        var size = label === "Hour" ? 24 : 60;
                        dial.changed((dial.hours + delta + size) % size);
                    }

                    implicitWidth: 112
                    implicitHeight: 116

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 80
                            height: 40
                            radius: 20
                            color: upMouse.hovered || downMouse.hovered ? Theme.surface2 : Theme.surface

                            Text {
                                anchors.centerIn: parent
                                text: (dial.hours < 10 ? "0" : "") + dial.hours
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 30
                                font.bold: true
                            }

                            HoverHandler {
                                id: upMouse

                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                onTapped: dial.bump(1)
                            }

                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: dial.label
                            color: Theme.subtext0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 8

                            Rectangle {
                                width: 26
                                height: 22
                                radius: 11
                                color: downMouse.hovered ? Theme.surface2 : "transparent"

                                Icon {
                                    anchors.centerIn: parent
                                    text: ""
                                    color_: Theme.subtext0
                                    font.pixelSize: 8
                                }

                                HoverHandler {
                                    id: downMouse

                                    cursorShape: Qt.PointingHandCursor
                                }

                                TapHandler {
                                    onTapped: dial.bump(-1)
                                }

                            }

                            Rectangle {
                                width: 26
                                height: 22
                                radius: 11
                                color: upMouse.hovered ? Theme.surface2 : "transparent"

                                Icon {
                                    anchors.centerIn: parent
                                    text: ""
                                    color_: Theme.subtext0
                                    font.pixelSize: 8
                                }

                                TapHandler {
                                    onTapped: dial.bump(1)
                                }

                            }

                        }

                    }

                }

            }

        }

        // ── Repeat and sound ────────────────────────────────────────────────
        Row {
            width: parent.width
            height: 34
            spacing: 10

            Rectangle {
                width: repeatLabel.implicitWidth + 32
                height: 32
                radius: 16
                color: root.editRepeat ? Theme.accent : Theme.surface
                border.width: root.editRepeat ? 0 : 1
                border.color: Theme.divider

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ""
                        color_: root.editRepeat ? Theme.crust : Theme.subtext0
                        font.pixelSize: 11
                    }

                    Text {
                        id: repeatLabel

                        anchors.verticalCenter: parent.verticalCenter
                        text: "Repeat daily"
                        color: root.editRepeat ? Theme.crust : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: root.editRepeat
                    }

                }

                HoverHandler {
                    id: repeatHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: {
                        root.editRepeat = !root.editRepeat;
                        if (root.editing)
                            AlarmService.update(root.editingId, root.editHour, root.editMinute, root.editRepeat);

                    }
                }

            }

            Item {
                width: 1
                height: 1
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Alarm sound"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
            }

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: AlarmService.sound
                onToggled: function(value) {
                    AlarmService.sound = value;
                    AlarmService.save();
                }
            }

        }

        // ── Saved alarms ────────────────────────────────────────────────────
        ListView {
            id: alarmList

            width: parent.width
            height: Math.min(contentHeight, 180)
            visible: AlarmService.alarms.length > 0
            clip: true
            spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            model: AlarmService.alarms

            delegate: Rectangle {
                id: row

                required property var modelData

                width: alarmList.width
                height: 48
                radius: Theme.cornerRadiusSmall
                color: rowHover.hovered ? Theme.hover : root.editingId === modelData.id ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16) : Theme.surface
                border.width: root.editingId === modelData.id ? 1 : 0
                border.color: Theme.accent

                Row {
                    spacing: 12

                    anchors {
                        left: parent.left
                        leftMargin: 14
                        right: deleteButton.left
                        rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }

                    Toggle {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: row.modelData.enabled
                        onToggled: function(_value) {
                            AlarmService.toggle(row.modelData.id);
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            text: AlarmService.timeFor(row.modelData)
                            color: row.modelData.enabled ? Theme.text : Theme.subtext0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLarge
                            font.bold: true
                        }

                        Text {
                            text: row.modelData.repeat ? "Repeats daily" : "Once"
                            color: Theme.subtext0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }

                    }

                }

                Rectangle {
                    id: deleteButton

                    width: 30
                    height: 30
                    radius: 15
                    color: deleteHover.hovered ? Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b, 0.18) : "transparent"

                    anchors {
                        right: parent.right
                        rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }

                    Icon {
                        anchors.centerIn: parent
                        text: ""
                        color_: deleteHover.hovered ? Theme.red : Theme.subtext0
                        font.pixelSize: 10
                    }

                    HoverHandler {
                        id: deleteHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: AlarmService.remove(row.modelData.id)
                    }

                }

                TapHandler {
                    onTapped: root.edit(row.modelData)
                }

            }

        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: AlarmService.alarms.length === 0
            text: "No alarms yet · set one above"
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }

    }

}
