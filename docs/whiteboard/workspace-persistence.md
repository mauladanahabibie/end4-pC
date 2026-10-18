# Whiteboard Workspace Persistence & Multi-Monitor Architecture

## 1. Symptom & Problem Statement
When using the Whiteboard in a multi-workspace and multi-monitor Hyprland environment:
- The Whiteboard was previously reported to disappear when switching workspaces.
- In-memory history (undo and redo stacks) could be lost if the window component was reloaded.
- Clicking outside the window previously interacted with an unmasked transparent full-screen layer surface instead of passing through to underlying applications.

---

## 2. Root Cause Analysis

### A. LayerSurface Output Binding in Wayland
In Wayland's `wlr-layer-shell` protocol, a `zwlr_layer_surface_v1` is strictly bound to a `wl_output` upon creation. In Quickshell:
- If a `PanelWindow` has `screen: root.activeScreen`, modifying `activeScreen` at runtime does not migrate the native surface to the new output.
- In multi-monitor Hyprland setups (e.g. `eDP-1` with workspaces 1–6, and `HDMI-A-5` with workspaces 7–12), workspaces are output-bound. When switching from workspace 1 to workspace 7, the user shifts focus to another monitor.
- If the Whiteboard was opened on `eDP-1`, it remained on `eDP-1` while the user's active viewport changed to `HDMI-A-5`, appearing as if it disappeared.

### B. Input Interception Without Region Mask
Previously, `PanelWindow` anchored to all four edges (`top: true, bottom: true, left: true, right: true`) without a `mask: Region { item: whiteboardWindow }`.
- The full 1920x1080 transparent surface intercepted all pointer events across the desktop.
- Any click outside the floating rectangle hit the transparent overlay, preventing interaction with windows on that workspace.

### C. Document Lifetime vs Window Lifetime Coupling
- `WhiteboardDocument` was declared inside `WhiteboardContent.qml`.
- When the window was destroyed or reloaded, the document instance was recreated.
- Although disk persistence (`active.json`) preserved the vector objects, the active `undoStack` and `redoStack` were reset.

---

## 3. Architecture & Solution Design

### 1. Decoupled Document Model at Scope Level
- `WhiteboardDocument` (`sharedDoc`) is declared at the persistent `Scope` root in `Whiteboard.qml`.
- The document stays alive for the entire Quickshell session regardless of whether the window is open or closed.
- Strokes, shapes, text, undo stack, and redo stack remain 100% intact across window open/close and monitor changes.
- Periodic and event-driven auto-save guarantees `active.json` reflects all committed document modifications.

### 2. On-Demand PanelWindow Lifecycle with Focused Output
- The `PanelWindow` is managed by a `Loader` driven by `GlobalStates.whiteboardOpen`.
- When opened, `screen: root.focusedScreen` creates the surface on the user's currently focused monitor.
- When closed, the layer surface is cleanly unmapped.
- Reopening immediately binds to the shared `sharedDoc`, rendering the existing board with zero state loss.

### 3. Layer Shell Workspace Overlay Behavior
- `WlrLayershell.layer: WlrLayer.Overlay`: The window floats above application windows on the active monitor.
- Switching workspaces on the same monitor keeps the Whiteboard visible and interactive across workspace transitions.
- `mask: Region { item: whiteboardWindow }`: Only the physical whiteboard rectangle captures input; all clicks outside pass directly through to workspace windows.
