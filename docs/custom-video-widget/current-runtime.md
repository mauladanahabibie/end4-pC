# Current Runtime Status

**Date:** 2026-08-22
**Runtime access:** AVAILABLE (quickshell launched directly, logs captured)
**Method:** `/usr/bin/quickshell -p /home/danzzalexandra/.config/quickshell/end4-pC/shell.qml`

---

## MASTER FINDING — SHELL DOES NOT LOAD AT ALL

Captured runtime error, verbatim:

```
ERROR: Failed to load configuration
ERROR:   caused by @shell.qml[56:20]: Type IllogicalImpulseFamily unavailable
ERROR:   caused by @panelFamilies/IllogicalImpulseFamily.qml[33:30]: Type Background unavailable
ERROR:   caused by @modules/ii/background/Background.qml[541:38]: Type CustomVideo unavailable
ERROR:   caused by @modules/ii/background/widgets/videos/CustomVideo.qml[274:17]: ControlButton is not a type
```

Process exit code: **255**. Quickshell terminates. No panels, no background, no widgets.

`ControlButton` is referenced 4× in `CustomVideo.qml` (lines 274, 281, 289, 295) but is **not defined anywhere in the repository**:
- No `ControlButton.qml` file exists (verified via glob `**/ControlButton.qml` → only match is a doc reference).
- No inline `component ControlButton:` declaration in `CustomVideo.qml`.
- No import provides it. Similar names exist but are unrelated and not in scope: `OskControlButton` (inline component in `OnScreenKeyboard.qml`), `AiMessageControlButton` (aiChat).

### Consequence for all prior bug reports

Because `CustomVideo.qml` fails to compile, the type is unavailable, which makes `Background.qml` unavailable, which makes the whole shell config fail. Therefore:

- No version of `CustomVideo.qml` containing this reference has ever executed.
- All four reported runtime behaviours were observed against a previously-loaded shell state (stale process from before this file was introduced/edited), NOT against the current code.
- Previous agents' `qmllint` "0 errors" checks were meaningless: qmllint could not resolve any `qs.*` import (`Failed to import qs.services`, `qs.modules.common`, `qs.modules.common.widgets`, `qs.modules.common.functions`, `qs.modules.ii.background.widgets`), so no type resolution occurred and the missing `ControlButton` type was never flagged.

---

## Bug 1 — Video Widget Drag

Result: **NOT REPRODUCIBLE AGAINST CURRENT CODE — BLOCKED BY LOAD FAILURE**

Steps:
1. Launch quickshell with current repo state.
2. Observe: shell exits 255 before any widget is created.

Expected: empty widget draggable, video widget draggable.
Actual: no widget exists; `CustomVideo` type unavailable. Drag behaviour cannot be evaluated until the shell loads.

Note: previously reported asymmetry (empty draggable / video-present not draggable) was observed on an older loaded build, not this code.

---

## Bug 2 — File Drag & Drop

Result: **NOT REPRODUCIBLE AGAINST CURRENT CODE — BLOCKED BY LOAD FAILURE**

Steps:
1. Launch quickshell with current repo state.
2. Observe: shell exits 255; no drop target instantiated.

Expected: drop video file → video loads.
Actual: no widget exists.

Static note (not runtime-verified): a `DropArea` with `keys: ["text/uri-list"]` is present in `CustomVideo.qml` inside `videoShape`, structurally identical to the working one in `CustomImage.qml`. Its correctness is untested because the component never loads.

---

## Bug 3 — Empty Widget Picker

Result: **NOT REPRODUCIBLE AGAINST CURRENT CODE — BLOCKED BY LOAD FAILURE**

Steps:
1. Launch quickshell with current repo state.
2. Observe: shell exits 255; no widget to click.

Expected: click empty widget → picker opens.
Actual: no widget exists.

---

## Bug 4 — Toggle/Add Instance Collision

Result: **NOT REPRODUCIBLE AGAINST CURRENT CODE — BLOCKED BY LOAD FAILURE**

Steps:
1. Launch quickshell with current repo state.
2. Observe: shell exits 255; no instances created at all.

Expected: Toggle ON → A; Add → A + B; Add → A + B + C.
Actual: zero instances; `Background.qml` itself is unavailable.

---

## Blocking Order

The load failure must be resolved before any of the four bugs can be reproduced, root-caused at runtime, or verified. It is a prerequisite, not one of the four bugs.
