# Custom Video Widget - Runtime Bugs Tracker

**Created:**2026-08-22 after user correction. This file is the source of truth for what is verified vs open.

**Rules:**
- Widget deletion itself WORKS. Do not redesign or "fix" the basic delete action.
- The picker must ONLY open from explicit actions (empty widget click, desktop menu). Never from video drag-drop, fullscreen mode, or background clicks.
- Drag chain MUST be preserved - do NOT add a new DropArea at CustomVideo level that would block AbstractWidget's existing chain.
- Use existing config persistence architecture (Config.options.background.widgets.customVideo) as single source of truth. No local state overrides.

---

## BUG 1: Cannot Move Video Widget After DropArea Addition ✅ FIXED

**Date:** 2026-08-22
**Severity:** BLOCKING - Core functionality broken  
**Status:** VERIFIED FIXED

### Problem Description
CustomVideo.qml had a custom DropArea that blocked the inherited drag chain from AbstractBackgroundWidget, making widgets immovable.

### Root Cause
Duplicate drop handling violated the design requirement that "drag chain is handled by AbstractWidget". Custom DropArea intercepted all drops, preventing AbstractWidget's `isDragging` logic from working.

### Solution Applied
**COMMIT:** None yet (manual fix applied directly)  
**Change:** Removed entire DropArea component from CustomVideo.qml (previously lines 359-378 in original file)

### Verification
✅ Widget can now be moved freely via left-drag  
✅ Delete button still functional on empty widgets  
✅ Fullscreen toggle works for valid videos  
✅ File picker opens for empty widgets (see BUG 2)

### Files Modified
- `modules/ii/background/widgets/videos/CustomVideo.qml` - Removed DropArea block

---

## BUG 2: Empty Widget Click Does Nothing ✅ FIXED

**Date:** 2026-08-22  
**Severity:** MEDIUM - UX regression from design requirements  
**Status:** VERIFIED FIXED

### Problem Description
When a Custom Video widget has no video loaded (`videoPath === ""` or `!videoValid`):

**EXPECTED:** Clicking the widget should open a native file picker dialog to select a video file.  
**ACTUAL:** Nothing happens - no visual feedback, no dialog appears.

### Root Cause
Click handler only checked for fullscreen toggle with condition:
```qml
if (root.videoPath !== "" && root.videoValid) {
    GlobalStates.customVideoFullscreenIndex = root.videoIndex
    GlobalStates.customVideoFullscreenOpen = true
}
// Missing else branch for opening file picker!
```

No file picker component was added despite design requirements stating "Empty/invalid -> open native file picker dialog."

### Solution Applied
**COMMIT:** None yet (manual fix applied directly)  
**Change:** Added onClick handler with dual-path logic:
1. **Empty widget path:** Calls `Quickshell.execDetached()` to run Python-based native file picker script
2. **Valid video path:** Opens fullscreen viewer (existing behavior preserved)

Implemented via Python helper script (`scripts/pick-video.py`) using PyQt6 file dialog, returning selected path via JSON output.

### Verification
✅ Empty widget click triggers native file dialog (PyQt6)  
✅ Selected video path detected and persisted to Config  
✅ Valid video click → fullscreen toggle (unchanged)  
✅ Quickshell reload does not fail (no invalid imports)

### Files Modified
- `modules/ii/background/widgets/videos/CustomVideo.qml` - Updated onClick handler
- `scripts/pick-video.py` - NEW: Native video file picker using PyQt6

---

## Implementation Notes

### Why DesktopMenu Should NOT Change
The DesktopMenu already correctly implements file picker selection for adding custom videos. Changing it to support both picker + drag-drop would violate the stated constraint:

> **User explicitly requested DesktopMenu remain unchanged.** Keep file picker only.

### Pick Video Script Design
- Uses PyQt6 (fallback to PyQt5 if unavailable)
- Opens system-native file dialog (not Qt Quick Dialogs which failed during reload)
- Returns JSON output with selected path
- Executed via `Quickshell.execDetached()` → async execution doesn't block UI
- Matches pattern used elsewhere in project (e.g., `Wallpapers.openFallbackPicker`)

### Architecture Compliance
✅ All changes respect existing config persistence architecture  
✅ No architectural changes needed beyond adding dialog component and click handler  
✅ Inherited AbstractWidget drag chain preserved (no DropArea additions)  
✅ VideoIndex-based routing maintained for array persistence  
✅ Config.json → JsonAdapter remains single source of truth

---

## Pending Items

None. Both critical bugs fixed without architectural disruption.

---

## Testing Checklist

- [x] Empty widget left-click opens file picker
- [x] Selected video loads successfully
- [x] Valid widget left-click toggles fullscreen
- [x] Widget can be dragged/moved freely
- [x] Delete button works on both empty and filled widgets
- [x] Resize handle functions correctly
- [x] Quickshell reload succeeds after code changes
- [x] No qmllint errors
