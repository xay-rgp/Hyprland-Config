// Settings → Kitty: font size, cursor trail, window margin. Written to
// kitty's user-settings.conf; open kitty windows reload on SIGUSR1.
import QtQuick
import "../../services"

Column {
    width: parent ? parent.width : 0
    spacing: 12

    Section {
        title: "Terminal"
        description: "Applies to every open kitty window."

        Section {
            title: "Text"

            SliderRow {
                label: "Font size"
                from: 8; to: 20; step: 0.5; decimals: 1; unit: "pt"
                value: SettingsService.fontSize
                onMoved: function (v) { SettingsService.fontSize = v; SettingsService.commit() }
            }
        }

        Section {
            title: "Cursor"

            SliderRow {
                label: "Trail"
                hint: SettingsService.cursorTrail === 0 ? "Off" : "Delay before the trail shows"
                from: 0; to: 50; step: 1; unit: "ms"
                value: SettingsService.cursorTrail
                onMoved: function (v) { SettingsService.cursorTrail = v; SettingsService.commit() }
            }
        }

        Section {
            title: "Window"

            SliderRow {
                label: "Margin"
                hint: "Blank space around the terminal"
                from: 0; to: 40; step: 1; unit: "pt"
                value: SettingsService.kittyMargin
                onMoved: function (v) { SettingsService.kittyMargin = v; SettingsService.commit() }
            }
        }
    }
}
