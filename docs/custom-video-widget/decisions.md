# Custom Video Widget — Architectural Decisions

Decisions made during implementation, with rationale and rejected alternatives.
Future agents: read this before changing approach.

## D1: Identity = array index (no ID field)
**Decision:** Videos are identified by position in `customVideo.videos`, exactly like
`customImage.images`.
**Why:** The repo has no ID system; CustomImage is the proven multi-instance precedent.
Adding IDs would require migration logic and touch every consumer.
**Tradeoff accepted:** deleting index i shifts later entries; Repeater delegates are
recreated. Count-based model (D2) makes that recreation harmless for players only when
entries at surviving indices keep their content; deletion still restarts surviving
players if the Repeater model changed — with `model: count`, count changes only when
entries are added/removed, so surviving players only recreate on add/remove, not on
every config write.

## D2: Repeater uses `model: videos.length`, NOT `model: videos`
**Decision:** `Repeater { model: Config...customVideo.enable && screenInList ? Config...customVideo.videos.length : 0 }`.
**Why (VideoLifecycle scout):** the persistence idiom is rebuild-and-reassign the whole
array. With `model: videos`, every reassignment destroys and recreates ALL delegates →
every MediaPlayer restarts from frame 0 on each drag release / resize / mute toggle.
With a count-based model, delegates keyed by integer index survive reassignment when the
count is unchanged; their bindings re-read the fresh array objects.
**Rejected:** `model: videos` (mirrors image literally but destroys players on every
write), and patch-in-place array mutation (would break persistence: in-place nested
mutation does not fire JsonAdapter change notification).

## D3: Legacy singleton kept alongside the array
**Decision:** when `videos.length === 0`, a legacy FadeLoader renders `videoIndex:-1`
bound to the scalar fields (path/shape/size/x/y + playback flags). Same as the image
legacy loader.
**Why:** backward compatibility with existing configs (current live config has
`customVideo.path` set, no `videos` key). No migration needed; JSON overlay fills the
missing `videos` key with `[]`.
**Rejected:** one-time migration moving the legacy path into `videos[0]` (riskier,
rewrites user data, breaks the settings legacy UX precedent set by Custom Image).

## D4: Widget-local file picker REMOVED
**Decision:** CustomVideo.qml loses `videoPickerProc` and `openFilePicker()`. Clicking
an empty widget is a no-op. Videos are added via desktop menu "Add Custom Video" or the
settings page; a video's file is replaced via drag & drop or the settings row picker.
**Why (PickerTrace scout):** the widget-local picker was the ONLY implicitly reachable
picker; the X-delete click double-fires into the root onClicked empty-state branch and
re-opens the picker. The 800ms `videoClearedAt` guard was a timing band-aid. Removing
the widget-local picker eliminates every implicit-open path at its single choke point.
**Rejected:** keeping the picker and hardening the guard (still bypassed by restart /
config reload / slow double-click; adds state instead of removing a bad policy).

## D5: Per-entry fields in `videos[]`
**Decision:** entry = `{path, shape, size, x, y, autoplay, loop, muted,
playWhenCharging, playWhenOnBattery}`. Type-level scalar fields remain as defaults for
new entries and as the legacy singleton state.
**Why:** spec requires per-instance autoplay/loop/muted/power behavior (VideoLifecycle
recommended exactly this set). Type-level `enable` stays global (WidgetsSubmenu toggle).
**Rejected:** per-entry `placementStrategy` (images don't have it per-entry either;
least-busy placement for N videos is out of scope — array entries use free placement).

## D6: Fullscreen viewer addressed by index in GlobalStates
**Decision:** add `GlobalStates.customVideoFullscreenIndex: int` (default -1). Viewer
resolves `videos[index]` when index >= 0, else legacy scalar path. `customVideoFullscreenOpen`
bool kept as the open flag (IPC openFullVideo/closeFullVideo unchanged in signature).
**Why:** minimal change; the viewer is a single global instance anyway.
**Rejected:** passing a path string through GlobalStates (would drift from config truth
on external edits), and removing the viewer (existing feature, works, out of scope).

## D7: Settings page mirrors the image list UI
**Decision:** Custom Video section keeps the Enable switch; a "Videos" subsection with
per-entry rows (path label + remove button, shape picker via the shared
`ConfigSelectionShapeArray`, size spinbox, folder_open picker button, per-entry
autoplay/loop/muted/power switches) + ToolbarPairedFab add button. Legacy Video/Shape
subsections visible only when `videos.length === 0`. Page-level helpers
`addCustomVideo/removeCustomVideo/updateCustomVideo` mirror the image helpers.
**Why:** reuse of existing components (ConfigSelectionShapeArray, ConfigSwitch,
ConfigSpinBox, ToolbarPairedFab, RippleButton) keeps the Material visual language; the
image section is the exact structural precedent.
**Rejected:** a bespoke video list design (violates "no AI-generated UI / smallest
clean change").

## D8: Power gating semantics fixed
**Decision:** `powerAllowsPlay = !Battery.available ? true : (Battery.isPluggedIn ?
playWhenCharging : playWhenOnBattery)`. Both flags false → never plays.
**Why:** VideoLifecycle found the old `both false → true` branch played anyway, which
contradicts user intent.
**Rejected:** adding a separate "power gating enabled" toggle (schema bloat; both-false
is a sufficient off switch).

## D9: X button visibility for legacy singleton
**Decision:** array entries: X removes the entry (`deleteThisVideo`). Legacy singleton
(videoIndex -1): X clears the path (`setVideoPath("")`) — same as before, since the
legacy widget stays as a placeholder shell by design (matches legacy image behavior).
**Why:** preserves existing legacy behavior; the reported delete problem is about
instances added via the menu, which become array entries.

## D10: `Component.onDestruction: player.stop()`
**Decision:** added to CustomVideo for clean GStreamer pipeline teardown.
**Why (VideoLifecycle):** teardown was purely implicit; stop() flushes the decoder.
