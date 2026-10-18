# Technical Stability Research: Quickshell Rice Architecture

**Document:** `docs/stability-audit/research.md`  
**Target:** Quickshell `end4-pC` Rice on Qt 6 / Hyprland Wayland

---

## 1. Core Runtime Architecture & ABI Risk

### 1.1 Qt 6.11.2 vs Qt 6.12.0 ABI Mismatch
During startup, Quickshell logs:
```
WARN: Quickshell was built against Qt 6.11.2 but the system has updated to Qt 6.12.0 without rebuilding the package.
This is likely to cause crashes, so the quickshell package must be rebuilt.
```
- **Mechanism:** Arch/CachyOS rolling release updated Qt6 libraries to `6.12.0` (`/usr/lib/libQt6Quick.so.6.12.0`), but the installed `quickshell-git` package binary was compiled against headers from `6.11.2`.
- **Impact:** Binary ABI divergence in C++ virtual method tables and private implementation classes (e.g. `QQuickItemPrivate`, `QQuickWindowPrivate`). Memory offsets that shifted between 6.11 and 6.12 can lead to fatal segfaults when QML items are dirtied, destroyed, or garbage collected.
- **Mitigation:** The QML codebase must be engineered defensively to strictly avoid triggering fragile scene-graph state mutations (such as unparented items, invalid property bindings, and rapid anonymous item creation). Rebuilding `quickshell-git` from AUR with `makepkg -Csi` is also recommended.

---

## 2. Crash Vectors: The `OpacityMask` Scene Graph Race

### 2.1 The Anonymous `maskSource: Rectangle { ... }` Hazard
- **Observed Behavior:** Segfault in `QQuickItemPrivate::dirty(QQuickItemPrivate::DirtyType)` during theme switching or button interactions.
- **Root Cause Analysis:**
  1. `layer.effect: OpacityMask { maskSource: Rectangle { ... } }` creates an anonymous `Rectangle` inside the property assignment.
  2. Because the rectangle is instantiated directly in the property value without an explicit parent item, its visual parent in the QtQuick hierarchy is `null`.
  3. When JavaScript garbage collection runs or when `layer.enabled` switches between `true` and `false`, the JS wrapper for the anonymous `Rectangle` can be finalized while the QtQuick scene-graph node (`QSGNode`) retains a pointer to it.
  4. Subsequent scene-graph traversals dereference freed memory (`0xfefefefefefefefe`), producing an unrecoverable SIGSEGV.
- **Universal Fix Pattern:**
  Declare a persistent, explicitly parented item with `visible: false` outside the layer effect, and pass its ID to `maskSource`:
  ```qml
  Rectangle {
      id: persistentMask
      anchors.fill: parent
      radius: root.radius
      visible: false
  }

  layer.enabled: true
  layer.effect: OpacityMask {
      maskSource: persistentMask
  }
  ```
  This guarantees that the mask item is parented, lives as long as the parent component, is never garbage-collected independently, and costs zero GPU rasterization overhead when hidden.

---

## 3. Scope & Import Resolution: Undefined Identifier Hazards

### 3.1 Unqualified Singleton Resolution
In Quickshell, singletons declared in the root folder (`GlobalStates.qml`) require `import qs` to be in scope. Common functions (`ColorUtils.qml`) require `import qs.modules.common.functions`.
- **Observed Failures in Logs:**
  - `ConverterWidget.qml`: `ReferenceError: GlobalStates is not defined`, `ReferenceError: ColorUtils is not defined`.
  - `NoteEditorView.qml`: `ReferenceError: GlobalStates is not defined`, `ReferenceError: ColorUtils is not defined`.
  - `DiNotifs.qml`: `ReferenceError: GlobalStates is not defined` when clicking a notification.
  - `FrameHoverArea.qml`: `ReferenceError: GlobalStates is not defined` on mouse enter.
  - `DisplayProjection.qml`: `ReferenceError: GlobalStates is not defined` on shortcut trigger.
- **Root Cause:** When `import qs` is missing, accessing `GlobalStates` fails silently at compile time because QML allows dynamic lookups, but throws a `ReferenceError` at runtime whenever that branch executes.
- **Resolution:** Systematically add `import qs` and `import qs.modules.common.functions` to all consuming files.

---

## 4. CPU & Performance Architecture

### 4.1 Process Spawning & Visualizer Overhead
- `cava`: Runs in raw output mode (`scripts/cava/raw_output_config.txt`) streaming to `Visualizer.qml`.
  - Generates ~4-5% continuous CPU load while active.
  - Needs verification that `cava` suspends or pauses when the visualizer is hidden or when audio is not playing.
- `mpvpaper`: Two instances run concurrently for dual-screen animated wallpapers.
  - Generates ~10% CPU load per screen when active.
  - Mitigated by `LiveWallpaper.qml` power management (pausing on battery power, low battery, and lockscreen).
- `ResourceUsage.qml`: Polling loop reads `/proc/stat`, `/proc/meminfo`, and GPU sysfs every 2000ms.
  - Low overhead (~0.2% CPU).

---

## 5. Memory & Lifecycle Vectors

### 5.1 Multi-Instance Custom Video & Image Widgets
- Multiple instances of `CustomVideo.qml` can be placed on the desktop.
- Each instance creates a `MediaPlayer` and `VideoOutput`.
- Risk: Memory growth if videos are switched repeatedly or if playback is not stopped before destruction.
- Verification Target: Ensure `MediaPlayer.stop()` and source unbinding occurs cleanly.

### 5.2 Whiteboard Drawing History
- `WhiteboardDocument.qml` stores strokes, objects, and undo/redo stacks.
- Risk: Unbounded undo stacks (`undoStack.push(...)`) can consume hundreds of megabytes if drawings contain thousands of points without a stack depth limit.
- Verification Target: Inspect undo stack bounds and coordinate serialization overhead.

### 5.3 Notifications Queue
- `Notifications.qml` stores active notifications.
- Risk: In unbounded notification storms, `notificationsModel` could accumulate memory indefinitely.
- Verification Target: Ensure expiration timers and list pruning function properly.
