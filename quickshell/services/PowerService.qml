// Session power actions used by the island's power menu.

// Lock and logout use the same direct commands as the Hyprland config:
// hyprlock owns the lock screen, while Hyprland's exit dispatcher ends the
// session (Lua config: the legacy `dispatch exit` form no longer works). Reboot and power off go through loginctl, which applies the desktop
// session policy and can show polkit.
pragma Singleton
import QtQuick
import Quickshell.Io
import "."
import "../state"

QtObject {
    id: root

    property Process _lock

    _lock: Process {
        command: ["hyprlock"]
    }

    property Process _logout

    _logout: Process {
        command: ["hyprctl", "dispatch", "hl.dsp.exit()"]
    }

    property Process _reboot

    _reboot: Process {
        command: ["loginctl", "reboot"]
    }

    property Process _powerOff

    _powerOff: Process {
        command: ["loginctl", "poweroff"]
    }

    function lock() {
        if (!_lock.running)
            _lock.running = true;

    }

    function logout() {
        if (!_logout.running)
            _logout.running = true;

    }

    function reboot() {
        if (!_reboot.running)
            _reboot.running = true;

    }

    function powerOff() {
        if (!_powerOff.running)
            _powerOff.running = true;

    }

}
