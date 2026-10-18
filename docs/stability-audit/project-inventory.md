# Full Project Inventory: Quickshell Rice (`end4-pC`)

**Audit Date:** 2026-10-18  
**Auditor:** Antigravity Stability Agent  
**Repository:** `/home/danzzalexandra/.config/quickshell/end4-pC`  
**Git Branch / Commit:** `main` @ `7532506` (synced to remote `maulan`)

---

## 1. Runtime & Environment Inventory

- **Quickshell Version:** `0.2.1` (commit `7511545ee20664e3b8b8d3322c0ffe7567c56f7a`, distributed by AUR `quickshell-git`).
- **Qt Engine Version:** Built against Qt `6.11.2`, running on host Qt `6.12.0` (`/usr/lib`).
- **Compositor:** Hyprland `0.54.x` (Wayland).
- **Secondary WM Support:** Niri (partial fallback logic present in code).
- **Screen Architecture:** Multi-monitor setup:
  - Monitor 1: `HDMI-A-5` (2560x1440 @ 0,0).
  - Monitor 2: `eDP-1` (1920x1080 @ 2240,1440).
- **Core Runtime Entry Point:** `shell.qml` (`ShellRoot`).

---

## 2. Shell Root & Panel Inventory

All panel layers are defined in `panelFamilies/IllogicalImpulseFamily.qml` and conditionally loaded via `PanelLoader.qml` into `shell.qml`:

| Panel Identifier | Component File | Wayland Layer / Type | Visibility / Lifecycle |
|---|---|---|---|
| `Bar` | `modules/ii/bar/Bar.qml` | `WlrLayer.Top` / `PanelWindow` | When `!Config.options.bar.vertical` |
| `VerticalBar` | `modules/ii/verticalBar/VerticalBar.qml` | `WlrLayer.Top` / `PanelWindow` | When `Config.options.bar.vertical` |
| `Background` | `modules/ii/background/Background.qml` | `WlrLayer.Bottom` / `PanelWindow` | Persistent per monitor |
| `FullscreenVideoViewer` | `modules/ii/background/FullscreenVideoViewer.qml` | `WlrLayer.Overlay` | Controlled by `GlobalStates.customVideoFullscreenOpen` |
| `Dock` | `modules/ii/dock/Dock.qml` | `WlrLayer.Top` / `PanelWindow` | When `Config.options.dock.enable` |
| `EqualizerPopup` | `modules/ii/equalizer/EqualizerPopup.qml` | `WlrLayer.Overlay` | Controlled by `GlobalStates.equalizerOpen` |
| `Lock` | `modules/ii/lock/Lock.qml` | `WlrLayer.Overlay` (LockSurface) | Controlled by `GlobalStates.screenLocked` |
| `MediaControls` | `modules/ii/mediaControls/MediaControls.qml` | `WlrLayer.Overlay` | Controlled by `GlobalStates.mediaControlsOpen` |
| `NotificationPopup` | `modules/ii/notificationPopup/NotificationPopup.qml` | `WlrLayer.Overlay` | Triggered by notification events |
| `OnScreenDisplay` | `modules/ii/onScreenDisplay/OnScreenDisplay.qml` | `WlrLayer.Overlay` | OSD for volume/brightness |
| `OnScreenKeyboard` | `modules/ii/onScreenKeyboard/OnScreenKeyboard.qml` | `WlrLayer.Overlay` | Controlled by `GlobalStates.oskOpen` |
| `Overlay` | `modules/ii/overlay/Overlay.qml` | `WlrLayer.Overlay` | Desktop widget overlay (`GlobalStates.overlayOpen`) |
| `Overview` | `modules/ii/overview/Overview.qml` | `WlrLayer.Overlay` | Workspaces, windows, clipboard, emojis |
| `Polkit` | `modules/ii/polkit/Polkit.qml` | `WlrLayer.Overlay` | Polkit authentication dialog |
| `RegionSelector` | `modules/ii/regionSelector/RegionSelector.qml` | `WlrLayer.Overlay` | Snipping tool, OCR, translate, record |
| `ScreenCorners` | `modules/ii/screenCorners/ScreenCorners.qml` | `WlrLayer.Overlay` | Fake rounded screen corner overlays |
| `ScreenTranslator` | `modules/ii/screenTranslator/ScreenTranslator.qml` | `WlrLayer.Overlay` | Translation result window |
| `SessionScreen` | `modules/ii/sessionScreen/SessionScreen.qml` | `WlrLayer.Overlay` | Power menu, lock, sleep, reboot |
| `SidebarLeft` | `modules/ii/sidebarLeft/SidebarLeft.qml` | `WlrLayer.Overlay` | AI chat & tools |
| `SidebarRight` | `modules/ii/sidebarRight/SidebarRight.qml` | `WlrLayer.Overlay` | Toggles, connectivity, productivity tools |
| `WallpaperSelector` | `modules/ii/wallpaperSelector/WallpaperSelector.qml` | `WlrLayer.Overlay` | Wallpaper picker & thumbnail browser |
| `Settings` | `modules/ii/settings/Settings.qml` | `WlrLayer.Overlay` | Configuration dashboard & pages |
| `DesktopMenu` | `modules/ii/desktopMenu/DesktopMenu.qml` | `WlrLayer.Overlay` | Desktop right-click context menu |
| `DropShelfPanel` | `modules/ii/dropover/DropShelfPanel.qml` | `WlrLayer.Overlay` | Temporary drag-and-drop shelf |
| `Cheatsheet` | `modules/ii/cheatsheet/Cheatsheet.qml` | `WlrLayer.Overlay` | Keybinding reference dialog |
| `DisplayProjectionOsd` | `modules/ii/displayProjection/DisplayProjectionOsd.qml` | `WlrLayer.Overlay` | Display layout projection OSD |
| `ScreenFrame` | `modules/ii/frame/ScreenFrame.qml` | `WlrLayer.Top` | Visual window borders & hover frame |
| `Whiteboard` | `modules/ii/whiteboard/Whiteboard.qml` | `WlrLayer.Overlay` | Freehand drawing & shapes canvas |

---

## 3. Services and Data Providers (`services/`)

Total active services: **62 QML singletons** under `services/`:

1. `Ai.qml`: Gemini/AI integration.
2. `AppSearch.qml`: Desktop applications indexer.
3. `Audio.qml`: WirePlumber / PipeWire / PulseAudio integration.
4. `Battery.qml`: UPower and `/sys/class/power_supply` power state.
5. `BluetoothStatus.qml`: BlueZ adapter and device manager.
6. `Brightness.qml`: Brightness control (`brightnessctl`).
7. `Cliphist.qml`: Clipboard manager with image/text history.
8. `ColorSchemes.qml`: Material You color palette switcher.
9. `DateTime.qml`: System time and date formatter.
10. `DesktopWidgets.qml`: Desktop widget state manager.
11. `DisplayProjection.qml`: Multi-monitor layout controller.
12. `GoogleCloud.qml`: Speech-to-text / cloud API.
13. `HyprlandData.qml`: Hyprland IPC events (workspaces, active windows, monitors).
14. `LiveWallpaper.qml`: `mpvpaper` controller and power policies.
15. `LyricsService.qml`: Now-playing synced lyrics provider.
16. `MaterialThemeLoader.qml`: Material You dynamic theming.
17. `MprisController.qml`: MPRIS media player controller.
18. `Network.qml`: NetworkManager connectivity and Wi-Fi scanner.
19. `Notes.qml`: Legacy notes provider.
20. `Notifications.qml`: Freedesktop notification server.
21. `PeripheralBattery.qml`: Connected peripherals battery monitoring.
22. `ResourceUsage.qml`: CPU, RAM, GPU, and IO telemetry.
23. `SettingsPages.qml`: Settings navigation model.
24. `SystemAppearance.qml`: System GTK, Qt, and cursor theming.
25. `SystemInfo.qml`: Host OS and hardware information.
26. `TimerService.qml`: Stopwatches and countdown timers.
27. `Todo.qml`: Persistent task list.
28. `Translation.qml`: Localization provider.
29. `Updates.qml`: Arch/Pacman system updates checker.
30. `Vpn.qml`: VPN connection status.
31. `Wallpapers.qml`: Wallpaper library, order map, and thumbnail loader.
32. `Weather.qml`: Open-Meteo weather service.
33. `WorldClock.qml`: Multi-timezone clock data.
34. Additional specialized services: `Booru.qml`, `ClaudeUsage.qml`, `ConflictKiller.qml`, `EasyEffects.qml`, `Emojis.qml`, `FirstRunExperience.qml`, `Football.qml`, `HyprlandAntiFlashbangShader.qml`, `HyprlandConfig.qml`, `HyprlandKeybinds.qml`, `HyprlandOptions.qml`, `HyprlandXkb.qml`, `Hyprsunset.qml`, `Idle.qml`, `KeyringStorage.qml`, `LatexRenderer.qml`, `LauncherSearch.qml`, `MaterialSymbolsSearch.qml`, `NiriBackend.qml`, `NiriConfig.qml`, `NiriXkb.qml`, `OnlineWallpapers.qml`, `PolkitService.qml`, `PresetThumbs.qml`, `Presets.qml`, `PresetsOnline.qml`, `Privacy.qml`, `SessionWarnings.qml`, `SettingsQuickControls.qml`, `SettingsSearchIndex.qml`, `SongRec.qml`, `TaskbarApps.qml`, `TrayService.qml`, `WallhavenSearch.qml`, `Webapps.qml`, `WM.qml`, `Ydotool.qml`.

---

## 4. Recurring Tasks & Process Spawning

- **Total `Timer` Components in Codebase:** 200 instances.
- **Total `Process` Declarations:** 253 instances.
- **Total `Quickshell.execDetached` Invocations:** 219 calls.
- **Key Polling Loops:**
  - `ResourceUsage.qml`: Telemetry timer (default 2000ms).
  - `LiveWallpaper.qml`: Socket poller (3000ms).
  - `NetworkSpeed.qml`: Interface bytes delta (1000ms).
  - `Updates.qml`: Periodic update checker (every 30 minutes).
  - `ClockWidget.qml`: Clock tick (1000ms).
  - `CookieClock.qml`: Background widget clock tick (1000ms).

---

## 5. File Persistence & Configuration

- **Main Configuration:** `~/.config/illogical-impulse/config.json` via `Config.qml` (JSON adapter).
- **Persistent State:** `~/.local/state/quickshell/states.json` via `Persistent.qml`.
- **Notepad Data:** `~/.local/state/quickshell/user/notepad.json`.
- **Calculator History:** `~/.local/state/quickshell/user/calculator_history.json`.
- **Todo List:** `~/.local/state/quickshell/user/todo.json`.
- **Whiteboard Boards:** `~/.local/state/quickshell/user/whiteboard/` (JSON board files).
- **Material Theme Cache:** `~/.local/state/quickshell/user/generated/colors.json`.
- **Wallpaper Thumbnails:** `~/.cache/quickshell/media/thumbnails/`.

---

## 6. Recent Git History & Changes

- `7532506`: feat(livewallpaper): support lockscreen live wallpaper, battery power policies, and settings light mode styling.
- `e5ad789`: fix(converter): fix mass icon, align card dropdowns symmetrically, and make unit picker modal solid opaque.
- `cce7489`: fix(notepad): refine delete dialog button styling and auto-dismiss modal on sidebar close.
- `3fef1b6`: fix(sidebarRight): fix calculator symmetry, converter category sync, and redesign delete dialog.
- `5aa1210`: feat(sidebarRight): integrate productivity tools (Notepad, Calculator, Unit Converter).
- `9b60124`: feat(whiteboard): add bidirectional cross-monitor drag and dynamic display migration.
