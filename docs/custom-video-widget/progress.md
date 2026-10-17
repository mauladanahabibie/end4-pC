# Custom Video Widget - Progress Tracker v2

**Last Updated:** 2026-10-18  
**Status:** CONTEXT MENU DELETE ACTIONS RESTORED & VERIFIED

---

## Fixes Applied

### FIX 1 — Drag & Drop (BUG 1)
- **Root cause:** No `DropArea` in CustomVideo.qml. `dropHover` was dead state. `setVideoPath` unreachable via drop.
- **Fix:** Added `DropArea` inside `videoShape` mirroring CustomImage.qml. Keys: `["text/uri-list"]`. Validates extensions: mp4, webm, mkv, avi, mov, m4v, ogv. Calls `root.setVideoPath(cleanPath)` on drop.
- **File:** `modules/ii/background/widgets/videos/CustomVideo.qml`

### FIX 2+3 — Picker + returntrue typo (BUG 3)
- **Root cause:** `returntrue` (no space) caused ReferenceError when `!Battery.available`. Also, CustomVideo's `onClicked` overrode AbstractWidget's right-click → widgetsLocked toggle was lost.
- **Fix:** Fixed `returntrue` → `return true`. Restored right-click handler in `onClicked` to toggle `widgetsLocked`.
- **File:** `modules/ii/background/widgets/videos/CustomVideo.qml`

### FIX 4 — Instance Collision (BUG 4)
- **Root cause:** Background.qml legacy FadeLoader `shown` condition conflicts.
- **Fix:** Cleaned loader conditions and multi-instance handling.

### FIX 5 — Drag Ghost / Stale Position Desync
- **Root cause:**
  1. `modules/ii/background/WidgetsLoader.qml` had removed the `visible: !Config.options.background.widgets.customVideo.videos || Config.options.background.widgets.customVideo.videos.length === 0` guard on `customVideoComp`. When `videos.length > 0`, BOTH `customVideoComp` (`videoIndex: -1`) and the `Repeater` instance (`videoIndex: 0`) were instantiated at identical coordinates.
  2. During dragging, the array instance moved while the legacy instance remained stationary at `(configEntry.x, configEntry.y)`.
  3. On mouse release, `AbstractBackgroundWidget.qml`'s `commitPosition()` wrote the new drop coordinates into `configEntry.x` and `configEntry.y`, causing the legacy instance to instantly jump underneath the dropped widget, creating the illusion of a disappearing ghost.
- **Fix:**
  1. Restored `visible: !Config.options.background.widgets.customVideo.videos || Config.options.background.widgets.customVideo.videos.length === 0` on `customVideoComp` in `WidgetsLoader.qml`.
  2. Implemented `updateArrayVideoPosition(idx, x, y)` in `CustomVideo.qml` to update coordinates in a single atomic write.
  3. Overrode `function commitPosition()` in `CustomVideo.qml` so dragging array instances updates only the array element without corrupting `configEntry.x/y`.
  4. Added `visible: Config.options.background.widgets.shadow` to `StyledDropShadow` in `CustomVideo.qml`.
- **Files:**
  - `modules/ii/background/WidgetsLoader.qml`
  - `modules/ii/background/widgets/videos/CustomVideo.qml`
  - `docs/custom-video-widget/drag-ghost-root-cause.md`

### FIX 6 — Context Menu: Restore Per-Widget Delete Action
- **Root cause:**
  1. `CustomVideo.qml` intercepted right-clicks and merely toggled `widgetsLocked`, never exposing a context menu.
  2. `deleteHandle` red button conflated media clearing with widget deletion (`setVideoPath("")` vs `deleteThisVideo()`).
  3. `requestDelete()` was not implemented on `CustomVideo`, falling back to `AbstractBackgroundWidget.qml` which disabled the global category `enable = false`.
  4. Deleting the last video left `customVideo.enable = true`, resurrecting the legacy single-widget fallback.
- **Fix:**
  1. Created `CustomVideoContextMenu.qml` styled according to Material Design 3 and Quickshell tokens.
  2. Added distinct actions: `Delete Video` (clears media only, keeps widget in place, stops player) and `Delete Widget` (removes instance completely, stops resurrection).
  3. Context-sensitive `Select Video` vs `Change Video` item.
  4. Integrated context menu into `CustomVideo.qml` right-click handler.
  5. Implemented `deleteVideoMedia()` and `requestDelete()`, and ensured `customVideo.enable = false` when `videos` array becomes empty.
- **Files:**
  - `modules/ii/background/widgets/videos/CustomVideoContextMenu.qml`
  - `modules/ii/background/widgets/videos/CustomVideo.qml`
  - `docs/custom-video-widget/context-menu-delete-fix.md`

---

## Test Matrix

### TEST A — Context Menu on Empty Widget
- [x] Right-clicking empty widget opens context menu
- [x] Displays `Select Video`, `Delete Widget`, and lock toggle
- [x] `Delete Video` is hidden
- [x] Selecting `Delete Widget` completely removes widget from screen and config

### TEST B — Context Menu on Loaded Widget
- [x] Right-clicking loaded widget opens context menu
- [x] Displays `Change Video`, `Delete Video`, `Delete Widget`, and lock toggle
- [x] Selecting `Delete Video` clears media without deleting widget or opening picker
- [x] Selecting `Delete Widget` deletes widget instance

### TEST C — Multi-Instance Isolation
- [x] Multiple video widgets can coexist with individual playback
- [x] Deleting video on widget B does not affect widget A's playback
- [x] Deleting widget A removes A while preserving widget B
- [x] Deleting last widget results in clean desktop without legacy widget resurrection

### TEST D — Custom Image & Other Widgets
- [x] Custom Image dragging, right-click, and lifecycle remain unaffected
- [x] Other desktop widgets remain unaffected
