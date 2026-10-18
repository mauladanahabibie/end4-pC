# Whiteboard Widget Architecture & System Research

## 1. Overview
The goal is to implement a fully functional, production-ready, interactive **Whiteboard Widget** for the Quickshell desktop rice on Qt 6 / QML, designed according to the existing Material 3 / rice aesthetics, window management lifecycle, persistence standards, and interaction conventions.

---

## 2. Existing Desktop Rice Architecture Analysis

### 2.1 Window Management & Component Lifecycle
- **Entry point**: `panelFamilies/IllogicalImpulseFamily.qml` uses `Scope` and `PanelLoader` to instantiate desktop surfaces.
- **Floating window conventions**: Examined `Settings.qml` and `EqualizerPopup.qml`:
  - Uses `PanelWindow` anchored full screen (`anchors.fill: parent`) with `exclusiveZone: 0`, `WlrLayershell.namespace: "quickshell:whiteboard"`, and `WlrLayershell.layer: WlrLayer.Overlay`.
  - Inner window `Rectangle` with floating geometry (e.g. width ~1080, height ~720, clamped to screen dimensions).
  - Dragging: implemented via titlebar `MouseArea` with `drag.target: whiteboardWindow`, `drag.axis: Drag.XAndYAxis`.
  - Resizing: corner / edge `ResizeHandler` or `MouseArea` with cursor shape switching.
  - Keyboard focus: `WlrLayershell.keyboardFocus: GlobalStates.whiteboardOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None`.
  - Dismissal: registered with `GlobalFocusGrab.addDismissable(panelWindow)`.
  - Controlled via `GlobalStates.whiteboardOpen` (single shared instance, no duplicate windows).

### 2.2 Entry Points & Widget Integration
- **Desktop Context Menu (`modules/ii/desktopMenu/DesktopMenu.qml`)**:
  - Opened via desktop right-click or IPC (`qs-ipc desktopMenu`).
  - Contains main sections: Wallpaper & style, Widgets, DropShelf, Add Widget, Display Projection, Settings.
  - Adding a dedicated **"Whiteboard"** entry with `MaterialSymbol { text: "draw" }` directly opens the whiteboard workspace.
- **Desktop Widgets Catalog (`services/DesktopWidgets.qml`)**:
  - Maintains `catalog` with `{ key: "whiteboard", icon: "draw", name: Translation.tr("Whiteboard") }`.
- **Top Bar Utility Buttons (`modules/ii/bar/UtilButtons.qml`)**:
  - Utility buttons container for quick desktop tools.
- **IPC Handler (`IpcHandler`)**:
  - `target: "whiteboard"` with `toggle()`, `open()`, `close()`.

### 2.3 Reusable UI Controls & Design Tokens
- **Colors**:
  - Surfaces: `Appearance.colors.colUiBackground`, `colLayer0`, `colLayer1`, `colLayer2`, `colSecondaryContainer`.
  - Text & Icons: `Appearance.colors.colOnSurface`, `colOnSurfaceVariant`, `colOnLayer1`, `colOnSecondaryContainer`.
  - Accents: `Appearance.colors.colPrimary`, `colSecondary`, `colTertiary`.
  - Transparency helpers: `ColorUtils.transparentize(...)`.
- **Rounding**:
  - `Appearance.rounding.windowRounding` (18px), `screenRounding` (23px), `normal` (17px), `small` (12px), `full` (9999px).
- **Icons**:
  - `MaterialSymbol.qml` powered by Material Symbols font (`edit`, `draw`, `highlight`, `ink_eraser`, `horizontal_rule`, `arrow_right_alt`, `crop_square`, `circle`, `text_fields`, `pan_tool`, `undo`, `redo`, `palette`, `line_weight`, `zoom_in`, `zoom_out`, `fit_screen`, `save`, `folder_open`, `download`, `delete`, `close`).
- **Toolbar & Buttons**:
  - `Toolbar.qml`: Material 3 expressive floating toolbar with inner layout and click-through prevention (`MouseArea { acceptedButtons: Qt.AllButtons }`).
  - `IconToolbarButton.qml`: Round toggleable toolbar button with `toggled`, hover, and active states.
  - `RippleButton.qml`: M3 ripple effect and clean press animations.
  - `ConfigSlider.qml` & `StyledSlider.qml`: Sliders for stroke thickness and zoom.

### 2.4 Persistence & Storage Architecture
- **Directories (`modules/common/Directories.qml`)**:
  - `Directories.state` (`~/.local/state/quickshell`) is the standard XDG state location for persistent session data.
  - Target directory for boards: `~/.local/state/quickshell/user/whiteboard/`.
  - Auto-save file: `~/.local/state/quickshell/user/whiteboard/active.json`.
- **File I/O**:
  - `Quickshell.Io.FileView`: Reactive file watcher and writer with `path`, `onLoaded`, `setText()`.
  - Python / Zenity / KDialog bridge for explicit file dialogs (Save As, Open, Export).

### 2.5 Drawing Engine APIs in Qt 6 / Quickshell
- **Environment**: Quickshell 0.2.1 running on Qt 6.12.0.
- **Qt Quick `Canvas` (`getContext("2d")`)**:
  - Full HTML5-style Canvas 2D API support.
  - Two-tier rendering architecture:
    1. **Committed Canvas**: Renders all committed vector objects (freehand strokes, highlighters, lines, arrows, rectangles, ellipses, text). Only repainted when document changes or view transform changes.
    2. **Preview Canvas**: Renders transient in-progress interaction (the line being dragged, active freehand stroke, selection box). Repainted in real-time without re-evaluating existing objects.
  - Smooth Bezier Interpolation: Freehand points are smoothed using midpoint quadratic bezier curves for natural ink rendering.
  - Canvas transformation: `ctx.translate(panX, panY)` and `ctx.scale(zoom, zoom)` keeps all object definitions in unscaled world coordinates.
  - Export: `item.grabToImage(result => result.saveToFile(destination))` and `canvas.save(destination)`.

---

## 3. Findings Summary & Architectural Strategy
1. The whiteboard will be a standalone desktop workspace window registered in `panelFamilies/IllogicalImpulseFamily.qml` and controlled by `GlobalStates.whiteboardOpen`.
2. It will have an entry point in `DesktopMenu.qml` and `DesktopWidgets.qml`.
3. The drawing engine will store structured vector-like data (`strokes`, `shapes`, `text`) enabling full undo/redo, selection, moving, deletion, zoom, and serialization.
4. Auto-save ensures work is never lost across closes or restarts.
