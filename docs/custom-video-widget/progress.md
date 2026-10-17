# Custom Video Widget - Progress Tracker v2

**Last Updated:** 2026-10-18  
**Status:** DRAG GHOST FIX APPLIED — RUNTIME VERIFICATION

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

### FIX 5 — Drag Ghost / Stale Position Desync (Current Task)
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

---

## Test Matrix

### TEST A — Single Widget Drag (Ghost Elimination)
- [x] Dragging video widget moves smoothly with cursor
- [x] No ghost / stale visual remains at original location
- [x] Video continues playing continuously during drag
- [x] Release drops widget cleanly without visual jump or ghost reappearance

### TEST B — Multi-Instance Isolation
- [x] Multiple video widgets can be moved independently
- [x] Moving instance 0 does not alter instance 1's position
- [x] Position persists across restart

### TEST C — Custom Image & Other Widgets
- [x] Custom Image dragging remains unaffected
- [x] Other desktop widgets remain unaffected

---

## Pass Criteria
- Dragging any Custom Video widget leaves NO ghost at original position.
- Video playback continues without interruption.
- Positions persist accurately to configuration.
- Zero regressions in Custom Image or other widgets.
