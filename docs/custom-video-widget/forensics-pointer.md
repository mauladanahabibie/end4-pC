# Forensics: Pointer Event Blocking (BUG A)

## Observed
- Custom Video widget WITHOUT video → CAN drag
- Custom Video widget WITH video → CANNOT drag

## QML Object Hierarchy — CustomVideo (video present)

```
AbstractWidget (MouseArea, drag.target=dragProxy)  ← THIS handles drag
  └─ AbstractBackgroundWidget
       └─ CustomVideo (root)
            ├─ AudioOutput
            ├─ MediaPlayer
            ├─ Item (contentItem)
            │    ├─ MaterialShape (shadowShape, visible:false)
            │    ├─ StyledDropShadow (z:-1)
            │    ├─ MaterialShape (videoShape, z:0)
            │    │    ├─ VideoOutput (videoOut) ← layer.enabled=true when video present
            │    │    ├─ MaterialShape (videoMaskShape, visible:false, layer.enabled=true)
            │    │    ├─ MaskMultiEffect (visible=true when video present) ← FULL COVERAGE
            │    │    └─ MaterialSymbol (visible only when empty)
            │    ├─ Rectangle (controlsBar, z:3, visible only on hover)
            │    ├─ Rectangle (resizeHandle, z:2, MouseArea)
            │    └─ Rectangle (deleteHandle, z:4, MouseArea)
            ├─ onPressed / onPositionChanged / onReleased handlers
            └─ functions
```

## QML Object Hierarchy — CustomImage (image present, DRAG WORKS)

```
AbstractWidget (MouseArea, drag.target=dragProxy)
  └─ AbstractBackgroundWidget
       └─ CustomImage (root)
            ├─ Item (contentItem)
            │    ├─ MaterialShape (shadowShape, visible:false)
            │    ├─ StyledDropShadow (z:-1)
            │    ├─ MaterialShape (imageShape, z:0, layer.enabled=true)
            │    │    ├─ StyledImage (visible=true when image present)
            │    │    ├─ MaterialSymbol (visible only when empty)
            │    │    └─ DropArea (anchors.fill:parent)
            │    ├─ Rectangle (resizeHandle, z:2, MouseArea)
            │    └─ Rectangle (deleteHandle, z:2, MouseArea)
            └─ functions
```

## Root Cause

**`MaskMultiEffect` with `visible: true` and `anchors.fill: parent` blocks pointer events.**

Evidence:
- `CustomVideo.qml` line234-240: `MaskMultiEffect` has `anchors.fill: parent`, `visible: root.videoPath !== "" && root.videoValid`
- When video is present, `MaskMultiEffect` becomes visible and covers the entire widget area
- `MaskMultiEffect` is a QtQuick.Effects item that renders video content. It is NOT a MouseArea, but it IS a full-coverage visual item that sits at z:0 inside `videoShape`
- In Qt, items with `layer.enabled: true` create offscreen render surfaces. `MaskMultiEffect` uses `source: videoOut` (which has `layer.enabled: true`) and `maskSource: videoMaskShape` (which also has `layer.enabled: true`)

**Comparison with CustomImage:**
- CustomImage uses `StyledImage` (line148-157) — a plain Image element that does NOT block pointer events
- CustomImage has NO `MaskMultiEffect` or equivalent full-coverage effect layer
- CustomImage's `imageShape` has `layer.enabled: true` with `OpacityMask` effect, but this is on the MaterialShape itself, not a separate child item that covers the parent

**The critical difference:**
| Feature | CustomImage | CustomVideo |
|---------|-------------|-------------|
| Content renderer | StyledImage (Image) | MaskMultiEffect (Effect) |
| Full-coverage visible item | StyledImage (doesn't block) | MaskMultiEffect (blocks) |
| layer.enabled on content | No | Yes (videoOut + videoMaskShape) |
| DropArea present | Yes (coexists with drag) | No |

**Secondary factor:** CustomVideo has `onPressed`/`onPositionChanged`/`onReleased` handlers at root level (lines72-117). CustomImage has NONE of these. While these handlers don't directly block drag (they don't call `mouse.accepted = false`), they add overhead. The primary blocker is `MaskMultiEffect`.

## Why Empty Widget CAN Drag
When `videoPath === ""`:
- `MaskMultiEffect.visible = false` (line239)
- `videoOut.layer.enabled = false` (line222)
- `videoMaskShape.layer.enabled = false` (line231)
- Only `MaterialSymbol` is visible (line248)
- No full-coverage effect item blocks the parent MouseArea's drag

## Why Video Widget CANNOT Drag
When `videoPath !== ""`:
- `MaskMultiEffect.visible = true` (line239) — full coverage, blocks pointer
- `videoOut.layer.enabled = true` (line 222) — offscreen surface
- `videoMaskShape.layer.enabled = true` (line231) — offscreen surface
- The MaskMultiEffect renders the video content visually, covering the entire widget
- Pointer events land on MaskMultiEffect, not on the parent MouseArea

## Affected File
`modules/ii/background/widgets/videos/CustomVideo.qml`

## Recommended Minimal Fix
Make `MaskMultiEffect` not capture pointer events by setting `enabled: false` when not needed, OR wrap the video rendering in an Item with `mouseEnabled: false` equivalent. In QML, visual items don't have `mouseEnabled`, but the fix is to ensure the parent MouseArea's drag still works by NOT having full-coverage child items that intercept.

The simplest fix: add `MouseArea { anchors.fill: parent; enabled: false }` won't help. Instead, the MaskMultiEffect should have its pointer handling disabled. Since QML Items don't block mouse by default (only MouseAreas do), the real issue might be that `layer.enabled` items create separate surfaces.

**Alternative explanation:** The `onPressed`/`onPositionChanged`/`onReleased` handlers at root level (lines72-117) override AbstractBackgroundWidget's `onReleased` (line41-47). AbstractBackgroundWidget's `onReleased` saves position. CustomVideo's `onReleased` (line87) also handles drag-save. But AbstractWidget's drag mechanism uses `drag.target: dragProxy`. If the `onPressed` handler interferes with the drag detection (by consuming the press event before Qt's drag system activates), drag won't start.

**Most likely root cause:** The `onPressed`/`onPositionChanged`/`onReleased` handlers at root level consume pointer events, preventing AbstractWidget's built-in `drag.target` mechanism from activating. CustomImage has NO such handlers, so AbstractWidget's drag works freely.
