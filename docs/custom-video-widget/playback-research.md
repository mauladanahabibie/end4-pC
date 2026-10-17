# Custom Video Widget Playback Research

## 1. Executive Summary
This research document details the technical investigation of the existing Custom Video widget, fullscreen viewer, power/battery services, settings persistence, and multi-instance lifecycle in the Quickshell rice (`~/.config/quickshell/end4-pC`).

All findings are based on actual code inspection, runtime verification, and subagent deep-dives across repository files.

---

## 2. Component Inventory & Architecture

### 2.1 Custom Video Widget (`modules/ii/background/widgets/videos/CustomVideo.qml`)
- **Base Class:** Inherits from `AbstractBackgroundWidget` (`modules/ii/background/widgets/AbstractBackgroundWidget.qml`), which inherits from `AbstractWidget` (`modules/common/widgets/widgetCanvas/AbstractWidget.qml`).
- **Media Pipeline:**
  - `MediaPlayer` (`id: player`, lines 120–135):
    - `source`: `"file://" + root.videoPath`
    - `videoOutput`: `videoOut` (`VideoOutput`)
    - `audioOutput`: `audioOut` (`AudioOutput`)
    - `loops`: `(root.videoConfig.loop ?? true) ? MediaPlayer.Infinite : 1`
    - `autoPlay`: `false` (explicitly managed via `syncPlayback()`)
    - `onMediaStatusChanged: root.syncPlayback()`
    - `Component.onDestruction: player.stop()`
  - `VideoOutput` & `MaskMultiEffect` (lines 196–220):
    - Offscreen `videoOut` and white `videoMaskShape` rendered into `MaskMultiEffect` with `autoPaddingEnabled: false`.
- **Playback Synchronization:**
  - `playIntent`: User manual playback intent (defaulting to `videoConfig.autoplay ?? true`).
  - `powerAllowsPlay`: Currently gates playback by `Battery.isPluggedIn ? playWhenCharging : playWhenOnBattery`.
  - `effectivePlay`: `root.playIntent && root.powerAllowsPlay && root.videoValid && root.videoPath !== ""`
  - `syncPlayback()`: Checks `effectivePlay` and `player.mediaStatus`, calling `player.play()` or `player.pause()`.
- **Controls & Interaction:**
  - Hover `controlsBar` (lines 254–322):
    - Play/Pause button: toggles `root.playIntent` and calls `root.syncPlayback()`.
    - Replay button: resets `player.position = 0` and sets `root.playIntent = true`.
    - Mute button: toggles `root.videoConfig.muted`.
    - Fullscreen button: sets `GlobalStates.customVideoFullscreenIndex = root.videoIndex` and `GlobalStates.customVideoFullscreenOpen = true`.
  - Empty widget click (lines 89–95): executes `scripts/images/pick-video.py`.
  - Resize handle (`resizeArea`, lines 343–372): resizes widget (`widgetSize`).
  - Delete handle (`deleteArea`, lines 394–407): deletes array entry or clears legacy path.
  - Drop area (`DropArea`, lines 230–251): accepts `text/uri-list`, decodes URL, validates extension (`mp4`, `webm`, `mkv`, `avi`, `mov`, `m4v`, `ogv`).

### 2.2 Fullscreen Video Viewer (`modules/ii/background/FullscreenVideoViewer.qml`)
- **Root Container:** `Scope { id: root }`
- **Activation:** `Loader { id: viewerLoader; active: GlobalStates.customVideoFullscreenOpen && root.resolvedPath !== "" }`
- **Window:** `PanelWindow { id: viewerWindow }` on `WlrLayer.Overlay` with `WlrKeyboardFocus.Exclusive`.
- **Player:** Own independent `MediaPlayer` (`id: fsPlayer`, lines 134–141), `AudioOutput` (`id: fsAudio`), and `VideoOutput` (`id: fsVideoOut`).
  - Does **not** share `MediaPlayer` with `CustomVideo.qml`.
- **Closing Mechanism:**
  - `root.close()` (lines 34–38) sets:
    ```qml
    GlobalStates.customVideoFullscreenOpen = false
    GlobalStates.customVideoFullscreenIndex = -1
    ```
  - Triggered by `Escape` key, click outside controls, or `"close"` button.
- **Current Limitation:** `CustomVideo.qml` does not observe `GlobalStates.customVideoFullscreenOpen`. Therefore, the background video continues playing underneath the fullscreen overlay.

### 2.3 Power & Battery Services (`services/Battery.qml` & `Quickshell.Services.UPower`)
- **UPower Integration:**
  - `Quickshell.Services.UPower` exposes:
    - `UPower.onBattery` (`bool`): `true` when running on battery (unplugged from AC), `false` when connected to external line power / AC adapter. Universally available on Linux.
    - `UPower.displayDevice.isLaptopBattery` (`bool`): `true` if a laptop battery is installed.
    - `UPower.displayDevice.state`: `UPowerDeviceState` enum (`Unknown=0`, `Charging=1`, `Discharging=2`, `Empty=3`, `FullyCharged=4`, `PendingCharge=5`, `PendingDischarge=6`).
- **`services/Battery.qml` Singleton:**
  - `available`: `UPower.displayDevice.isLaptopBattery` (laptop battery present).
  - `isCharging`: `chargeState == UPowerDeviceState.Charging`.
  - `isPluggedIn`: `isCharging || chargeState == UPowerDeviceState.PendingCharge`.
  - **Critical Power Detection Insight:**
    - `Battery.isPluggedIn` evaluates to `false` when battery is 100% full (`FullyCharged`) and AC is plugged in.
    - `UPower.onBattery` correctly evaluates to `false` whenever external power is connected, regardless of battery percentage or charge state.
    - On desktop machines with no battery: `Battery.available` is `false`, and `UPower.onBattery` is `false`.

### 2.4 Settings System & Persistence (`modules/common/Config.qml` & `BackgroundConfig.qml`)
- **Configuration Schema:** `modules/common/Config.qml` (lines 434–450):
  ```qml
  property JsonObject customVideo: JsonObject {
      property bool enable: false
      property string placementStrategy: "free"
      property real x: 400
      property real y: 100
      property string path: ""
      property string shape: "Cookie4Sided"
      property real size: 200
      property bool autoplay: true
      property bool loop: true
      property bool muted: true
      property bool playWhenCharging: true
      property bool playWhenOnBattery: true
      property list<var> videos: []
  }
  ```
- **Persistence Mechanism:** Quickshell persists `Config.options` to `~/.config/illogical-impulse/config.json`.
- **List Rebuild Idiom:** `property list<var>` requires shallow/deep copies and re-assignment (`videos = list`) to trigger QML property bindings and atomic disk serialization.
- **Settings UI (`modules/ii/settings/pages/BackgroundConfig.qml`):**
  - Uses `ContentSection`, `ContentSubsection`, `GroupedList`, and `ConfigSwitch`.
  - `GroupedList` styles consecutive `ConfigSwitch` items with rounded corners. Note: `Repeater` must be placed outside `GroupedList`.

---

## 3. Multi-Instance Isolation Architecture
- **Instance Identity:**
  - `videoIndex: -1` represents the legacy singleton instance.
  - `videoIndex >= 0` represents an entry in `Config.options.background.widgets.customVideo.videos[videoIndex]`.
  - `WidgetsLoader.qml` runs a `Repeater` over `model: videos.length`.
- **Isolation Boundaries:**
  - Each `CustomVideo` instance creates its own `MediaPlayer`, `AudioOutput`, `VideoOutput`, and `MaskMultiEffect`.
  - In-memory playback state (`playIntent`, pause tracking, errors) must be kept strictly per-widget in local QML properties.
  - Fullscreen pause applies only to the specific instance whose index matches `GlobalStates.customVideoFullscreenIndex`.

---

## 4. Key Risks and Past Regressions Documented
1. **Pointer Grab vs Dragging:** Inner MouseAreas (`controlsBar`, handles) must not swallow drags meant for the outer widget.
2. **Path Encoding:** Dropped URLs from Wayland/file managers must be sanitized using `decodeURIComponent(url.replace(/^file:\/\//, ""))`.
3. **Explicit Picker vs Implicit Click:** Clicking an empty widget launches the file picker, but clicking a loaded widget opens fullscreen.
4. **Collision Between Singleton & Multi-Instance:** The legacy instance and multi-instance array must coexist without overwriting each other.
