# Custom Video Widget — Implementation Plan

Based on completed research (see research.md, subagents.md). Goal: give Custom Video the
same multi-instance lifecycle as Custom Image, fixing the four reported problems.

## The four problems → root causes

1. **Shape broken / rectangle** — per-instance shape needs `videos[]` entries with
   `shape`; singleton settings picker already works, per-row picker missing.
2. **Context menu missing "Custom Video"** — button exists but add OVERWRITES the
   singleton (no append); make it a real array append like image.
3. **Cannot delete/re-add** — delete only clears `path`; must remove array entry so the
   Repeater destroys the widget.
4. **Picker auto-opens on delete** — X-click double-fires into the widget's empty-state
   `onClicked` which opens the widget-local picker. Remove widget-local picker; picker
   only from explicit buttons.

## Phases

### Phase A — Config schema
- **Objective:** add `videos` array to customVideo.
- **Files:** `modules/common/Config.qml` (customVideo JsonObject, ~L337-350).
- **Changes:** add `property list<var> videos: []` with comment documenting entry shape
  `{path, shape, size, x, y, autoplay, loop, muted, playWhenCharging, playWhenOnBattery}`.
- **Dependencies:** none.
- **Verification:** qmllint clean; shell starts; existing config loads (missing key →
  default `[]`).

### Phase B — Multi-instance CustomVideo widget
- **Objective:** CustomVideo.qml supports `videoIndex` (>=0 array entry, -1 legacy).
- **Files:** `modules/ii/background/widgets/videos/CustomVideo.qml`.
- **Changes:**
  - Add `property int videoIndex: -1`.
  - `videoConfig` resolver: array entry if in range else legacy scalar-derived object.
  - Override `targetX/targetY` from per-entry x/y (mirror CustomImage L51-58).
  - `setVideoPath/setVideoSize/setVideoMuted` route through `updateArrayVideo` for
    index >= 0.
  - Add `deleteThisVideo()` (rebuild array without entry) — X button calls it when
    `videoIndex >= 0`; legacy X keeps `setVideoPath("")`.
  - Override `onReleased`: hide canvas grid first, then per-entry x/y write,
    `restoreXYBinding()` (mirror CustomImage L342-363).
  - REMOVE widget-local `videoPickerProc` + `openFilePicker()`; empty-state click is a
    no-op; valid-video click opens fullscreen viewer with this instance's index.
  - REMOVE `videoClearedAt` guard (no longer needed).
  - Fix power gating: `Battery.isPluggedIn ? playWhenCharging : playWhenOnBattery`
    (both false → never plays).
  - Add `Component.onDestruction: player.stop()`.
  - `videoPickerProc` import cleanup.
- **Dependencies:** Phase A.
- **Verification:** qmllint clean; runtime: N widgets render with distinct
  shape/size/position; drag/resize persists per entry; delete removes entry from
  config.json; picker never auto-opens.

### Phase C — Background canvas registration
- **Objective:** instantiate one CustomVideo per array entry + legacy loader.
- **Files:** `modules/ii/background/Background.qml` (~L536-547).
- **Changes:** legacy FadeLoader gated on `videos.length ===0` (`videoIndex: -1`) +
  `Repeater { model: videos.length }` delegate with `videoIndex: index`.
  Count-based model is REQUIRED so rebuild+reassign array writes don't destroy players.
- **Dependencies:** Phase A, B.
- **Verification:** qmllint; runtime widget count == videos.length + (legacy ? 1 : 0).

### Phase D — Desktop menu append
- **Objective:** "Add Custom Video" appends an entry instead of overwriting.
- **Files:** `modules/ii/desktopMenu/DesktopMenu.qml` (proc L72-82, button L318-334).
- **Changes:** `desktopMenuVideoPickerProc.onRead` deep-copies `videos`, pushes new
  entry (defaults: shape Cookie4Sided, size 200, x400, y 100, autoplay/loop/muted/
  power flags from config type-level defaults), reassigns. Button sets `enable = true`
  at click time (mirror image button).
- **Dependencies:** Phase A.
- **Verification:** each "Add Custom Video" grows the array by exactly one; entries
  persist across restart.

### Phase E — Settings per-video UI
- **Objective:** settings page manages per-entry videos + legacy fallback.
- **Files:** `modules/ii/settings/pages/BackgroundConfig.qml`.
- **Changes:**
  - Add page-level helpers: `addCustomVideo(path)`, `removeCustomVideo(index)`,
    `updateCustomVideo(index, key, value)` (mirror image helpers L26-59).
  - Custom Video ContentSection: keep Enable switch; move playback switches to
    per-video rows; legacy Video/Shape subsections visible only when
    `videos.length === 0`; Videos subsection with per-entry rows (path label, shape
    picker via ConfigSelectionShapeArray, size spinbox, picker button, autoplay/loop/
    muted/power switches) + FAB add; `videoPickerProc` gains `videoIndex` routing.
- **Dependencies:** Phase A.
- **Verification:** qmllint; runtime: add/remove/edit rows reflected in config.json.

### Phase F — Fullscreen viewer index-awareness
- **Objective:** viewer shows the clicked video instance.
- **Files:** `GlobalStates.qml`, `modules/ii/background/FullscreenVideoViewer.qml`.
- **Changes:**
  - GlobalStates: add `property int customVideoFullscreenIndex: -1`.
  - Viewer: resolve path from `videos[index]` when index >= 0 else legacy `path`;
    `setVideoPath`/mute writes target the right entry; loader active condition keeps
    path-nonempty check.
  - CustomVideo click + expand button set the index before opening.
- **Dependencies:** Phase A, B.
- **Verification:** qmllint; runtime: clicking instance i shows its video; drop-replace
  writes entry i.

### Phase G — Verification
- qmllint on all touched files.
- Runtime: restart quickshell, exercise add/delete/re-add via config.json edits +
  desktop menu where possible, check persistence, shapes render non-rectangle, picker
  never auto-opens.
- Reviewer subagent pass over the diff for races/duplicate state/persistence issues.
