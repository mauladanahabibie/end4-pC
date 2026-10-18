# Rice Stability & Regression Test Plan

This document outlines the repeatable, structured test scenarios used to verify the stability, responsiveness, memory footprint, and regression-free operation of the Quickshell rice.

---

## 1. Test Matrix Overview

| Test ID | Module / Feature | Focus Area | Success Criteria |
| :--- | :--- | :--- | :--- |
| **ST-01** | Shell Startup & Reload | Process Lifecycle, QML compilation | Clean startup without SIGSEGV; no ReferenceErrors in journal logs. |
| **ST-02** | RippleButton & Masking | Memory safety, QSG Scene-Graph | Rapid clicks across 50+ UI buttons without memory faults or unparented item crashes. |
| **ST-03** | Dynamic Island Lifecycle | Notifications, Media, Animations | Multiple notifications queued, dismissed, and transitioned to media player without state desync. |
| **ST-04** | SidebarRight Productivity Suite | Notepad, Converter, To-Do, Calculator | Tab switching preserves state; no `GlobalStates` or `ColorUtils` ReferenceErrors. |
| **ST-05** | Whiteboard Canvas Stress | Freehand drawing, Undo/Redo, Objects | Sustained drawing of 500+ strokes; undo/redo stack verification; memory remains bounded. |
| **ST-06** | Custom Video & Wallpaper Policy | Power states, Multi-instance | Videos pause when AC adapter disconnected (on battery); resume when plugged in; no zombie players. |
| **ST-07** | Network & Bluetooth Inspector | D-Bus polling, dynamic card layout | Switching between Wi-Fi and Bluetooth inspector cards without duplicate subscriptions or UI freeze. |
| **ST-08** | Extended Uptime / Memory Leak | Heap & RSS consumption | RSS stays stable after 100+ open/close cycles of major panels. |

---

## 2. Test Execution Details

### ST-01: Startup & QML Cleanliness
```bash
# Verify QML syntax and runtime loading
qs -c end4-pC --check-only || true
# Monitor systemd/journalctl logs during startup
journalctl --user -u quickshell -n 100 --no-pager
```

### ST-02: Button Masking Stress Test
- **Action**: Rapidly click tab buttons, quick toggles, settings buttons, and media controls.
- **Verification**: Inspect stderr/stdout for `QQuickItemPrivate::dirty` crashes or `Segmentation fault (core dumped)`.
- **Pass Criteria**: 0 segmentation faults across 100 rapid click events.

### ST-03: Dynamic Island Stress Test
- **Action**:
  1. Trigger 5 test notifications using `notify-send "Test" "Body"`.
  2. Start music playback via `playerctl play`.
  3. Expand and collapse the Dynamic Island island card.
- **Verification**: Observe smooth transitions, correct mask clipping, and zero orphan notification items.

### ST-04: Productivity Hub Functional Check
- **Action**:
  1. Open SidebarRight -> Productivity Hub.
  2. Select `Converter`: Change unit categories and input numeric values.
  3. Select `Notepad`: Type multi-line text and switch between notes.
  4. Select `Calculator`: Perform compound calculations.
- **Verification**: No console errors regarding `GlobalStates` or `ColorUtils`. Data persists after switching views.

### ST-05: Whiteboard Drawing & History Test
- **Action**:
  1. Open Whiteboard window.
  2. Draw 50 continuous freehand strokes.
  3. Perform 20 undo operations (`Ctrl+Z`) and 10 redo operations (`Ctrl+Y`).
  4. Create shapes (rectangle, circle, line) and test marquee selection.
- **Verification**: Smooth 60 FPS rendering; no CPU runaway after drawing finishes; canvas clears cleanly.

### ST-06: Custom Video & Power Policy Test
- **Action**:
  1. Configure a Custom Video widget with video wallpaper.
  2. Simulate AC disconnect (`upower` battery state change).
  3. Verify video pause behavior and CPU/GPU usage drops.
  4. Simulate AC connect; verify automatic playback resumption.
- **Verification**: Media player process respects power settings without freezing.

### ST-07: Connectivity Inspector Test
- **Action**:
  1. Open Network / Bluetooth dialog.
  2. Scan for available Wi-Fi networks and Bluetooth peripherals.
  3. Verify central node and connecting lines render accurately in both dark and light modes.
- **Verification**: Responsive rendering, no D-Bus timeouts.
