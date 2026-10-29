// Battery via UPower. Mirrors what waybar's battery module showed.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../theme"

QtObject {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool available: !!device && device.isPresent
    readonly property bool onBattery: UPower.onBattery

    readonly property real percentage: device && device.percentage !== undefined
                                       ? device.percentage : 0
    readonly property int percent: Math.round(percentage * 100)

    readonly property bool charging:
        device ? device.state === UPowerDeviceState.Charging ||
                 device.state === UPowerDeviceState.FullyCharged
               : false

    readonly property bool isLaptopBattery: device ? device.isLaptopBattery : false

    // Show the battery only where one exists — this is a desktop with a
    // possible UPS, so the module hides rather than showing 0%.
    readonly property bool visible: available && device && device.isLaptopBattery

    readonly property string glyph: {
        if (charging) return "\uf0e7"        // bolt
        if (percent >= 90) return "\uf240"
        if (percent >= 65) return "\uf241"
        if (percent >= 40) return "\uf242"
        if (percent >= 15) return "\uf243"
        return "\uf244"
    }

    readonly property color color: {
        if (charging) return Theme.success
        if (percent <= 10) return Theme.urgent
        if (percent <= 25) return Theme.warning
        return Theme.text
    }

    // Time to empty/full, formatted like waybar's tooltip.
    readonly property string timeText: {
        if (!device) return ""
        var secs = charging ? device.timeToFull : device.timeToEmpty
        if (!secs || secs <= 0) return ""
        var h = Math.floor(secs / 3600)
        var m = Math.floor((secs % 3600) / 60)
        return (h > 0 ? h + "h " : "") + m + "m"
    }
}
