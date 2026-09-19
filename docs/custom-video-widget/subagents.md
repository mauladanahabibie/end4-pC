# Custom Video Widget — Subagent Research Log

Five read-only scout subagents completed their investigations before implementation
began. All findings below are theirs; nothing was invented afterwards.

---

## 1. ArchAudit — architecture/generic widget system

**Role:** Scout (read-only architecture audit).
**Investigated:** How CustomImage's multi-instance lifecycle works end to end; what a
multi-instance CustomVideo must replicate.

**Findings (condensed):**
- Widget identity == array index. No ID system exists anywhere.
- CustomImage flow: context-menu add (deep-copy array + push + reassign), Repeater in
  Background.qml instantiating one FadeLoader per entry, `imageIndex` resolver,
  `targetX/targetY` overrides, `onReleased` grid-hide-first + `updateArrayImage` +
  `restoreXYBinding`, `deleteThisImage` entry removal.
- AbstractBackgroundWidget has hard singleton assumptions: `configEntry.x/y` write-back
  on drag release (last-write-wins across instances), shared `placementStrategy`.
- Config persistence: JsonAdapter property tree is the schema; `list<var>` arrays only
  persist via full rebuild + reassign (in-place nested mutation does NOT notify).
- Repeater delegates are destroyed/recreated when the array is reassigned.

**Relevant files:** `modules/common/Config.qml`, `modules/ii/background/Background.qml`,
`modules/ii/background/widgets/AbstractBackgroundWidget.qml`,
`modules/ii/background/widgets/images/CustomImage.qml`,
`modules/common/widgets/widgetCanvas/AbstractWidget.qml`,
`modules/common/widgets/FadeLoader.qml`.

**Recommendations (adopted):**
1. Add `list<var> videos: []` to `customVideo` schema.
2. Repeater in Background.qml gated `enable && screenFilter`, delegates pass `videoIndex`.
3. Widget: `videoIndex` + resolver + `targetX/Y` override + `onReleased` override +
   `updateArrayVideo` + `deleteThisVideo`.
4. DesktopMenu appends to array instead of overwriting singleton.
5. Fullscreen viewer must become index-aware (GlobalStates carrier).
6. Settings must get a per-video list UI.

---

## 2. MenuLifecycle — context menu + delete/recreate lifecycle

**Role:** Scout (read-only).
**Investigated:** Why "Add Custom Video" overwrites instead of appending; why deletion
leaves a stale widget; full picker call chains from the menu.

**Findings:**
- "Add Custom Image" button (DesktopMenu.qml ~302-315) force-enables the widget then
  launches `pick-image.py`; stdout handler deep-copies `images`, pushes a new entry,
  reassigns — every pick appends.
- "Add Custom Video" button (~318-334) launches `pick-video.py`; stdout handler sets
  `customVideo.enable = true` and OVERWRITES `customVideo.path`. No new instance ever.
- Video "delete" only runs `setVideoPath("")`; `enable` stays true, the JsonObject
  persists, FadeLoader (keyed only on `enable`) keeps the empty shell instantiated.
- FullscreenVideoViewer is instantiated globally via PanelLoader and reads/writes the
  same singleton (`videoConfig.path`, drop-replace, MediaPlayer source).

**Relevant files:** `modules/ii/desktopMenu/DesktopMenu.qml`,
`modules/ii/background/widgets/videos/CustomVideo.qml`,
`modules/ii/background/FullscreenVideoViewer.qml`, `GlobalStates.qml`,
`panelFamilies/IllogicalImpulseFamily.qml`, `modules/common/widgets/FadeLoader.qml`.

**Recommendations (adopted):** exact 5-step array migration (schema array, menu append,
Repeater, index-based widget binding + deleteThisVideo, viewer retargeting).

---

## 3. ShapeSystem — shape selection system

**Role:** Scout (read-only).
**Investigated:** How shape selection is wired for Custom Image vs Custom Video; whether
anything is missing for video shapes.

**Findings:**
- The full singleton chain is already wired for the legacy single video: Config.qml
  `customVideo.shape` (line 343) → settings `ConfigSelectionShapeArray`
  (BackgroundConfig.qml1281-1295) → live binding in CustomVideo.qml (shape at
  videoShape/shadowShape/videoMaskShape).
- Shared components: `ConfigSelectionShapeArray` (selector, canonical name→enum map),
  `page.customImageShapes` (32-name list, de-facto shared model), `MaterialShape`
  (35-entry Shape enum), `MaskMultiEffect`.
- Video masking via MaskMultiEffect (MultiEffect) is CORRECT; OpacityMask caches its FBO
  and would freeze live video frames. Image keeps OpacityMask because it's static.
- Controls overlay is deliberately outside the masked shape so wavy edges don't clip
  buttons.
- Four duplicated name→enum switches exist; `ConfigSelectionShapeArray.getShape` is the
  canonical one.

**Conclusion:** For the singleton nothing is missing. For multi-instance, per-entry
`shape` in the `videos` array + per-row `ConfigSelectionShapeArray` in settings is the
required work.

**Relevant files:** `modules/ii/settings/pages/BackgroundConfig.qml`,
`modules/common/widgets/ConfigSelectionShapeArray.qml`, `modules/common/Config.qml`,
`modules/common/widgets/MaterialShape.qml`, `modules/common/widgets/MaskMultiEffect.qml`.

---

## 4. VideoLifecycle — multimedia lifecycle + multi-instance readiness

**Role:** Scout (read-only).
**Investigated:** MediaPlayer/AudioOutput lifecycle, playback state machine races,
masking cost, every singleton coupling, resource cleanup.

**Findings:**
- No `player.stop()` / no destruction hooks anywhere; teardown is implicit via Loader
  unload.
- Lock-screen fade (opacity 0) does NOT pause playback — video keeps decoding while
  invisible.
- Fullscreen viewer creates a second independent MediaPlayer while the widget keeps
  playing: double decode, potential double audio.
- Power gating bug: `if (!playWhenCharging && !playWhenOnBattery) return true` means
  "user disabled both power modes" still plays.
- `playIntent` reset on every path change discards manual pause; optimistic `videoValid`
  plays before probe; `StalledMedia` admitted by the ready window.
- **CRITICAL:** CustomImage's rebuild-the-entire-array write strategy would destroy and
  recreate every MediaPlayer on every config write if used as `model: videos` — all
  videos restart from frame 0 on each drag release.

**Relevant files:** `modules/ii/background/widgets/videos/CustomVideo.qml`,
`modules/ii/background/FullscreenVideoViewer.qml`, `services/Battery.qml`,
`modules/ii/background/Background.qml`, `modules/common/Config.qml`, `GlobalStates.qml`.

**Recommendations (adopted):**
- Use `model: videos.length` in the Repeater (delegates keyed by integer survive array
  reassignment; bindings re-evaluate against the new array objects) while keeping
  rebuild+reassign for persistence.
- Per-entry schema: `{path, shape, size, x, y, autoplay, loop, muted, playWhenCharging,
  playWhenOnBattery}` (type-level fields stay as defaults/legacy).
- Index carrier for the fullscreen viewer.
- Fix power gating to `Battery.isPluggedIn ? playWhenCharging : playWhenOnBattery`.
- Add `player.stop()` on destruction.

**Recommendations (deferred, documented):**
- Pause widget player while fullscreen viewer is open (double decode).
- Pause when hidden/locked.
- playIntent reset only on actual file change.

---

## 5. PickerTrace — file picker auto-open investigation

**Role:** Scout (read-only).
**Investigated:** Every path that launches `pick-video.py`; why the picker auto-opens on
delete.

**Findings:**
- Four independent picker Processes: widget-local (CustomVideo.qml), fullscreen viewer,
  settings page, desktop menu. Only the widget-local one is reachable implicitly.
- Root cause of auto-open: the widget root `onClicked` empty-state branch
  (CustomVideo.qml lines 64-66) interprets ANY left click on an empty widget as "pick a
  video". The X-delete click double-fires (deleteArea child MouseArea AND the root
  AbstractWidget MouseArea both receive onClicked for the same press).
- The 800ms `videoClearedAt` guard is a timing band-aid that only masks the immediate
  case; restart, config reload, slow double-clicks, and invalid-file clicks all bypass
  it.
- Nothing auto-launches the picker programmatically (no onCompleted/Timer/path-changed
  trigger) — all implicit opens funnel through the single click branch at lines64-66.

**Relevant files:** `modules/ii/background/widgets/videos/CustomVideo.qml`,
`modules/common/widgets/widgetCanvas/AbstractWidget.qml`,
`modules/ii/background/FullscreenVideoViewer.qml`,
`modules/ii/settings/pages/BackgroundConfig.qml`,
`modules/ii/desktopMenu/DesktopMenu.qml`, `scripts/images/pick-video.py`.

**Recommendations (adopted):**
- Remove the widget-local picker entirely; clicking an empty widget becomes a no-op;
  picker opens only from explicit buttons (settings, desktop menu "Add Custom Video",
  viewer library button). The `videoClearedAt` guard becomes unnecessary and is removed.
- Drag & drop onto the widget remains as an explicit, discoverable replace/add path.
