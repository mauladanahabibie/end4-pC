# Root Cause v2 — Custom Video Widget (4 Bugs)

**Date:** 2026-08-22
**Status:** Investigation complete. Fixes NOT yet implemented.

---

## BUG 1 — Drag & Drop Video Files Broken

### Reproduction
1. Create empty Custom Video (toggle ON)
2. Drag `.mp4` file from file manager onto widget
3. Expected: video loads
4. Actual: nothing happens

### Exact event/state flow
```
File Manager
 → Wayland drag enters widget
 → Qt DragEnterEvent delivered to widget
 → DropArea? — CustomVideo.qml has NO DropArea
 → No drag.accept() called
 → Qt auto-rejects the drop
 → onDropped never fires
 → setVideoPath never called
 → video does not load
```

### Root cause
`CustomVideo.qml` has NO `DropArea`. The property `dropHover` (line 36) is dead state — declared, consumed by the placeholder `MaterialSymbol` (lines 220-224), but never set `true` by any handler. `setVideoPath` (line 374) exists and works, but is unreachable via file drag-drop.

`CustomImage.qml` (reference, works) has `DropArea` at lines 172-193:
```qml
DropArea {
    anchors.fill: parent
    keys: ["text/uri-list"]
    onEntered: (drag) => { drag.accept(Qt.CopyAction); root.dropHover = true }
    onExited: { root.dropHover = false }
    onDropped: (drop) => {
        if (drop.hasUrls && drop.urls.length > 0) {
            var cleanPath = drop.urls[0].toString().replace(/^file:\/\//, "")
            var ext = cleanPath.split(".").pop().toLowerCase()
            var accepted = ["png","jpg","jpeg","webp","avif","bmp","gif","tiff","tif"]
            if (accepted.indexOf(ext) !== -1) root.setImagePath(cleanPath)
        }
        root.dropHover = false
    }
}
```

### Affected file
`modules/ii/background/widgets/videos/CustomVideo.qml`

### Affected property/function
- Missing `DropArea` inside `contentItem` (should be child of `videoShape`, mirroring CustomImage)
- `dropHover` (line 36) — dead, needs to be wired to `DropArea.onEntered`/`onExited`
- `setVideoPath` (line 374) — exists, correct, just unreachable via drop

### Minimal fix
Add `DropArea` inside `videoShape` (after `MaterialSymbol`), mirroring CustomImage lines 172-193:
```qml
DropArea {
    anchors.fill: parent
    keys: ["text/uri-list"]
    onEntered: (drag) => {
        drag.accept(Qt.CopyAction)
        root.dropHover = true
    }
    onExited: {
        root.dropHover = false
    }
    onDropped: (drop) => {
        if (drop.hasUrls && drop.urls.length > 0) {
            var cleanPath = drop.urls[0].toString().replace(/^file:\/\//, "")
            var ext = cleanPath.split(".").pop().toLowerCase()
            var accepted = ["mp4","webm","mkv","avi","mov","m4v","ogv"]
            if (accepted.indexOf(ext) !== -1) {
                root.setVideoPath(cleanPath)
            }
        }
        root.dropHover = false
    }
}
```

### Regression risk
**Low.** DropArea only handles drag-drop (file drops), not pointer events for widget movement. `keys: ["text/uri-list"]` restricts to file URLs. `setVideoPath` reuses existing array/legacy routing. `dropHover` is visual-only (changes placeholder icon).

---

## BUG 2 — Video-Present Widget Cannot Move (Drag Regression)

### Reproduction
1. Load video into Custom Video widget
2. Try to drag widget (left-click + move)
3. Expected: widget moves
4. Actual: widget does not move

5. Empty widget (no video) — drag works fine

### Exact event/state flow
```
Left-click on widget body
 → MouseArea (AbstractWidget.qml:8) receives press
 → drag.target = draggable ? dragProxy : undefined
 → draggable = placementStrategy === "free" && !widgetsLocked (true)
 → press reaches root MouseArea... but drag doesn't engage
```

### Root cause
When video is present, these items become visible/active inside `videoShape` (z:0):
- `videoOut` (VideoOutput): `layer.enabled = true` (line197)
- `videoMaskShape` (MaterialShape): `layer.enabled = true` (line 206), `visible: false` but layer active
- `MaskMultiEffect` (line 209): `visible: true`, `anchors.fill: parent` — full coverage

`MaskMultiEffect` is a `MultiEffect` (QtQuick.Effects) that samples `source: videoOut` and `maskSource: videoMaskShape`. Both sources have `layer.enabled: true`, creating offscreen FBO surfaces. The `MaskMultiEffect` itself becomes the only full-coverage visible child of `videoShape` when video is loaded.

**Comparison with CustomImage (works):**
- CustomImage uses `StyledImage` (plain `Image`) — no MultiEffect, no layer-source effect subtree
- CustomImage's `imageShape` has `layer.enabled: true` with `OpacityMask` effect, but this is on the MaterialShape itself, not a separate full-coverage child
- CustomImage has NO `MaskMultiEffect` or equivalent full-coverage effect item

**Why empty widget drags:** When `videoPath === ""`:
- `MaskMultiEffect.visible = false` (line 214)
- `videoOut.layer.enabled = false` (line 197)
- `videoMaskShape.layer.enabled = false` (line 206)
- Only `MaterialSymbol` (placeholder) is visible — doesn't block drag

**The `MaskMultiEffect` with `visible: true` + `anchors.fill: parent` + two `layer.enabled` sources creates a render surface that interferes with pointer event delivery to the parent MouseArea.** This is the sole structural difference between CustomVideo (broken) and CustomImage (working) when content is loaded.

### Affected file
`modules/ii/background/widgets/videos/CustomVideo.qml`

### Affected property/function
- `MaskMultiEffect` (lines 209-215): `visible: root.videoPath !== "" && root.videoValid` + `anchors.fill: parent`
- `videoOut` (line 197): `layer.enabled: root.videoPath !== "" && root.videoValid`
- `videoMaskShape` (line 206): `layer.enabled: root.videoPath !== "" && root.videoValid`

### Minimal fix
**Option A (recommended): Replace `MaskMultiEffect` + `layer.enabled` approach with `OpacityMask` clipping (mirror CustomImage).**

CustomImage uses `layer.effect: OpacityMask { maskSource: MaterialShape {...} }` on `imageShape` itself, and a plain `StyledImage` inside. No separate full-coverage MultiEffect child.

For video, `OpacityMask` would freeze video frames (FBO caching) — this is documented in research.md. So OpacityMask is NOT viable for live video.

**Option B: Make `MaskMultiEffect` not interfere with pointer delivery.**

`MaskMultiEffect` is a plain `Item` subclass (`MultiEffect`). Non-MouseArea Items should not block pointer events. The issue may be that `layer.enabled: true` on the sources creates offscreen surfaces that Qt's pointer delivery treats differently.

Test: set `videoOut.layer.enabled = false` and `videoMaskShape.layer.enabled = false` — but this breaks the masking pipeline.

**Option C (most likely correct): The issue is NOT actually `MaskMultiEffect` blocking pointer events.**

MultiEffect is NOT a MouseArea. It does not capture pointer events. The real issue may be something else that changes when video is present.

**Re-examination needed at runtime.** The forensics cannot definitively prove MaskMultiEffect blocks pointer events from static code analysis alone. Need runtime diagnostic:
```qml
// Temporary diagnostic in AbstractWidget onMousePressed:
console.log("[AbstractWidget] press received, draggable:", root.draggable, "drag.active:", root.drag.active)
```

**HOWEVER** — the most actionable hypothesis: `MaskMultiEffect` with `layer.enabled` sources may create an implicit grab surface. The fix is to ensure the parent MouseArea's press propagates through.

**Option D (safest): Add `MouseArea { anchors.fill: parent; enabled: false }` trick — NO.** This doesn't help.

**Option E (pragmatic): Wrap `MaskMultiEffect` so it doesn't cover the full parent.** — Not viable, it needs full coverage for masking.

**Recommended approach:** Add temporary diagnostic logging to AbstractWidget to trace whether the press event reaches the root MouseArea when video is present. If it does, the issue is in the drag machinery, not pointer delivery. If it doesn't, the issue is pointer delivery through the layer.enabled/MultiEffect stack.

### Regression risk
**Medium.** Any change to the video rendering pipeline risks breaking video display. Must verify video still plays and masks correctly after fix.

---

## BUG 3 — Empty Widget Click Does Not Open Picker

### Reproduction
1. Create empty Custom Video widget
2. Left-click on empty widget body
3. Expected: file picker opens
4. Actual: nothing happens (OR: `returntrue` typo causes ReferenceError)

### Exact event/state flow
```
Left-click empty widget
 → AbstractWidget (MouseArea) receives press
 → AbstractWidget.onClicked (line 21): right-click toggles widgetsLocked
 → CustomVideo.onClicked (line 83): left-click + empty → videoPickerProc.running = true
 → videoPickerProc Process starts
 → runs: python3 scripts/images/pick-video.py
 → user selects file OR cancels
 → on success: prints plain path to stdout
 → SplitParser.onRead: data => { root.setVideoPath(data.trim()) }
 → setVideoPath: routes to updateArrayVideo or Config.path
 → video loads
```

**BUT** — line 59 has a syntax error: `returntrue` (no space). This is `returntrue` — a single token that Qt's JS engine may parse as an identifier reference, not `return true`. When `!Battery.available` is true, this throws `ReferenceError: returntrue is not defined`.

This ReferenceError may abort the property binding evaluation, causing `powerAllowsPlay` to be undefined/false, which cascades to `effectivePlay = false`, but this shouldn't block the picker.

**The real question: does the click actually reach `onClicked`?**

AbstractWidget's `onClicked` (line 21) handles right-click → widgetsLocked toggle. CustomVideo overrides `onClicked` (line 83). In QML, when a subclass defines `onClicked`, it REPLACES the parent's `onClicked` — the parent's right-click handler is LOST.

So CustomVideo's `onClicked` (line 83) only handles left-click. Right-click does nothing (no widgetsLocked toggle). This is a secondary bug but not the primary cause.

**Primary cause hypothesis: `returntrue` typo causes ReferenceError during component initialization.** When `Battery.available` is false (no battery, desktop), `powerAllowsPlay` throws. This may prevent the component from fully initializing, or cause the `onClicked` handler to be in a broken state.

### Root cause
1. **`returntrue` typo** (line 59): `returntrue` is not valid JS `return true`. Causes `ReferenceError` when `!Battery.available`. On a desktop without battery, this fires on every evaluation of `powerAllowsPlay`.
2. **Lost right-click handler**: CustomVideo's `onClicked` overrides AbstractWidget's `onClicked` which handled right-click → widgetsLocked toggle.

### Affected file
`modules/ii/background/widgets/videos/CustomVideo.qml`

### Affected property/function
- Line 59: `returntrue` (should be `return true`)
- Line 83: `onClicked` — overrides parent, loses right-click handler

### Minimal fix
1. Fix `returntrue` → `return true` (line 59)
2. In `onClicked` (line 83), add right-click handling to preserve widgetsLocked toggle:
```qml
onClicked: (mouse) => {
    if (mouse.button === Qt.RightButton) {
        Config.options.background.widgetsLocked = !Config.options.background.widgetsLocked
        return
    }
    if (mouse.button !== Qt.LeftButton) return
    if (root.videoPath === "" || !root.videoValid) {
        videoPickerProc.command = ["python3", `${Directories.scriptPath}/images/pick-video.py`]
        videoPickerProc.running = true
    } else {
        GlobalStates.customVideoFullscreenIndex = root.videoIndex
        GlobalStates.customVideoFullscreenOpen = true
    }
}
```

### Regression risk
**Low.** Fixing a typo can only help. Adding right-click handler restores expected behavior. Left-click picker logic unchanged.

---

## BUG 4 — Instance Collision (Toggle Instance Disappears on Add)

### Reproduction
1. Toggle Custom Video ON → instance A appears (empty, `videoIndex: -1`, `path: ""`)
2. Click "Add Custom Video" in DesktopMenu → picker opens
3. Select video → picker appends to `videos[]` array
4. Expected: A + B (both visible)
5. Actual: A disappears, B appears

### Exact event/state flow
```
Toggle ON:
 → Config.options.background.widgets.customVideo.enable = true
 → Config defaults: path="", videos=[]
 → Background.qml legacy FadeLoader (line 537):
     shown: enable && (videos.length === 0 || path !== "") && screenList guard
     =true && (true || "") && true = true
 → Legacy CustomVideo { videoIndex: -1 } instantiated → instance A visible

Add Custom Video:
 → DesktopMenu.qml line 358: onClicked
 → customVideo.enable = true (ensures enabled)
 → desktopMenuVideoPickerProc.running = true
 → User picks video file
 → picker stdout: plain path
 → SplitParser.onRead (line 77):
     rebuilds videos array: copy existing + push { path: pickedPath, ... }
     Config.options.background.widgets.customVideo.videos = list
 → videos.length = 1 (was 0)
 → Background.qml legacy FadeLoader re-evaluates shown:
     shown: true && (false || "") && true
     = true && false && true = FALSE
 → FadeLoader.active = false → sourceComponent destroyed → instance A unloaded
 → Repeater (line 556): model = videos.length = 1
     → CustomVideo { videoIndex: 0 } instantiated → instance B visible
```

**Key:** `customVideo.path` stays `""` after Add Custom Video. The Add flow only appends to `videos[]`. It never sets `customVideo.path`. So the `|| path !== ""` rescue clause is inert — it only saves legacy instances that already had a video picked into the legacy `path` slot.

### Root cause
`Background.qml` line 539: legacy FadeLoader `shown` condition `videos.length === 0` kills the legacy instance as soon as any array entry exists. The `|| path !== ""` rescue only fires when the legacy instance already has a video — not when it's the empty toggle-created placeholder.

Two config namespaces are intentionally distinct:
- `customVideo.path` (legacy, videoIndex=-1)
- `customVideo.videos[].path` (array, videoIndex>=0)

The toggle creates a legacy instance with `path=""`. Add Custom Video appends to `videos[]` without touching `path`. The legacy instance has nothing to keep it shown once `videos.length > 0`.

### Affected file
`modules/ii/background/Background.qml`

### Affected property/function
- Line 539: `shown: ... && (customVideo.videos.length === 0 || customVideo.path !== "")`

### Minimal fix
The legacy instance and array instances serve different purposes:
- Legacy (`videoIndex: -1`): single toggle-created instance, uses `customVideo.path/x/y/size`
- Array (`videoIndex: >= 0`): added instances, use `videos[i].path/x/y/size`

**The toggle-created legacy instance should remain visible as long as the toggle is ON, regardless of array contents.** The array and legacy are independent.

Fix: remove the `videos.length === 0` condition entirely — the legacy instance should show whenever `enable` is true (plus screenList guard):
```qml
shown: Config.options.background.widgets.customVideo.enable
    && (Config.options.background.screenList.length === 0
        || Config.options.background.screenList.includes(bgRoot.screen.name))
```

**OR** if legacy should only show when it has its own path (to avoid double-empty):
```qml
shown: Config.options.background.widgets.customVideo.enable
    && (Config.options.background.widgets.customVideo.path !== ""
        || Config.options.background.widgets.customVideo.videos.length === 0)
    && (Config.options.background.screenList.length === 0
        || Config.options.background.screenList.includes(bgRoot.screen.name))
```

**Option 2 is safer:** legacy shows when it has a path OR when there are no array entries (avoiding double-empty when both legacy and array are empty but toggle is on).

### Regression risk
**Medium.** Changing visibility logic affects instance lifecycle. Must verify: toggle ON → A visible; Add → A + B; Delete B → A remains; Toggle OFF → A gone.

---

## Summary Table

| Bug | Root cause | Affected file | Fix risk |
|-----|-----------|---------------|----------|
| 1. Drop broken | No `DropArea` in CustomVideo.qml | CustomVideo.qml | Low |
| 2. Drag broken (video present) | `MaskMultiEffect` + `layer.enabled` sources interfere with pointer delivery | CustomVideo.qml | Medium — needs runtime diagnostic |
| 3. Picker broken | `returntrue` typo (ReferenceError) + lost right-click handler | CustomVideo.qml | Low |
| 4. Instance collision | Legacy FadeLoader `shown` condition kills instance when `videos.length > 0` | Background.qml | Medium |
