# Forensics: CustomVideo drag — does a loaded video block movement?

> Read-only investigation. No source files modified.
> Scope: System1 ONLY — widget movement (dragging the CustomVideo widget).
> Not file-drop, not picker, not instance lifecycle.
> Qt version under analysis: **6.11.2** (matches the rebuilt quickshell binary).

## Reproduction

As reported (and as carried forward by `forensics-video-drag.md` §1 and
`root-cause-v2.md` BUG2):

1. `Config.options.background.widgets.customVideo.enable` ON.
2. One CustomVideo widget placed (legacy `videoIndex:-1` or array instance).
3. Empty (`videoPath === ""`) → body press engages `AbstractWidget.drag.target`;
   widget moves.
4. Pick a `.mp4`/`.webm` → `setVideoPath` sets `videoPath`/`videoValid = true`.
5. Once the video texture is live, a body press no longer engages
   `drag.target`; widget cannot be moved. Right-click still toggles
   `widgetsLocked`; resize/delete corner handles still work.
6. Clear path → drag returns.

**Caveat on live config.** PROVEN FACT4 records `widgetsLocked = true` at
observation time. `draggable` is
`placementStrategy === "free" && !Config.options.background.widgetsLocked`
(`AbstractBackgroundWidget.qml:40`), so with `widgetsLocked = true` drag is
disabled for **both** empty and loaded widgets. The reported differential
(empty drags, loaded does not) is therefore only observable with
`widgetsLocked = false`. The analysis below assumes that condition
(`draggable = true`), consistent with `forensics-video-drag.md` §3.

## Event Flow (Qt6.11.2 pointer delivery, proven from source)

Mouse press delivery in Qt Quick is performed by
`QQuickDeliveryAgentPrivate::deliverPointerEvent`, which calls
`pointerTargets(rootItem, event, point, checkMouseButtons, checkAcceptsTouch)`
to build the candidate list (`qquickdeliveryagent.cpp`, codebrowser v6.10 ≈ 6.11):
`deliverSinglePointEventUntilAccepted` at line ~1338 calls `pointerTargets` at
line ~1343, then iterates `targetItems` in reverse paint order, delivering to
each until `point.isAccepted()`.

`pointerTargets` relevance is "mainly determined by
`QQuickItem::contains()` and `QQuickItem::clipRect()`" (qt/qtdeclarative PR
#10), and for mouse events `checkMouseButtons = true`: an item is a candidate
**only if `acceptedMouseButtons() & event->button()` is non-zero** and
`contains(point)` is true.

Therefore the press reaches exactly the items that (a) geometrically contain
the point and (b) accept the pressed button, topmost-first. Items with
`acceptedMouseButtons() == Qt::NoButton` are **excluded from the target list
entirely** — they neither receive the press nor "claim" it; they are simply
invisible to mouse delivery.

## Exact Object Receiving the Pointer

### Default `acceptedMouseButtons` of every QQuickItem subclass in the subtree

Verified from Qt6.11.2 primary source (codebrowser + GitHub raw +
`/usr/include/qt6`):

| Item (QML) | C++ class | `setAcceptedMouseButtons` called in ctor? | Default `acceptedMouseButtons` | Source |
|---|---|---|---|---|
| `Item` (contentItem) | `QQuickItem` | no | `Qt::NoButton` | `qquickitem.cpp:2377` ctor → `QQuickItemPrivate` (`qquickitem.cpp:3294`) sets `flags(0)`, no `LeftMouseButtonAccepted` tag; accessor `qquickitem_p.h:1065-1069` returns `Qt::NoButton` when tag unset and `extra` unallocated |
| `MaterialShape` (ShapeCanvas) | `QQuickShape` | no — ctor calls `init()` which only `setFlag(ItemHasContents)` | `Qt::NoButton` | `qquickshape.cpp:899-904` ctor → `QQuickShapePrivate::init` (`:856-860`) sets only `ItemHasContents` |
| `StyledDropShadow` (DropShadow) | `QQuickDropShadow` (Qt5Compat) | no | `Qt::NoButton` (inherits QQuickItem) | effect items do not register mouse buttons |
| `VideoOutput` | `QQuickVideoOutput` | no | `Qt::NoButton` | `qquickvideooutput_p.h:88` ctor; no mouse registration |
| `MaskMultiEffect` (MultiEffect) | `QQuickMultiEffect` | no | `Qt::NoButton` | `qquickmultieffect_p_p.h:32` `QQuickMultiEffectPrivate : public QQuickItemPrivate`; no mouse setup in API/ctor |
| `MaterialSymbol` (Text) | `QQuickText` | no | `Qt::NoButton` | text items do not accept mouse buttons by default |
| `DropArea` | `QQuickDropArea` | **no** — ctor only `setFlags(ItemAcceptsDrops)` | `Qt::NoButton` | `qquickdroparea.cpp:80-83` ctor: `setFlags(ItemAcceptsDrops)` only |
| `Rectangle` (controlsBar/resizeHandle/deleteHandle) | `QQuickRectangle` | no | `Qt::NoButton` | rectangles do not accept mouse buttons |
| `RippleButton` (Button) | `QQuickAbstractButton` → `QQuickControl` | **yes** (Control registers LeftButton) | `Qt::LeftButton` | QtQuick.Controls base registers mouse buttons |
| `MouseArea` (resizeArea/deleteArea/root) | `QQuickMouseArea` | **yes** | `Qt::LeftButton|RightButton` (root: `AbstractWidget.qml:22`) | MouseArea registers accepted buttons |

**Conclusion:** In CustomVideo's `contentItem`, the only items that accept a
left press are:
- the4 `RippleButton`s inside `controlsBar` (z:3),
- `resizeArea` MouseArea (z:2, 16×16 bottom-right corner),
- `deleteArea` MouseArea (z:4, 22×22 top-right corner).

Every other child — `MaterialShape`×3, `StyledDropShadow`, `VideoOutput`,
`MaskMultiEffect`, `MaterialSymbol`, `DropArea`, the three `Rectangle`s — has
`acceptedMouseButtons == Qt::NoButton` and is **excluded from the mouse-press
target list**. They cannot receive, block, or "claim" a mouse press.

### Geometry of the press-accepting children

| Child | z | anchors / size | visible when | body coverage |
|---|---|---|---|---|
| `controlsBar` (RowLayout of4 RippleButtons) | 3 | `horizontalCenter: videoShape.horizontalCenter; bottom: videoShape.bottom; bottomMargin: max(8, w*0.06)`; width ≈ `4*28 + 3*8 +12 = 148`, height ≈ `28+8 =36` (`CustomVideo.qml:255-323`) | `containsMouse && videoPath !== "" && videoValid` (`:267-268`) | bottom strip only (~148×36 of a200×200 widget ≈13% area) |
| `resizeArea` |2 | `right/bottom: videoShape; margins:6`; 16×16 (`:325-344`) | `containsMouse \|\| resizeArea.containsMouse \|\| pressed` && `!widgetsLocked` (`:336-337`) | 16×16 bottom-right corner |
| `deleteArea` | 4 | `top/right: videoShape; margins:6`;22×22 (`:376-408`) | `containsMouse \|\| deleteArea.containsMouse` && `(videoIndex>=0 \|\| videoPath !== "")` (`:387-388`) |22×22 top-right corner |

None of these covers the widget body. A press on the center / upper-left /
upper-right (outside the22×22 delete corner) / lower-left reaches **no
press-accepting child** and is delivered to the root `AbstractWidget` MouseArea
(the `root` item itself, which accepts `Qt.LeftButton|RightButton`,
`AbstractWidget.qml:22`).

### Therefore

In **both** the empty and the loaded state, a body press (outside the three
corner/strip regions) is delivered to the **root `AbstractWidget` MouseArea**.
`drag.target: draggable ? dragProxy : undefined` (`AbstractWidget.qml:23`) is
set identically in both states because `draggable`
(`placementStrategy === "free" && !widgetsLocked`,
`AbstractBackgroundWidget.qml:40`) is **not** a function of `videoPath`.
`drag.active` (exposed as `root.dragging`, `AbstractWidget.qml:15`) must flip
on press+move in both states.

## Root Cause

**The pointer-blocking theory is FALSIFIED by Qt 6.11.2 source.**

`forensics-video-drag.md` §4 and `root-cause-v2.md` BUG 2 attribute the drag
failure to the `MaskMultiEffect` + `VideoOutput` `layer.enabled` effect subtree
"claiming the press before the MouseArea drag machinery can latch
`drag.target`" — a "scene-graph, not a MouseArea rule" mechanism. That
mechanism does not exist in Qt 6.11.2:

- `QQuickMultiEffect`, `QQuickVideoOutput`, `QQuickShape`, `QQuickDropArea`,
  `QQuickRectangle`, `QQuickText` all default to
  `acceptedMouseButtons == Qt::NoButton` (constructors verified above).
- `QQuickDeliveryAgentPrivate::pointerTargets` filters mouse-press candidates
  by `acceptedMouseButtons & button`; `NoButton` items are not candidates and
  cannot intercept.
- `layer.enabled` (render-to-texture / FBO) affects the scene-graph paint path
  only; it does **not** set `clip`, does not alter `clipRect()` or
  `contains()`, and does not register mouse buttons. It has no input-delivery
  effect.

There is no body-covering, press-accepting child in CustomVideo. The only
video-dependent press acceptors are the hover-revealed `controlsBar`
RippleButtons (bottom strip, ~13% area) and the `deleteArea` corner (which
CustomVideo shows for legacy instances too, via `videoPath !== ""`, unlike
CustomImage's `imageIndex >=0` — `CustomVideo.qml:388` vs
`CustomImage.qml:261`). These explain a drag failure **only when the user
presses inside their small regions**, not a total body-press failure.

**ROOT CAUSE NOT PROVEN (for a total failure).** Static analysis of Qt6.11.2
source and the examined files shows that a center/upper body press must reach
the root MouseArea and engage `drag.target` in both the empty and loaded
states. If the reported total failure reproduces, the cause lies outside what
these files and headers can prove — it requires runtime instrumentation:

- `QML_MOUSE_MANIPULATION` / `qt.quick.mouse.target` / `qt.quick.pointer`
  logging to see which item receives the left press and whether
  `drag.active` flips;
- or temporary `onPressed`/`onPositionChanged` handlers on the root MouseArea
  to confirm press arrival and `dragging` state.

### Hypotheses (unproven, ranked)

1. **Partial-coverage misread (most likely).** The reported "cannot move" is
   actually "cannot move when pressing the bottom strip / corners," because
   hover reveals `controlsBar`/`deleteArea`/`resizeArea` exactly when a video
   is loaded. A user who grabs the widget near the bottom (where the controls
   appear) hits a RippleButton, which takes the exclusive grab and the root
   drag never engages. Center/upper presses would still drag. This matches the
   geometry above and requires no new Qt mechanism.
2. **A runtime-only Qt interaction** between a live, per-frame-updating
   `VideoOutput` texture (`layer.enabled:true`) and the `MultiEffect` source
   sampling it, affecting drag grab timing. Not derivable from headers; needs
   runtime proof.
3. **`widgetsLocked` state at test time.** If `widgetsLocked = true`
   (PROVEN FACT 4), `draggable = false` for **both** states and neither drags;
   the "empty drags" observation would then be stale or from a different
   session. Re-confirm `widgetsLocked` at the moment of reproduction.

## Evidence

### Qt6.11.2 source (primary)

- `qquickitem.cpp:2377` — `QQuickItem::QQuickItem` ctor → `d->init(parent)`.
- `qquickitem.cpp:3294` — `QQuickItemPrivate` ctor: `flags(0)`, no
  `LeftMouseButtonAccepted` tag set, `extra` lazily unallocated.
- `qquickitem_p.h:1065-1069` — `acceptedMouseButtons()` accessor:
  `return (extra.tag().testFlag(LeftMouseButtonAccepted) ? Qt::LeftButton
  : (extra.isAllocated() ? extra->acceptedMouseButtons : Qt::NoButton))`.
  Default (tag unset, extra unallocated) ⇒ `Qt::NoButton`.
- `qquickitem_p.h:478-479` — `NoTag =0x1`, `LeftMouseButtonAccepted =0x2`;
  default tag is `NoTag`, so the `LeftMouseButtonAccepted` bit is clear by
  default.
- `qquickitem.cpp:8342-8350` — `setAcceptedMouseButtons` sets the
  `LeftMouseButtonAccepted` tag only when explicitly called with
  `Qt::LeftButton`; plain items never call it.
- `qquickshape.cpp:899-904` + `:856-860` — `QQuickShape` ctor →
  `QQuickShapePrivate::init` sets only `ItemHasContents`; no
  `setAcceptedMouseButtons`.
- `qquickdroparea.cpp:80-83` — `QQuickDropArea` ctor: `setFlags(ItemAcceptsDrops)`
  only; no `setAcceptedMouseButtons` ⇒ `Qt::NoButton`.
- `qquickmultieffect_p_p.h:32` — `QQuickMultiEffectPrivate : public
  QQuickItemPrivate`; no mouse-button registration in the MultiEffect API.
- `qquickvideooutput_p.h:88` — `QQuickVideoOutput` ctor; no mouse-button
  registration.
- `qquickdeliveryagent.cpp` (codebrowser v6.10 ≈ 6.11): `deliverSinglePointEventUntilAccepted`
  (~:1338) → `pointerTargets(rootItem, event, point, checkMouseButtons=false,
  checkAcceptsTouch=false)` (~:1343); for mouse press the mouse path sets
  `checkMouseButtons=true`, excluding `NoButton` items. Delivery iterates
  `targetItems` reverse-paint-order until `point.isAccepted()` (~:1361-1374).
- qt/qtdeclarative PR #10: "`pointerTargets` relevance is mainly determined by
  `QQuickItem::contains()` and `QQuickItem::clipRect()`" — geometric + button
  acceptance, not paint/layer ownership.

### Project source (cited)

- `AbstractWidget.qml:8` — root is `MouseArea`.
- `AbstractWidget.qml:22` — `acceptedButtons: Qt.LeftButton | Qt.RightButton`.
- `AbstractWidget.qml:23` — `drag.target: draggable ? dragProxy : undefined`.
- `AbstractWidget.qml:15` — `readonly property bool dragging: drag.active`.
- `AbstractWidget.qml:93-99` — `Binding{target:root; property:"x";
  value: snap(dragProxy.x); when: root.dragging; restoreMode: RestoreNone}`.
  During drag this owns `x`; the declarative `x: targetX` binding is removed.
  `RestoreNone` ⇒ on drag end `x` is a static value until `restoreXYBinding()`
  re-binds it. Identical for CustomImage and CustomVideo — not a differential.
- `AbstractBackgroundWidget.qml:27` — `x: targetX` (declarative).
- `AbstractBackgroundWidget.qml:40` — `draggable: placementStrategy === "free"
  && !Config.options.background.widgetsLocked` (video-independent).
- `AbstractBackgroundWidget.qml:41-45` — `restoreXYBinding()` re-binds
  `x/y/z` to `targetX/Y/Z`.
- `AbstractBackgroundWidget.qml:57` — base `onReleased: root.commitPosition()`.
- `CustomVideo.qml:49-56` — overrides `targetX`/`targetY` from `videoConfig`.
- `CustomVideo.qml:160-417` — `contentItem` children (declaration order):
  `shadowShape` (visible:false), `StyledDropShadow` (z:-1), `videoShape` (z:0,
  containing `videoOut` visible:false + `videoMaskShape` visible:false +
  `MaskMultiEffect` visible:videoPath!=="" + `MaterialSymbol` + `DropArea`),
  `controlsBar` (z:3, RippleButtons), `resizeHandle` (z:2, MouseArea),
  `deleteHandle` (z:4, MouseArea).
- `CustomVideo.qml:231-252` — `DropArea` exists (contradicts stale
  `root-cause-v2.md` BUG1 which claimed it was missing).
- `CustomVideo.qml:267-268` — `controlsBar` visible only on
  `containsMouse && videoPath !== "" && videoValid`.
- `CustomVideo.qml:388` — `deleteHandle` visible when
  `videoIndex >=0 || videoPath !== ""` (broader than CustomImage's
  `imageIndex >= 0`).
- `CustomVideo.qml:492-509` — `onReleased` override: writes
  `videos[i].x/y` or `configEntry.x/y`, then `restoreXYBinding()`. Does not
  call `commitPosition()`; does not re-bind `targetX` (its declarative binding
  was never removed). Affects post-drag persistence only, not drag engagement.
- `CustomImage.qml:139-146` — `imageShape` `layer.enabled:true` +
  `layer.effect: OpacityMask` (the working clipping pattern).
- `CustomImage.qml:148-157` — `StyledImage` (plain `Image`, `Qt::NoButton`).
- `CustomImage.qml:172-193` — `DropArea` `anchors.fill: parent` (same as
  CustomVideo); CustomImage drags fine ⇒ DropArea does not intercept press
  (confirmed by `qquickdroparea.cpp:80-83`).
- `CustomImage.qml:261` — `deleteHandle` visible only for
  `imageIndex >=0` (legacy instance never shows delete).

### Delta table

| Aspect | CustomVideo (loaded, "fails") | CustomImage (loaded, works) |
|---|---|---|
| Visible content item | `MaskMultiEffect` (MultiEffect, NoButton) sampling `videoOut` (VideoOutput, NoButton, layer.enabled) + `videoMaskShape` (Shape, NoButton, layer.enabled) | `StyledImage` (Image, NoButton) inside `imageShape` with `layer.enabled:true` + `OpacityMask` |
| `DropArea` | present, `anchors.fill: parent` (NoButton) | present, `anchors.fill: parent` (NoButton) |
| `controlsBar` | z:3, 4 RippleButtons, bottom strip, hover+video | none |
| `deleteHandle` visible | `videoIndex>=0 \|\| videoPath !== ""` (legacy+array) | `imageIndex >=0` (array only) |
| `deleteHandle` z | 4 |2 |
| `draggable` | `free && !widgetsLocked` | `free && !widgetsLocked` |
| `drag.target` | `dragProxy` | `dragProxy` |
| Body-covering press acceptor? | **none** (proven) | none |

The only structural delta that activates with a loaded video and has no
CustomImage counterpart is the `MaskMultiEffect`/`VideoOutput`/`videoMaskShape`
effect subtree. **It is proven not to accept mouse buttons**, so it cannot be
the pointer-blocking cause attributed to it.

## Minimal Fix

Because the prevailing theory is falsified, **do not apply the
`forensics-video-drag.md` §6 Option A rewrite on the premise that the effect
subtree blocks the press** — that premise is false. Instead:

### Step 1 — Confirm the symptom and locate the press (required, runtime)

Before any code change, instrument to determine where the left press actually
lands and whether `drag.active` flips:

- Run with `QT_LOGGING_RULES="qt.quick.mouse.target=true;qt.quick.pointer=true"`
  (and optionally `qt.quick.hover.trace=true`) and reproduce.
- Or temporarily add to `AbstractWidget.qml` root:
  ```qml
  onPressed: (mouse) => { console.log("press on root", mouse.button, "drag.target=", drag.target) }
  onPositionChanged: (mouse) => { if (drag.active) console.log("dragging", drag.target.x) }
  ```
  and to `CustomVideo.qml` `controlsBar`/`deleteArea`/`resizeArea` an
  `onPressed` log, to see which item takes the grab.

If the press lands on a RippleButton/`deleteArea`/`resizeArea` (Hypothesis1),
the fix is to keep those handlers from suppressing the parent drag — e.g. set
`propagateComposedEvents: true` on them or ensure they only cover their visual
footprint (they already do). The real fix is then UX: the user is pressing on a
control, not the body.

### Step2 — If runtime proves a total body-press failure (Hypothesis2)

Only then consider the `forensics-video-drag.md` §6 Option A rewrite (mirror
`CustomImage`'s `layer.effect: OpacityMask` pattern, drop `MaskMultiEffect` +
`videoMaskShape`, make `videoOut` `visible:true`). This is a reasonable
defensive simplification — it removes the only video-specific subtree and
aligns with the working reference — but it should be justified by runtime
evidence, not by the falsified pointer theory. It carries the visual-regression
risks already noted in `forensics-video-drag.md` §7 (soft mask → hard alpha
mask).

### Step3 — Re-confirm `widgetsLocked` (Hypothesis 3)

Verify `widgetsLocked = false` at reproduction time; if it is `true`, drag is
disabled for both states and the reported differential cannot occur in that
session.

## Stale-prior-analysis note

- `root-cause-v2.md` BUG 1 ("CustomVideo has NO DropArea") is **stale**:
  `CustomVideo.qml:231-252` now contains a `DropArea` mirroring CustomImage.
- `root-cause-v2.md` BUG2 and `forensics-video-drag.md` §4 blame the
  `MaskMultiEffect`/`VideoOutput` `layer` effect subtree for "claiming the
  press." **Falsified** by Qt 6.11.2 source: those items are
  `Qt::NoButton` and are excluded from mouse-press delivery; `layer.enabled`
  has no input-delivery effect.
- `forensics-pointer.md` / `root-cause.md` BUG A blame removed root-level
  press handlers (`CustomVideo.qml:72-117` in a pre-fix tree). Already noted
  stale by `forensics-video-drag.md` §8; the current tree has only
  `onClicked` (`:83`), `onReleased` (`:492`), `onVideoPathChanged` (`:155`).
