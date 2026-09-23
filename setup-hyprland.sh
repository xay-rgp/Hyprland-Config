#!/usr/bin/env bash
#
# Arch Linux setup script for Hyprland-Config dotfiles
#
# Bar: uses quickshell (not waybar) for the status bar.
#
# Expects to be run from the root of the repo, with ALL dotfiles sitting
# flat next to this script (no subfolders), EXCEPT the quickshell config,
# which lives in its own subfolder:
#   ./hyprland.lua
#   ./hyprpaper.conf
#   ./mywallpaper.png
#   ./wofi-style.css
#   ./kitty.conf
#   ./fastfetch.jsonc
#   ./quickshell/            <- whole folder gets copied to ~/.config/quickshell
#
# Uses hyprland.lua (not hyprland.conf) — as of Hyprland 0.55+, .conf is
# being phased out in favor of Lua config. This script wipes ~/.config/hypr
# clean before deploying so there's no leftover default file (Hyprland
# auto-generates hyprland.lua on first boot if nothing exists, and that
# default silently takes priority over anything you drop in later unless
# it's removed first).
#
# Usage:
#   chmod +x setup-hyprland.sh
#   ./setup-hyprland.sh
#
# NOTE: Everything runs with --noconfirm EXCEPT the `steam` install itself,
# which is left interactive so you can pick the correct vulkan driver
# provider (nvidia/amd/intel) when pacman prompts for it.
#
# yay is installed as an AUR helper for your own future use, even though
# nothing in this script currently needs the AUR.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()  { echo -e "\e[1;32m[+]\e[0m $*"; }
warn() { echo -e "\e[1;33m[!]\e[0m $*"; }
err()  { echo -e "\e[1;31m[-]\e[0m $*" >&2; }

if [[ $EUID -eq 0 ]]; then
    err "Don't run this script as root directly — run it as your normal user."
    err "It will call sudo itself whenever it needs elevated privileges."
    exit 1
fi

# Keep sudo alive for the whole script
sudo -v
( while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done ) &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT

### ---------------------------------------------------------------------
### 1. Enable multilib
### ---------------------------------------------------------------------
log "Enabling multilib repository..."
if grep -q "^\[multilib\]" /etc/pacman.conf; then
    log "multilib already enabled, skipping."
else
    sudo cp /etc/pacman.conf /etc/pacman.conf.bak
    sudo sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf
fi

log "Syncing package databases..."
sudo pacman -Syu --noconfirm

### ---------------------------------------------------------------------
### 2. Install official repo packages (noconfirm) - everything except steam
### ---------------------------------------------------------------------
PACMAN_PACKAGES=(
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
)

log "Installing pacman packages: ${PACMAN_PACKAGES[*]}"
sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"

### ---------------------------------------------------------------------
### 3. Install steam interactively so the vulkan driver provider prompt
###    stays selectable
### ---------------------------------------------------------------------
log "Installing steam (interactive — pick the correct vulkan driver / lib32 provider when prompted)..."
sudo pacman -S --needed steam

### ---------------------------------------------------------------------
### 4. Install yay (AUR helper)
### ---------------------------------------------------------------------
if ! command -v yay >/dev/null 2>&1; then
    log "Installing yay AUR helper..."
    BUILD_DIR="$(mktemp -d)"
    git clone --depth 1 https://aur.archlinux.org/yay.git "$BUILD_DIR/yay"
    (cd "$BUILD_DIR/yay" && makepkg -si --noconfirm)
    rm -rf "$BUILD_DIR"
else
    log "yay already installed, skipping."
fi

### ---------------------------------------------------------------------
### 5. Flatpak + Mission Center
### ---------------------------------------------------------------------
log "Setting up flathub remote..."
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

log "Installing Mission Center from Flathub..."
sudo flatpak install -y flathub io.missioncenter.MissionCenter

### ---------------------------------------------------------------------
### 6. Deploy dotfiles (flat repo -> proper ~/.config/ subfolders)
### ---------------------------------------------------------------------
log "Deploying config files..."

# Wipe ~/.config/hypr clean first. This is the important part: Hyprland
# auto-generates a default hyprland.lua (and sometimes hyprland.conf) on
# first boot, and that default silently wins over anything dropped in
# later unless it's removed. Starting clean guarantees only OUR config
# is present.
if [[ -d "$HOME/.config/hypr" ]]; then
    log "Clearing existing ~/.config/hypr contents..."
    rm -rf "$HOME/.config/hypr"
fi

mkdir -p "$HOME/.config/hypr" \
         "$HOME/.config/wofi" \
         "$HOME/.config/kitty" \
         "$HOME/.config/fastfetch"

copy_config() {
    local src="$1" dst="$2"
    if [[ -f "$src" ]]; then
        cp -f "$src" "$dst"
        log "  -> $dst"
    else
        err "  Missing source file: $src"
        exit 1
    fi
}

# Same idea as copy_config, but for a whole directory (used for quickshell,
# since its config is a folder of files rather than a single dotfile).
copy_config_dir() {
    local src="$1" dst="$2"
    if [[ -d "$src" ]]; then
        rm -rf "$dst"
        cp -rf "$src" "$dst"
        log "  -> $dst"
    else
        err "  Missing source directory: $src"
        exit 1
    fi
}

copy_config "$SCRIPT_DIR/hyprland.lua"        "$HOME/.config/hypr/hyprland.lua"
copy_config "$SCRIPT_DIR/hyprpaper.conf"      "$HOME/.config/hypr/hyprpaper.conf"
copy_config "$SCRIPT_DIR/mywallpaper.png"     "$HOME/.config/hypr/mywallpaper.png"
copy_config "$SCRIPT_DIR/wofi-style.css"      "$HOME/.config/wofi/style.css"
copy_config "$SCRIPT_DIR/kitty.conf"          "$HOME/.config/kitty/kitty.conf"
copy_config "$SCRIPT_DIR/fastfetch.jsonc"     "$HOME/.config/fastfetch/config.jsonc"
copy_config_dir "$SCRIPT_DIR/quickshell"      "$HOME/.config/quickshell"

### ---------------------------------------------------------------------
### 7. Add fastfetch to .bashrc
### ---------------------------------------------------------------------
log "Adding fastfetch to ~/.bashrc..."
if ! grep -qxF 'fastfetch' "$HOME/.bashrc" 2>/dev/null; then
    echo -e '\n# Run fastfetch on shell start\nfastfetch' >> "$HOME/.bashrc"
    log "  Added."
else
    log "  Already present, skipping."
fi

log "Done! Fully log out and start Hyprland again (or reboot) — hyprland.lua vs .conf priority is only checked once at startup, so 'hyprctl reload' alone will NOT pick this up."
warn "Remember: this script did NOT touch your GPU/vulkan driver packages beyond the steam prompt — install lib32-nvidia-utils / lib32-vulkan-radeon / lib32-vulkan-intel yourself if the prompt didn't cover it."
