# Custom Video Playback Rules & Power Controls — Progress

## Implementation Checklist

### Phase 1: Research & Planning
- [x] Inspect existing Custom Video implementation (`CustomVideo.qml`, `WidgetsLoader.qml`).
- [x] Inspect fullscreen viewer architecture (`FullscreenVideoViewer.qml`, `GlobalStates.qml`).
- [x] Inspect battery & power detection (`services/Battery.qml`, `Quickshell.Services.UPower`).
- [x] Inspect settings schema and UI (`Config.qml`, `BackgroundConfig.qml`).
- [x] Document research in `docs/custom-video-widget/playback-research.md`.
- [x] Create comprehensive implementation plan in `docs/custom-video-widget/playback-plan.md`.
- [x] Initialize tracking in `docs/custom-video-widget/playback-progress.md`.

### Phase 2: Schema & Settings UI
- [x] Add playback configuration options to `modules/common/Config.qml`:
  - `enablePlaybackRules`
  - `autoplay`
  - `pauseInFullscreen`
  - `pauseOnBattery`
  - `resumeWhenCharging`
  - `pauseWhenHidden`
- [x] Add dedicated Playback section in `modules/ii/settings/pages/BackgroundConfig.qml` with Material Design styling.
- [x] Verify settings serialization to `~/.config/illogical-impulse/config.json`.

### Phase 3: Playback Policy State Machine in `CustomVideo.qml`
- [x] Implement reactive power state detection via `UPower.onBattery` and `Battery.available`.
- [x] Implement per-instance fullscreen detection via `GlobalStates.customVideoFullscreenIndex === root.videoIndex`.
- [x] Implement visibility / active tracking.
- [x] Implement coordinated playback policy state machine:
  - Track `userManualPaused`, `wasPlayingBeforeAutoPause`, active pause condition bitmask/flags.
  - Handle overlapping pause conditions without conflicting play/pause loops.
  - Coordinate manual controls with automatic rules.
- [x] Multi-instance state isolation verification.

### Phase 4: Regression Testing & Scenario Verification
- [x] Test 1: Master playback rules disabled. (PASSED)
- [x] Test 2: Autoplay enabled & disabled. (PASSED)
- [x] Test 3: Pause in fullscreen. (PASSED)
- [x] Test 4: Pause on battery. (PASSED)
- [x] Test 5: Reconnect AC (Resume when charging). (PASSED)
- [x] Test 6: Reconnect AC after manual pause. (PASSED)
- [x] Test 7: Overlapping rules (Fullscreen + Battery). (PASSED)
- [x] Test 8: Multi-instance isolation. (PASSED)
- [x] Test 9: Settings persistence across restarts. (PASSED)
- [x] Test 10: Missing/unavailable power-state handling. (PASSED)
- [x] Non-regression: Empty widget click -> file picker. (PASSED)
- [x] Non-regression: Drag-and-drop video file onto widget. (PASSED)
- [x] Non-regression: Moving & resizing widget. (PASSED)
- [x] Non-regression: Deleting widget instance. (PASSED)

### Phase 5: Documentation & Git Push
- [x] Update documentation and progress records.
- [x] Commit and push to `maulan/main`.
