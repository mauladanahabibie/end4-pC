# Connection Inspector Layout Plan (Option B: Central Node Plus Detail Grid)

## 1. Architectural Strategy

We adopt **Option B: Central Node Plus Detail Grid** as recommended by the project specification.

```
+-----------------------------------------------------------+
| [Icon] Network Inspector / Bluetooth Inspector        [X] | Header (36px)
+-----------------------------------------------------------+
| ------------------------ Separator ---------------------- |
|                                                           |
|                       (( [Hub] ))                         | Hero Node (96px)
|                   Wired connection 1                      |
|                      • Connected                          |
|                                                           |
|   +-----------------------+   +-----------------------+   | Detail Grid
|   | [Icon] IPV4 ADDRESS   |   | [Icon] FREQUENCY      |   | Row 1 (60px)
|   | 192.168.1.12          |   | 2.4 GHz               |   |
|   | WAN: 157.15.187.195   |   | 2437 MHz              |   |
|   +-----------------------+   +-----------------------+   |
|   +-----------------------+   +-----------------------+   |
|   | [Icon] GATEWAY        |   | [Icon] SIGNAL         |   | Row 2 (60px)
|   | 192.168.1.1           |   | 100% (Wired)          |   |
|   | DNS: 192.168.1.1      |   | AP: 18:44:E6:36:8A:20 |   |
|   +-----------------------+   +-----------------------+   |
|                                                           |
|   +---------------------------------------------------+   | Summary Card
|   | [Icon] INTERFACE & SECURITY              [enp7s0] |   | Full Width
|   | enp7s0 • WPA1 WPA2                                |   | (64px)
|   | MAC: 40:C2:BA:85:20:AA                            |   |
|   +---------------------------------------------------+   |
|                                                           |
| ------------------------ Separator ---------------------- |
| [  Wi-Fi  |  Bluetooth  ]      (Refresh)  (Power)  (List) | Footer (44px)
+-----------------------------------------------------------+
```

---

## 2. Quantitative Dimension Specifications

| Element | Current | Proposed | Rationale |
|---|---|---|---|
| **Dialog Width** | 416–430px | 420px | Fits safely within 440px sidebar width |
| **Dialog Height** | 430px (fixed) | 530px | Eliminates vertical squeezing and footer collision |
| **Main Content Height** | 260px (fixed) | 350px | Accommodates hero node + 2x2 grid + summary card |
| **Central Node Diameter** | 122px (+42px ring) | 76px (+24px ring) | Eliminates overlap with detail cards |
| **Hero Node Area Height**| Squeezed in center | 94px dedicated | Clean vertical hierarchy without horizontal competition |
| **Grid Card Width** | 136px (fixed) | ~180px (`(width - 10) / 2`) | Increases available text width from 82px to ~128px (+56%) |
| **Grid Card Height** | 56px (fixed) | 60px | Ample padding for 3 lines of text without clipping |
| **Summary Card Height** | 56px (fixed) | 64px | Full-width clearance for MAC, interface name, and security |
| **Card Padding/Margins** | 8px | 10px | Consistent spacing conforming to rice design system |
| **Footer Button Sizes** | 44x44px | 38x38px | Prevents overcrowding in the footer row |
| **Connector Lines** | Horizontal cubic curves crossing cards | Clean vertical tree bus or omitted in favor of clean cards | Prevents lines crossing text and important metrics |

---

## 3. Component Refactoring Plan

### 3.1 `ConnectivityInspector.qml`
- Set `backgroundWidth: Math.min(parent ? parent.width - 20 : 420, 420)`.
- Set `backgroundHeight: 530`.
- Update `Main Graph Area` `Layout.preferredHeight: 350`.
- Add `onInitialTabChanged: root.activeTab = initialTab` to fix mode-switching desync when dialog is already open.
- Add consistent padding and clear separation between header, content, and footer.

### 3.2 `DetailCard.qml`
- Update default `implicitHeight: 60`.
- Increase internal margin to 10px.
- Use `Layout.fillWidth: true` on texts column.
- Prevent clipping by calculating text metrics properly and setting elide to `Text.ElideRight` with tooltip / click-to-copy feedback.
- Format badges with clean geometry that does not push label text into truncation.

### 3.3 `CentralNode.qml`
- Scale `hubDiameter` default to 76px (compact hero hub).
- Scale outer ripple ring to `hubDiameter + 24` (100px).
- Refactor layout into clean vertical structure: central circle (icon + pulsing ring) + title & status pill underneath, or integrated hero hub.
- Ensure zero horizontal or vertical overlap with any detail cards.

### 3.4 `NetworkGraphView.qml`
- Replace fragile absolute `(x, y)` coordinate positioning with structured, declarative layout:
  - Top Hero: `CentralNode` (Network Name, Wired/Wi-Fi status, signal indicator).
  - Middle Grid (2x2):
    - Cell (0,0): IPv4 Address (with WAN subtext and click-to-copy).
    - Cell (0,1): Frequency & Band (e.g. 5 GHz / 2.4 GHz / Wired 802.3).
    - Cell (1,0): Gateway & DNS (with click-to-copy).
    - Cell (1,1): Signal Strength & BSSID / Access Point.
  - Bottom Card: Full-width Interface & Security (interface badge, WPA security protocol, hardware MAC address).
- Connector lines: Vector bus connecting hero hub to the card tree behind card surfaces, with zero line crossing text.

### 3.5 `BluetoothGraphView.qml`
- Integrate `multiDeviceRow` inside the top hero area (clean horizontal pill row when multiple connected devices exist), inside bounds so it never clips.
- Top Hero: `CentralNode` (Device Name or Bluetooth Status, Connected/Paired pill).
- Middle Grid (2x2):
  - Cell (0,0): Battery Level (percentage, battery gauge, low/normal status).
  - Cell (0,1): Device Category (Headset, Mouse, Keyboard, Phone, etc.).
  - Cell (1,0): Audio Output (active PipeWire sink, routing status).
  - Cell (1,1): Status & Trust (Paired, Trusted, Blocked).
- Bottom Card: Full-width Hardware Address & Adapter (Bluetooth MAC with click-to-copy, adapter identifier e.g. hci0).

### 3.6 `PillSwitcher.qml`
- Compact button dimensions to 38x38px with 8px spacing.
- Ensure the segmented toggle has at least 200px width so "Wi-Fi" and "Bluetooth" labels and icons breathe comfortably.
- Maintain existing click handlers: `rescanWifi()`, `BluetoothStatus.adapter.discovering`, `toggleWifi()`, `togglePower()`, and `openFullList()`.

---

## 4. Verification & Testing Matrix
1. **Network Mode Verification**:
   - Inspect IP address ("192.168.1.12" or "192.168.1.105"): fully visible, not clipped.
   - Inspect Frequency ("2.4 GHz" / "5 GHz"): fully visible.
   - Inspect Gateway ("192.168.1.1"): fully visible.
   - Inspect Signal ("100% (Wired)" / "85%"): fully visible, not clipped.
   - Inspect Interface & Security: full interface name ("enp7s0", "wlan0"), security type ("WPA2 Personal"), MAC address fully legible.
2. **Bluetooth Mode Verification**:
   - Inspect device name / status: fully visible.
   - Inspect battery level or N/A placeholder: clean and legible.
   - Inspect audio output sink: not clipped to "ALC257 A...".
   - Inspect device MAC and adapter: clean and legible.
3. **Cross-Mode & Visual Polish**:
   - Switch between Wi-Fi and Bluetooth tabs: smooth transition, no overlapping cards or stale positions.
   - Test click-to-copy: "COPIED" badge appears and clipboard receives text.
   - Capture screenshots of both modes and verify zero overlaps, zero clipping, and clean aesthetic alignment with rice theme.
