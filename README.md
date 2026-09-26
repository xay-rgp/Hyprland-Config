Hyprland Config

A personal Hyprland desktop setup for Arch Linux, built around a clean and minimal workflow with Quickshell as the status bar instead of Waybar.

This repository contains the Hyprland configuration, wallpaper, terminal and launcher styling, Fastfetch configuration, Quickshell setup, and an installation script that installs the required software and deploys everything automatically.

Warning: This setup is designed for a fresh or disposable Hyprland configuration. The installer removes ~/.config/hypr before deploying the repository configuration. Back up your existing configuration before running it.

Features

Hyprland — Wayland compositor

Quickshell — Custom desktop shell and status bar

Hyprpaper — Wallpaper management

Kitty — Terminal emulator

Wofi — Application launcher

Mission Center — System monitor

LibreWolf — Privacy-focused web browser

Discord

Steam

Fastfetch — System information

Pavucontrol — Audio control

Nautilus — File manager

yay — AUR helper

Flatpak + Flathub

Repository Structure

Most configuration files are intentionally kept flat alongside the installation script.

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

The installer must be run as a normal user. Do not run the installer directly as root.

Installation

Clone the repository:

git clone <YOUR-REPOSITORY-URL>
cd <YOUR-REPOSITORY-DIRECTORY>


Make the installer executable:

chmod +x setup-hyprland.sh


Run the installer:

./setup-hyprland.sh


The script will request your sudo password when elevated privileges are required.

Steam and Vulkan

Most packages are installed automatically with --noconfirm.

Steam is intentionally installed separately and interactively so you can select the appropriate Vulkan and 32-bit Vulkan packages for your GPU.

Depending on your hardware, you may need packages such as:

NVIDIA

lib32-nvidia-utils


AMD

lib32-vulkan-radeon


Intel

lib32-vulkan-intel


Make sure the Vulkan packages you install match your graphics hardware and existing driver setup.

What the Installer Does
1. Enables Multilib

The installer enables the Arch Linux multilib repository if it is not already enabled.

Before modifying /etc/pacman.conf, the script creates a backup:

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

Steam is installed separately and interactively so the appropriate Vulkan provider can be selected for your hardware.

4. Installs yay

If yay is not already installed, the installer builds it from the Arch User Repository.

yay is included for convenience and future AUR package management.

5. Configures Flatpak

The installer adds Flathub as a Flatpak repository and installs Mission Center:

io.missioncenter.MissionCenter

6. Deploys the Configuration

The configuration files are copied into their appropriate locations under:

~/.config/


The entire quickshell/ directory is copied as well.

7. Configures Kitty

The installer adds a Hyprland window rule preventing Kitty from requesting a maximized window, provided that the rule is not already present.

8. Enables Fastfetch

The installer adds:

fastfetch


to:

~/.bashrc


This causes Fastfetch to run whenever a new Bash shell starts.

⚠️ Configuration Warning

The installer removes the existing:

~/.config/hypr


directory before deploying the repository configuration.

This is intentional and ensures that old Hyprland configuration files do not interfere with this setup.

If you already have a custom Hyprland configuration, back it up before running the installer.

For example:

cp -r ~/.config/hypr ~/.config/hypr.backup


You can restore it later with:

rm -rf ~/.config/hypr
mv ~/.config/hypr.backup ~/.config/hypr

After Installation

After the installer finishes, completely log out of your current graphical session and start Hyprland again.

A reboot also works:

reboot


A simple:

hyprctl reload


is not intended to replace a fresh Hyprland session after the initial installation.

Customization

The main configuration files can be modified directly in the repository.

Hyprland
hyprland.lua


Controls the compositor configuration, keybinds, window rules, startup applications, monitors, and other Hyprland settings.

Quickshell
quickshell/


Contains the custom Quickshell configuration used for the desktop shell and status bar.

Wallpaper

Replace:

mywallpaper.png


with your own wallpaper and update hyprpaper.conf if necessary.

Kitty
kitty.conf


Contains the Kitty terminal configuration.

Wofi
wofi-style.css


Controls the appearance of the Wofi application launcher.

Fastfetch
fastfetch.jsonc


Controls the information displayed by Fastfetch when Bash starts.

Reinstalling or Updating

If you make changes to the repository configuration, you can rerun:

./setup-hyprland.sh


Warning: The installer clears ~/.config/hypr each time it runs.

If you only want to update individual configuration files, copy them manually instead of rerunning the entire installer.

For example:

cp hyprland.lua ~/.config/hypr/

Troubleshooting
Hyprland is not using the repository configuration

Check that the configuration was deployed:

ls -la ~/.config/hypr/


You should see:

hyprland.lua
hyprpaper.conf
mywallpaper.png


If the directory contains unexpected or old configuration files, remove them and redeploy the repository configuration.

Quickshell is not starting

Check that the configuration was copied:

ls -la ~/.config/quickshell/


You can also launch Quickshell manually to check for configuration or runtime errors.

Steam has graphics or Vulkan issues

Verify that the appropriate Vulkan and 32-bit Vulkan packages for your GPU are installed.

For Steam, the relevant lib32-* driver packages are particularly important.

Fastfetch does not appear

Make sure you are using Bash and check whether Fastfetch was added to .bashrc:

grep -n "fastfetch" ~/.bashrc


Then start a new Bash shell:

bash

Disclaimer

This repository contains a personal Arch Linux and Hyprland configuration.

Hardware, GPU drivers, monitor layouts, package availability, and system configuration vary between machines. Review setup-hyprland.sh before running it, especially if you already have an existing Hyprland setup.

The configuration is provided as-is and may require modifications for your hardware or personal setup.

Credits

This setup is built around the following projects:

Hyprland

Quickshell

Hyprpaper

Kitty

Wofi

Fastfetch

Mission Center

Arch Linux

yay

If you use this configuration as a starting point, feel free to fork it, modify it, and make it your own.
