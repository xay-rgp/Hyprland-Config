// A numeric setting: slider plus its current value. Values snap to `step`
// and `moved` only fires when the snapped value actually changes, so a drag
// doesn't flood the service with identical writes.
import QtQuick
import "../../theme"
import "../../components"

SettingRowBase {
    id: root

    property real   value: 0
    property real   from: 0
    property real   to: 1
    property real   step: 1
    property int    decimals: 0
    property string unit: ""
    // Show 0..1 values as a percentage.
    property bool   percent: false

    signal moved(real value)

    function _snap(v) {
        var s = Math.round((v - root.from) / root.step) * root.step + root.from
        s = Math.max(root.from, Math.min(root.to, s))
        return Number(s.toFixed(Math.max(root.decimals, 2)))
    }

    Row {
        spacing: 12

        Slider {
            anchors.verticalCenter: parent.verticalCenter
            width: 190
            from: root.from
            to: root.to
            value: root.value
            onMoved: function (v) {
                var s = root._snap(v)
                if (s !== root.value) root.moved(s)
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 52
            horizontalAlignment: Text.AlignRight
            text: root.percent ? Math.round(root.value * 100) + "%"
                               : root.value.toFixed(root.decimals) + root.unit
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }
}
