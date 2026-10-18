# Implementation Plan: Interactive Network & Bluetooth Inspector

## 1. Overview & Goals

Create a native **Network & Bluetooth Inspector** dialog within the Quickshell sidebar (`end4-pC`), providing an interactive orbital node-and-card visualization of active connections. The inspector will display real-time data from NetworkManager, BlueZ, PipeWire, and UPower, adhering strictly to the rice's Material Design 3 theme tokens.

---

## 2. Directory & Component Architecture

All new inspector components will reside in:
`modules/ii/sidebarRight/connectivity/`

### 2.1 Component Breakdown
1. **`DetailCard.qml`**:
   - Reusable satellite card displaying an icon, title (value), subtitle (label), and optional action (e.g. copy to clipboard).
   - Styled with `Appearance.colors.colLayer2`, `1px` border with `colLayer0Border`, radius `Appearance.rounding.normal` (17px).
   - Hover elevation transition (`colLayer2Hover`).
   - Click-to-copy capability with transient clipboard feedback.

2. **`CentralNode.qml`**:
   - Circular hub displaying the active connection icon, primary name (SSID or device name), and status subtitle.
   - Concentric outer ripple rings with gentle opacity oscillation when actively connected.
   - Distinct color accents:
     - Wi-Fi: Warm earthy terracotta (`#A97363` / `colPrimaryContainer`)
     - Bluetooth: Slate beige (`m3colors.m3primaryFixed` / `colSecondaryContainer`)
     - Disconnected: Muted neutral outline with `colLayer1` fill.

3. **`ConnectorLines.qml`**:
   - Vector canvas using `QtQuick.Shapes` (`Shape`, `ShapePath`, `PathCubic`).
   - Dynamically calculates cubic Bézier curves connecting each satellite card anchor point to the nearest perimeter point on the central hub.
   - Anti-aliased with `layer.samples: 4`.

4. **`NetworkGraphView.qml`**:
   - Orchestrates the Wi-Fi & Ethernet inspector view:
     - Central hub bound to `Network.networkName`, `Network.materialSymbol`, and `Network.wifiStatus`.
     - Satellite cards for:
       1. IPv4 Address (`Network.ipAddress`)
       2. Frequency Band (`Network.activeBand` / `2.4 GHz` or `5.0 GHz`)
       3. Default Gateway (`Network.gateway`)
       4. Signal Strength (`Network.networkStrength`%)
       5. Security Standard (`Network.active?.security` / `"WPA2 / WPA3"`)
       6. Hardware MAC & Interface (`Network.networkInterface` + `Network.macAddress`)
       7. Primary DNS (`Network.dns`)
     - Disconnected state: Graceful placeholder with "Scan Networks" button.

5. **`BluetoothGraphView.qml`**:
   - Orchestrates the Bluetooth inspector view:
     - Central hub bound to `BluetoothStatus.primaryConnectedDevice` (or selected device).
     - Satellite cards for:
       1. Battery Level (percentage + charging state)
       2. Device Type / Category (Headphones, Mouse, Keyboard, etc.)
       3. Hardware MAC Address
       4. Connection State (Connected, Paired, Trusted)
       5. Audio Route / PipeWire Sink (active audio output sink indication)
       6. Multi-Device Selector: Quick row/dropdown if multiple devices are connected.
     - Disconnected state: Graceful placeholder with "Discover Devices" button.

6. **`PillSwitcher.qml`**:
   - Bottom segmented pill switcher (`Wi-Fi` vs `Bluetooth`) with smooth animated sliding selection pill.
   - Dedicated power toggle button (radio on/off for Wi-Fi, adapter power for Bluetooth).
   - Shortcut action button to open traditional device list dialogs (`WifiDialog` or `BluetoothDialog`).

7. **`ConnectivityInspector.qml`**:
   - Root dialog component inheriting `WindowDialog.qml`.
   - Manages active tab state (`"wifi"` vs `"bluetooth"`).
   - Contains header with title and close button, the active graph view, and the bottom control bar.
   - Responsive sizing: standard dialog width (~430px) that fits inside the sidebar width (460px).

---

## 3. Backend Data Enhancements (`services/Network.qml`)

To provide full fidelity for the network cards without disruptive changes:
1. **Expose `activeBand`**:
   Calculate dynamically from `active?.frequency`:
   - `frequency < 3000 ? "2.4 GHz" : frequency < 5900 ? "5.0 GHz" : "6.0 GHz"`.
2. **Expose `activeSecurity`**:
   Safely expose `active?.security || (ethernet ? "Wired (802.3)" : "Open")`.
3. **Expose `dns`**:
   Include `IP4.DNS` in `updateNetworkDetails` so primary DNS is available.

---

## 4. Integration into Sidebar & Dialogs

### 4.1 `SidebarRightContent.qml`
- Add properties:
  - `property bool showInspectorDialog: false`
  - `property string inspectorTab: "wifi"`
- Add `ToggleDialog` loader for `ConnectivityInspector.qml`.
- Ensure `showInspectorDialog = false` inside `onSidebarRightOpenChanged`.

### 4.2 `WifiDialog.qml` & `BluetoothDialog.qml`
- Update the "Details" footer button:
  - Currently launches `kcmshell6` and closes the sidebar.
  - New behavior: Sets `root.parentContent.inspectorTab = "wifi"` (or `"bluetooth"`), opens `showInspectorDialog = true`, and closes `showWifiDialog = false`.
  - Keeps the entire experience seamless and native inside Quickshell.

---

## 5. Implementation Phases & Task Order

1. **Phase 1: Backend Data Properties (`services/Network.qml`)**
   - Add `activeBand` calculation.
   - Extract `dns` in `updateNetworkDetails`.
2. **Phase 2: Core Visual Components**
   - Implement `DetailCard.qml`.
   - Implement `CentralNode.qml` with pulse animation and concentric rings.
   - Implement `ConnectorLines.qml` with dynamic Bézier curves.
   - Implement `PillSwitcher.qml`.
3. **Phase 3: Network & Bluetooth Graph Views**
   - Implement `NetworkGraphView.qml`.
   - Implement `BluetoothGraphView.qml`.
4. **Phase 4: Main Inspector Dialog Container**
   - Implement `ConnectivityInspector.qml`.
5. **Phase 5: Sidebar Integration**
   - Wire up `SidebarRightContent.qml`, `WifiDialog.qml`, and `BluetoothDialog.qml`.
6. **Phase 6: Runtime Verification & Git Commit**
   - Verify layout, interactions, animations, data reactivity, and theme consistency.
   - Commit and push to `maulan/main`.
