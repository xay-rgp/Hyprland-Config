Hyprland Config

A personal Hyprland desktop setup for Arch Linux, built around a clean, minimal workflow with Quickshell as the status bar instead of Waybar.

The repository includes the Hyprland configuration, wallpaper, terminal, launcher styling, Fastfetch configuration, and a setup script that installs the required software and deploys everything automatically.

Features

Hyprland — Wayland compositor

Quickshell — custom status bar / shell

Hyprpaper — wallpaper management

Kitty — terminal emulator

Wofi — application launcher

Mission Center — system monitor

LibreWolf — privacy-focused browser

Discord

Steam

Fastfetch — system information

Pavucontrol — audio control

Nautilus — file manager

yay — AUR helper

Flatpak + Flathub

Repository Structure

The repository intentionally keeps most configuration files flat next to the installation script.

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


After installation, the files are deployed to:

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

Requirements

This setup is intended for:

Arch Linux

A working sudo configuration

An internet connection

A Wayland-capable GPU

The installer expects to be run as a normal user, not directly as root.

Installation

Clone the repository:

git clone <YOUR-REPOSITORY-URL>
cd <YOUR-REPOSITORY-DIRECTORY>


Make the installer executable:

chmod +x setup-hyprland.sh


Run it:

./setup-hyprland.sh


The script will request your sudo password when necessary.

Steam / Vulkan

Most packages are installed automatically with --noconfirm.

Steam is intentionally different.

The Steam installation remains interactive so you can select the appropriate Vulkan/lib32 provider for your GPU.

Depending on your hardware, you may need packages such as:

NVIDIA:
lib32-nvidia-utils

AMD:
lib32-vulkan-radeon

Intel:
lib32-vulkan-intel


Make sure the Vulkan packages you install match your graphics hardware and driver setup.

What the Installer Does

The setup script performs the following steps.

1. Enables multilib

The script enables the Arch Linux multilib repository if it isn't already enabled.

A backup of /etc/pacman.conf is created before modifying it:

/etc/pacman.conf.bak


It then synchronizes the system:

sudo pacman -Syu

2. Installs Required Packages

The installer installs the required packages from the official Arch repositories, including:

hyprland
hyprpaper
discord
flatpak
librewolf
wofi
kitty
nautilus
fastfetch
base-devel
git
go
ttf-hack-nerd
quickshell
pavucontrol

3. Installs Steam

Steam is installed separately and interactively to allow the appropriate Vulkan provider to be selected.

4. Installs yay

If yay isn't already installed, the script builds it from the Arch User Repository.

yay is included for convenience and future package management.

5. Configures Flatpak

Flathub is added as a Flatpak repository and Mission Center is installed:

io.missioncenter.MissionCenter

6. Deploys the Dotfiles

Configuration files are copied into their appropriate locations under:

~/.config/


The Quickshell directory is copied as a complete directory.

7. Configures Kitty

The installer adds a Hyprland window rule preventing Kitty from requesting a maximized window if the rule isn't already present.

8. Enables Fastfetch

The installer adds:

fastfetch


to ~/.bashrc so Fastfetch runs when Bash starts.

Configuration Warning

The installer removes the existing ~/.config/hypr directory before deploying the repository configuration.

This is intentional so that old Hyprland configuration files don't interfere with the setup.

If you already have a custom Hyprland configuration, back it up before running the installer.

For example:

cp -r ~/.config/hypr ~/.config/hypr.backup

After Installation

Once the script finishes, completely log out of your current graphical session and start Hyprland again.

A reboot also works:

reboot


A simple:

hyprctl reload


is not intended to replace a fresh Hyprland session after the initial installation.

Customization

The main configuration files are easy to modify directly in the repository.

Hyprland
hyprland.lua


Controls the compositor configuration, keybinds, window rules, startup applications, monitors, and other Hyprland settings.

Quickshell
quickshell/


Contains the custom Quickshell configuration used for the desktop shell/status bar.

Wallpaper

Replace:

mywallpaper.png


with your own wallpaper and update hyprpaper.conf if necessary.

Kitty
kitty.conf


Contains terminal configuration.

Wofi
wofi-style.css


Controls the appearance of the Wofi launcher.

Fastfetch
fastfetch.jsonc


Controls the Fastfetch display shown when Bash starts.

Reinstalling / Updating

If you make changes to the repository configuration, you can rerun:

./setup-hyprland.sh


Be aware: the installer clears ~/.config/hypr each time it runs.

If you only want to update individual configuration files, you can copy them manually instead of rerunning the complete installer.

Troubleshooting
Hyprland isn't using the repository configuration

Check that the deployed file exists:

ls -la ~/.config/hypr/


You should see:

hyprland.lua
hyprpaper.conf
mywallpaper.png


Also make sure an old configuration wasn't left behind.

Quickshell isn't starting

Check that the configuration was copied:

ls -la ~/.config/quickshell/


You can also launch Quickshell manually to check for configuration errors.

Steam has graphics/Vulkan issues

Verify that the appropriate Vulkan and 32-bit Vulkan packages for your GPU are installed.

For Steam, the relevant lib32-* driver packages are particularly important.

Fastfetch doesn't appear

Make sure you're using Bash and check:

grep -n "fastfetch" ~/.bashrc


Then start a new shell.

Disclaimer

This repository contains a personal Arch Linux / Hyprland configuration.

Hardware, GPU drivers, monitor layouts, package availability, and system configuration can vary between machines. Review the installer before running it, especially if you already have an existing Hyprland setup.

The configuration is provided as-is and may require adjustments for your hardware.

Credits

Built around the following projects:

Hyprland

Quickshell

Hyprpaper

Kitty

Wofi

Fastfetch

Mission Center

Arch Linux

yay

If you use this configuration as a starting point, feel free to fork it and make it your own.
