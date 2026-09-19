# Debug: CustomVideo Widget — Registry / Model / Persistence / State Ownership

Read-only investigation of the quickshell `end4-pC` shell (2026-08-22).
Scope: who owns CustomVideo instance lifecycle/state, how config persistence
works, the current live config state, and whether any mechanism exists that
can resurrect deleted widget instances.

---

## 1. Is there a widget registry / model / enabledWidgets list?

**No. Background widgets are purely declarative — config-driven, no registry.**

- `modules/ii/background/Background.qml`: `Variants` (one `PanelWindow` per
  screen) → `WidgetCanvas` (`anchors.fill: parent`). Each widget type is a
  static `FadeLoader` child whose `shown:` condition reads
  `Config.options.background.widgets.<key>.enable` (+ `screenList` filter).
  Multi-instance types add a `Repeater` whose model is the **array length**:
  - Legacy CustomVideo loader (~L537-553): `shown: customVideo.enable && customVideo.videos.length === 0 && screenOK` → `CustomVideo { videoIndex: -1 }`
  - Array Repeater (~L555-577): `model: (customVideo.enable && screenOK) ? customVideo.videos.length : 0` → delegate `FadeLoader { CustomVideo { videoIndex: index } }`
- The only "widget list" in the codebase is `WidgetsSubmenu.qml` L14-22
  (`widgetList`: static `{key, icon, name}` display list driving settings
  toggles bound to `widgets.<key>.enable`). It is settings-menu UI only;
  `Background.qml` never consults it. No `enabledWidgets`, no registry, no
  model object anywhere.
- No id registry / objectName bookkeeping: widgets never register themselves.
  Canvas discovery is dynamic — `AbstractWidget.findCanvas()` walks the parent
  chain looking for `isWidgetCanvas === true`.
- Note: the task referenced `modules/common/widgets/widgetCanvas/AbstractBackgroundWidget.qml`;
  the actual file is `modules/ii/background/widgets/AbstractBackgroundWidget.qml`
  (`modules/common/widgets/widgetCanvas/` contains only `WidgetCanvas.qml`,
  `AbstractWidget.qml`, `AbstractOverlayWidget.qml`).

### Per-instance state — `AbstractWidget.qml` (common/widgets/widgetCanvas)

`MouseArea` base. Per-instance state is transient UI-only:
`animateXPos/animateYPos`, `draggable`, `gridSize: 12`, `snapEnabled`,
`dragging`, a `dragProxy` Item mirroring drag position, snap `Binding`s on
x/y active only while dragging, Behaviors for animated moves. **No ids, no
objectName, no canvas registration, no persistence.** Right-click toggles
`Config.options.background.widgetsLocked` (config write).

### `WidgetCanvas.qml`

- `readonly property bool isWidgetCanvas: true` — marker for `findCanvas()`.
- `gridSize: 24` (visual grid-line spacing), `showGrid` (transient, true only
  while a drag is active), `gridVisible = showGrid && Config.options.background.showGrid`.
- `centerXActive/centerYActive` transient center-highlight flags;
  `flashLines()` spawns self-destroying Rectangle components.
- **Holds zero per-widget position state.** Children position themselves with
  absolute x/y in canvas coordinates.

### Per-instance state — `AbstractBackgroundWidget.qml` (ii/background/widgets)

- `configEntryName` (required) → `configEntry: Config.options.background.widgets[configEntryName]`
  — a live binding into the singleton config object. **The config entry IS the
  instance identity and state store.**
- `placementStrategy` from `configEntry.placementStrategy`.
- `targetX/targetY` = clamped bindings on `configEntry.x/y`; `x/y` bound to them.
- `visibleWhenLocked`/opacity from `GlobalStates.screenLocked`.
- Auto-placement: `Process` running `scripts/images/least-busy-region-venv.sh`
  when strategy != "free"; result sets `targetX/targetY` and `dominantColor`
  (runtime-only, never persisted).
- `onReleased`: `configEntry.x = root.x; configEntry.y = root.y` — drag end
  persists position into the config entry. **This base-class handler fires for
  EVERY subclass instance (see §6 — duplicate-write finding).**

---

## 2. Persistence machinery — `modules/common/Config.qml`

- Singleton. `filePath = Directories.shellConfigPath` =
  `~/.config/illogical-impulse/config.json` (`Directories.shellConfig` =
  `$XDG_CONFIG_HOME/illogical-impulse`, name `config.json`).
- `FileView configFileView` (L64-77):
  - `path: root.filePath`, **`watchChanges: true`** (inotify-backed file watching),
  - `blockWrites: root.blockWrites`,
  - `onFileChanged: fileReloadTimer.restart()` → after `readWriteDelay` → `configFileView.reload()`,
  - `onAdapterUpdated: fileWriteTimer.restart()` → after `readWriteDelay` → `configFileView.writeAdapter()`,
  - `onLoaded: ready = true`; `onLoadFailed` FileNotFound → `writeAdapter()` (recreates the file).
- **Serialization**: `JsonAdapter` (`configOptionsJsonAdapter`) — declarative
  QML properties ARE the schema. On load, JSON file content is overlaid onto
  the declared defaults (missing keys keep schema defaults, e.g. a config
  without `videos` gets the schema default `videos: []`).
- **`readWriteDelay: 50` ms** debounces BOTH directions (reload and write timers).
- **`blockWrites: false`** by default. Only consumer found: `killDialog.qml`
  (`Config.readWriteDelay = 0; Config.blockWrites = true;` on open — conflict
  killer window suppresses config writes in that process). Never set in the
  main shell.
- **Whole-file writes**: any adapter mutation re-serializes the ENTIRE config
  (`writeAdapter()`); there are no per-key writes.
- **`list<var>` reassignment**: in-place mutation of `list<var>` does not emit
  change notifications, so the codebase idiom is rebuild-and-reassign:
  `Config.options.background.widgets.customVideo.videos = list`
  (CustomVideo.updateArrayVideo/deleteThisVideo, BackgroundConfig
  add/remove/updateCustomVideo, DesktopMenu append — all of them).
  The reassignment fires `adapterUpdated` → 50 ms → whole-file write.
  **Yes: reassigning `videos` writes the entire config.json.**

### External reload watcher — EXISTS

- `FileView.watchChanges: true` IS the watcher. Any external modification of
  `config.json` → `onFileChanged` → 50 ms → `reload()` → adapter values
  replaced from disk → every dependent binding in the shell re-evaluates.
- No other FileSystemWatcher/inotify/Process watches config.json (verified by
  repo-wide grep; `Persistent.qml` watches a different file, `states.json`).
- Known external writers:
  - `scripts/presets.sh --apply` (invoked by `Presets.apply` →
    `Quickshell.execDetached bash`): `jq -s '.[0] * .[1]' config.json preset.json > tmp && mv tmp config.json`
    — out-of-process full-file rewrite → inotify → reload.
  - `scripts/presets.sh --save`: snapshots the ENTIRE live config (including
    the complete `customVideo` object) into `presets/<name>.json`.
  - Any manual/scripted edit of `config.json` (the documented user workflow).

### Stale-instance resurrection: POSSIBLE — confirmed mechanism

Widget instance existence is a **pure function of current config content**
(FadeLoader `shown` conditions + Repeater model). There is no in-memory
registry, tombstone, or "deleted" flag anywhere outside `config.json`.
Deletion (removing a `videos[]` entry, clearing `path`) exists only in the
file. Any external rewrite that restores `enable`/`path`/`videos[]` (preset
apply, manual edit) flips the loaders back on and the widgets are
re-instantiated — a previously deleted instance comes back as a fresh object
reading the restored fields. Nothing in memory can prevent or detect it; the
FadeLoader simply fades back in. See §3 for how little is needed to arm the
legacy instance with the current live config.

---

## 3. Live config snapshot — `~/.config/illogical-impulse/config.json`

`customVideo` object (lines 174-191), captured 2026-08-22:

```json
"customVideo": {
    "autoplay": true,
    "enable": true,
    "loop": true,
    "muted": true,
    "path": "",
    "placementStrategy": "free",
    "playWhenCharging": true,
    "playWhenOnBattery": true,
    "shape": "Circle",
    "size": 240,
    "videos": [],
    "x": 660,
    "y": 252
}
```

Related background fields: `screenList: []` (widgets on ALL screens),
`widgetsLocked: false`, `showGrid: true`.

**Analysis:**
- `enable: true` + `videos: []` → the **legacy** FadeLoader gate
  (`videos.length === 0`) is satisfied: a legacy `CustomVideo` instance with
  `videoIndex: -1` is instantiated on every screen RIGHT NOW.
- Legacy flat fields still hold renderable values: `shape: "Circle"`,
  `size: 240`, `x: 660`, `y: 252`, all playback flags true. Only `path` is empty.
- With `path: ""` the live legacy instance renders the empty placeholder shell
  (`videoValid: false`, movie icon, no media source). **But a single write to
  `customVideo.path`** (drop onto the widget, FullscreenVideoViewer fallback
  write, or any external config edit/preset apply) instantly turns this
  already-instantiated legacy shell into a playing video at (660, 252),
  size 240, Circle shape — no other change required. The flat fields are
  fully populated and armed.

---

## 4. GlobalStates.qml

Properties (L49-50):
- `customVideoFullscreenOpen: bool = false`
- `customVideoFullscreenIndex: int = -1`

IPC handlers — `IpcHandler { target: "background" }` (L113-121):
- `openFullVideo()` → `customVideoFullscreenOpen = true`
  **Does NOT set the index** → the viewer resolves with index -1 → legacy flat
  path/muted/loop.
- `closeFullVideo()` → `customVideoFullscreenOpen = false`
- (`toggleCenteredWallpaper` — unrelated to video)

No IPC handler ever sets `customVideoFullscreenIndex`. It is written only by
widget clicks (`CustomVideo.qml` L87, L345) and reset to -1 by
`FullscreenVideoViewer.close()`.

---

## 5. Background.qml canvas parenting & position storage

- Per monitor: `Variants { model: Quickshell.screens }` → `PanelWindow`
  (WlrLayer.Bottom, namespace `quickshell:background`) → `Item` →
  `WidgetCanvas { id: widgetCanvas; anchors.fill: parent }`.
- All widget FadeLoaders / the Repeater are direct children of `WidgetCanvas`;
  each loaded widget item is parented to its FadeLoader (Loader reparenting),
  so the parent chain widget → FadeLoader → WidgetCanvas satisfies
  `findCanvas()` (`isWidgetCanvas === true`).
- Widget positions are absolute x/y inside the canvas, bound from config.
  **Canvas state (positions) is stored NOWHERE except the config entry
  itself**: flat `customVideo.x/y` (legacy) and `videos[i].x/y` (array). No
  separate canvas-state file. `Persistent.qml` (`states.json`) stores overlay
  widget geometry only — zero background-widget entries.

---

## 6. Duplicate-identity risk: legacy (videoIndex -1) vs array instances

**Gating is mutually exclusive under in-process writes** — legacy requires
`videos.length === 0`, the Repeater requires `videos.length > 0`; a single
config write swaps them (with a fade). BUT both flavors share one config
object (`configEntry = Config.options.background.widgets.customVideo`), and
several flat fields are writable by multiple parties:

**Reads:**
- Legacy: `videoConfig` = the whole `customVideo` object → flat
  path/shape/size/x/y/autoplay/loop/muted/playWhen*.
- Array: `videoConfig` = `videos[i]`; however `placementStrategy`
  (AbstractBackgroundWidget) still reads the FLAT `configEntry.placementStrategy`
  for array instances too — entries carry no placementStrategy field.

**Flat-field writers (shared-write surface):**
- Legacy instance: `setVideoPath/setVideoSize/setVideoMuted` write flat
  `customVideo.path/size/muted`; drag-release writes flat `x/y`.
- Array instances: `updateArrayVideo`/`deleteThisVideo` rebuild-reassign
  `videos[]` only. **However QML does not override base-class signal
  handlers**: `AbstractBackgroundWidget.onReleased` (writes flat
  `configEntry.x/y`) and `CustomVideo.onReleased` (writes `videos[i].x/y`)
  BOTH fire on every drag release of EVERY instance — including array ones.
  Net effect: dragging any array video also clobbers flat `customVideo.x/y`
  with that widget's drop position. Flat x/y is effectively last-writer-wins
  across all instances.
- `FullscreenVideoViewer.updateActiveEntry` (L62-88): when the fullscreen
  index is invalid (<0 or >= videos.length), writes fall through to the FLAT
  object: `Config...customVideo[key] = value`.
- `DesktopMenu.qml` (L79-108): appends a new entry to `videos[]`, SEEDING it
  by copying the flat autoplay/loop/muted/playWhenCharging/playWhenOnBattery
  values; also sets `customVideo.enable = true` (L360-365).
- `BackgroundConfig.qml`: enable toggle + legacy playback switches write flat
  fields; per-entry rows write `videos[]` (rebuild-reassign, L79-104).

**Resurrection scenarios (all via the §2 reload path):**
1. A preset saved while a video existed (legacy path set, or videos[]
   non-empty) is applied later → reload restores those values → instance reappears.
2. Manual/scripted edit restoring `path` or a `videos[]` entry → same.
3. Because the flat fields stay populated (live config: shape/size/x/y set;
   only `path` empty), restoring **only `path`** fully resurrects the legacy
   instance — and since flat x/y is continually clobbered by array-widget
   drags (§6), a resurrected legacy instance lands at whatever position the
   most recently dragged array video wrote.

---

## Verdict

- **Ownership**: `config.json` is the sole registry/model/owner of CustomVideo
  instances. Identity = array index (or the implicit legacy singleton). No
  UUIDs, no in-memory instance list, no enabledWidgets structure.
- **Persistence**: JsonAdapter-over-FileView, 50 ms debounced both ways,
  whole-file writes; `list<var>` changes persisted via rebuild-and-reassign.
- **External reload EXISTS** (`FileView.watchChanges: true`; external writers:
  `presets.sh --apply`, manual edits). It CAN resurrect deleted instances —
  confirmed possible, not hypothetical — because instance existence is a pure
  function of file content and nothing in memory guards against it.
- **Current live state**: legacy singleton is enabled and instantiated on all
  screens as an empty placeholder; flat fields are fully populated, so one
  write to `path` (or an external reload restoring it) makes it render.

## File index

| File | Relevance |
|---|---|
| `modules/ii/background/Background.qml` | Legacy FadeLoader (~L537), count-based Repeater (~L555), WidgetCanvas parenting |
| `modules/ii/background/widgets/videos/CustomVideo.qml` | Resolver L26-34; setters L447-472; deleteThisVideo/updateArrayVideo L475-519; onReleased L521-543 |
| `modules/ii/background/widgets/AbstractBackgroundWidget.qml` | configEntry binding; base onReleased flat x/y write; placement Process |
| `modules/common/widgets/widgetCanvas/AbstractWidget.qml` | Transient drag/snap state only |
| `modules/common/widgets/widgetCanvas/WidgetCanvas.qml` | isWidgetCanvas marker; transient grid/highlight state only |
| `modules/common/Config.qml` | FileView L64-77; timers L46-63; customVideo schema L337-353 |
| `modules/ii/background/FullscreenVideoViewer.qml` | Index resolution L47-60; flat-fallback writes L62-88 |
| `modules/ii/settings/pages/BackgroundConfig.qml` | Array CRUD L79-104; flat-field switches L1224+ |
| `modules/ii/desktopMenu/DesktopMenu.qml` | Append to videos[] L79-108; enable L360-365 |
| `GlobalStates.qml` | customVideoFullscreen* L49-50; IPC L113-121 |
| `scripts/presets.sh` | External whole-file rewrite (--apply) and snapshot (--save) |
| `~/.config/illogical-impulse/config.json` | Live state, customVideo at L174-191 |
