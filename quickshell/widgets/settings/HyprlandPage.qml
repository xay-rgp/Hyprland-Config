// Settings → Hyprland: gaps, opacity, blur, animations. Every change goes
// live through SettingsService.commit().
import QtQuick
import "../../services"

Column {
    width: parent ? parent.width : 0
    spacing: 12

    Section {
        title: "Windows"

        Section {
            title: "Gaps"

            SliderRow {
                label: "Inner"
                hint: "Between windows"
                from: 0; to: 30; step: 1; unit: "px"
                value: SettingsService.gapsIn
                onMoved: function (v) { SettingsService.gapsIn = v; SettingsService.commit() }
            }
            SliderRow {
                label: "Outer"
                hint: "Between windows and the screen edge"
                from: 0; to: 60; step: 1; unit: "px"
                value: SettingsService.gapsOut
                onMoved: function (v) { SettingsService.gapsOut = v; SettingsService.commit() }
            }
        }

        Section {
            title: "Opacity"

            SliderRow {
                label: "Focused"
                from: 0.5; to: 1; step: 0.01; percent: true
                value: SettingsService.activeOpacity
                onMoved: function (v) { SettingsService.activeOpacity = v; SettingsService.commit() }
            }
            SliderRow {
                label: "Unfocused"
                from: 0.3; to: 1; step: 0.01; percent: true
                value: SettingsService.inactiveOpacity
                onMoved: function (v) { SettingsService.inactiveOpacity = v; SettingsService.commit() }
            }
        }
    }

    Section {
        title: "Effects"

        Section {
            title: "Blur"

            ToggleRow {
                label: "Blur behind windows"
                checked: SettingsService.blurEnabled
                onToggled: function (v) { SettingsService.blurEnabled = v; SettingsService.commit() }
            }
            SliderRow {
                label: "Size"
                enabled: SettingsService.blurEnabled
                from: 1; to: 20; step: 1
                value: SettingsService.blurSize
                onMoved: function (v) { SettingsService.blurSize = v; SettingsService.commit() }
            }
            SliderRow {
                label: "Passes"
                hint: "More is smoother, and costs more GPU"
                enabled: SettingsService.blurEnabled
                from: 1; to: 6; step: 1
                value: SettingsService.blurPasses
                onMoved: function (v) { SettingsService.blurPasses = v; SettingsService.commit() }
            }
        }

        Section {
            title: "Animations"

            ToggleRow {
                label: "Animations"
                hint: "Window, workspace and layer animations"
                checked: SettingsService.animationsEnabled
                onToggled: function (v) { SettingsService.animationsEnabled = v; SettingsService.commit() }
            }
        }
    }
}
