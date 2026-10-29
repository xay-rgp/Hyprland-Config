# Hyprland Config

A personal Hyprland desktop setup for Arch Linux, built around a clean and minimal workflow with Quickshell as the status bar instead of Waybar.

This repository contains the Hyprland configuration, wallpaper, terminal and launcher styling, Fastfetch configuration, Quickshell setup, and an installation script that installs the required software.

> Warning: This setup is designed for a fresh or disposable Hyprland configuration. The installer removes `~/.config/hypr` before deploying the repository configuration. Back up your existing configuration before running it.

## Features

- Hyprland — Wayland compositor
- Quickshell — Custom desktop shell and status bar
- Hyprpaper — Wallpaper management
- Kitty — Terminal emulator
- Wofi — Application launcher
- Mission Center — System monitor
- LibreWolf — Privacy-focused web browser
- Discord
- Steam
- Fastfetch — System information
- Pavucontrol — Audio control
- Nautilus — File manager
- yay — AUR helper
- Flatpak + Flathub

## Repository Structure

Most configuration files are intentionally kept flat alongside the installation script.

```text
.
├── setup-hyprland.sh
├── hyprland.lua
├── hyprpaper.conf
├── mywallpaper.png
├── wofi-style.css
├── kitty.conf
├── fastfetch.jsonc
└── quickshell/
    └── ...
```

After installation, the files are deployed to:

```text
~/.config/
├── hypr/
│   ├── hyprland.lua
│   ├── hyprpaper.conf
│   └── mywallpaper.png
├── wofi/
│   └── style.css
├── kitty/
│   └── kitty.conf
├── fastfetch/
│   └── config.jsonc
└── quickshell/
    └── ...
```

## Requirements

This setup is intended for:

- Arch Linux
- A working sudo configuration
- An internet connection
- A Wayland-capable GPU

The installer must be run as a normal user. Do not run the installer directly as root.

## Installation

Clone the repository:

```bash
git clone <YOUR-REPOSITORY-URL>
cd <YOUR-REPOSITORY-DIRECTORY>
```

Make the installer executable:

```bash
chmod +x setup-hyprland.sh
```

Run the installer:

```bash
./setup-hyprland.sh
```

The script will request your sudo password when elevated privileges are required.

## Steam and Vulkan

Most packages are installed automatically with `--noconfirm`.

Steam is intentionally installed separately and interactively so you can select the appropriate Vulkan and 32-bit Vulkan packages for your GPU.

Depending on your hardware, you may need packages such as:

- NVIDIA:
  - `lib32-nvidia-utils`
- AMD:
  - `lib32-vulkan-radeon`
- Intel:
  - `lib32-vulkan-intel`

Make sure the Vulkan packages you install match your graphics hardware and existing driver setup.

## What the Installer Does

1. Enables Multilib

   The installer enables the Arch Linux multilib repository if it is not already enabled.

   Before modifying `/etc/pacman.conf`, the script creates a backup:

   ```text
   /etc/pacman.conf.bak
   ```

   It then synchronizes the system:

   ```bash
   sudo pacman -Syu
   ```

2. Installs Required Packages

   The installer installs the required packages from the official Arch repositories, including:

   - `hyprland`
   - `hyprpaper`
   - `discord`
   - `flatpak`
   - `librewolf`
   - `wofi`
   - `kitty`
   - `nautilus`
   - `fastfetch`
   - `base-devel`
   - `git`
   - `go`
   - `ttf-hack-nerd`
   - `quickshell`
   - `pavucontrol`

3. Installs Steam

   Steam is installed separately and interactively so the appropriate Vulkan provider can be selected for your hardware.

4. Installs yay

   If yay is not already installed, the installer builds it from the Arch User Repository.

   `yay` is included for convenience and future AUR package management.

5. Configures Flatpak

   The installer adds Flathub as a Flatpak repository and installs Mission Center:

   ```text
   io.missioncenter.MissionCenter
   ```

6. Deploys the Configuration

   The configuration files are copied into their appropriate locations under:

   ```text
   ~/.config/
   ```

   The entire `quickshell/` directory is copied as well.

7. Configures Kitty

   The installer adds a Hyprland window rule preventing Kitty from requesting a maximized window, provided that the rule is not already present.

8. Enables Fastfetch

   The installer adds:

   ```bash
   fastfetch
   ```

   to:

   ```text
   ~/.config/fish/config.fish
   ```

   This causes Fastfetch to run whenever a new interactive Fish shell starts.

## ⚠️ Configuration Warning

The installer removes the existing:

```text
~/.config/hypr
```

directory before deploying the repository configuration.

This is intentional and ensures that old Hyprland configuration files do not interfere with this setup.

If you already have a custom Hyprland configuration, back it up before running the installer.

For example:

```bash
cp -r ~/.config/hypr ~/.config/hypr.backup
```

You can restore it later with:

```bash
rm -rf ~/.config/hypr
mv ~/.config/hypr.backup ~/.config/hypr
```

## After Installation

After the installer finishes, completely log out of your current graphical session and start Hyprland again.

A reboot also works:

```bash
reboot
```

A simple:

```bash
hyprctl reload
```

is not intended to replace a fresh Hyprland session after the initial installation.

## Customization

The main configuration files can be modified directly in the repository.

### Hyprland

```text
hyprland.lua
```

Controls the compositor configuration, keybinds, window rules, startup applications, monitors, and other Hyprland settings.

### Quickshell

```text
quickshell/
```

### Integrated Quickshell bar

The included bar is the compact monochrome version: 28 px tall, content-sized
ends with equal padding, a read-only track/artist display on the left, and a
12-hour clock in the middle. Hover the clock for CPU/GPU/RAM usage; click it
for local machine and disk stats. The right menu contains network, audio and
Bluetooth controls. Spotify-specific controls, VPN, notifications, Lights,
Night Light and a brightness slider are not included. There is no screenshot
keybinding or screenshot helper.

Colors live in [`quickshell/theme/monochrome.json`](quickshell/theme/monochrome.json).
The bar requires no separate `~/quickshell-bar` checkout. Hyprland launches
`~/.config/quickshell/run.sh -d`; the launcher prevents duplicate instances.
To restart it manually:

```bash
~/.config/quickshell/run.sh --restart -d
```

The setup script reads [`quickshell/packages.txt`](quickshell/packages.txt) for
bar and keyboard-shortcut dependencies: Quickshell, Hack Nerd Font,
NetworkManager, BlueZ, PipeWire/PipeWire-Pulse, WirePlumber, libpulse, jq,
Python, util-linux, udisks2, iproute2, gawk, grep, coreutils, procps-ng,
playerctl and brightnessctl. Qt modules are installed through Quickshell's
package dependencies. GPU drivers are unchanged. Brightnessctl is for the
existing hardware keys, not a bar slider.

The installer enables NetworkManager and Bluetooth for subsequent boots,
without restarting networking in the current session. If another network
manager is enabled, resolve that conflict before rebooting. Existing
Quickshell files are deleted and replaced directly, without backups. Other
installer behavior remains the same, including replacing `~/.config/hypr`.

The bar is adapted from [SaratAngajalaoffl/dotfiles-quickshell](https://github.com/SaratAngajalaoffl/dotfiles-quickshell/tree/1afda74e30d8d9bdb5c19f4dcd583e144d435f1b).
See [`quickshell/README.md`](quickshell/README.md) for details.


### Wallpaper

Replace:

```text
mywallpaper.png
```

with your own wallpaper and update `hyprpaper.conf` if necessary.

### Kitty

```text
kitty.conf
```

Contains the Kitty terminal configuration.

### Wofi

```text
wofi-style.css
```

Controls the appearance of the Wofi application launcher.

### Fastfetch

```text
fastfetch.jsonc
```

Controls the information displayed by Fastfetch when Fish starts.

## Reinstalling or Updating

If you make changes to the repository configuration, you can rerun:

```bash
./setup-hyprland.sh
```

> Warning: The installer clears `~/.config/hypr` each time it runs.

If you only want to update individual configuration files, copy them manually instead of rerunning the entire installer.

For example:

```bash
cp hyprland.lua ~/.config/hypr/
```

## Troubleshooting

### Hyprland is not using the repository configuration

Check that the configuration was deployed:

```bash
ls -la ~/.config/hypr/
```

You should see:

```text
hyprland.lua
hyprpaper.conf
mywallpaper.png
```

If the directory contains unexpected or old configuration files, remove them and redeploy the repository configuration.

### Quickshell is not starting

Check that the configuration was copied:

```bash
ls -la ~/.config/quickshell/
```

You can also launch Quickshell manually to check for configuration or runtime errors.

### Steam has graphics or Vulkan issues

Verify that the appropriate Vulkan and 32-bit Vulkan packages for your GPU are installed.

For Steam, the relevant `lib32-*` driver packages are particularly important.

### Fastfetch does not appear

Make sure you are using Fish and check whether Fastfetch was added to `~/.config/fish/config.fish`:

```bash
grep -n "fastfetch" ~/.config/fish/config.fish
```

Then start a new Fish shell:

```bash
fish
```

## Disclaimer

This repository contains a personal Arch Linux and Hyprland configuration.

Hardware, GPU drivers, monitor layouts, package availability, and system configuration vary between machines. Review `setup-hyprland.sh` before running it, especially if you already have an existing Hyprland configuration.

The configuration is provided as-is and may require modifications for your hardware or personal setup.

## Credits

This setup is built around the following projects:

- Hyprland
- Quickshell
- Hyprpaper
- Kitty
- Wofi
- Fastfetch
- Mission Center
- Arch Linux
- yay

If you use this configuration as a starting point, feel free to fork it, modify it, and make it your own.
