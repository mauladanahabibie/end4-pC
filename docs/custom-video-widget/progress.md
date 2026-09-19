# Custom Video Widget - Progress Tracker v2

**Last Updated:** 2026-08-22
**Status:** FIXES APPLIED — NEEDS RUNTIME VERIFICATION

---

## Fixes Applied (v2)

### FIX 1 — Drag & Drop (BUG 1)
- **Root cause:** No `DropArea` in CustomVideo.qml. `dropHover` was dead state. `setVideoPath` unreachable via drop.
- **Fix:** Added `DropArea` inside `videoShape` (line 229) mirroring CustomImage.qml:172-193. Keys: `["text/uri-list"]`. Validates extensions: mp4, webm, mkv, avi, mov, m4v, ogv. Calls `root.setVideoPath(cleanPath)` on drop.
- **File:** CustomVideo.qml

### FIX 2+3 — Picker + returntrue typo (BUG 3)
- **Root cause:** `returntrue` (no space) at line 59 caused ReferenceError when `!Battery.available` (desktop without battery). Also, CustomVideo's `onClicked` overrode AbstractWidget's right-click → widgetsLocked toggle was lost.
- **Fix:** Fixed `returntrue` → `return true` (line 59). Restored right-click handler in `onClicked` (line 83) to toggle `widgetsLocked`.
- **File:** CustomVideo.qml

### FIX 4 — Instance Collision (BUG 4)
- **Root cause:** Background.qml legacy FadeLoader `shown` condition: `enable && (videos.length === 0 || path !== "")`. Toggle creates legacy with `path=""`. Add Custom Video appends to `videos[]` (length > 0). Both conditions false → legacy hidden → instance A disappears.
- **Fix:** Removed `videos.length` and `path` conditions. Legacy shows when `enable && screenList guard` — independent of array contents.
- **File:** Background.qml

### BUG 2 — Video-Present Drag (UNRESOLVED — needs runtime test)
- **Forensics finding:** MaskMultiEffect + layer.enabled sources may interfere with pointer delivery. But MultiEffect is NOT a MouseArea — should not capture pointer events.
- **Hypothesis:** The `returntrue` typo may have caused initialization errors that indirectly affected drag. Now fixed.
- **Status:** Needs runtime verification. If drag still fails with video present, add diagnostic logging to AbstractWidget.qml to trace whether press reaches root MouseArea.

---

## Test Matrix (NEEDS RUNTIME VERIFICATION)

### TEST A — Empty Widget
- [ ] Can move widget
- [ ] Can click empty widget
- [ ] Explicit picker opens

### TEST B — Video Widget
- [ ] Video plays
- [ ] Widget can still move
- [ ] Widget can still resize

### TEST C — File Drop
- [ ] Drop event received
- [ ] Correct instance receives path
- [ ] Video appears
- [ ] Video plays

### TEST D — Multiple Instances
- [ ] Toggle ON: A appears
- [ ] Add: A + B
- [ ] Add: A + B + C
- [ ] No instance disappears

### TEST E — Clear
- [ ] Clear B: B becomes empty
- [ ] No automatic picker
- [ ] A and C unaffected

### TEST F — Explicit Picker
- [ ] Click B's empty state: picker opens
- [ ] Select video: loads ONLY into B

### TEST G — Delete
- [ ] Delete B: A + C remain

---

## Pass Criteria
- ALL tests must pass
- If ANY test fails: STATUS = BLOCKED with exact failing test
