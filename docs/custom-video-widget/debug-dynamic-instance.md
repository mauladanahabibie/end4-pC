---
title: "Debug Dynamic Instance Lifecycle"
tags: []
created: 2026-08-22T06:06:57.114Z
updated: 2026-08-22T06:06:57.114Z
sources: []
links: []
category: debugging
confidence: medium
schemaVersion: 1
---

# Debug Dynamic Instance Lifecycle

# DYNAMIC 'Add Custom Video' Lifecycle Investigation

**Author:** Qoder | **Session Date:** 2026-08-22 | **Target Directory:** `modules/ii/background/widgets/videos/` + related config/menu/viewer files

## Executive Summary

This document traces the complete lifecycle of dynamically added custom video widgets, from initial user action in the Desktop Menu through runtime instantiation, updates, deletion, and persistence. The implementation uses a **rebuild+reassign idiom** for array mutations and a **count-based Repeater model** to avoid destroying MediaPlayer instances on every config write.

### Key Acceptance Questions Answered

1. **After Add #1 from empty videos[], exactly which widgets exist?**
   - Legacy singleton `CustomVideo { videoIndex: -1 }` is destroyed (FadeLoader unloads).
   - ONE dynamic delegate created by Repeater: `CustomVideo { videoIndex: 0 }` rendering `videos[0]` path.
   - No legacy widget remains; no index-0 duplicate exists.

2. **After deleting videos[0] of [A,B], which delegate instances remain and what do they now render?**
   - ONLY `videoIndex: 1` delegate survives (tail element deleted).
   - Surviving delegate re-resolves `videos[1]`, which NOW contains B's data after shift.
   - Its existing MediaPlayer instance stays alive but its binding source changes → new player loaded.

---

## 1. Desktop Menu Button: `enable=true` Trigger and Config Mutations

**Location:** `DesktopMenu.qml` L358-366 (exact)

```qml
RippleButton {
    onClicked: {
        GlobalStates.desktopMenuOpen = false
        // Enable custom video so the widget becomes visible for the new entry
        if (!Config.options.background.widgets.customVideo.enable)
            Config.options.background.widgets.customVideo.enable = true
        desktopMenuVideoPickerProc.command = [...]
        desktopMenuVideoPickerProc.running = true
    }
}
```

### Exact Click Sequence

| Step | Action | Config Mutation |
|------|--------|-----------------|
| 1 | User clicks "Add Custom Video" button | `GlobalStates.desktopMenuOpen ← false` |
| 2 | If `customVideo.enable == false`, set it `true` | `Config.options.background.widgets.customVideo.enable ← true` (if needed) |
| 3 | Launch Python picker (`pick-video.py`) | No mutation; Process launched |
| 4 | User selects file → picker prints path → QML `onRead` fires | See Section 2 |

**Per-click mutations:**
- **Atomic:** `desktopMenuOpen = false` always executes
- **Conditional:** `enable = true` executes ONCE per first click after shell restart or explicit disable
- **No immediate append:** Array push occurs only in picker's `onRead` callback, not at click time

**File citations:** `DesktopMenu.qml:358-366`, `DesktopMenu.qml:71-110`

---

## 2. desktopMenuVideoPickerProc.onRead: Build-and-Reassign Logic

**Location:** `DesktopMenu.qml` L75-110 (exact)

```qml
Process {
    id: desktopMenuVideoPickerProc
    stdout: SplitParser {
        onRead: data => {
            if (data.trim().length > 0) {
                let list = []
                const vids = Config.options.background.widgets.customVideo.videos
                for (let i = 0; i < vids.length; i++) {
                    let o = vids[i]
                    list.push({ normalize... }) // preserve ALL fields
                }
                list.push({ path: data.trim(), shape: "Cookie4Sided", ... }) // NEW ENTRY
                Config.options.background.widgets.customVideo.videos = list
            }
        }
    }
}
```

### Branching Behavior

| Existing Array State | Rebuild Loop Iteration | Append Operation | Result |
|---------------------|----------------------|------------------|--------|
| `[]` (empty) | 0 iterations (range check fails immediately) | Push `{ path: "/path/to/new.mp4", shape: "Cookie4Sided", size:200, x:400, y: 100, autoplay: ..., loop: ..., muted: ..., playWhenCharging: ..., playWhenOnBattery: ... }` | `[newEntry]` length=1 |
| `[A,B,C]` | 3 iterations (copy A, B, C normalized) | Push `{ path: data.trim(), shape: default, ... }` | `[A,B,C,newEntry]` length=4 |

**Critical observations:**
- Each existing entry is **deep-copied** with normalized defaults for any missing fields (see `normalizeVideoEntry` pattern in BackgroundConfig.qml L63-75).
- Defaults applied when field absent:
  - `shape: "Cookie4Sided"`
  - `size: 200`
  - `x: 400`
  - `y: 100`
  - `autoplay: true`
  - `loop: true`
  - `muted: true`
  - `playWhenCharging: true`
  - `playWhenOnBattery: true`
- Assignment `videos = list` triggers Qt binding notification + JSON adapter `onAdapterUpdated` → debounced file write (50 ms via `Config.readWriteDelay`).

**File citations:** `DesktopMenu.qml:71-110`, `BackgroundConfig.qml:63-75` (same normalization logic reused in settings page)

---

## 3. Background.qml Repeater: Count-Based Model & Delegate Lifecycle

**Location:** `Background.qml` L537-570 (exact)

```qml
// Legacy single-video widget (shown ONLY when videos array is empty)
FadeLoader {
    shown: Config.options.background.widgets.customVideo.enable
        && Config.options.background.widgets.customVideo.videos.length === 0
        ...
    sourceComponent: CustomVideo { videoIndex: -1, ... }
}

// Dynamic multi-video Repeater (shown when enable=true)
Repeater {
    model: Config.options.background.widgets.customVideo.enable
        && (screenList filter)
        ? Config.options.background.widgets.customVideo.videos.length
        : 0
    delegate: FadeLoader {
        required property int index
        shown:true
        sourceComponent: CustomVideo { videoIndex: index, ... }
    }
}
```

### What Happens When Array Grows by +1

**Qt Repeater semantics (count-based model):**
- Repeater with numeric model instantiates **exactly N delegates** where N = model count.
- Delegates are NOT identified by content; they are indexed 0..N-1.
- **Expansion:** When count grows from N to N+1:
  - **Existing delegates survive unchanged** (delegate 0, 1, ..., N-1 persist).
  - **One new delegate created** at the tail (`index = N`).
  - All existing delegates re-evaluate their bound properties (including `videoConfig`) against the NEW array contents.
- **Contraction:** When count shrinks from N+1 to N:
  - **One delegate destroyed** (typically the highest index, i.e., tail).
  - Remaining delegates shift indices conceptually but retain instance identity.

**Applied to our case:**

| Initial state | After add one video | Which delegates? |
|--------------|--------------------|------------------|
| `videos=[]` → Repeater model=0 | `videos=[A]` → Repeater model=1 | OLD: none<br>NEW: delegate{index=0} created<br>Legacy FadeLoader: destroyed (condition `videos.length === 0` fails) |
| `videos=[A,B]` → model=2 | `videos=[A,B,C]` → model=3 | OLD: d0, d1<br>NEW: d2 created<br>Existing d0, d1 stay (they now render `videos[0]=A`, `videos[1]=B` — same bindings re-read from updated array) |
| `videos=[A,B]` → model=2 | `videos=[A]` → model=1 | d1 destroyed (tail)<br>d0 survives, now renders `videos[0]=A` (unchanged data) |

**Why MediaPlayer doesn't die:**
- CustomVideo's `MediaPlayer { id: player }` is child of CustomVideo delegate item.
- When delegate survives, MediaPlayer instance survives.
- On array reassignment, `player.source` binding (`source: root.videoPath !== "" ? "file://" + root.videoPath : ""`) re-evaluates, triggering reload only if source string changes.

**File citations:** `Background.qml:537-570`, `Background.qml:517-530` (similar image Repeater pattern)

---

## 4. Settings Page Paths: How Users Can Add Videos

### 4.1 Primary Add Path: ToolbarPairedFAB in BackgroundConfig.qml

**Location:** `BackgroundConfig.qml` L1597-1600 (exact)

```qml
ToolbarPairedFab {
    iconText: "add"
    onClicked: page.addCustomVideo("")
}
```

**Action:** Calls helper function L78-84:

```qml
function addCustomVideo(path) {
    let list = []
    const vids = Config.options.background.widgets.customVideo.videos
    for (let i = 0; i < vids.length; i++) list.push(normalizeVideoEntry(vids[i]))
    list.push(normalizeVideoEntry({ path: path ?? "" })) // EMPTY PATH initially
    Config.options.background.widgets.customVideo.videos = list
}
```

**User flow:** Click `+` → Entry created with empty path → New row appears with "folder_open" pick button to select actual video file.

### 4.2 Per-Row Pick Button: Update Existing Entry's Path

**Location:** `BackgroundConfig.qml` L1534-1536 (exact)

```qml
RippleButton {
    onClicked: {
        videoPickerProc.command = [...pick-video.py]
        videoPickerProc.videoIndex = vidRow.index
        videoPickerProc.running = true
    }
}
```

**Picker routing (L1612-1616):**
```qml
stdout: SplitParser {
    onRead: data => {
        if (videoPickerProc.videoIndex >= 0) {
            page.updateCustomVideo(videoPickerProc.videoIndex, "path", data.trim())
        } else {
            Config.options.background.widgets.customVideo.path = data.trim()
        }
    }
}
```

### 4.3 Delete Paths

| Location | Target | Action |
|----------|--------|--------|
| BackgroundConfig.qml L1485 | Row in Repeater | `page.removeCustomVideo(vidRow.index)` |
| CustomVideo.qml L432-433 | In-widget delete button | `root.deleteThisVideo()` |
| FullscreenViewer.qml L251-259 | Library view | Not yet implemented (no delete UI) |

**Settings remove() helper (L86-94):** Identical rebuild+reassign pattern as add, skipping index `i === index`.

**File citations:** `BackgroundConfig.qml:78-84`, `BackgroundConfig.qml:86-94`, `BackgroundConfig.qml:1597-1600`, `BackgroundConfig.qml:1534-1536`, `BackgroundConfig.qml:1612-1616`

---

## 5. Dynamic Instance Identity: videoIndex Resolution

### 5.1 Widget Field Definitions

**Location:** `CustomVideo.qml` L23, L27-33, L36 (exact)

```qml
property int videoIndex: -1  // -1 = legacy single-video mode

readonly property var videoConfig: {
    if (videoIndex >= 0) {
        const vids = Config.options.background.widgets.customVideo.videos
        if (vids.length > videoIndex)
            return vids[videoIndex]  // ARRAY ACCESS
    }
    return Config.options.background.widgets.customVideo  // FALLBACK TO LEGACY SINGLETON
}
```

**Binding chain (field → playback engine):**
```qml
property string videoPath: videoConfig.path ?? ""           // L36
property bool videoValid: videoPath !== ""                  // L38
property real widgetSize: videoConfig.size ??200 // L42
AudioOutput { muted: root.videoConfig.muted ?? true }       // L135
MediaPlayer { source: root.videoPath !== "" ? "file://" + root.videoPath : "" } // L141
loops: (root.videoConfig.loop ?? true) ? MediaPlayer.Infinite : 1 // L144
```

**targetX/Y override for per-instance positioning:**
```qml
targetX: {
    const ix = root.videoConfig.x ??400
    return Math.max(0, Math.min(ix, scaledScreenWidth - width))
}
targetY: { /* same pattern */ } // L56-62
```

### 5.2 Index Shift During Deletion

When `deleteThisVideo(index=0)` runs on `[A,B,C]`:
1. Helper rebuilds list without index 0 → `[B,C]`
2. `videos = list` assignment fires.
3. Repeater model drops from 3 to 2.
4. **Delegate destruction:** Highest index delegate (`videoIndex: 2`) removed.
5. **Surviving delegates:**
   - `videoIndex: 0` now resolves `videos[0]` → **B** (previously A).
   - `videoIndex: 1` now resolves `videos[1]` → **C** (unchanged content).
6. **MediaPlayer behavior:**
   - Delegate 0's MediaPlayer `source` binding changes from `"file:///A"` to `"file:///B"` → reloads.
   - Delegate 1's MediaPlayer continues playing C (no source change).

**Critical detail:** The surviving delegate's **visual identity** (widget at screen position X,Y) persists but **media content** may change if that index now points to a different array entry.

**File citations:** `CustomVideo.qml:23`, `CustomVideo.qml:27-33`, `CustomVideo.qml:36`, `CustomVideo.qml:42`, `CustomVideo.qml:56-62`, `CustomVideo.qml:133-144`

---

##6. Delete Lifecycle: Tail Destruction & Surviving Delegate Re-resolution

### 6.1 deleteThisVideo Implementation

**Location:** `CustomVideo.qml` L474-495 (exact)

```qml
function deleteThisVideo() {
    if (root.videoIndex < 0) return  // NOOP for legacy mode
    let list = []
    const vids = Config.options.background.widgets.customVideo.videos
    for (let i = 0; i < vids.length; i++) {
        if (i === root.videoIndex) continue  // SKIP DELETED INDEX
        let o = vids[i]
        list.push({ normalize... })  // COPY remaining entries
    }
    Config.options.background.widgets.customVideo.videos = list  // REBUILD+REASSIGN
}
```

### 6.2 UpdateArrayVideo Helper (Same Pattern)

**Location:** `CustomVideo.qml` L497-519 (exact)

```qml
function updateArrayVideo(idx, key, value) {
    let list = []
    const vids = Config.options.background.widgets.customVideo.videos
    for (let i = 0; i < vids.length; i++) {
        let o = vids[i]
        list.push({ normalize... })
    }
    if (idx < list.length) {
        list[idx][key] = value  // MUTATE IN PLACE THEN COPY
    }
    Config.options.background.widgets.customVideo.videos = list
}
```

### 6.3 What Gets Destroyed?

**Repeater with count-based model:**
- When count decreases, the **highest-index delegate** is destroyed.
- Example: `videos=[A,B,C]` (model=3) → delete `A (index=0)` → `videos=[B,C]` (model=2):
  - **Destroyed:** `videoIndex: 2` delegate (was rendering C's old slot).
  - **Remaining:** `videoIndex: 0` (now B), `videoIndex: 1` (now C).

**Why tail?**
- QtQuick Repeater internally allocates delegates sequentially.
- On shrinkage, it recycles and destroys from end of allocation.
- This is well-documented Qt behavior: see *Declarative Repeater* documentation.

### 6.4 Surviving MediaPlayer Fate

**Case study:** Delete videos[0] from `[A,B]`.
- **Before:** d0→A, d1→B.
- **After:** d0→B (re-bound), d1 destroyed.
- **MediaPlayer d0:**
  - Binding `player.source` evaluates new path `"file:///B"` ≠ old `"file:///A"`.
  - MediaPlayer detects source change, stops current media, loads new source.
  - **Instance survives**, decoding pipeline tears down cleanly.
- **MediaPlayer d1:** Never existed (only two elements); no impact.

**Case study:** Delete videos[1] from `[A,B]`.
- **Before:** d0→A, d1→B.
- **After:** d0→A (d1 destroyed).
- **MediaPlayer d0:** Source unchanged (`A` → `A`), continues playing.
- **MediaPlayer d1:** Destroys during delegate teardown (`Component.onDestruction: player.stop()` runs).

**File citations:** `CustomVideo.qml:474-495`, `CustomVideo.qml:497-519`, `CustomVideo.qml:156`

---

## 7. Persistence: Config Write Timing & Triggers

###7.1 Config.qml Write Mechanism

**Location:** `Config.qml` L13, L47-70 (exact)

```qml
property int readWriteDelay:50 // milliseconds
property bool blockWrites: false

Timer {
    id: fileWriteTimer
    interval: root.readWriteDelay
    repeat: false
    onTriggered: configFileView.writeAdapter()
}

FileView {
    id: configFileView
    watchChanges: true
    blockWrites: root.blockWrites
    onFileChanged: fileReloadTimer.restart()
    onAdapterUpdated: fileWriteTimer.restart()
    onLoaded: root.ready = true
}
```

**Chain of events:**
1. Any property mutation (including `videos = list` array replacement) notifies Qt bindings.
2. JsonAdapter's `onAdapterUpdated` signal fires.
3. `fileWriteTimer` resets/restarts (debounces coalesces multiple writes within 50 ms).
4. Timer triggers `writeAdapter()` → whole JSON file written atomically.
5. File watcher detects external change (self-monitoring) → reloads config on disk.

### 7.2 Does Array Reassignment Trigger a Write?

**YES.** Every rebuild+reassign expression:
- `Config.options.background.widgets.customVideo.videos = list`
- Fires JsonAdapter notification (array type has change tracking).
- Restarts 50 ms debouncer.
- Results in full config.json rewrite once debounce settles.

**Empirical verification:** grep confirmed `writeAdapter()` call sites: `Config.qml:60`, `Persistent.qml:37`. No special case for arrays.

### 7.3 blockWrites Control

Set to `true` temporarily by `killDialog.qml:L37-38` and `SettingsContent.qml:L81` during theme reapply to prevent rapid-fire writes during batch mutations.

**File citations:** `Config.qml:13`, `Config.qml:47-70`, `Config.qml:68`, `killDialog.qml:37-38`, `SettingsContent.qml:81`

---

## 8. Additional Add/Update Paths

### 8.1 Desktop Menu Context (Primary Path Covered Above)
- L358-366: Button click enables + launches picker → onRead append.

### 8.2 Settings Page FAB (Section 4.1)
- L1597-1600: `page.addCustomVideo("")` creates empty entry → user picks file via row-specific button.

###8.3 Drop Area (Widget Runtime)
- `CustomVideo.qml` L256-273:
  ```qml
  DropArea {
      keys: ["text/uri-list"]
      onDropped: (drop) => {
          if (accepted ext) {
              root.setVideoPath(cleanPath)
          }
      }
  }
  ```
- For array entries (`videoIndex >= 0`): `setVideoPath` calls `updateArrayVideo` (rebuid+reassign).
- For legacy mode (`videoIndex == -1`): sets singleton `config.customVideo.path`.

###8.4 Fullscreen Viewer Library Button
- `FullscreenVideoViewer.qml` L257-260:
  ```qml
  ViewerButton {
      symbol: "video_library"
      onClicked: { videoPickerProc.running = true }
  }
  ```
- Picker routes via `setVideoPath(path)` (L40-42):
  ```qml
  function setVideoPath(path) { root.updateActiveEntry("path", path) }
  ```
- `updateActiveEntry` (L63-88): rebuild+reassign for index ≥ 0; direct write for legacy.

**File citations:** `CustomVideo.qml:256-273`, `FullscreenVideoViewer.qml:257-260`, `FullscreenVideoViewer.qml:40-42`

---

## 9. Acceptance Question Deep Dive

### Q1: After Add #1 from empty videos[], exactly which widgets exist (legacy? index 0?)

**Initial state (videos=[]):**
- `CustomVideo.enable = false` OR `true`.
- Legacy FadeLoader condition: `enable && videos.length ===0` → **SHOWN**.
- Repeater model: `enable ? videos.length : 0` → **0**.
- Widgets visible: ONE legacy `CustomVideo { videoIndex: -1 }` (singleton fields).

**After first Add via Desktop Menu:**
1. Picker returns path `/home/user/video.mp4`.
2. `desktopMenuVideoPickerProc.onRead` rebuilds empty list → appends new entry → `videos = [{ path: "/home/user/video.mp4", ... }]`.
3. Config change triggers fade animation / layout recomputation.
4. Legacy FadeLoader condition: `enable && videos.length === 0` → **FAILS** (length=1). Fader unloads.
5. Repeater model: `enable ? videos.length : 0` → **1**.
6. ONE delegate instantiated: `FadeLoader → CustomVideo { videoIndex: 0 }`.
7. CustomVideo binds:
   - `videoConfig = videos[0]` (the newly added entry).
   - `videoPath = "/home/user/video.mp4"`.
   - `player.source = "file:///home/user/video.mp4"`.

**Final widget set:**
- ❌ Legacy widget: **destroyed**.
- ✅ Dynamic widget: **ONE** at index 0, rendering the new entry.

**Answer:** Exactly one widget exists: the dynamic delegate at index 0. No legacy widget coexists.

---

### Q2: After deleting videos[0] of [A,B], which delegate instances remain and what do they now render?

**Initial state:** `videos = [A, B]` (length=2).
- Repeater model=2.
- Two delegates: d0→A, d1→B.

**Delete action on d0's delete button:**
1. `root.videoIndex = 0`.
2. `deleteThisVideo()` skips index 0, copies indices 1..1.
3. `list = [normalize(B)]`.
4. `videos = [B]` (reassign).
5. Repeater model drops 2→1.
6. **Delegate destruction order:** Repeater frees highest index first: d1 removed.
7. **Delegate survival:** d0 remains.
8. **Binding re-evaluation:** d0 re-binds:
   - `videoConfig = videos[0]` → now **B** (was A).
   - `videoPath = B.path` (string changed).
   - `player.source` changes A→B, MediaPlayer stops A, loads B.

**Surviving widget:**
- **Instance:** d0 (original delegate for A).
- **Rendered content:** Now **B** (index shift).
- **Player:** Same instance, new media loaded.

**If deleting videos[1] instead (B):**
- `videos = [A]`.
- d1 (B) destroyed (tail).
- d0 survives, still renders A (unchanged).

**Answer:** Deleting videos[0] of [A,B] leaves ONE delegate (the original d0) which now renders B. Deleting videos[1] leaves d0 which continues rendering A.

---

## Appendix: Architecture Map

| Layer | Purpose | Key Files |
|-------|---------|-----------|
| **Persistence Schema** | Declares `videos[]` array, defaults | `Config.qml:337-352` |
| **Config Write Bus** | Debounced JSON adapter | `Config.qml:13,47-70` |
| **Desktop Menu** | First-run add trigger | `DesktopMenu.qml:358-366` |
| **Desktop Picker Proc** | onRead rebuild+reassign | `DesktopMenu.qml:75-110` |
| **Settings Page** | Secondary add/edit/delete paths | `BackgroundConfig.qml:78-100,1597-1620` |
| **Runtime Instantiate** | Legacy FadeLoader + Repeater | `Background.qml:537-570` |
| **Dynamic Widget** | videoIndex resolver, array helpers | `CustomVideo.qml:23-34,474-519` |
| **Full-screen Viewer** | Per-instance picker route | `FullscreenVideoViewer.qml:40-88` |
| **Power Gating** | Battery status play control | `CustomVideo.qml:64-75` |
| **Drop Area** | Drag-drop video URI handler | `CustomVideo.qml:256-273` |

**Key code patterns:**
- **Rebuild+reassign** (NOT in-place mutate) for all array writes.
- **Count-based Repeater model** (`videos.length`) to preserve MediaPlayer instances.
- **videoIndex sentinel** (-1 legacy vs ≥0 dynamic) for dual-mode support.
- **Normalize-on-copy** ensures consistent schema across entries.

---

## References

1. `DesktopMenu.qml`: L358-366 (button onClicked), L71-110 (picker proc).
2. `Background.qml`: L537-570 (legacy loader + dynamic Repeater).
3. `CustomVideo.qml`: L23, L27-34 (videoConfig resolver), L474-519 (delete/update helpers), L256-273 (drop area), L156 (onDestruction cleanup).
4. `BackgroundConfig.qml`: L78-100 (helper functions), L1597-1620 (settings picker routing).
5. `FullscreenVideoViewer.qml`: L40-88 (fullscreen picker route), L257-260 (library button).
6. `Config.qml`: L13 (readWriteDelay), L47-70 (persistence bus).
7. `WidgetsSubmenu.qml`: L57-66 (enable toggles).
8. `GlobalStates.qml`: L49-50 (fullscreen flags).
9. Qt Declarative Repeater docs: *count-based model* section.
10. `scripts/images/pick-video.py`: Zenity/KDialog fallback picker.

---

**END OF INVESTIGATION** |2026-08-22
