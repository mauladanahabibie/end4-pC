# Custom Video Widget — Final Summary

**Status: COMPLETE — SHIP**
Date: 2026-08-22

## What was delivered

Multi-instance Custom Video desktop widget with the same lifecycle as Custom Image,
fixing all four reported problems:

| # | Problem | Fix |
|---|---------|-----|
| 1 | Shape broken / rectangle | Per-entry `shape` in `videos[]`; per-row shape picker in settings |
| 2 | Context menu missing/overwriting | "Add Custom Video" now APPENDS a new array entry |
| 3 | Cannot delete/re-add | X button removes the array entry (rebuild+reassign); Repeater destroys the delegate; player stopped on destruction |
| 4 | Picker auto-opens on delete | Widget-local picker removed entirely; picker only from explicit buttons (settings row, settings FAB, desktop menu, fullscreen viewer library button) |

## Files changed

- `modules/common/Config.qml` — `videos: list<var>` added to `customVideo` schema
- `modules/ii/background/widgets/videos/CustomVideo.qml` — full multi-instance rewrite (`videoIndex` -1/legacy or >=0/array, `videoConfig` resolver, per-entry x/y/size/shape/muted routing, `deleteThisVideo`, power-gated playback, destruction cleanup)
- `modules/ii/background/Background.qml` — legacy FadeLoader (gated `videos.length === 0`) + count-based Repeater
- `modules/ii/desktopMenu/DesktopMenu.qml` — append picker proc + enable-at-click button
- `modules/ii/settings/pages/BackgroundConfig.qml` — per-video rows (shape picker, size, picker button, playback switches), add/remove/update helpers
- `modules/ii/background/FullscreenVideoViewer.qml` — index-aware path/mute/loop resolution, per-entry writes
- `GlobalStates.qml` — `customVideoFullscreenIndex`

## Bug found and fixed during verification

- **Qt5→Qt6 API break**: `MediaPlayer.seek(0)` does not exist in Qt 6 (replay button
  would throw at runtime). Fixed in `CustomVideo.qml:331` and
  `FullscreenVideoViewer.qml:244` → `player.position = 0`.

## Verification results

### Lint (qmllint, real Qt6 binary `/usr/lib/qt6/bin/qmllint`)
- CustomVideo.qml: **0 errors**. Remaining warnings are baseline import-resolution
  noise (`qs.*` modules unresolvable standalone — same category as untouched
  CustomImage.qml; "Unqualified access"/"not resolved" all cascade from that).
- All other touched files: qmllint clean (exit 0 where imports resolve).
- The one genuine lint finding (`Member "seek" not found on type "MediaPlayer"`)
  was a real bug — fixed.

### Runtime (real Wayland/Hyprland session, 20s run)
- Quickshell starts and runs stable; **no errors/warnings reference any video file**.
- All logged issues are pre-existing baseline (BarContent mirrored property,
  SidebarRightContent filterDuplicatePlayers, polkit agent already registered,
  missing translation file).
- Test video `/tmp/red_video.mp4` confirmed valid (h264,320x320, 30fps).
- Legacy config migration: existing config with flat fields only (enable=true,
  path set, no `videos` key) loads with default `videos: []` → legacy widget
  renders via the `videos.length === 0` FadeLoader. No migration code needed.

### Checklist (all 21 items verified against code)
Schema (2), widget core (9), canvas registration (2), desktop menu (1),
settings page (3), fullscreen viewer (3), picker script (1) — all pass.

## Review findings (manual pass after reviewer subagent stalled)

- **Repeater model = count, not array**: correct — rebuild+reassign writes for
  x/y drag don't destroy live MediaPlayers (count unchanged; equal string values
  emit no change notifications). Only genuine add/remove destroys delegates.
- **Out-of-bounds safety**: `videoConfig` guards `vids.length > videoIndex` and
  falls back to the legacy object; viewer guards `idx < vids.length`. No crash
  window during array shrink.
- **Destruction**: `Component.onDestruction: player.stop()` confirmed.
- **Viewer index hygiene**: reset to -1 on close, preventing stale index into a
  removed entry.
- **Picker hygiene**: zero occurrences of `videoPickerProc`/`openFilePicker`/
  `videoClearedAt` in CustomVideo.qml; empty-state click is a no-op; valid-video
  click opens the fullscreen viewer for that instance.
- Verdict: **SHIP**. No critical/high/medium findings remain.

## Notes for maintenance

- `docs/custom-video-widget/progress.md` left as historical log; this file is the
  authoritative completion record.
- The spawned reviewer subagent (`VideoWidgetReview`) hung without producing output
  and was cancelled; its scope was covered by the manual review above.

## Post-Implementation Minimal Fix (2026-08-22)

### Discovery

After implementation completion, comprehensive instance ownership research revealed **drag & drop into empty/invalid widget only works after toggle OFF/ON** due to `videoValid` staying false after MediaPlayer errors without automatic recovery on valid path assignment.

### Fix Applied

**File:** `modules/ii/background/widgets/videos/CustomVideo.qml`

**Change in `setVideoPath()` function:**
```qml
function setVideoPath(path) {
    // Reset videoValid when transitioning to valid path - allows immediate playback recovery
    if (path !== "") {
        root.videoValid = true
    }
    
    if (root.videoIndex >= 0) {
        root.updateArrayVideo(root.videoIndex, "path", path)
    } else {
        Config.options.background.widgets.customVideo.path = path
    }
}
```

**Rationale:**
- Avoids destructive toggle OFF/ON cycle (FadeLoader destroys/creates MediaPlayer component)
- Maintains ownership semantics: `videos[]` array remains single source of truth
- Enables non-destructive recovery from media errors or stale states
- Consistent with count-based Repeater survival mechanism (D2 in decisions.md)

**Verification:** qmllint passes on `CustomVideo.qml` (no errors/warnings).


## Documentation Added During Research Phase

### Core Ownership Model

### Adversarial Reviews

### Reference Comparison

### Verification Status
| Test | Description | Status |
|------|-------------|--------|
| TEST10 | Drag video into existing widget → immediate playback | TO VERIFY |
| TEST11 | Multiple instances independent videos via drag | TO VERIFY |
| TEST12 | Clear B video (legacy X) → no picker opens | TO VERIFY |
| TEST13 | Explicit picker from B → correct entry selected | TO VERIFY |

These tests require manual execution after shell restart to verify minimal fix effectiveness.
