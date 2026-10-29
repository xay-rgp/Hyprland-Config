# Compact monochrome Quickshell bar

Installed at `~/.config/quickshell` by the repository's setup script.

- 28 px bar, 3 px screen frame, equal 8 px padding and content-sized ends.
- Left: read-only now-playing track/artist from MPRIS players and browsers.
- Center: 12-hour clock with AM/PM. Hover for CPU/GPU/RAM; click for local
  CPU, RAM, GPU and disk statistics. Escape or click outside closes it.
- Right: network and volume indicators; click for network, audio and Bluetooth
  controls. Scroll the status pill to adjust volume.
- Solid black/white palette in `theme/monochrome.json`.
- No Spotify-specific page, VPN, notifications, Lights, Night Light, brightness
  slider, workspace indicator or other center-menu widgets.

## Launch

```bash
~/.config/quickshell/run.sh
# Restart this bar and detach from the terminal:
~/.config/quickshell/run.sh --restart -d
```

Hyprland starts the launcher automatically. Repeated normal launches use
`--no-duplicate`. The launcher stops only the old `~/quickshell-bar` instance
when migrating, and only this configuration when `--restart` is requested.
It does not stop unrelated Quickshell configurations.

## Dependencies

`packages.txt` is the dependency list used by `setup-hyprland.sh`. Quickshell
provides Qt/MPRIS/PipeWire integrations; NetworkManager (`nmcli`), BlueZ
(`bluetoothctl`), PipeWire/WirePlumber, `pactl`, `jq`, Python's standard library
and `udisksctl` support the current controls and machine statistics. The list
also covers the configured media and brightness keys.
No Spotify client, API credentials, Kubernetes, theme helper or DDC/CI setup
is required for this bar. GPU drivers are not installed or replaced.

The installer enables NetworkManager and Bluetooth for subsequent boots. It
does not restart networking or audio in the current session. Mount/eject
requests may need your session's authentication agent. GPU readings depend
on driver support (AMD sysfs, NVIDIA nvidia-smi when supplied by its driver).
Now-playing titles require the audio application to publish MPRIS metadata.

## Source

Adapted from SaratAngajalaoffl/dotfiles-quickshell at commit
1afda74e30d8d9bdb5c19f4dcd583e144d435f1b:
https://github.com/SaratAngajalaoffl/dotfiles-quickshell/tree/1afda74e30d8d9bdb5c19f4dcd583e144d435f1b
Original comments and attribution remain in the source. Unused upstream
widget files are retained, but the registry exposes only machine stats.
