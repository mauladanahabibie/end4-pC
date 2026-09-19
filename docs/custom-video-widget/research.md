# Custom Video Widget — Research

Consolidated findings from 5 scout subagents (MenuLifecycle, ShapeSystem, ArchAudit,
VideoLifecycle, PickerTrace) plus direct file verification. No findings invented; all
line numbers verified against the working tree on 2026-08-22.

## The four reported problems

1. Shape selection broken → widget becomes a plain rectangle.
2. Context menu does not expose "Custom Video", only "Custom Image".
3. Custom Video widgets cannot be deleted and cannot be re-added after deletion.
4. Removing the video media auto-opens the file picker instead of requiring explicit user action.

## Repository architecture (relevant subset)

Quickshell (Qt6/QML) desktop shell "end4-pC". Widget stack:

- `modules/common/Config.qml` — FileView + JsonAdapter persistence. The QML property
  tree IS the schema; saved JSON overlays declared defaults on load. Any property
  mutation fires `onAdapterUpdated` → 50 ms-debounced whole-file `writeAdapter()`
  (L55-62, L64-76). `list<var>` arrays persist ONLY via full rebuild+reassign; in-place
  nested mutation does not notify.
- `modules/ii/background/Background.qml` — `Variants { model: Quickshell.screens }`,
  one bottom-layer PanelWindow per screen, each with a `WidgetCanvas` (L472). Widget
  presence is declarative: singleton types get one `FadeLoader` gated on
  `widgets.<name>.enable` + screenList filter; `customImage` additionally gets a
  `Repeater` over `widgets.customImage.images` (L517-535) spawning one
  FadeLoader+CustomImage per array entry. Legacy single image loader at L502-515
  (`imageIndex: -1`, gated on `images.length === 0`).
- `modules/ii/background/widgets/AbstractBackgroundWidget.qml` — binds each widget to
  ONE config entry by `configEntryName` (L19); default `targetX/targetY` clamp
  `configEntry.x/y` (L21-24); default `onReleased` writes `configEntry.x/y` (L41-47).
  Hard singleton assumption — multi-instance widgets must override.
- `modules/common/widgets/widgetCanvas/AbstractWidget.qml` — IS itself a MouseArea
  (L8); subclass `onClicked` handlers accumulate.
- `modules/common/widgets/FadeLoader.qml` — Loader fading on `shown`;
  `active: opacity > 0` (lazy teardown).
- Identity: array INDEX (no ID field). Deleting index i shifts later entries; the
  Repeater destroys/recreates shifted delegates (fade reload; positions survive in the
  entry's x/y).

## Problem 1: shape selection

- `Config.qml` L343: `customVideo.shape: "Cookie4Sided"` EXISTS and persists.
- `BackgroundConfig.qml` L1281-1295: video Shape subsection with
  `ConfigSelectionShapeArray` bound to `customVideo.shape`, options
  `page.customImageShapes` (32-name list at L17-24) — ALREADY PRESENT.
- `CustomVideo.qml` reads shape at L192/L206 (`videoShape.shape =
  getShape(videoConfig.shape ?? "Cookie4Sided")`), mask shape follows at L224.
- Masking: invisible VideoOutput + invisible white MaterialShape mask +
  `MaskMultiEffect` (MultiEffect; OpacityMask would freeze video frames via FBO
  caching — documented at CustomVideo.qml L208-212). Correct approach, keep it.
- The singleton chain works. What was missing: per-instance shape for multiple video
  widgets — requires the `videos[]` array with per-entry `shape`.

## Problem 2: context menu "Custom Video" missing

- `DesktopMenu.qml` L318-334: "Add Custom Video" RippleButton EXISTS (verified).
  Runtime invisibility suspected stale shell process or menu overflow.
- `WidgetsSubmenu.qml` L17 also has a customVideo enable toggle.
- The real asymmetry: image add APPENDS to an array; video add OVERWRITES the
  singleton path (DesktopMenu.qml L72-82: `enable = true; path = data`). Second add
  replaces the first — appears "cannot add another".

## Problem 3: cannot delete / re-add

- Image delete (`CustomImage.qml` L305-321 `deleteThisImage`) rebuilds the array
  WITHOUT the element → Repeater destroys the delegate. Clean.
- Video delete (`CustomVideo.qml` L424-427) only does `setVideoPath("")` (L440-442):
  clears one string. `enable` stays true; FadeLoader stays loaded; widget remains an
  empty shell. There is no array element to remove and no Repeater.
- Root cause stack: (1) Config schema — no `videos` array; (2) menu overwrites;
  (3) single FadeLoader, no Repeater; (4) delete clears path instead of removing entry.

## Problem 4: picker auto-opens after delete

- No B-F class opens the picker programmatically (no Timer/onCompleted/onPathChanged
  trigger exists — grep-verified). The vector is the X click itself: AbstractWidget IS
  the root MouseArea; the child deleteArea handles the click AND the root onClicked
  (L62-70) also fires for the same press. After `setVideoPath("")`, the root handler
  sees `videoPath === ""` → `openFilePicker()` (L66).
- The 800 ms `videoClearedAt` guard (L56/L65/L425) is a timing band-aid covering only
  the immediate same-click case; slow double-clicks, restart-with-empty-path, config
  reload, and missing-file clicks still open the picker on next click.
- Only legitimate picker-open sites (explicit user action): settings `folder_open`
  button (BackgroundConfig.qml L1267), fullscreen viewer `video_library` button
  (FullscreenVideoViewer.qml L211), desktop menu "Add Custom Video"
  (DesktopMenu.qml L331-332).
- Recommendation: remove the widget-local picker entirely; clicking a valid video opens
  the fullscreen viewer; empty-state click is a no-op.

## Multi-instance blueprint (from ArchAudit, adopted)

Six integration points to mirror CustomImage:

1. Schema: `Config.qml` add `property list<var> videos: []` to customVideo.
2. Instantiation: `Background.qml` legacy FadeLoader (gated `videos.length === 0`)
   + Repeater over videos with `videoIndex`.
3. Widget: `videoIndex` property, array/legacy `videoConfig` resolver, `targetX/Y`
   overrides, `onReleased` grid-hide-first + per-entry x/y write,
   `updateArrayVideo`/`deleteThisVideo` helpers, X gated on `videoIndex >= 0`.
4. Desktop menu: append to `videos` (mirror image L55-67), set enable at button click.
5. Fullscreen viewer: index-aware via `GlobalStates.customVideoFullscreenIndex`;
   resolve path per entry; retarget setVideoPath/muted writes.
6. Settings: per-entry list UI mirroring image rows (path, shape, size, picker, remove)
   + per-entry playback switches; legacy section gated on `videos.length === 0`.

## Critical constraints (from VideoLifecycle)

- `Repeater { model: videosArray }` + rebuild-and-reassign writes would destroy and
  recreate EVERY MediaPlayer on every config write (drag release, resize, mute...).
  MITIGATION: use `model: videos.length` — count-based model; delegates keyed by count
  survive array reassignment; bindings re-read fresh entries.
- Power gating bug at CustomVideo.qml L44-46: both flags false → returns true
  ("gating disabled"), i.e. plays anyway. Must become:
  `Battery.isPluggedIn ? playWhenCharging : playWhenOnBattery` (both false = never).
- Add `Component.onDestruction: player.stop()` for clean pipeline teardown.
- Known acceptable tradeoffs (documented, not fixed): MediaPlayer keeps decoding during
  lock-screen fade; fullscreen viewer double-decodes while open; playIntent resets to
  autoplay default on path change. Out of scope for this task.

## Files inspected

- modules/common/Config.qml (schema L227-390, persistence L46-76)
- modules/ii/background/Background.qml (widget canvas L472-560)
- modules/ii/background/widgets/AbstractBackgroundWidget.qml (full)
- modules/common/widgets/widgetCanvas/AbstractWidget.qml (via scout)
- modules/common/widgets/FadeLoader.qml, MaskMultiEffect.qml, ConfigSelectionShapeArray.qml
- modules/ii/background/widgets/images/CustomImage.qml (full — reference implementation)
- modules/ii/background/widgets/videos/CustomVideo.qml (full)
- modules/ii/background/FullscreenVideoViewer.qml (full)
- modules/ii/desktopMenu/DesktopMenu.qml (procs L40-82, buttons L297-368)
- modules/ii/settings/pages/BackgroundConfig.qml (helpers L17-59, image section
  L959-1168, video section L1170-1327)
- GlobalStates.qml (customVideoFullscreenOpen L49, IPC L112-121)
- panelFamilies/IllogicalImpulseFamily.qml (FullscreenVideoViewer at L34)
- scripts/images/pick-video.py, pick-image.py (zenity/kdialog dialogs)
- services/Battery.qml (UPower: available L12, isPluggedIn L15)
