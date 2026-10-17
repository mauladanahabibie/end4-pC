# Custom Video Widget Playback Implementation Plan

## 1. Objectives & Scope
Implement configurable, power-aware, and fullscreen-aware playback controls for the Custom Video widget in the Quickshell desktop rice.

Key Requirements:
1. **Master Toggle:** `enablePlaybackRules` — when disabled, automatic rules do not interfere with manual playback.
2. **Autoplay:** `autoplay` — automatically starts playback when the widget loads/becomes active, if allowed.
3. **Fullscreen Rule:** `pauseInFullscreen` — pauses the widget when its fullscreen viewer opens; resumes when closed only if previously playing.
4. **Battery Rule:** `pauseOnBattery` — pauses playback when disconnected from AC power.
5. **Charging Resume:** `resumeWhenCharging` — resumes playback when external power is restored, provided it was playing before the power pause.
6. **Visibility Rule:** `pauseWhenHidden` — pauses playback when the widget is hidden or disabled.
7. **Manual Control Preservation:** Manual pause must never be overridden by automatic events.
8. **Multi-Instance Isolation:** Independent playback state per widget instance, identified by stable `videoIndex`.
9. **Settings Persistence:** UI settings in `BackgroundConfig.qml` stored persistently in `Config.options` / `config.json`.
10. **Zero Regression:** No regressions in widget movement, resizing, drag-and-drop, explicit file picker, or deletion.

---

## 2. Exact Changes Required

### Change 1: Configuration Schema (`modules/common/Config.qml`)
- Add new properties under `JsonObject customVideo`:
  - `property bool enablePlaybackRules: true`
  - `property bool pauseInFullscreen: true`
  - `property bool pauseOnBattery: true`
  - `property bool resumeWhenCharging: true`
  - `property bool pauseWhenHidden: true`
- Keep existing properties (`enable`, `placementStrategy`, `x`, `y`, `path`, `shape`, `size`, `autoplay`, `loop`, `muted`, `playWhenCharging`, `playWhenOnBattery`, `videos`).

### Change 2: Settings UI (`modules/ii/settings/pages/BackgroundConfig.qml`)
- Restructure the top of the Custom Video section:
  - Add a dedicated `ContentSubsection` for **Playback**:
    - `ConfigSwitch`: "Enable playback rules" (icon: `"tune"`, master toggle for `enablePlaybackRules`).
    - `ConfigSwitch`: "Autoplay" (icon: `"autoplay"`, `autoplay`).
    - `ConfigSwitch`: "Pause in fullscreen" (icon: `"fullscreen"`, `pauseInFullscreen`).
    - `ConfigSwitch`: "Pause on battery" (icon: `"battery_alert"`, `pauseOnBattery`).
    - `ConfigSwitch`: "Resume when charging" (icon: `"battery_charging_full"`, `resumeWhenCharging`, enabled when `pauseOnBattery`).
    - `ConfigSwitch`: "Pause when hidden" (icon: `"visibility_off"`, `pauseWhenHidden`).
  - Child switches are visually enabled only when `enablePlaybackRules` is checked.
  - Remove redundant/duplicate switch lists in lines 1375–1430 vs 1432–1483.
  - Ensure multi-video array cards allow per-video `autoplay`, `loop`, `muted` settings.

### Change 3: Playback Policy Coordinator (`modules/ii/background/widgets/videos/CustomVideo.qml`)
- **Power Detection Integration:**
  - Import `Quickshell.Services.UPower` and `qs.services`.
  - Compute `isExternalPowerConnected`:
    - If `!Battery.available`: desktop or no battery -> return `true`.
    - Else: return `!UPower.onBattery || Battery.isPluggedIn || Battery.chargeState == UPowerDeviceState.FullyCharged`.
  - Compute `isOnBattery`: `Battery.available && !isExternalPowerConnected`.
- **Fullscreen Detection:**
  - Compute `isThisInstanceInFullscreen`:
    `GlobalStates.customVideoFullscreenOpen && (GlobalStates.customVideoFullscreenIndex === root.videoIndex)`.
- **Visibility Detection:**
  - Compute `isWidgetHidden`: `!root.visible || !Config.options.background.widgets.customVideo.enable`.
- **Rule Coordination State Properties:**
  - `property bool userManualPaused: false`
  - `property bool wasPlayingBeforeAutoPause: false`
  - `property bool autoPausedByBattery: false`
  - `property bool autoPausedByFullscreen: false`
  - `property bool autoPausedByHidden: false`
  - `readonly property bool pauseConditionFullscreen`:
    `root.rulesEnabled && root.rulePauseInFullscreen && root.isThisInstanceInFullscreen`
  - `readonly property bool pauseConditionBattery`:
    `root.rulesEnabled && root.rulePauseOnBattery && root.isOnBattery`
  - `readonly property bool pauseConditionHidden`:
    `root.rulesEnabled && root.rulePauseWhenHidden && root.isWidgetHidden`
  - `readonly property bool hasActivePauseCondition`:
    `pauseConditionFullscreen || pauseConditionBattery || pauseConditionHidden`
- **State Machine Evaluation (`evaluatePlayback()`):**
  - Consolidates state transitions:
    - If `hasActivePauseCondition`:
      - If playing, capture `wasPlayingBeforeAutoPause = true` and pause `player`.
    - Else (no active pause condition):
      - If `!userManualPaused && wasPlayingBeforeAutoPause && root.videoValid`:
        - If power was the reason, only resume if `ruleResumeWhenCharging` is allowed (or cleared).
        - Resume playback (`player.play()`), reset `wasPlayingBeforeAutoPause = false`.
  - Manual Play/Pause button updates `userManualPaused` and triggers `evaluatePlayback()`.

---

## 3. Test Plan for Verification

| # | Test Scenario | Steps | Expected Outcome |
|---|---|---|---|
| 1 | Master playback rules disabled | Disable `enablePlaybackRules`. Disconnect AC power or open fullscreen. | Video continues playing unaffected. Manual play/pause works. |
| 2 | Autoplay enabled & disabled | Set `autoplay: false`, reload video. Set `autoplay: true`, reload. | False: video stays paused at frame 0. True: starts playing immediately. |
| 3 | Pause in fullscreen | Open fullscreen viewer with `pauseInFullscreen: true`. Close viewer. | Background video pauses on open; resumes automatically on close. |
| 4 | Pause on battery | Disconnect AC power with `pauseOnBattery: true`. | Video pauses immediately upon unplugging AC. |
| 5 | Reconnect AC (Resume when charging) | Video auto-paused by battery -> reconnect AC with `resumeWhenCharging: true`. | Video resumes playback immediately upon reconnecting AC. |
| 6 | Reconnect AC after manual pause | Video auto-paused by battery -> user clicks Pause button -> reconnect AC. | Video remains paused (manual pause preserved). |
| 7 | Overlapping rules (Fullscreen + Battery) | Video playing -> battery unplugged (pauses) -> fullscreen opened -> AC reconnected -> fullscreen closed. | Video remains paused while fullscreen is open; resumes only after fullscreen is closed. |
| 8 | Multi-instance isolation | Add 2 video widgets on desktop. Open fullscreen for Video 1. | Video 1 background pauses; Video 2 continues playing unaffected. |
| 9 | Settings persistence across restarts | Toggle settings in BackgroundConfig -> restart Quickshell (`killall qs; qs -c end4-pC`). | All playback toggles retain their saved values in `config.json`. |
| 10 | Desktop / Missing power state | Run on system where `Battery.available == false`. | Power rule treats power as connected; no false battery pauses or loops. |
