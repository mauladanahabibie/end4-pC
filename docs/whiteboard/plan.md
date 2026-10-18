# Whiteboard Widget Implementation Plan

## 1. Goal
Implement a fully functional, high-performance, interactive **Whiteboard Widget** for Quickshell on Qt 6 / QML, complete with vector drawing, shape tools, text editing, selection/movement, zoom/pan, undo/redo, auto-persistence, and image export.

---

## 2. Phased Roadmap

### Phase A: Core Architecture, Window, Canvas Shell & Freehand Ink
- [x] Research existing desktop architecture and document findings (`docs/whiteboard/research.md`).
- [ ] Create `modules/ii/whiteboard/` directory structure.
- [ ] Implement `WhiteboardDocument.qml` (data model for strokes, shapes, text, undo/redo command stack, and state management).
- [ ] Implement `WhiteboardCanvas.qml` with two-tier canvas rendering:
  - Base canvas for committed objects.
  - Preview canvas for active interaction.
  - Midpoint quadratic curve smoothing for freehand ink.
- [ ] Implement Freehand Pen and Highlighter (semi-transparent, custom lineCap/Join).
- [ ] Implement Eraser (object/stroke eraser with immediate visual feedback and undo support).
- [ ] Implement Toolbars & Controls (`WhiteboardToolbar.qml`, color palette picker, stroke thickness presets/slider).
- [ ] Implement Floating Window container (`Whiteboard.qml`, titlebar drag, minimize/maximize/close, resize handlers).
- [ ] Register in `panelFamilies/IllogicalImpulseFamily.qml`, `GlobalStates.qml`, and `DesktopMenu.qml`.
- [ ] Verify Phase A functionality in Quickshell.

### Phase B: Shapes, Text Tool, Selection & Viewport Navigation
- [ ] Implement Shape Tools:
  - Straight Line with angle snapping/freeform.
  - Arrow with proportional vector arrowhead.
  - Rectangle (outline / filled).
  - Ellipse / Circle (outline / filled).
- [ ] Implement Text Tool:
  - Click-to-insert text point.
  - Inline editing with `TextInput` / `TextEdit` overlaid on canvas in document coordinates.
  - Color and font size configuration.
  - Commit to document on defocus or Enter.
- [ ] Implement Selection & Transformation Tool:
  - Bounding box hit testing for strokes, shapes, and text.
  - Selection box rendering.
  - Object drag/movement in document space.
  - Delete selected objects (via Delete key or toolbar button).
- [ ] Implement Viewport Navigation (Zoom & Pan):
  - Zoom range 25% to 400% with clamping.
  - Zoom controls: Zoom In, Zoom Out, Reset (100% / Fit).
  - Pan mode and middle-click / space-bar pan.
  - Transform matrix alignment: screen coordinates to document coordinates.
- [ ] Canvas Background Options: Dark, Light, Dots Grid, Lines Grid.
- [ ] Verify Phase B functionality in Quickshell.

### Phase C: Persistence, Document Management, Export & Shortcuts
- [ ] Document serialization and deserialization (JSON format).
- [ ] Auto-save active document to `~/.local/state/quickshell/user/whiteboard/active.json`.
- [ ] Session restore on startup / window reopen.
- [ ] Board management:
  - New board (with discard/save prompt or safe clear).
  - Open existing board (via Zenity / KDialog file picker).
  - Save board As (via Zenity / KDialog file picker).
  - Clear board with confirmation dialog.
- [ ] Image Export:
  - Render full canvas or bounds to PNG.
  - Export destination picker (`pick-save-path.py` / zenity).
- [ ] Keyboard Shortcuts:
  - `Ctrl+Z`: Undo
  - `Ctrl+Shift+Z` / `Ctrl+Y`: Redo
  - `Ctrl+S`: Save
  - `Ctrl+O`: Open
  - `Ctrl+N`: New board
  - `Delete` / `Backspace`: Delete selected object
  - `Escape`: Cancel action / deselect
  - `+` / `-`: Zoom in / Zoom out
  - `0`: Reset zoom
- [ ] Verify Phase C functionality in Quickshell.

### Phase D: Visual Polish, Performance Review & Runtime Verification
- [ ] Visual styling polish: match rice theme, shadows, rounded corners, icons, tooltips.
- [ ] Input reliability testing: ensure no accidental marks from toolbar clicks or dragging.
- [ ] Performance testing with hundreds of strokes.
- [ ] Regression testing of existing rice features (bar, media, sidebar, settings).
- [ ] Complete test matrix in `docs/whiteboard/progress.md`.
