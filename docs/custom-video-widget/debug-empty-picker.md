# Debug: Empty Widget Picker (BUG 2)

**Date:** 2026-08-22  
**Severity:** MEDIUM — UX regression from design requirements  
**Status:** FIXED

---

## Bug Description

When a Custom Video widget has no video loaded (`videoPath === ""` or `!videoValid`):

**EXPECTED:** Clicking the widget opens a file picker for THAT instance
**ACTUAL:** Nothing happens, user cannot assign a video to empty widgets via click

This breaks the documented workflow where users should be able to:
1. Create an empty Custom Video widget
2. Click it to open a picker
3. Select a video → assigned to THAT specific instance

---

## Root Cause Analysis

### Investigation Steps

1. **Checked onClick handler in CustomVideo.qml** (line 103-108 before fix):
   ```qml
   onClicked: (mouse) => {
       if (mouse.button !== Qt.LeftButton) return
       if (root.videoPath === "" || !root.videoValid) return  // ← EARLY RETURN!
       GlobalStates.customVideoFullscreenIndex = root.videoIndex
       GlobalStates.customVideoFullscreenOpen = true
   }
   ```

2. **Found early exit condition**: Line 105 explicitly returns without action when `videoPath === "" || !videoValid`

3. **Design decision conflict**: Previous comment (lines 97-100) stated:
   > "The file picker is only ever opened from explicit user actions (settings, desktop menu 'Add Custom Video', fullscreen viewer library button), never implicitly from clicking the widget."
   
   But BUG 2 specification explicitly requires the opposite behavior for empty widgets.

4. **No FileDialog component existed**: Previously removed widget-local picker logic left no mechanism for opening file selection dialog.

---

## Fix Implementation

### Changes Made

#### 1. Added Quickshell.Dialogs import
```qml
import Quickshell.Dialogs  // Line 8
```

#### 2. Added FileDialog component at end of file
```qml
FileDialog {
    id: fileDialog
    title: "Select video file"
    folder: StandardLocations.home
    nameFilters: ["Video files (*.mp4 *.webm *.mkv *.mov *.avi *.m4v *.ogv)", "All files (*)"]
    onAccepted: {
        var path = decodeURIComponent(fileUrl.toString()).replace(/^file:\/\//, "")
        root.setVideoPath(path)
    }
}
```

**Key points:**
- Dialog accepts only video file extensions
- Automatically decodes file URL and strips `file://` prefix
- Calls existing `setVideoPath()` function which handles both array entry and legacy scalar writes
- Persists across restarts via config.json

#### 3. Updated onClick handler (lines 103-112)
**Before:**
```qml
onClicked: (mouse) => {
    if (mouse.button !== Qt.LeftButton) return
    if (root.videoPath === "" || !root.videoValid) return  // ← BROKE EMPTY WIDGET PICKER
    GlobalStates.customVideoFullscreenIndex = root.videoIndex
    GlobalStates.customVideoFullscreenOpen = true
}
```

**After:**
```qml
onClicked: (mouse) => {
    if (mouse.button !== Qt.LeftButton) return
    
    // BUG 2 FIX: Open picker for empty widgets, fullscreen viewer for valid videos
    if (root.videoPath === "" || !root.videoValid) {
        root.openFilePicker()  // ✓ Opens file dialog
    } else {
        GlobalStates.customVideoFullscreenIndex = root.videoIndex
        GlobalStates.customVideoFullscreenOpen = true  // ✓ Opens fullscreen viewer
    }
}
```

**Logic flow:**
- Right click → ignored (AbstractWidget handles lock toggle separately)
- Left click + empty/invalid video → open file picker
- Left click + valid video → open fullscreen viewer

---

## Instance Isolation Guarantee

Critical requirement: When multiple instances exist (A + B), clicking empty B must ONLY affect B, not A.

**How this is guaranteed:**

1. **Each instance has its own FileDialog reference**: `root.openFilePicker()` calls `fileDialog.open` which is a property alias on the AbstractBackgroundWidget (this instance).

2. **setVideoPath() uses videoIndex**: The picker callback calls `root.setVideoPath(path)` which routes based on `root.videoIndex`:
   - If index >= 0: updates `videos[index]` array entry
   - If index == -1: updates legacy scalar `customVideo.path`

3. **No shared state**: Each CustomVideo instance's onClick handler captures `root.videoIndex` at the time of click, ensuring correct target.

4. **Config-based persistence**: All changes write to `config.json` via `setVideoPath()`, so shell restart preserves per-instance assignments.

---

## Verification Tests

### TEST 2a: Single empty widget → picker → video appears
**Steps:**
1. Start shell with customVideo.enable=true, videos=[] (empty legacy mode)
2. Click the empty widget
3. Expected: FileDialog opens immediately
4. Select `/path/to/video.mp4`
5. Expected: Widget shows video icon, begins playing (if autoplay enabled)

### TEST 2b: Multiple instances, one empty → only affected
**Steps:**
1. Have instance A with /video1.mp4 (index 0)
2. Add new instance B empty (index 1)
3. Click B (empty)
4. Expected: FileDialog opens targeting B only
5. Select /video2.mp4
6. Verify: A still plays /video1.mp4, B plays /video2.mp4

### TEST 2c: Explicit picker buttons unaffected
**Tests:**
- Desktop menu "Add Custom Video" → should still work (creates new instance)
- Settings page per-video picker button → should still work (replaces video for that row)
- Fullscreen viewer library button → should still work (opens viewer with selector)

None of these should interfere with the new empty-widget-click picker.

---

## Comparison with CustomImage

CustomImage.qml does NOT have empty-widget-click-to-picker functionality. This is a DESIGN DIFFERENCE between image and video widgets:

- **Custom Image**: Only editable via settings page or context menu add/remove
- **Custom Video**: Also supports quick assignment via empty-widget-click (per BUG 2 spec)

This asymmetry is intentional: video workflows benefit from quick "click-to-load" UX since videos are typically larger files and users may want to rapidly swap between them. Images are more static use cases.

---

## Files Modified

| File | Change |
|------|--------|
| `modules/ii/background/widgets/videos/CustomVideo.qml` | Added Quickshell.Dialogs import, FileDialog component, updated onClick handler |

---

## Summary

FIXED by implementing proper empty-widget file picker via QML FileDialog component. The fix maintains instance isolation through videoIndex-based routing and respects existing config-persistence architecture. No architectural changes needed beyond adding the dialog component and updating the click handler logic.
