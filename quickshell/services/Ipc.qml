// IPC surface: `qs ipc call theme reload`, etc.
//
// Needed because theme-set.sh replaces the `~/.config/theme/current` symlink
// rather than editing the palette file in place. FileView watches the resolved
// inode, so repointing the symlink fires no change event and the shell would
// never repaint. theme-set.sh calls this after switching, which forces a
// re-read.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"
import "../state"
import "../services"
import "../widgets"

QtObject {
    // Force the palette to be re-read from disk.
    function reloadTheme(): string {
        Colors.reloadTheme()
        return "theme reloaded"
    }

    function closeAllPopups(): string {
        ShellState.closeAll()
        return "closed"
    }

    function togglePopup(name: string): string {
        ShellState.toggle(name)
        return name
    }

    // One-stop "the desktop changed underneath you, catch up" call, used by
    // reload_all_services.sh (SUPER+SHIFT+R). Cheap operations only — it
    // re-reads the palette and re-lists the things services cache from disk.
    function reloadAll(): string {
        Colors.reloadTheme()
        WallpaperService.refresh()
        AppService.load()
        return "reloaded"
    }

    // Handlers live as children so they are instantiated with the singleton.
    property IpcHandler _theme: IpcHandler {
        target: "theme"
        function reload(): string { return reloadTheme() }
        function current(): string { return Colors.mode }
    }

    property IpcHandler _reload: IpcHandler {
        target: "reload"
        function all(): string { return reloadAll() }
    }



    property IpcHandler _popups: IpcHandler {
        target: "popups"
        function closeAll(): string { return closeAllPopups() }
        function toggle(name: string): string { return togglePopup(name) }
    }

    // The center island: open a widget straight from a keybind, e.g.
    // `qs ipc call island toggle launcher`. Ids come from widgets/Registry.qml;
    // "home" is the grid of all of them.
    property IpcHandler _island: IpcHandler {
        target: "island"
        function open(widget: string): string {
            if (!Registry.find(widget)) return "unknown widget: " + widget
            ShellState.openWidget(widget, false)
            return widget
        }
        function toggle(widget: string): string {
            if (!Registry.find(widget)) return "unknown widget: " + widget
            ShellState.toggleWidget(widget)
            return widget
        }
        function close(): string { ShellState.closeAll(); return "closed" }
        // Open Settings on a tab: hyprland, monitors, kitty.

        // Open Agents on a tab: claude, opencode, bifrost.

        function list(): string {
            return Registry.widgets.map(function (w) { return w.id }).join("\n")
        }
    }



    // Theme list + switching, so scripts stop needing a rofi dmenu.
    property IpcHandler _themes: IpcHandler {
        target: "themes"
        function count(): string { return String(ThemeService.themes.length) }
        function current(): string { return ThemeService.current }
        function list(): string {
            return ThemeService.themes.map(function (t) { return t.name }).join("\n")
        }
        function set(name: string): string { ThemeService.apply(name); return name }
        function refresh(): string { ThemeService.refresh(); return "loading" }
    }



    // Settings + pomodoro, for scripting and diagnostics.
    property IpcHandler _settings: IpcHandler {
        target: "settings"
        function get(): string { return JSON.stringify(SettingsService.snapshot()) }
        function set(key: string, value: string): string {
            var v = value
            if (value === "true") v = true
            else if (value === "false") v = false
            else if (!isNaN(Number(value))) v = Number(value)
            SettingsService[key] = v
            SettingsService.commit()
            return key + "=" + v
        }
        function reset(): string { SettingsService.reset(); return "reset" }
        // "all" or one output name to leave on.
        function monitors(mode: string): string { SettingsService.setMonitorMode(mode); return mode }
        function workspace(ws: string, output: string): string {
            SettingsService.setWorkspaceMonitor(ws, output)
            return ws + " -> " + output
        }
    }





    // Wallpaper control (diagnostics + scripting).
    property IpcHandler _wallpaper: IpcHandler {
        target: "wallpaper"
        function count(): string { return String(WallpaperService.images.length) }
        function current(): string { return WallpaperService.current }
        function set(path: string): string { WallpaperService.apply(path); return path }
        function first(): string {
            return WallpaperService.images.length > 0 ? WallpaperService.images[0].path : "(none)"
        }
        function reload(): string { WallpaperService.refresh(); return "loading" }
        function transition(t: string): string { WallpaperService.transition = t; return t }
    }

    // App index introspection (diagnostics).
    property IpcHandler _apps: IpcHandler {
        target: "apps"
        function count(): string { return String(AppService.apps.length) }
        function loaded(): string { return AppService.loaded ? "yes" : "no" }
        function first(): string {
            return AppService.apps.length > 0 ? AppService.apps[0].name : "(none)"
        }
        function reload(): string { AppService.load(); return "loading" }
    }




}
