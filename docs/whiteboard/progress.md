# Whiteboard Widget Implementation Progress

## Status Overview
- Current Phase: **Completed & Verified**
- Overall Progress: 100%

---

## Task Checklist

### Phase A: Architecture, Window, Canvas Shell & Freehand Ink
- [x] Research existing desktop architecture (`docs/whiteboard/research.md`)
- [x] Implementation plan (`docs/whiteboard/plan.md`)
- [x] Create `modules/ii/whiteboard/` directory and components
- [x] Document model & history stack (`WhiteboardDocument.qml`)
- [x] Interactive dual-layer canvas (`WhiteboardCanvas.qml`)
- [x] Freehand Pen & Highlighter with smooth quadratic curves
- [x] Eraser tool
- [x] Color picker & stroke width controls (`WhiteboardColorPopup.qml`, `WhiteboardStrokePopup.qml`)
- [x] Floating desktop workspace window (`Whiteboard.qml`)
- [x] Register in `panelFamilies/IllogicalImpulseFamily.qml` & `GlobalStates.qml` & `DesktopMenu.qml`
- [x] Phase A Runtime Verification (PASS)

### Phase B: Shapes, Text, Selection, Zoom & Pan
- [x] Shape tools (Line, Arrow, Rectangle, Ellipse)
- [x] Inline text insertion and vector text objects
- [x] Object selection, movement, and deletion
- [x] Viewport navigation (Zoom 25%-400% & Pan)
- [x] Grid backgrounds (Dots, Lines, Solid Dark, Solid Light)
- [x] Phase B Runtime Verification (PASS)

### Phase C: Persistence, Board Management, Export & Shortcuts
- [x] JSON document serialization & auto-persistence (`~/.local/state/quickshell/user/whiteboard/active.json`)
- [x] Session restore on reload
- [x] File dialogs (Save As, Open Board, Export Image via Zenity/KDialog fallback scripts)
- [x] Clear board confirmation
- [x] Keyboard shortcuts (Ctrl+Z, Ctrl+Y, Ctrl+S, Del, Esc, Zoom +/-)
- [x] Phase C Runtime Verification (PASS)

### Phase D: Multi-Monitor, Workspace Persistence & Marquee Selection
- [x] Clickable Undo / Redo toolbar buttons (responsive to both mouse clicks and keyboard shortcuts)
- [x] Decouple document lifecycle from `PanelWindow` to root `Scope`:
  - `WhiteboardDocument` and auto-save `Timer` reside at persistent Scope root
  - Layer-shell window dynamically hosted inside `Loader { active: GlobalStates.whiteboardOpen }`
  - Input click passthrough via `mask: Region { item: whiteboardWindow }`
- [x] Multi-monitor layer surface binding:
  - Freeze `root.activeScreen` at open time to prevent `zwlr_layer_surface_v1` crash during cross-monitor pointer travel
  - Dynamic surface recreation on focused monitor (`eDP-1` and `HDMI-A-5`)
  - Two-way sync of viewport parameters (`zoom`, `panX`, `panY`, `backgroundMode`, `gridMode`) into document model
- [x] Drag-to-Select / Marquee Selection:
  - **Window Selection** (left-to-right drag): Selects only objects completely enclosed within the marquee rectangle (solid blue `#3b82f6` border with translucent blue fill)
  - **Crossing Selection** (right-to-left drag): Selects objects intersecting or crossing the marquee rectangle (dashed green `#22c55e` border with translucent green fill)
  - Accurate geometry bounding box hit testing for strokes, lines, arrows, rectangles, ellipses, and text
  - Additive marquee selection when holding `Shift` (unions existing selected IDs with new matches)
  - Group drag movement with single atomic undo/redo command
  - Group deletion (`Delete` key) with single atomic undo/redo restoration
  - Hit testing for hollow unfilled shapes inside selected bounding box
  - Phase D Runtime Verification (PASS)

---

## Runtime Verification Matrix

| # | Test Case | Status | Notes & Visual Evidence |
|---|---|---|---|
| 1 | Open and close whiteboard | **PASS** | Toggles via DesktopMenu, compositor shortcut, and IPC. Clean entry/exit. |
| 2 | Freehand pen drawing | **PASS** | Responsive continuous pointer strokes with quadratic bezier smoothing. |
| 3 | Change color and stroke width | **PASS** | Popups with palette presets, custom picker, and stroke widths (1-32px). |
| 4 | Highlighter semi-transparent stroke | **PASS** | Smooth 38% alpha stroke with increased thickness. |
| 5 | Draw shapes (Line, Arrow, Rect, Ellipse) | **PASS** | Real-time shape preview on overlay canvas, committed to base canvas on release. |
| 6 | Insert and edit text | **PASS** | Inline text input overlay, committed as scalable vector text object. |
| 7 | Eraser tool | **PASS** | Hit-tests and removes objects under pointer. |
| 8 | Undo and redo operations | **PASS** | Fully functional via keyboard (`Ctrl+Z`, `Ctrl+Y`) and clickable toolbar buttons. |
| 9 | Single object selection & movement | **PASS** | Clicking object shows dashed bounding box with handles, drag moves object. |
| 10 | Marquee: Window Selection (L to R) | **PASS** | Solid blue box; selects only fully enclosed objects (`step2_window_selected.png`). |
| 11 | Marquee: Crossing Selection (R to L) | **PASS** | Dashed green box; selects intersecting objects (`step3_crossing_selected.png`). |
| 12 | Marquee: Additive Selection (`Shift`) | **PASS** | Holding `Shift` appends new marquee objects to current selection (`shift_step2_both_selected.png`). |
| 13 | Multi-object group movement | **PASS** | Moving selected group moves all items in sync; single undo restores all (`step4_group_moved.png`). |
| 14 | Multi-object group deletion & undo | **PASS** | Delete key deletes all selected objects; `Ctrl+Z` restores all (`step5_group_deleted.png`, `step6_undo_restored.png`). |
| 15 | Zoom and pan navigation | **PASS** | Wheel zoom (25%-400%) anchored at cursor; middle-click and Pan tool pan canvas. |
| 16 | Multi-monitor & workspace switching | **PASS** | Closing on `eDP-1` and opening on `HDMI-A-5` preserves exact board and viewport (`hdmi_workspace7_reopened.png`). |
| 17 | Persistence across Quickshell reload | **PASS** | State saved in `active.json`; auto-saved and restored seamlessly. |
| 18 | Toolbar input isolation & click mask | **PASS** | Layer-shell surface mask passes clicks outside window; toolbar clicks do not bleed into drawing. |
