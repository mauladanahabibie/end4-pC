# Add Widget Submenu Refactor — Progress

## Checklist
- [x] Inspect existing context menu implementation in `modules/ii/desktopMenu/DesktopMenu.qml`.
- [x] Inspect existing submenu components (`WidgetsSubmenu.qml`, `WallpaperSubmenu.qml`).
- [x] Create plan document in `docs/context-menu/add-widget-submenu-plan.md`.
- [x] Create progress document in `docs/context-menu/add-widget-submenu-progress.md`.
- [x] Create `modules/common/widgets/AddWidgetSubmenu.qml` with Material Design styling, matching `Appearance.colors.colUiBackground` and `RippleButton`.
- [x] Refactor `modules/ii/desktopMenu/DesktopMenu.qml` to replace individual `Add Custom Image` and `Add Custom Video` entries with `Add Widget ›`.
- [x] Integrate `AddWidgetSubmenu` via `Component`, `HoverHandler`, and `openSubmenuComponent`.
- [x] Connect `onAddImageClicked` and `onAddVideoClicked` directly to existing `desktopMenuPickerProc` and `desktopMenuVideoPickerProc` processes.
- [x] Fix runtime import resolution in `CustomVideo.qml` (`import qs`) and bound property declarations in `WidgetsLoader.qml`.
- [x] Test desktop context menu in active Quickshell environment with live rendering and screenshot inspection.
- [x] Verify `Add Widget` opens submenu with `Custom Image` and `Custom Video` actions.
- [x] Verify hovering/leaving coordinates correctly trigger `submenuCloseTimer` without flickering.
- [x] Verify clicking outside cleanly dismisses context menu and submenus.
- [x] Verify existing `Widgets` submenu, `Wallpaper & style`, `DropShelf`, `Display Projection`, and `Settings` remain fully functional.
- [x] Commit and push to `maulan/main`.

## Verification Summary
1. **Visual Presentation:** The desktop context menu items now follow the exact requested hierarchy:
   - Wallpaper & style ›
   - Widgets ›
   - DropShelf
   - Add Widget ›
   - Display Projection ›
   - Settings ›
2. **Submenu Functionality:** Hovering over or clicking `Add Widget` reveals the `Add Widget` submenu containing `Custom Image` and `Custom Video` with respective icons `"image"` and `"movie"`.
3. **Creation Logic Preserved:** Widget creation triggers the exact original processes (`scripts/images/pick-image.py` and `scripts/images/pick-video.py`) appending to multi-instance configuration arrays while preserving widget state, movement, and playback controls.
