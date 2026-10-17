# Refactor Desktop Context Menu: Add Widget Submenu — Plan

## 1. Objective
Refactor the desktop context menu (`modules/ii/desktopMenu/DesktopMenu.qml`) by replacing the two individual top-level entries (`Add Custom Image` and `Add Custom Video`) with a single compact `Add Widget` entry that opens a submenu.

The submenu will provide:
- **Custom Image** (icon: `"image"`)
- **Custom Video** (icon: `"movie"`)

## 2. Target Hierarchy & Flow
### Main Menu:
1. `Wallpaper & style` (opens `WallpaperSubmenu`)
2. `Widgets` (opens `WidgetsSubmenu`)
3. `DropShelf`
4. `Add Widget ›` (opens `AddWidgetSubmenu`)
5. `Display Projection ›`
6. `Settings ›`

### Submenu (`Add Widget`):
- `Custom Image`: Closes desktop menu, ensures `Config.options.background.widgets.customImage.enable = true`, runs `scripts/images/pick-image.py`.
- `Custom Video`: Closes desktop menu, ensures `Config.options.background.widgets.customVideo.enable = true`, runs `scripts/images/pick-video.py`.

## 3. Implementation Steps
1. Create `modules/common/widgets/AddWidgetSubmenu.qml`:
   - Follow `WidgetsSubmenu.qml` structure and Material Design styling (`Appearance.colors.colUiBackground`, `Appearance.rounding.verylarge`, `RippleButton`).
   - Define signals `signal addImageClicked()` and `signal addVideoClicked()`.
2. Update `modules/ii/desktopMenu/DesktopMenu.qml`:
   - Replace separate `Add Custom Image` and `Add Custom Video` rows with `addWidgetRow` (`RippleButton` with icon `"add_circle"` and `chevron_right`).
   - Add `HoverHandler` and `onClicked` to anchor and open `AddWidgetSubmenu` via `menuWindow.openSubmenuComponent = addWidgetSubmenu`.
   - Connect `onAddImageClicked` and `onAddVideoClicked` to existing picker execution routines.
3. Verification:
   - Verify layout and styling in Quickshell.
   - Verify submenu opens on click/hover.
   - Verify image and video widget creation actions function identical to original.
   - Verify existing `Widgets` submenu and other items are intact.
