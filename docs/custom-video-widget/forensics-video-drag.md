# Forensics: CustomVideo drag blocked when a video is loaded

> Read-only investigation. No source files were modified. Report only.
> Scope: explain why a `CustomVideo` widget that has a valid video path cannot be
> dragged, while the same widget with an empty/invalid path *can* be dragged,
> and while `CustomImage` (image loaded) drags fine.

## 1. Reproduction

1. Enable `Config.options.background.widgets.customVideo.enable` (toggle ON).
2. Place one Custom Video widget (legacy `videoIndex: -1` or an array instance).
3. Leave it empty -> drag works (body press -> `drag.target` engages).
4. Click the empty widget -> `pick-video.py` runs -> pick a `.mp4`/`.webm` ->
   `setVideoPath` sets `root.videoPath` and `root.videoValid = true`.
5. Once the video texture is live, a body press no longer engages
   `AbstractWidget.drag.target`; the widget cannot be moved. Right-click still
   toggles `widgetsLocked` (so the MouseArea is alive), and the resize/delete
   corner handles still work (they own their own MouseAreas).
6. Clear the path (`setVideoPath("")` / delete) -> drag returns.

Correlates 1:1 with `root.videoPath !== "" && root.videoValid`.

## 2. Inheritance / object hierarchy

```
WidgetCanvas (modules/common/widgets/widgetCanvas/WidgetCanvas.qml)
  +-- FadeLoader (Loader; no MouseArea, does not block)            [Background.qml:537-555,562-572]
      +-- AbstractWidget  (MouseArea; drag.target = draggable ? dragProxy : undefined)  [AbstractWidget.qml:7-18]
          |   acceptedButtons: Qt.LeftButton | Qt.RightButton       [AbstractWidget.qml:16]
          |   drag.target drives dragProxy; bindings snap root.x/y   [AbstractWidget.qml:18,41-49]
          |   root is the MouseArea that owns the press for the whole widget
          +-- AbstractBackgroundWidget                                [AbstractBackgroundWidget.qml]
              |   x: targetX; y: targetY                              [AbstractBackgroundWidget.qml:21-23]
              |   draggable: placementStrategy === "free" && !widgetsLocked  [AbstractBackgroundWidget.qml:36]
              |   onReleased: writes configEntry.x/y; restoreXYBinding()       [AbstractBackgroundWidget.qml:38-46]
              +-- CustomVideo (root)                                  [CustomVideo.qml]
                  |   configEntryName: "customVideo"; hoverEnabled: true         [CustomVideo.qml:9-10]
                  |   targetX/targetY override -> videoConfig.x/y                 [CustomVideo.qml:46-53]
                  |   onClicked: empty->picker, loaded->fullscreen                [CustomVideo.qml:83-90]
                  |   onReleased (OVERRIDES base): writes videos[i].x/y,          [CustomVideo.qml:449-464]
                  |       then restoreXYBinding()
                  +-- AudioOutput / MediaPlayer (not visual)          [CustomVideo.qml:118-141]
                  +-- Item contentItem (implicitWidth/Height = widgetSize)         [CustomVideo.qml:155-158]
                       +-- MaterialShape shadowShape  visible:false                [CustomVideo.qml:173-178]
                       +-- StyledDropShadow  z:-1  (DropShadow, behind)            [CustomVideo.qml:180-183]
                       +-- MaterialShape videoShape  z:0  (ShapeCanvas)           [CustomVideo.qml:185-226]
                       |    +-- VideoOutput videoOut  visible:false                [CustomVideo.qml:192-198]
                       |    |    layer.enabled = videoPath!=="" && videoValid
                       |    +-- MaterialShape videoMaskShape visible:false         [CustomVideo.qml:200-207]
                       |    |    layer.enabled = videoPath!=="" && videoValid
                       |    +-- MaskMultiEffect  visible = videoPath!==""          [CustomVideo.qml:209-215]  <-- full coverage
                       |    |    source: videoOut; maskSource: videoMaskShape; anchors.fill: parent
                       |    +-- MaterialSymbol  visible = empty/invalid            [CustomVideo.qml:217-225]
                       +-- Rectangle controlsBar  z:3 (hover-only strip)          [CustomVideo.qml:228-277]
                       |    +-- RowLayout { ControlButton x4 }                    [CustomVideo.qml:244-276]
                       +-- Rectangle resizeHandle z:2 + MouseArea                [CustomVideo.qml:286-328]
                       +-- Rectangle deleteHandle z:4 + MouseArea                [CustomVideo.qml:337-369]
```

`CustomImage` (works with an image loaded) for comparison:

```
AbstractWidget(MouseArea) -> AbstractBackgroundWidget -> CustomImage
  +-- Item contentItem
       +-- MaterialShape shadowShape visible:false
       +-- StyledDropShadow z:-1
       +-- MaterialShape imageShape z:0  layer.enabled:true + OpacityMask     [CustomImage.qml:139-186]
       |    +-- StyledImage (plain Image) visible = imagePath!==""             [CustomImage.qml:148-157]  <-- plain Item, no effect subtree
       |    +-- MaterialSymbol visible = empty
       |    +-- DropArea anchors.fill: parent                                 [CustomImage.qml:188-211]
       +-- Rectangle resizeHandle z:2 + MouseArea
       +-- Rectangle deleteHandle z:2 + MouseArea
```

## 3. What changes when a video is present vs empty

All deltas are gated on `root.videoPath !== "" && root.videoValid`:

| Element | Empty (drags) | Loaded (no drag) | Line |
|---|---|---|---|
| `videoOut` (VideoOutput) | `visible:false`, `layer.enabled:false` | `visible:false`, **`layer.enabled:true`** | 192-198 |
| `videoMaskShape` (MaterialShape) | `visible:false`, `layer.enabled:false` | `visible:false`, **`layer.enabled:true`** | 200-207 |
| `MaskMultiEffect` | `visible:false` | **`visible:true`, `anchors.fill: parent`** | 209-215 |
| `MaterialSymbol` (placeholder) | `visible:true` | `visible:false` | 217-225 |
| `controlsBar` | `opacity:0`/`visible:false` | appears on `containsMouse` (z:3 strip) | 228-242 |
| `deleteHandle` | only if `videoIndex>=0` | also eligible via `videoPath!==""` | 337-344 |

`draggable` itself is NOT video-dependent: it is
`placementStrategy === "free" && !widgetsLocked` (`AbstractBackgroundWidget.qml:36`),
`customVideo.placementStrategy` defaults to `"free"` (`Config.qml:339`), and
`widgetsLocked` defaults to `false` (`Config.qml:224`). So the MouseArea is in
the drag-capable state in both cases. Right-click keeps working in both cases,
confirming the MouseArea is receiving events -- what fails is `drag.target`
engaging on a body press.

## 4. Root cause

The only structural difference that activates *exactly* when a video is loaded
and has no counterpart in the working `CustomImage` is the **`MaskMultiEffect`
effect subtree**: a fully-covering, visible `MultiEffect` (`QtQuick.Effects`)
sitting at the top of `videoShape`, sampling two `layer.enabled` offscreen
sources (`videoOut` + `videoMaskShape`), one of which (`videoOut`) is a live
`VideoOutput` whose texture updates every frame while playing.

- `CustomImage.qml:148-157` renders its content with a plain `StyledImage`
  (`Image`) -- an `Item` that does not create a render-to-texture effect subtree
  and does not intercept press delivery to the ancestral `MouseArea`.
- `CustomVideo.qml:209-215` renders its content with `MaskMultiEffect`
  (`MultiEffect` + `maskEnabled`), pulling from `videoOut` (`layer.enabled`,
  `VideoOutput`) and `videoMaskShape` (`layer.enabled`). When the video is
  valid this whole subtree flips to `visible`/`layer`-active at once
  (`CustomVideo.qml:197,206,214`).

Mechanism (scene-graph, not a MouseArea rule): `MultiEffect` with
`source`/`maskSource` bound to `layer.enabled` items, combined with a
per-frame-updating `VideoOutput` source, creates a render-to-texture subtree
that owns the widget's painting surface. The press that should be delivered to
the `AbstractWidget` `MouseArea` (the `root` item) is instead claimed by the
effect subtree's surface before the `MouseArea` drag machinery can latch
`drag.target`. The empty widget never builds this subtree
(`MaskMultiEffect.visible:false`, `videoOut.layer.enabled:false`), so presses
reach the `MouseArea` and `drag.target = dragProxy` engages normally.

Evidence the bug is tied to this subtree and not to the (already-removed) root
handlers:

- `CustomVideo.qml` has **no** root-level `onPressed`/`onPositionChanged`
  (only `onClicked:83`, `onReleased:449`, `onEffectivePlayChanged`,
  `onVideoPathChanged`). The earlier root-cause blaming root handlers
  (`docs/custom-video-widget/root-cause.md`, `forensics-pointer.md`) describes
  the *pre-fix* file (`lines 72-117`) and is stale for the current tree.
- `onClicked` fires only on a genuine click (no drag) and never calls
  `mouse.accepted = false`; it cannot suppress drag.
- The only child `MouseArea`s are `resizeArea` (16x16 corner, `CustomVideo.qml:299`)
  and `deleteArea` (22x22 corner, `CustomVideo.qml:350`). Neither covers the
  body, so they cannot explain a full-body drag failure.
- `CustomImage` keeps an identical handle layout and still drags with an image
  loaded; the sole render-path difference is `StyledImage` (plain `Image`) vs
  `MaskMultiEffect` over `VideoOutput`.

## 5. Affected file:line

Primary:
- `modules/ii/background/widgets/videos/CustomVideo.qml:209-215` -- `MaskMultiEffect`
  becomes the full-coverage visible child of `videoShape` when a video is loaded.
Contributing (activate together with it):
- `modules/ii/background/widgets/videos/CustomVideo.qml:192-198` -- `VideoOutput`
  `layer.enabled` goes true (live texture source for the effect).
- `modules/ii/background/widgets/videos/CustomVideo.qml:200-207` -- `videoMaskShape`
  `layer.enabled` goes true (mask texture source for the effect).

Contrast (works):
- `modules/ii/background/widgets/images/CustomImage.qml:148-157` -- `StyledImage`
  plain `Image`, no `MultiEffect`/`layer`-source subtree; drag works with image.

## 6. Minimal fix

Goal: stop the effect subtree from owning the press surface so the
`AbstractWidget` `MouseArea` receives the press and `drag.target` engages, while
keeping the masked video visible. Two equivalent options; pick one.

### Option A -- isolate the effect from hit-testing (preferred, smallest diff)

Keep `videoOut`/`videoMaskShape` offscreen, but make the *visible* item that
the user actually presses be a plain `Item`/`Image`-equivalent that the
`MouseArea` can see through. Concretely: drop the custom
`MaskMultiEffect`+`VideoOutput` layer masking and mirror `CustomImage`: clip
the `VideoOutput` with the shape the same way `CustomImage` clips `StyledImage`
via `imageShape` `layer.effect` `OpacityMask` (`CustomImage.qml:143-186`). The
`VideoOutput` stays `visible:true` inside a `layer.enabled` `MaterialShape`
whose `layer.effect` is an `OpacityMask` with a `MaterialShape` maskSource --
exactly the pattern `CustomImage` already uses and that does not block drag.

Sketch (illustrative; not applied -- read-only):

```qml
MaterialShape {
    id: videoShape
    anchors.fill: parent
    z: 0
    color: Appearance.colors.colPrimaryContainer
    shape: root.getShape(root.videoConfig.shape ?? "Cookie4Sided")
    layer.enabled: root.videoPath !== "" && root.videoValid
    layer.effect: OpacityMask {
        maskSource: MaterialShape {
            width: videoShape.width
            height: videoShape.height
            shape: videoShape.shape
        }
    }
    VideoOutput {                       // visible, clipped by the shape's layer.effect
        id: videoOut
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        visible: root.videoPath !== "" && root.videoValid
    }
    MaterialSymbol { /* placeholder, visible when empty */ }
}
// remove: videoMaskShape, MaskMultiEffect
```

This removes the `MultiEffect`-over-`layer`-sources subtree that correlates with
the drag failure and adopts the proven `CustomImage` clipping pattern.

### Option B -- keep `MaskMultiEffect`, but make the effect not own the press

If the masked-`MultiEffect` look must be preserved, ensure the effect subtree
does not receive the press by putting a transparent, non-interactive
`MouseArea`-passthrough is not possible (a second MouseArea would itself
intercept). Instead, keep the effect but guarantee the ancestral `MouseArea`
gets the press by *not* anchoring the effect to the full parent -- e.g. render
the masked video inside a child `Item` that does not cover the whole
`videoShape`, or set the effect item's `enabled: false` (disables its own
internal input without disabling paint is not guaranteed for `MultiEffect`).
Option A is the reliable fix; Option B is fragile and not recommended.

### Required regardless of option
- Verify the `onClicked` fullscreen trigger still fires for a loaded video
  (`CustomVideo.qml:83-90`) after the change -- a genuine click (no drag) must
  still open fullscreen; a drag must move the widget.
- Verify `controlsBar` hover show / `resizeArea` / `deleteArea` still work.

## 7. Regression risk

- **Mask/shape fidelity**: `MaskMultiEffect`+`videoMaskShape` produces a
  soft-edged mask (`MaskMultiEffect.qml`: `maskThresholdMin:0.5`,
  `maskSpreadAtMin:1`). Switching to `OpacityMask` (`CustomImage` pattern) gives
  a hard alpha mask -- edges will look crisper/different. Acceptable for
  `Cookie4Sided`-style shapes but visually different from the current soft
  mask; needs a visual check.
- **`VideoOutput` visibility**: Option A flips `videoOut.visible` to
  `true` (was `false`). `VideoOutput` is a sink for `MediaPlayer`; making it
  visible is required for the `layer.effect` `OpacityMask` to sample it.
  Ensure no second `VideoOutput` competes for the same `MediaPlayer`
  (`FullscreenVideoViewer.qml` also binds the same `player`? check before
  relying on this -- `player` is per-instance `id: player`, so safe).
- **Performance**: `imageShape`/`videoShape` `layer.enabled:true` + per-frame
  video texture update already costs a render pass; Option A is on par with
  `CustomImage` and drops the extra `MaskMultiEffect` pass, so net equal or
  cheaper.
- **Click-vs-drag semantics**: `onClicked` (genuine click) must keep firing
  fullscreen for loaded videos; if the new clipping path somehow let a press
  reach `onClicked` during a drag, fullscreen would open spuriously. Protect by
  keeping `onClicked` gated on `mouse.button === Qt.LeftButton` (already so,
  `CustomVideo.qml:84`) and relying on Qt's click-vs-drag distinction.
- **`resizeArea`/`deleteArea`**: unaffected; they are corner `MouseArea`s above
  `z:2`/`z:4` and do not overlap the effect subtree's press path.
- **Empty state**: empty widget path unchanged (`videoOut.visible:false`,
  placeholder `MaterialSymbol` visible) -- no regression for the picker flow.

## 8. Stale-prior-analysis note

`docs/custom-video-widget/root-cause.md` (BUG A) and
`forensics-pointer.md` blame root-level `onPressed`/`onPositionChanged`/
`onReleased` at `CustomVideo.qml:72-117` and, secondarily, `MaskMultiEffect`.
Those line numbers correspond to the **pre-fix** file; the current tree has no
root-level press handlers (see 2/4). The residual, still-reproducing drag
failure is attributable to the `MaskMultiEffect`/`VideoOutput` `layer` effect
subtree described above, not to removed handlers.
