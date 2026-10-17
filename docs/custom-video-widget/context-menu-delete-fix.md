# Fix Custom Video Context Menu: Restore Per-Widget Delete Action

**Date:** 2026-10-18  
**Component:** `modules/ii/background/widgets/videos/CustomVideo.qml`  
**New Component:** `modules/ii/background/widgets/videos/CustomVideoContextMenu.qml`  
**Status:** IMPLEMENTED & VERIFIED AT RUNTIME

---

## 1. Problem Description

Previously, the Custom Video widget exhibited inconsistent and incomplete context menu behavior:
1. When right-clicking a Custom Video widget, the context menu either failed to open or only performed a simple `widgetsLocked` toggle from `AbstractWidget.qml`.
2. There was no dedicated context menu distinguishing between media management and widget instance lifecycle.
3. Users had no menu action to delete an entire widget instance (`Delete Widget`) vs. clearing the video media (`Delete Video`).
4. When a video was loaded, users could not access widget-level deletion from the context menu.
5. In multi-instance desktop setups, deleting the media on one widget must not delete or affect any other instance, and deleting a widget must cleanly remove only that instance from `Config.options.background.widgets.customVideo.videos`.

---

## 2. Root Cause Analysis

1. **Missing Widget Context Menu:**
   - In `CustomVideo.qml`, `onClicked: (mouse) => { ... }` intercepted `mouse.button === Qt.RightButton` and only toggled `Config.options.background.widgetsLocked = !Config.options.background.widgetsLocked`, completely bypassing any menu popup.
2. **Conflation of Media Clearing vs. Widget Deletion:**
   - The red circular `deleteHandle` previously executed `deleteThisVideo()` if `videoIndex >= 0`, but for the legacy fallback instance called `root.setVideoPath("")`. Media clearing and widget deletion were mixed together without a clear UI distinction.
3. **Missing `requestDelete()` Implementation on `CustomVideo`:**
   - `CustomVideo` did not implement `requestDelete()`, falling back to `AbstractBackgroundWidget.qml` which simply set `Config.options.background.widgets.customVideo.enable = false`. For multi-instance widgets (`videos` array), this disabled the entire widget category instead of removing the clicked instance.
4. **Resurrection of Legacy Single Instance:**
   - In `deleteThisVideo()`, when all items in `videos` array were removed (`list.length === 0`), `customVideo.enable` remained `true`. Because `WidgetsLoader.qml` checks `!Config.options.background.widgets.customVideo.videos || Config.options.background.widgets.customVideo.videos.length === 0`, deleting the last array widget caused the legacy fallback widget `customVideoComp` to immediately resurrect on the desktop.

---

## 3. Architecture & Implementation

### 3.1. Dedicated Context Menu: `CustomVideoContextMenu.qml`
Created a Material Design 3 styled popup menu using `QtQuick.Controls.Menu` matching the rice's design language:
- **Styling:** Uses `Appearance.colors.colUiPopupBackground`, `colLayer0Border`, `colLayer1Hover`, `colOnLayer1`, and `Appearance.rounding.small`.
- **Transitions:** Expressive enter (scale 0.6 -> 1.0, opacity 0 -> 1.0) and exit animations using `Appearance.animationCurves`.
- **Actions Provided:**
  1. **Select Video / Change Video:**
     - Labeled **Change Video** when a valid video is loaded (`videoPath !== "" && videoValid`).
     - Labeled **Select Video** when the widget is empty or has an invalid video.
     - Triggers `root.targetWidget.openPicker()`.
  2. **Delete Video:**
     - Removes the currently assigned video media while keeping the widget alive and in place.
     - Stops playback, clears `videoError`, sets `videoPath = ""`.
     - Dynamically visible ONLY when `videoPath !== ""`.
     - Does NOT open the file picker automatically.
  3. **Delete Widget:**
     - Styled with `Appearance.m3colors.m3error` (red warning icon and text).
     - Always visible regardless of whether the widget is empty or loaded.
     - Calls `root.targetWidget.requestDelete()`.
  4. **Lock / Unlock widget positions:**
     - Preserves user control over desktop widget locking directly from the context menu.

### 3.2. Widget Enhancements in `CustomVideo.qml`
1. **Right-Click Integration:**
   - Updated `onClicked`: `if (mouse.button === Qt.RightButton) { contextMenu.popup(); return }`.
2. **`deleteVideoMedia()` Method:**
   - Explicitly stops `player.stop()`, resets `videoError = false`, and invokes `setVideoPath("")`.
   - Preserves widget coordinates, dimensions, shape, and auto-play configuration.
3. **`requestDelete()` Implementation:**
   - Stops playback and handles both multi-instance (`deleteThisVideo()`) and legacy modes (`customVideo.enable = false`).
4. **Clean Array Deletion in `deleteThisVideo()`:**
   - Reconstructs and reassigns `videos` array without the deleted index.
   - When `list.length === 0`, sets `Config.options.background.widgets.customVideo.enable = false` to guarantee no zombie/legacy widget resurrects.
5. **Delete Handle Red Circle:**
   - Updated `deleteArea.onClicked` to invoke `root.requestDelete()`.
   - Added `!Config.options.background.widgetsLocked` visibility guard to prevent accidental deletion when widgets are locked.

---

## 4. Verification & Test Results

All test cases were verified live on the running Quickshell daemon (`qs -c end4-pC`) on Hyprland workspace 2:

### Test Case 1: Empty Widget Context Menu
- **Action:** Right-clicked an empty Custom Video placeholder widget.
- **Result:** Context menu opened displaying `Select Video`, `Delete Widget`, and `Unlock widget positions`. `Delete Video` was hidden as expected.

### Test Case 2: Delete Widget on Empty Widget
- **Action:** Selected `Delete Widget` from the context menu on the empty widget.
- **Result:** Widget was cleanly removed from the screen. In `config.json`, `videos` array length became 0 and `enable` became `false`. No legacy widget was resurrected.

### Test Case 3: Loaded Widget Context Menu
- **Action:** Configured video widget with loaded MP4 video. Right-clicked the playing widget.
- **Result:** Context menu opened displaying `Change Video`, `Delete Video`, `Delete Widget`, and `Lock widget positions`.

### Test Case 4: Delete Video (Media Clearing)
- **Action:** Selected `Delete Video` from the context menu.
- **Result:**
  - Video playback immediately stopped.
  - Video path cleared to `""` in config.
  - Widget remained alive on the desktop as an empty placeholder with `movie` icon.
  - Widget position, size, and shape were 100% preserved.
  - File picker did NOT open automatically.

### Test Case 5: Multi-Instance Isolation
- **Action:** Added two Custom Video widgets (Widget 0 and Widget 1) playing distinct videos concurrently.
  1. Triggered `Delete Video` on Widget 1:
     - Widget 1 became an empty placeholder.
     - Widget 0 continued playing its video seamlessly without interruption.
  2. Triggered `Delete Widget` on Widget 0:
     - Widget 0 was completely removed.
     - Widget 1 remained intact on the desktop.
     - `videos` array length reduced from 2 to 1.
  3. Triggered `Delete Widget` on remaining Widget 1:
     - Widget 1 was removed.
     - Both widgets cleanly removed, resulting in an unobstructed desktop and `enable: false`.

---

## 5. Non-Regression Checklist

- [x] Widget drag-and-drop movement functions properly.
- [x] Widget resizing handles operate smoothly.
- [x] Custom mask shapes (Cookie4Sided, Cookie6Sided, Arch, etc.) render properly.
- [x] Desktop widget locking (`widgetsLocked`) hides delete handles and prevents accidental moves.
- [x] Dropping video files via `DropArea` loads media correctly.
- [x] Custom Image widgets and unrelated desktop components remain unaffected.
