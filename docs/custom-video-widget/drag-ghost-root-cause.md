# Root Cause Analysis: Custom Video Widget Dragging Ghost / Stale Position

**Date:** 2026-10-18  
**Status:** PROVEN & VERIFIED  
**Severity:** High (UI visual corruption / apparent state desynchronization)

---

## 1. Reproduction Steps

1. Configure Quickshell with at least one custom video entry in `Config.options.background.widgets.customVideo.videos` (e.g. `videos[0]` with path `/home/danzzalexandra/Downloads/oline.mp4`, shape `Cookie4Sided`, size 200).
2. Ensure `Config.options.background.widgets.customVideo.enable` is `true`.
3. Observe the desktop: a single video widget is visually displayed at coordinates `(636, 756)`.
4. Click and hold the mouse button on the Custom Video widget and drag it to a new location (e.g., `(836, 756)`).
5. **Observed Failure:**
   - As the widget moves with the cursor, a "ghost" copy of the widget (specifically with `Cookie6Sided` shape, size 240, empty video placeholder icon, and red delete button) remains visible and stationary at the original coordinates `(636, 756)`.
   - As soon as the mouse button is released, the "ghost" at `(636, 756)` instantly disappears.

---

## 2. Relevant QML Object Hierarchy

```
Background.qml / WidgetsLoader.qml
│
├── Repeater (FadeLoader delegate)
│   └── delegate: FadeLoader { key: "customVideo" }
│       └── customVideoComp: Component
│           └── CustomVideo {
│                   id: root (Instance A - Legacy Fallback)
│                   videoIndex: -1
│                   // Intended ONLY for legacy single-instance when videos.length == 0
│                   // BUT rendered concurrently due to missing visibility guard!
│                   targetX: configEntry.x (636)
│                   targetY: configEntry.y (756)
│                   shape: configEntry.shape ("Cookie6Sided")
│                   size: configEntry.size (240)
│               }
│
└── Repeater { model: videos.length }
    └── CustomVideo {
            id: root (Instance B - Array Instance 0)
            videoIndex: 0
            // The active video widget instance being dragged
            targetX: videoConfig.x (636)
            targetY: videoConfig.y (756)
            shape: videoConfig.shape ("Cookie4Sided")
            size: videoConfig.size (200)
        }
```

---

## 3. How the Widget Position Changes During Dragging

1. Both `CustomVideo` instances inherit `AbstractBackgroundWidget.qml`, which inherits `AbstractWidget.qml`.
2. When the user initiates a drag on the video widget, `AbstractWidget`'s internal `MouseArea` captures mouse events:
   - On press, the drag target is `root` (`Instance B`).
   - `root.x` and `root.y` are continuously updated via QtQuick's drag mechanics as the mouse pointer moves.
   - The video surface (`VideoOutput`), `MaterialShape` mask (`videoMaskShape`), and `MaskMultiEffect` are anchored to `contentItem` inside `root`. Because all anchors are relative to `root`, they follow `root.x` and `root.y` synchronously and continuously in real time. Video playback proceeds uninterrupted.
3. However, `Instance A` (`videoIndex: -1`) is an entirely separate QML object in the scene graph:
   - Its `x` and `y` are bound to `configEntry.x` and `configEntry.y`.
   - While `Instance B` is being dragged, `configEntry.x` and `configEntry.y` do NOT change during the drag.
   - Therefore, `Instance A` remains completely stationary at `(636, 756)`.
   - Because `Instance B` and `Instance A` were originally co-located at `(636, 756)` with `Instance B` stacked directly on top of `Instance A`, dragging `Instance B` reveals `Instance A` underneath it.

---

## 4. How the Video and Mask Layers Follow Position

- Within the dragged widget (`Instance B`), `contentItem` fills `root`.
- `videoOut` (the `VideoOutput`) and `videoMaskShape` (`MaterialShape`) both have `anchors.fill: parent` (`contentItem`).
- `MaskMultiEffect` also has `anchors.fill: parent`.
- There is NO texture caching, snapshotting, or delayed shader blitting causing the ghost. The dragged widget's visual pipeline is fully continuous and synchronized.
- The "ghost" is NOT an un-cleared framebuffer or a stuck shader effect. It is a live, distinct second QML widget instance rendering in the background.

---

## 5. Why the Stale Visual Appears and Why It Disappears on Mouse Release

### Why it appears:
In `modules/ii/background/WidgetsLoader.qml`:
Lines 180–191 previously lacked the visibility guard that `customImageComp` has:
```qml
// In customImageComp (line 170):
visible: !Config.options.background.widgets.customImage.images || Config.options.background.widgets.customImage.images.length === 0

// In customVideoComp (line 181-184):
CustomVideo {
    // Legacy instance visible whenever enable is true (via FadeLoader).
    // Independent of array contents — coexists with array instances.
    videoIndex: -1
```
Commit `6dc92cc1ec3126d4b2a1695251421c4da29d2f88` removed the visibility guard under the mistaken belief that legacy single-video should "coexist" with array instances. Consequently, whenever `customVideo.enable` is true and `videos.length > 0`, **two widgets are rendered at the exact same position**.

### Why it disappears on mouse release:
`CustomVideo` inherits `AbstractBackgroundWidget.qml`:
```qml
// AbstractBackgroundWidget.qml: line 51-61
function commitPosition() {
    configEntry.x = root.x;
    configEntry.y = root.y;
    configEntry.z = root.z;
    root.targetX = Qt.binding(() => Math.max(0, Math.min(configEntry.x, scaledScreenWidth - width)));
    root.targetY = Qt.binding(() => Math.max(0, Math.min(configEntry.y, scaledScreenHeight - height)));
    root.targetZ = Qt.binding(() => configEntry.z);
    root.restoreXYBinding();
}

onReleased: root.commitPosition()
```
When `Instance B` (`videoIndex: 0`) is dragged and released:
1. `AbstractBackgroundWidget`'s `onReleased` fires and calls `commitPosition()`.
2. Even though `Instance B` is an array instance, `configEntry` still points to `Config.options.background.widgets.customVideo`.
3. `commitPosition()` assigns `configEntry.x = root.x` and `configEntry.y = root.y` (the drop destination coordinates).
4. `Instance A` (`videoIndex: -1`), whose position is bound to `configEntry.x` and `configEntry.y`, **instantly jumps** to the new drop position directly underneath `Instance B`.
5. Because `Instance A` immediately moves from `(636, 756)` to `(836, 756)` beneath `Instance B`, the visual at the original position disappears at the exact instant of mouse release!

---

## 6. Exact Component, Property, and State Transition Responsible

1. **`modules/ii/background/WidgetsLoader.qml` (L180-191):**
   `customVideoComp` lacks the exclusivity guard:
   `visible: !Config.options.background.widgets.customVideo.videos || Config.options.background.widgets.customVideo.videos.length === 0`
   This caused duplicate concurrent instantiation of `CustomVideo` (legacy `videoIndex: -1` + Repeater `videoIndex: 0`).

2. **`modules/ii/background/widgets/videos/CustomVideo.qml` (L597-614):**
   `CustomVideo` defined `onReleased` without properly overriding `function commitPosition()`.
   As a result, releasing any array instance invoked `AbstractBackgroundWidget.commitPosition()`, corrupting `configEntry.x` and `configEntry.y` with the array widget's position and teleporting the legacy instance.
   Additionally, `onReleased` was calling `updateArrayVideo` twice sequentially (once for `"x"` and once for `"y"`), causing double model evaluations.

3. **`modules/ii/background/widgets/videos/CustomVideo.qml` (L274-277):**
   `StyledDropShadow` lacked `visible: Config.options.background.widgets.shadow` (unlike `CustomImage.qml`), rendering shadow layers unconditionally.

---

## 7. The Minimal Safe Fix

1. **In `modules/ii/background/WidgetsLoader.qml`:**
   Restore the standard exclusivity guard on `customVideoComp`:
   ```qml
   Component {
       id: customVideoComp
       CustomVideo {
           visible: !Config.options.background.widgets.customVideo.videos || Config.options.background.widgets.customVideo.videos.length === 0
           videoIndex: -1
           screenWidth: root.screen.width
           screenHeight: root.screen.height
           scaledScreenWidth: root.screen.width
           scaledScreenHeight: root.screen.height
           wallpaperScale: 1
       }
   }
   ```
   This guarantees that when `videos` array contains items, only the `Repeater` instances are visible; when `videos` is empty, only the legacy fallback instance is visible. Exactly matching `customImageComp`.

2. **In `modules/ii/background/widgets/videos/CustomVideo.qml`:**
   - Implement `updateArrayVideoPosition(idx, x, y)` to commit coordinates atomically in a single write.
   - Override `function commitPosition()` so that for `root.videoIndex >= 0`, only the array element's position is updated, without overwriting `configEntry.x` / `configEntry.y`.
   - Update `onReleased` to cleanly invoke `root.commitPosition()`.
   - Ensure `StyledDropShadow` checks `visible: Config.options.background.widgets.shadow`.
