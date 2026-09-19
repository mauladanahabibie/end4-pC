---
title: "debug-toggle-instance"
tags: ["custom-video", "toggle", "lifecycle", "debug", "FadeLoader", "MediaPlayer"]
created: 2026-08-22T06:11:48.475Z
updated: 2026-08-22T06:11:48.475Z
sources: []
links: []
category: debugging
confidence: medium
schemaVersion: 1
---

# debug-toggle-instance

# Custom Video Legacy Toggle Lifecycle — Debug Trace

## Executive Summary

This document traces the LEGACY single-video toggle lifecycle (`customVideo.enable`) read-only from the codebase. The investigation answers: what happens when `enable` toggles OFF/ON, and specifically what happens when `videos.length` transitions 0↔1 (does the legacy widget destroy or hide?).

---

## 1. Enable Toggle Location and Write Target

**File:** `modules/ii/settings/pages/BackgroundConfig.qml`  
**Lines:** L1219-1228 (Custom Video section)

```qml
ConfigSwitch {
    Layout.fillWidth: true
    buttonIcon: "check"
    text: Translation.tr("Enable")
    checked: Config.options.background.widgets.customVideo.enable
    onCheckedChanged: {
        Config.options.background.widgets.customVideo.enable = checked;
    }
}
```

**Exact write:** `Config.options.background.widgets.customVideo.enable = checked;`

The toggle only writes `enable`. It does NOT touch `path`, `videos`, or any playback flags.

**Schema location:** `modules/common/Config.qml` L337-350 defines the full `customVideo` JsonObject with flat legacy fields (`enable`, `placementStrategy`, `x`, `y`, `path`, `shape`, `size`, `autoplay`, `loop`, `muted`, `playWhenCharging`, `playWhenOnBattery`, `videos: []`).

---

## 2. Which Loader Creates the Legacy Widget on Toggle ON?

**File:** `modules/ii/background/Background.qml`  
**Line range:** L536-550 (inside Variants wrapper L29-32, so one instance per screen)

### FULL shown condition (L538-541):

```qml
shown: Config.options.background.widgets.customVideo.enable
    && Config.options.background.widgets.customVideo.videos.length === 0
    && (Config.options.background.screenList.length === 0
        || Config.options.background.screenList.includes(bgRoot.screen.name))
```

**Three conjuncts must hold:**
1. `enable === true` (from toggle)
2. `videos.length ===0` (legacy loader only shows when NO array entries exist)
3. Screen filter: `screenList.length === 0` OR current screen in list

**Widget instantiation (L542-549):**

```qml
sourceComponent: CustomVideo {
    videoIndex: -1   // ← indicates legacy singleton mode
    screenWidth: bgRoot.screen.width
    screenHeight: bgRoot.screen.height
    scaledScreenWidth: bgRoot.screen.width
    scaledScreenHeight: bgRoot.screen.height
    wallpaperScale: 1
}
```

The sibling Repeater (L551-573) handles multi-video array entries with `videoIndex: index`. They are mutually exclusive by construction.

---

## 3. FadeLoader Behavior When shown=false (Toggle OFF)

**File:** `modules/common/widgets/FadeLoader.qml` (imported via `qs.modules.common.widgets` at Background.qml L6)

**Full source (19 lines):**

```qml
Loader {
    id: root
    property bool shown: true
    property alias fade: opacityBehavior.enabled
    property alias animation: opacityBehavior.animation
    opacity: shown ? 1 : 0           // L10
    visible: opacity > 0             // L11
    active: opacity > 0              // L12 ← Critical binding

    Behavior on opacity {
        id: opacityBehavior
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }
}
```

### What happens when `shown=false`:

1. `opacity: shown ? 1 : 0` animates 1→0 via the Behavior (fade duration ~`elementMoveFast`)
2. `visible` becomes false (L11)
3. When opacity reaches 0, `active: opacity > 0` (L12) flips FALSE

### Destroy vs Hide Determination:

QML `Loader.active=false` DESTROYS the loaded object (releases it, calls `onDestruction`). The component is not merely hidden—it is torn down. Therefore:

**FadeLoader HIDES during the fade, then DESTROYS when opacity hits 0.**

**Consequence for MediaPlayer:** The embedded `MediaPlayer` is destroyed along with the widget. Playback position is lost. On re-enable (toggle ON or `videos.length` returns to 0), a brand-new `CustomVideo` instance is created (fresh MediaPlayer, `autoPlay: false` at CustomVideo.qml L144).

---

## 4. Legacy Instance Identity: All Fields Read

**File:** `modules/ii/background/widgets/videos/CustomVideo.qml`

### Key identity properties:

| Field | Line | Code |
|-------|------|------|
| `videoIndex` | L23 | `property int videoIndex: -1` |
| `videoConfig` resolution | L27-34 | Returns `vids[index]` if `index >=0`, else the flat `customVideo` object |

### ALL legacy flat-field reads (via `videoConfig.<field>` when `videoIndex === -1`):

| Field | Read line | Context/usage |
|-------|-----------|---------------|
| `path` | L36 | `property string videoPath: videoConfig.path ?? ""` → MediaPlayer source L141 |
| `autoplay` | L40, L176 | `property bool playIntent: videoConfig.autoplay ?? true` |
| `size` | L42 | `property real widgetSize: videoConfig.size ?? 200` → implicit dimensions L179-180 |
| `x` | L57 | `targetX: { const ix = root.videoConfig.x ?? 400 ... }` → clamped position |
| `y` | L61 | `targetY: { const iy = root.videoConfig.y ??100 ... }` → clamped position |
| `shape` | L197, L211 | `root.getShape(root.videoConfig.shape ?? "Cookie4Sided")` → shadow & mask shape |
| `muted` | L135 | AudioOutput `muted: root.videoConfig.muted ?? true` |
| `loop` | L145 | MediaPlayer `loops: (root.videoConfig.loop ?? true) ? MediaPlayer.Infinite : 1` |
| `playWhenCharging` | L72 | `powerAllowsPlay` power-gating check |
| `playWhenOnBattery` | L73 | `powerAllowsPlay` power-gating check |

All use `?? <default>` fallbacks, ensuring no crashes if legacy fields are undefined.

### Additional reads:
- L38: `videoValid: videoPath !== ""`
- L75: `effectivePlay: root.playIntent && root.powerAllowsPlay && root.videoValid && root.videoPath !== ""`

---

## 5. Legacy X (Delete) Button Behavior When videoIndex=-1

**File:** `modules/ii/background/widgets/videos/CustomVideo.qml`  
**Line range:** L406-448

### Delete handle visibility (L418):

```qml
visible: opacity > 0 && (root.videoIndex >= 0 || root.videoPath !== "")
```

Hides itself when `videoIndex=-1` AND `videoPath=""`.

### Click handler (L425-437):

```qml
MouseArea {
    id: deleteArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onClicked: {
        if (root.videoIndex >= 0) {
            root.deleteThisVideo()       // ← array branch removes entry
        } else {
            root.setVideoPath("")        // ← legacy branch clears path only
        }
    }
}
```

### setVideoPath("") for legacy (L450-456):

```qml
function setVideoPath(path) {
    if (root.videoIndex >= 0) {
        root.updateArrayVideo(root.videoIndex, "path", path)
    } else {
        Config.options.background.widgets.customVideo.path = path  // ← legacy write
    }
}
```

### Result of clicking X on legacy widget:
- `customVideo.path` is set to `""`
- Widget **instance STAYS ALIVE** (no array element exists; FadeLoader `shown` doesn't depend on `path`)
- Becomes empty placeholder shell: `videoValid=false`, "movie" icon visible (L233-238), no fullscreen viewer on click
- Playback stops (`effectivePlay` requires non-empty path at L75)

---

## 6. Does Toggling OFF/ON Recreate or Preserve the Widget?

**Answer: RECREATES it.** 

### Mechanism chain:
1. `enable=false` → FadeLoader `shown=false` → `opacity` animates 1→0
2. `active: opacity > 0` (L12) flips false when fade completes
3. QML `Loader.active=false` DESTROYS the loaded CustomVideo instance (`Component.onDestruction: player.stop()` fires at L156)
4. `enable=true` again → `shown=true` → `opacity` animates 0→1 → `active=true`
5. Loader instantiates a **brand-new CustomVideo { videoIndex: -1 }**, reading current config values

### No preservation:
- Old MediaPlayer instance is dead; new instance starts fresh at position 0
- `autoplay`, `loop`, `muted`, etc. are re-read from config (or defaults)
- Nothing about runtime state survives across OFF/ON

Same behavior when `videos.length` transitions 0↔1: the legacy instance is destroyed and recreated based solely on config values.

---

## 7. Desktop Menu / Settings "Clear Video" Paths for Legacy

### 7a. Widget X button (ONLY true clear while enable stays true)
See §5 above. Only the widget's own X button sets `customVideo.path=""` directly.

### 7b. Desktop menu "Add Custom Video" — NOT a clear; APPENDS array entry
**File:** `modules/ii/desktopMenu/DesktopMenu.qml` L70-110

The picker result handler rebuilds `videos[]` and APPENDS a new entry seeded from legacy playback flags (L102-106), then writes `config.videos = list` (L108). It does NOT write `customVideo.path`. Side effect: `videos.length` goes 0→1, hiding+destroying the legacy instance per §3.

### 7c. Settings page — legacy path SETTER exists but CLEARER does NOT
**File:** `modules/ii/settings/pages/BackgroundConfig.qml`

- Legacy subsections ("Default Shape" L1329-1345, "Video" L1347-1396) visible only when `videos.length === 0` (L1332, L1351)
- Legacy picker button sets `videoPickerProc.videoIndex = -1` and runs picker; result handler writes ONLY non-empty values:

```qml
// L1603-1618
Process {
    id: videoPickerProc
    property int videoIndex: -1
    stdout: SplitParser {
        onRead: data => {
            if (data.trim().length > 0) {
                if (videoPickerProc.videoIndex >= 0) {
                    page.updateCustomVideo(videoPickerProc.videoIndex, "path", data.trim())
                } else {
                    Config.options.background.widgets.customVideo.path = data.trim()   // L1615
                }
            }
        }
    }
}
```

There is **NO UI that writes `customVideo.path = ""`**. Every picker write sets a non-empty path from user selection. Per-entry removal (`removeCustomVideo(index)` L86-94, used at L1485) operates only on the `videos` array.

### 7d. Fullscreen viewer legacy fallback
**File:** `modules/ii/background/FullscreenVideoViewer.qml`

With `customVideoFullscreenIndex = -1`, `setVideoPath` routes to `Config.options.background.widgets.customVideo[key] = value` (L86). The viewer's loader is gated `active: ... && root.resolvedPath !== ""` (L104), so it simply deactivates when path is empty. Picker/drop inputs are always non-empty strings (L97, L184).

### Conclusion for §7:
Only the widget's own X button clears legacy video path while leaving `enable` unchanged. Desktop menu and settings only ADD/SET paths; they never clear.

---

##8. ANSWER TO THE KEY ASSIGNMENT QUESTION

> **"When enable=true and videos.length becomes 1, what happens to the legacy FadeLoader and its CustomVideo instance — destroyed or hidden? What recreates it when videos.length returns to 0?"**

### Direct answer:

**Destroyed (after brief hide), then recreated from scratch.**

### Step-by-step trace:

1. **Transition 0→1:** User clicks desktop menu "Add Custom Video" (DesktopMenu.qml L358-366) or adds via settings (BackgroundConfig.qml L79-84). Picker writes a new array entry → `videos.length` becomes 1.

2. **Legacy shown re-evaluates:** Background.qml L538-541 → conjunct 2 (`videos.length === 0`, L539) now false → `shown=false`.

3. **Fade out begins:** FadeLoader `opacity` animates 1→0 (L10), `visible` drops (L11).

4. **Destroy event fires:** When opacity reaches 0, FadeLoader `active: opacity > 0` (L12) flips false. QML Loader semantics: `active=false` destroys the loaded CustomVideo instance. Its `Component.onDestruction: player.stop()` (L156) runs; MediaPlayer tears down.

5. **New array instance created:** Simultaneously, Repeater (L555-573) instantiates `CustomVideo { videoIndex: 0 }` for the newly added array entry.

6. **Transition 1→0 (last entry removed):** Via widget X `deleteThisVideo()` (CustomVideo.qml L474-495) or settings `removeCustomVideo` (BackgroundConfig.qml L86-94). `videos.length` returns to 0.

7. **Legacy shown becomes true again:** Same conditions as step 1 now pass (`enable=true`, `videos.length===0`).

8. **Recreation:** FadeLoader opacity animates 0→1, `active` becomes true, Loader creates a FRESH `CustomVideo { videoIndex: -1 }` reading whatever legacy flat fields currently hold (§4). If legacy `path` was cleared earlier (§5), this new instance is an empty placeholder shell until a path is set again.

### Corollaries:
- **Toggle OFF/ON follows identical destroy/recreate semantics** (see §6). Any observed "position reset" is explained by this, not by config mutation.
- **Legacy and array widgets never coexist**: `videos.length === 0` gates the legacy loader (L539); Repeater count IS `videos.length` (L559).
- **Destroy is asynchronous**: fade animation delays destruction slightly; code observing config changes must not assume synchronous cleanup.

---

## Citation Index (file:line ranges)

| File | Lines | Content |
|------|-------|---------|
| modules/ii/settings/pages/BackgroundConfig.qml | 1219-1228 (esp. 1227) | Enable toggle; direct write of `customVideo.enable` |
| modules/ii/settings/pages/BackgroundConfig.qml | 79-104 | addCustomVideo/add/remove/update functions (array ops) |
| modules/ii/settings/pages/BackgroundConfig.qml | 1329-1345, 1347-1396 | Legacy-only settings sections (gated on `videos.length === 0`) |
| modules/ii/settings/pages/BackgroundConfig.qml | 1603-1618 (esp. 1615) | Legacy picker write `customVideo.path` (non-empty only) |
| modules/ii/background/Background.qml | 29-32 | Variants wrapper (one per screen) |
| modules/ii/background/Background.qml | 536-550 (esp. 538-541, 543) | Legacy FadeLoader + full shown condition + `videoIndex: -1` |
| modules/ii/background/Background.qml | 551-573 (esp. 556-560) | Multi-video Repeater with count-based model |
| modules/common/widgets/FadeLoader.qml | 5-18 (esp. 10-12) | `opacity/visible/active` bindings (active follows opacity) |
| modules/ii/background/widgets/videos/CustomVideo.qml | 23, 27-34 | `videoIndex` identity flag, `videoConfig` resolution logic |
| modules/ii/background/widgets/videos/CustomVideo.qml | 36, 40,42, 56-63, 68-75, 135, 141-145, 197, 211 | Legacy flat-field reads (path/autoplay/size/x/y/power/muted/loop/shape) |
| modules/ii/background/widgets/videos/CustomVideo.qml | 139-156 (esp. 144, 156) | MediaPlayer definition (`autoPlay: false`), `Component.onDestruction: player.stop()` |
| modules/ii/background/widgets/videos/CustomVideo.qml | 406-448 (esp. 418, 432-436) | X handle visibility + click handler: legacy branch `setVideoPath("")` |
| modules/ii/background/widgets/videos/CustomVideo.qml | 450-456 (esp.454) | `setVideoPath` function writing legacy `customVideo.path` |
| modules/ii/background/widgets/videos/CustomVideo.qml | 474-495 | `deleteThisVideo()` implementation (array only; early-return L475) |
| modules/ii/background/widgets/videos/CustomVideo.qml | 521-542 (esp.538-541) | `onReleased` position save via `configEntry.x/.y` |
| modules/ii/background/widgets/AbstractBackgroundWidget.qml | 19-24, 36-47 | `configEntry` object identity (same as `customVideo` object) |
| modules/ii/background/FullscreenVideoViewer.qml | 40-42,47-54, 63-88 (esp. 86),104 | Legacy fallback writes `customVideo[key]`; viewer loader gated on non-empty path |
| modules/ii/desktopMenu/DesktopMenu.qml | 70-110, 358-366 | "Add Custom Video" appends array entry, force-enables toggle |
| modules/common/Config.qml | 337-350 | `customVideo` schema (flat legacy fields + `videos: []`) |
| GlobalStates.qml | 49-50 | `customVideoFullscreenOpen` / `customVideoFullscreenIndex` state |

---

*Document created for toggle-lifecycle debugging investigation (read-only code tracing).*

