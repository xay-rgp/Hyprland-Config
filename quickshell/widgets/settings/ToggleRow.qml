// An on/off setting.
import QtQuick
import "../../components"

SettingRowBase {
    id: root

    property bool checked: false

    signal toggled(bool value)

    Toggle {
        checked: root.checked
        onToggled: function (v) { root.toggled(v) }
    }
}
