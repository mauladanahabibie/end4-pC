# Root Cause — Custom Video Widget (4 Bugs)

**Date:**2026-09-19
**Status:** Investigation against CURRENT code. Shell loads clean.

---

## Bug 1 — Video Widget Cannot Move (Video Present)

### Reproduction
1. Custom Video with NO video → draggable.
2. Custom Video WITH video → cannot move.

### Event Flow
```
Left-click on widget body
 → AbstractWidget MouseArea (AbstractWidget.qml:7) receives press
 → drag.target = draggable ? dragProxy : undefined (AbstractWidget.qml:9)
 → draggable = placementStrategy === "free" && !widgetsLocked (AbstractBackgroundWidget.qml:36)
 → If widgetsLocked === true: draggable = false → drag.target = undefined → no drag
```

### Exact Object Receiving the Pointer

Root `AbstractWidget` is a `MouseArea`. All children inside `contentItem` (Item).

**CustomVideo contentItem children (z, visible when video present, pointer-interactive):**

| Item | z | visible (video present) | pointer-interactive? |
|------|---|------------------------|---------------------|
| shadowShape |-1 | false | No (Item) |
| StyledDropShadow |-1 | true | No (Item) |
| videoShape (MaterialShape) |0 | true | No (Item) |
| videoOut (VideoOutput) |0 | false | No (Item) |
| videoMaskShape |0 | false | No (Item) |
| MaskMultiEffect | 0 | true | No (MultiEffect=Item, NOT MouseArea) |
| MaterialSymbol |0 | false | No (Item) |
| DropArea |0 | true | Yes — but drag-drop only, NOT mouse press |
| controlsBar (Rectangle) |3 | true (hover) | **Yes** — contains 4× RippleButton (Button) |
| resizeHandle (Rectangle) | 2 | true (hover) | Yes — MouseArea |
| deleteHandle (Rectangle) | 4 | true (hover) | Yes — MouseArea |

**CustomImage (WORKS) contentItem children for comparison:**

| Item | z | visible (image present) | pointer-interactive? |
|------|---|------------------------|---------------------|
| shadowShape |-1 | false | No |
| StyledDropShadow |-1 | true | No |
| imageShape (MaterialShape, layer.enabled:true) | 0 | true | No (Item) |
| StyledImage | 0 | true | No (Item) |
| MaterialSymbol | 0 | false | No |
| DropArea |0 | true | Yes (drag-drop only) |
| resizeHandle |2 | true (hover) | Yes — MouseArea |
| deleteHandle | 2 | true (hover, imageIndex>=0) | Yes — MouseArea |

### Root Cause

**ROOT CAUSE NOT PROVEN for empty-vs-video asymmetry.**

Live config has `widgetsLocked = true` (verified at `/home/danzzalexandra/.config/illogical-impulse/config.json`). With `widgetsLocked = true`, `draggable = false` for ALL widgets — empty and video-present alike. The reported asymmetry cannot occur under this config.

The asymmetry was observed on a stale shell process with unknown config state.

**Structural differences between CustomVideo (broken) and CustomImage (working) when content is present:**
1. CustomVideo has `controlsBar` (z:3) with 4× RippleButton — CustomImage has NO equivalent.
2. CustomVideo deleteHandle `visible: ... || root.videoPath !== ""` — shows for legacy video. CustomImage: `root.imageIndex >= 0` — hidden for legacy.
3. CustomVideo uses MaskMultiEffect (Item, not pointer-interactive). CustomImage uses StyledImage (Item, not pointer-interactive). Neither blocks pointer events.
4. CustomVideo videoShape has NO `layer.enabled`. CustomImage imageShape has `layer.enabled: true` + OpacityMask.

None of these structurally explain why video-present blocks drag while empty doesn't — controlsBar only covers a bottom strip, not full widget.

### Evidence
- AbstractBackgroundWidget.qml:36 — `draggable: placementStrategy === "free" && !Config.options.background.widgetsLocked`
- AbstractWidget.qml:9 — `drag.target: draggable ? dragProxy : undefined`
- Live config: `widgetsLocked = true`
- CustomVideo.qml:265 — controlsBar `opacity: (root.containsMouse && root.videoPath !== "" && root.videoValid) ? 1 :0`
- CustomVideo.qml:386 — deleteHandle `visible: opacity > 0 && (root.videoIndex >= 0 || root.videoPath !== "")`

### Minimal Fix
1. Set `widgetsLocked = false` and test. If drag works → root cause was config.
2. If still fails: add `console.log("[CustomVideo] press", root.draggable)` to AbstractWidget onPressed. Trace whether press reaches root MouseArea when video present.

---

## Bug 2 — File Drag & Drop Does Not Load Video

### Reproduction
1. Drag `.mp4` from file manager onto Custom Video.
2. Expected: video loads.
3. Actual: nothing happens.

### Drop Event Flow
```
File manager drag enters widget
 → DropArea (CustomVideo.qml:229) onEntered
 → drag.accept(Qt.CopyAction), root.dropHover =true
 → User drops → onDropped
 → drop.urls[0] → cleanPath → ext check → setVideoPath(cleanPath)
 → setVideoPath: videoIndex>=0 → updateArrayVideo; else → Config.path
 → MediaPlayer.source = "file://" + videoPath
```

### Exact Failure Point

**Issue1 — `videoValid` binding breakage:**
- Line35: `property bool videoValid: videoPath !== ""` (binding)
- Line419: `root.videoValid = true` (imperative in setVideoPath — breaks binding)
- Line103: `root.videoValid = false` (imperative in onErrorOccurred — breaks binding)

After onErrorOccurred sets `videoValid = false`, the binding is broken. Subsequent `setVideoPath(validPath)` sets `videoValid = true` (line419), but if another error fires, it's stuck at `false` again. `MaskMultiEffect.visible` and `videoOut.layer.enabled` both depend on `videoValid` — if stuck false, video invisible.

**Issue2 — percent-encoding:**
- Line241: `var cleanPath = drop.urls[0].toString().replace(/^file:\/\//, "")`
- Does NOT decode `%20` etc. A file `my video.mp4` arrives as `my%20video.mp4`.
- MediaPlayer.source = `"file://" + "/home/user/my%20video.mp4"` — may not decode.
- CustomImage has same bug (line172-193) but `Image.source` may be more tolerant.

**Issue3 — DropArea z:0 vs controlsBar z:3, deleteHandle z:4:**
- DropArea has no explicit z (defaults to0). controlsBar (z:3) and deleteHandle (z:4) are higher.
- BUT: drag events use different delivery than mouse events. DropArea receives drag events regardless of z, as long as it's the topmost DropArea under the cursor. controlsBar/deleteHandle are NOT DropAreas, so they don't interfere with drag delivery.
- This is NOT the failure point.

### Root Cause

**HYPOTHESIS: percent-encoding + videoValid binding breakage combine to prevent reliable loading.**

The drop event itself likely fires correctly. The path conversion leaves percent-encoded characters. MediaPlayer may fail to load the percent-encoded path, triggering onErrorOccurred, which breaks videoValid binding, making video invisible.

**ROOT CAUSE NOT PROVEN.** Runtime diagnostic needed: add `console.log("[CustomVideo] dropped", drop.urls[0], cleanPath, ext)` in onDropped.

### Evidence
- CustomVideo.qml:35 — `property bool videoValid: videoPath !== ""` (binding)
- CustomVideo.qml:419 — `root.videoValid = true` (imperative, breaks binding)
- CustomVideo.qml:103 — `root.videoValid = false` (imperative, breaks binding)
- CustomVideo.qml:241 — URL conversion without `decodeURIComponent`
- CustomImage.qml:172-193 — identical DropArea pattern

### Minimal Fix
1. Remove imperative `videoValid` assignments (lines419, 103). Let binding handle it. Use separate `property bool videoError` for error state.
2. Add `decodeURIComponent`: `var cleanPath = decodeURIComponent(drop.urls[0].toString().replace(/^file:\/\//, ""))`.

---

## Bug 3 — Empty Widget Click Does Not Open Picker

### Reproduction
1. Click empty Custom Video widget.
2. Expected: picker opens.
3. Actual: nothing.

### Click Event Flow
```
Left-click empty widget
 → AbstractWidget MouseArea receives press
 → drag.target = draggable ? dragProxy : undefined
 → If widgetsLocked=true: draggable=false, drag.target=undefined
 → Press-release without movement → onClicked fires
 → CustomVideo.onClicked (line83)
 → mouse.button === Qt.RightButton? No
 → mouse.button !== Qt.LeftButton? No
 → root.videoPath === "" || !root.videoValid? Yes (empty)
 → videoPickerProc.command = ["python3", `${Directories.scriptPath}/images/pick-video.py`]
 → videoPickerProc.running =true
 → Process spawns python3 scripts/images/pick-video.py
 → zenity --file-selection opens
 → user selects file
 → script prints path to stdout
 → SplitParser.onRead: root.setVideoPath(path)
```

### Picker Invocation Flow

`Directories.scriptPath = Quickshell.shellPath("scripts")` (Directories.qml:25). File `scripts/images/pick-video.py` exists in repo. Path resolves correctly.

`videoPickerProc` (line68-78): Process with SplitParser stdout. Command set imperatively in onClicked (line 89), then `running = true` (line90).

Comparison: DesktopMenu.qml (line364) uses same imperative pattern — works. BackgroundConfig.qml (line1656) uses declarative command — also works. Both patterns are valid.

### Exact Failure Point

**HYPOTHESIS: click does NOT reach CustomVideo.onClicked.**

AbstractWidget.qml:7 is a `MouseArea` with `acceptedButtons: Qt.LeftButton | Qt.RightButton`. With `widgetsLocked = true`, `drag.target = undefined`. A MouseArea with no drag target still emits `onClicked` on press-release without movement.

**BUT:** CustomVideo's `contentItem` children include controlsBar (z:3, RippleButton×4), deleteHandle (z:4, MouseArea), resizeHandle (z:2, MouseArea). When `widgetsLocked = true`:
- resizeHandle `visible: opacity > 0 && !widgetsLocked` → **hidden** (line335)
- deleteHandle `visible: opacity > 0 && (root.videoIndex >= 0 || root.videoPath !== "")` → for empty legacy (videoIndex=-1, path=""), this is `false || false = false` → **hidden**
- controlsBar `opacity: (root.containsMouse && root.videoPath !== "" && root.videoValid) ? 1 :0` → for empty, `videoPath === ""` → opacity0 → **hidden**

So for an empty widget with `widgetsLocked = true`, ALL child MouseAreas/Button are hidden. The root MouseArea should receive the click directly.

**The click should reach onClicked.** If it doesn't, the issue may be that `FadeLoader` wrapping the legacy component intercepts events, or that `visible: videos.length ===0` (WidgetsLoader.qml:168) causes the component to be hidden when it shouldn't be.

Wait — `visible: !Config.options.background.widgets.customVideo.videos || Config.options.background.widgets.customVideo.videos.length === 0` (WidgetsLoader.qml:168). With `videos = []`, `videos.length === 0` is true → `visible = true`. OK, legacy instance is visible.

**ROOT CAUSE NOT PROVEN.** The click flow appears correct from static analysis. Runtime diagnostic needed: add `console.log("[CustomVideo] onClicked", mouse.button, root.videoPath)` to verify onClicked fires.

### Evidence
- AbstractWidget.qml:7-9 — MouseArea with drag.target, acceptedButtons
- CustomVideo.qml:83-92 — onClicked handler
- CustomVideo.qml:89 — command set imperatively
- Directories.qml:25 — `scriptPath: Quickshell.shellPath("scripts")`
- scripts/images/pick-video.py — exists, outputs plain path
- WidgetsLoader.qml:168 — legacy `visible: videos.length === 0`

### Minimal Fix
Add `console.log("[CustomVideo] onClicked", mouse.button, root.videoPath, root.videoValid)` at line 83. Test click. If log appears → click reaches handler, issue is Process spawn. If no log → click doesn't reach, issue is event delivery.

---

## Bug4 — Toggle Instance vs Add Custom Video Collision

### Toggle Creation Flow
1. Toggle Custom Video ON in WidgetsSubmenu.
2. Writes `Config.options.background.widgets.customVideo.enable = true`.
3. Config defaults: `path = ""`, `videos = []`.
4. WidgetsLoader.qml:55-58 — FadeLoader `shown: enable && onThisScreen` → true.
5. WidgetsLoader.qml:165-176 — `customVideoComp` instantiated: `CustomVideo { videoIndex: -1, visible: videos.length === 0 }`.
6. `videos.length ===0` → `visible = true` → instance A appears.

### Add Creation Flow
1. Click "Add Custom Video" in DesktopMenu.
2. DesktopMenu.qml:358-366 — `customVideo.enable = true` (ensures enabled), then `desktopMenuVideoPickerProc.command = [...]`, `running = true`.
3. User picks video file.
4. DesktopMenu.qml:77-109 — SplitParser.onRead rebuilds videos array: copies existing entries + pushes new `{path: pickedPath, ...}`.
5. `Config.options.background.widgets.customVideo.videos = list` — whole array reassigned.
6. `videos.length` becomes1 (was0).

### Shared State
- `Config.options.background.widgets.customVideo.enable` — shared toggle.
- `Config.options.background.widgets.customVideo.path` — legacy instance path (videoIndex=-1).
- `Config.options.background.widgets.customVideo.videos[]` — array instances (videoIndex>=0).
- `Config.options.background.widgets.customVideo.videos.length` — used for legacy visibility AND array Repeater model.

### Exact Mutation Replacing/Removing Instance A

**WidgetsLoader.qml:168:** `visible: !Config.options.background.widgets.customVideo.videos || Config.options.background.widgets.customVideo.videos.length === 0`

When Add Custom Video appends to `videos[]`:
- `videos.length` changes from 0 to1.
- Legacy instance `visible: videos.length === 0` → `0 === 0` was true, now `1 ===0` is false.
- Legacy instance A becomes **invisible**.
- Array Repeater (WidgetsLoader.qml:124-139): `model: ... videos.length ... ? videos.length :0` → model changes from0 to 1.
- Repeater instantiates `CustomVideo { videoIndex:0 }` → instance B appears.
- Result: A invisible, B visible. User sees A "replaced" by B.

### Root Cause

**WidgetsLoader.qml:168 — legacy instance `visible` is bound to `videos.length === 0`.**

This is the **exact same pattern as CustomImage** (WidgetsLoader.qml:156): `visible: !Config.options.background.widgets.customImage.images || Config.options.background.widgets.customImage.images.length === 0`.

CustomImage has the same pattern and **works correctly** — legacy image hides when array images exist. The difference: CustomImage users apparently don't report this as a bug because the legacy image's purpose was always "single image mode" that gets replaced by array mode.

For CustomVideo, the user expects toggle ON (A) + Add (B) = A + B coexisting. But the design intent (mirrored from CustomImage) is: legacy instance is a fallback when no array entries exist; array entries replace it.

**The root cause is a design mismatch between user expectation and the implemented ownership model.** The legacy/array dual-namespace design means:
- Legacy (`customVideo.path`, videoIndex=-1): single toggle-created instance.
- Array (`customVideo.videos[i]`, videoIndex>=0): added instances.

They share `videos.length` as a visibility gate. When array gets entries, legacy hides.

### Evidence
- WidgetsLoader.qml:168 — `visible: ... videos.length ===0`
- WidgetsLoader.qml:124-139 — array Repeater model = `videos.length`
- DesktopMenu.qml:77-109 — array rebuild + reassign on picker stdout
- CustomImage (WidgetsLoader.qml:156) — identical pattern, works
- Config.qml:381-398 — `customVideo` config: `path` (legacy) + `videos` (array) as separate properties

### Minimal Fix

**Option A — Make legacy instance independent of array (recommended):**
Remove `visible: videos.length ===0` from `customVideoComp` (WidgetsLoader.qml:168). Legacy instance shows whenever `enable` is true, regardless of array contents. Array instances coexist alongside it.

Risk: when toggle ON + no video picked + Add Custom Video, user sees empty legacy placeholder + loaded array instance. Acceptable — legacy is the "primary" toggle instance, array are extras.

**Option B — Merge legacy into array (more complex):**
When toggle ON, create a `videos[0]` entry with default values. Toggle OFF removes all. Add appends to `videos[]`. No separate legacy namespace. This is a bigger refactor.

**Option A is minimal and matches user expectation.** CustomImage's pattern works for images because users don't expect toggle+add to coexist there. CustomVideo users do.
