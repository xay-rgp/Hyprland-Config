-- Hyprland Lua config — ported from hyprland.conf
-- Copy this to ~/.config/hypr/hyprland.lua
--
-- IMPORTANT: as of Hyprland 0.55+, if this file exists it is loaded
-- INSTEAD of hyprland.conf. Delete/rename hyprland.conf once this is
-- working so there's only one source of truth.
--
-- Where I was not 100% certain of the "sugared" Lua dispatcher function
-- (movewindow direction, togglegroup, fullscreen, resize), I called the
-- dispatcher directly via hl.dsp.exec_cmd("hyprctl dispatch ...") instead
-- of guessing at unconfirmed syntax. Dispatcher names themselves are
-- unchanged by the Lua migration, so this is a safe, always-works
-- fallback. Marked with "-- raw dispatch" comments below.

------------------
---- MONITORS ----
------------------
-- DP-2: Lenovo G25-10 — max mode is 1920x1080@144Hz — positioned LEFT
hl.monitor({
    output   = "DP-2",
    mode     = "1920x1080@144",
    position = "0x0",
    scale    = 1,
})

-- DP-1: Acer XV272U V3 — max mode is 2560x1440@180Hz — positioned RIGHT
hl.monitor({
    output   = "DP-1",
    mode     = "2560x1440@180",
    position = "1920x0",
    scale    = 1,
})

---------------------
---- MY PROGRAMS ----
---------------------
local terminal    = "kitty"
local fileManager = "nautilus"
local menu        = "wofi --show drun"

-------------------
---- AUTOSTART ----
-------------------
hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("qs") -- quickshell (replaces waybar); use "quickshell" or
                       -- "qs -c ~/.config/quickshell" if your setup needs it
end)

-----------------------
---- LOOK AND FEEL ----
-----------------------
hl.config({
    general = {
        gaps_in = 6,
        gaps_out = 12,
        border_size = 0,
        layout = "dwindle",
    },
    decoration = {
        rounding = 10,
    },
})

---------------------
---- KEYBINDINGS ----
---------------------
local mainMod = "SUPER"

-- Basics
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("wofi --show drun"))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + W", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))

-- Drag/resize floating windows with mod + mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("hyprctl dispatch exit")) -- raw dispatch

-- Moving focus around (vim keys + arrows)
hl.bind(mainMod .. " + h", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + j", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + k", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + l", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))

-- Move the focused window (raw dispatch — direction-based movewindow
-- isn't shown in the official Lua example, only workspace-based move is)
hl.bind(mainMod .. " + SHIFT + h", hl.dsp.exec_cmd("hyprctl dispatch movewindow l"))
hl.bind(mainMod .. " + SHIFT + j", hl.dsp.exec_cmd("hyprctl dispatch movewindow d"))
hl.bind(mainMod .. " + SHIFT + k", hl.dsp.exec_cmd("hyprctl dispatch movewindow u"))
hl.bind(mainMod .. " + SHIFT + l", hl.dsp.exec_cmd("hyprctl dispatch movewindow r"))
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.exec_cmd("hyprctl dispatch movewindow l"))
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.exec_cmd("hyprctl dispatch movewindow d"))
hl.bind(mainMod .. " + SHIFT + up", hl.dsp.exec_cmd("hyprctl dispatch movewindow u"))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.exec_cmd("hyprctl dispatch movewindow r"))

-- Workspaces: mainMod + [0-9] switches, mainMod + SHIFT + [0-9] moves window
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Layout
hl.bind(mainMod .. " + B", hl.dsp.layout("togglesplit")) -- dwindle only
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("hyprctl dispatch togglegroup")) -- raw dispatch
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd("hyprctl dispatch fullscreen")) -- raw dispatch
hl.bind(mainMod .. " + SPACE", hl.dsp.window.float({ action = "toggle" }))

-- Scratchpad (Hyprland's "special workspace")
hl.bind(mainMod .. " + SHIFT + minus", hl.dsp.window.move({ workspace = "special:scratchpad" }))
hl.bind(mainMod .. " + minus", hl.dsp.workspace.toggle_special("scratchpad"))

-- Resize (replaces the old submap — held-key continuous resize instead;
-- Lua submap syntax isn't in the official example, so this avoids
-- guessing at unconfirmed syntax)
hl.bind(mainMod .. " + CTRL + h", hl.dsp.exec_cmd("hyprctl dispatch resizeactive -10 0"), { repeating = true })
hl.bind(mainMod .. " + CTRL + j", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 10"), { repeating = true })
hl.bind(mainMod .. " + CTRL + k", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 -10"), { repeating = true })
hl.bind(mainMod .. " + CTRL + l", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 10 0"), { repeating = true })

-- Utilities — media/volume/brightness (work even when locked)
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ -5%"), { locked = true, repeating = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ +5%"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("pactl set-source-mute @DEFAULT_SOURCE@ toggle"), { locked = true })

hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl stop"), { locked = true })

hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })

hl.bind("Print", hl.dsp.exec_cmd("grim"))
