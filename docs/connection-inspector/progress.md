# Progress Tracker: Interactive Network & Bluetooth Inspector

## Status Overview
- **Status:** Completed
- **Branch:** `main`
- **Remote:** `maulan`

---

## Task Checklist

### Phase 1: Research & Planning
- [x] Analyze visual reference screenshots (`uploaded_media_0` and `uploaded_media_1`).
- [x] Deconstruct node-and-card topology, central circular node, concentric ripple rings, satellite cards, and Bézier curves.
- [x] Analyze rice design tokens in `Appearance.qml`, active colors in `colors.json`, and typography.
- [x] Analyze sidebar architecture (`SidebarRightContent.qml`, `ToggleDialog`, `WindowDialog.qml`).
- [x] Inspect Network subsystem (`services/Network.qml`, `WifiAccessPoint.qml`, `Vpn.qml`).
- [x] Inspect Bluetooth & Audio subsystem (`services/BluetoothStatus.qml`, `services/Audio.qml`, `services/PeripheralBattery.qml`).
- [x] Author `docs/connection-inspector/research.md`.
- [x] Author `docs/connection-inspector/plan.md`.
- [x] Author `docs/connection-inspector/progress.md`.

### Phase 2: Backend Data Enhancements
- [x] Add `activeBand` and `activeSecurity` properties to `services/Network.qml`.
- [x] Add DNS extraction to `updateNetworkDetails` in `services/Network.qml`.

### Phase 3: Visual & Graph Components
- [x] Create `modules/ii/sidebarRight/connectivity/DetailCard.qml`.
- [x] Create `modules/ii/sidebarRight/connectivity/CentralNode.qml`.
- [x] Create `modules/ii/sidebarRight/connectivity/ConnectorLines.qml`.
- [x] Create `modules/ii/sidebarRight/connectivity/PillSwitcher.qml`.
- [x] Create `modules/ii/sidebarRight/connectivity/NetworkGraphView.qml`.
- [x] Create `modules/ii/sidebarRight/connectivity/BluetoothGraphView.qml`.
- [x] Create `modules/ii/sidebarRight/connectivity/ConnectivityInspector.qml`.
- [x] Create `modules/ii/sidebarRight/connectivity/qmldir`.

### Phase 4: Sidebar Integration
- [x] Register inspector dialog in `modules/ii/sidebarRight/SidebarRightContent.qml`.
- [x] Add `requestInspectorDialog` signal and `openConnectionInspector(tab)` helper to `GlobalStates.qml`.
- [x] Update `IpcHandler` in `modules/ii/sidebarRight/SidebarRight.qml` with `inspectConnection(tab)`.
- [x] Update "Details" button in `modules/ii/sidebarRight/wifiNetworks/WifiDialog.qml` to open inspector.
- [x] Update "Details" button in `modules/ii/sidebarRight/bluetoothDevices/BluetoothDialog.qml` to open inspector.
- [x] Update `altAction` in classic quick toggles (`NetworkToggle.qml` and `BluetoothToggle.qml`) to open inspector.

### Phase 5: Testing & Verification
- [x] Verify Quickshell daemon logs for QML syntax or runtime errors (clean, no errors).
- [x] Test Wi-Fi inspector view with live connection data (`screenshot_wifi_polished.png`).
- [x] Test Bluetooth inspector view (`screenshot_bluetooth.png`).
- [x] Test mode switching (Wi-Fi $\leftrightarrow$ Bluetooth).
- [x] Test power controls and dialog navigation.
- [x] Test responsive sizing and mutual exclusivity in the sidebar.

### Phase 6: Git Commit & Remote Push
- [x] Stage all modified and new files.
- [x] Commit with descriptive message.
- [x] Push to `maulan/main`.
