# Research Document: Interactive Network & Bluetooth Inspector

## 1. Executive Summary & Objective

The objective is to implement a high-fidelity, interactive **Network & Bluetooth Inspector** for the Quickshell desktop rice. Inspired by the user-supplied reference screenshots (`uploaded_media_0` and `uploaded_media_1`), the interface employs an **Orbital Node-and-Card Topology** to visually communicate connectivity state:
- A prominent **central circular hub node** represents the active connection (Wi-Fi SSID or Bluetooth device name, connection status, primary icon, and animated wireless ripple/pulse rings).
- **Satellite detail cards** surround the center hub, presenting granular connection metadata (IP address, gateway, frequency band, security type, signal strength, MAC address, battery percentage, audio sink profile, etc.).
- **Smooth organic connector lines** (vector cubic Bézier curves via `QtQuick.Shapes`) tether each satellite card to the perimeter of the center hub.
- A **segmented pill mode switcher** at the bottom toggles between Wi-Fi and Bluetooth modes, accompanied by power toggles, device switching, and rescan/list actions.
- The inspector is integrated directly into the Quickshell sidebar architecture, accessible from the existing Quick Toggles and dialogs without opening duplicate windows.
- The aesthetic strictly respects the rice's Material Design 3 palette (olive, beige, warm terracotta, charcoal translucent layers from `Appearance.qml` and `colors.json`), discarding the foreign pink/orange palette from the raw references.

---

## 2. Visual Reference Deconstruction

### 2.1 Central Circular Hub Node
- **Wi-Fi Mode (`uploaded_media_0`):**
  - Large circular hub (~130px–150px diameter).
  - Centered icon (`MaterialSymbol` `"wifi"`, ~36–42px).
  - Prominent title: Active network SSID (e.g. `"Fibernet-IA024_"`), Google Sans Flex medium weight (`wght: 550`).
  - Status subtitle: `"Connected"` or `"Connecting"` or `"Disconnected"`.
  - Concentric ripple rings radiating outward with fading opacity, communicating an active wireless field.
- **Bluetooth Mode (`uploaded_media_1`):**
  - Similar circular hub node.
  - Centered icon matching device category (e.g. `"headphones"`, `"earbuds"`, `"speaker"`, `"mouse"`, `"keyboard"`).
  - Prominent title: Connected Bluetooth device name (e.g. `"WH-1000XM4"`).
  - Status subtitle: `"Connected • Audio Sink"` or battery percentage.
  - Concentric rings styled to match the Bluetooth accent color.

### 2.2 Satellite Detail Cards
Each card represents a specific dimension of the connection:
- **Wi-Fi Satellite Cards:**
  1. **Band / Frequency:** e.g. `"5.0 GHz"` / `"2.4 GHz"`, icon `"wifi_channel"` or `"radar"`.
  2. **IPv4 Address:** e.g. `"192.168.1.12"`, icon `"lan"` / `"router"`.
  3. **Security / Encryption:** e.g. `"WPA2 / WPA3 Personal"`, icon `"lock"` / `"security"`.
  4. **Signal Strength:** e.g. `"78% (-54 dBm)"`, icon `"signal_wifi_4_bar"`.
  5. **Gateway / DNS:** e.g. Gateway `"192.168.1.1"`, DNS `"1.1.1.1"`, icon `"dns"`.
  6. **Physical Interface / MAC:** e.g. `"wlan0 (40:C2:BA:85:20:AA)"`, icon `"developer_board"`.
- **Bluetooth Satellite Cards:**
  1. **Battery Level:** e.g. `"85%"`, icon `"battery_charging_full"` or `"battery_6_bar"`.
  2. **Device Category / Type:** e.g. `"Audio Headset"`, icon `"headphones"`.
  3. **Hardware Address (MAC):** e.g. `"34:09:C9:F5:7F:0C"`, icon `"bluetooth"`.
  4. **Connection State:** e.g. `"Paired & Trusted"`, icon `"verified_user"`.
  5. **Audio Routing:** e.g. `"Default PipeWire Sink"`, icon `"volume_up"`.
  6. **Active Device Switcher:** When multiple devices are paired/connected, quick selector to focus inspection on another device.

### 2.3 Connector Lines (Bézier Geometry)
- Organic S-curves connecting each satellite card's inward edge to the circular boundary of the central hub.
- Implemented using `QtQuick.Shapes`:
  - `Shape` with `layer.enabled: true` and `layer.samples: 4` (MSAA anti-aliasing).
  - `ShapePath` with `PathCubic` specifying control points `control1` and `control2` calculated dynamically from card centers and hub radius.
  - Subtle styling: 1.5px–2px stroke width, tinted with `colOutlineVariant` or muted primary accent (`0.35`–`0.55` opacity).

### 2.4 Bottom Controls & Actions
- **Pill Segmented Switcher:** Seamless sliding indicator toggle between `"Wi-Fi"` and `"Bluetooth"`.
- **Power Button:** Circular action button toggling adapter state (Wi-Fi radio or Bluetooth adapter).
- **Secondary Action:** Button to open full network list (`WifiDialog`) or Bluetooth device list (`BluetoothDialog`).

---

## 3. Theme & Styling Alignment

The active rice uses Material Design 3 tokens generated from wallpaper via Matugen (`.local/state/quickshell/user/generated/colors.json` and `modules/common/Appearance.qml`).

### 3.1 Color Palette
| Semantic Role | Token in `Appearance.qml` | Active Hex Value | Usage in Inspector |
| :--- | :--- | :--- | :--- |
| **Surface Base** | `colLayer0` / `colUiBackground` | `#141311` (with alpha `0.85`–`0.92`) | Dialog backdrop / window surface |
| **Surface Elev. 1** | `colLayer1` | `#1c1c19` | Central hub background, container base |
| **Surface Elev. 2** | `colLayer2` / `colSurfaceContainer`| `#20201d` | Satellite detail cards |
| **Surface Elev. 3** | `colLayer2Hover` / `colSurfaceContainerHigh` | `#2b2a27` | Hovered satellite cards |
| **Card Borders** | `colLayer0Border` / `colOutlineVariant` | `#484743` (alpha `0.4`–`0.6`) | Satellite card borders, connector lines |
| **Primary Accent** | `colPrimary` | `#cbc7ad` | Text accents, selected pill indicator |
| **Primary Container**| `colPrimaryContainer` | `#494833` | Wi-Fi active hub accent, active badges |
| **On Primary Cont.** | `colOnPrimaryContainer` | `#e7e3c8` | Icons and primary titles |
| **Bluetooth Accent**| `m3colors.m3primaryFixed` / `colSecondaryContainer` | `#e7e3d1` / `#49473a` | Bluetooth active hub accent |
| **Text Primary** | `colOnSurface` | `#e6e2dd` | Card titles, values |
| **Text Muted** | `colSubtext` / `m3onSurfaceVariant` | `#c9c6c2` / `#93908c` | Card labels, status subtitles |
| **Error / Critical** | `colError` | `#ffb4ab` | Disconnected state, critical battery |

### 3.2 Typography & Rounding
- **Fonts:** `Google Sans Flex` (`Appearance.font.family.main`), `JetBrains Mono NF` (`monospace` for IP/MAC).
- **Rounding:** `Appearance.rounding.small` (12px), `normal` (17px for cards), `verylarge` (30px), `full` (9999px for pills/hubs).
- **Animations:** Standard Material 3 curves (`Appearance.animation.elementMoveFast`, `elementMoveSlow`).

---

## 4. Sidebar Architecture & Extension Points

### 4.1 Existing Sidebar Layout (`modules/ii/sidebarRight/`)
- `SidebarRight.qml`: Root panel anchoring to the right screen edge with sliding open/close animation. Default width: 460px (`Appearance.sizes.sidebarWidth`).
- `SidebarRightContent.qml`: Hosts the vertical stack:
  1. Top widgets (Clock, Quick Toggles).
  2. Dialog Overlays (`ToggleDialog` loaders):
     - `showWifiDialog` $\rightarrow$ `WifiDialog.qml`
     - `showBluetoothDialog` $\rightarrow$ `BluetoothDialog.qml`
     - `showVolumeMixerDialog` $\rightarrow$ `VolumeDialog.qml`
     - `showVpnDialog` $\rightarrow$ `VpnDialog.qml`
- `WindowDialog.qml`: Base modal component providing:
  - Full-surface dark scrim backdrop with click-to-dismiss.
  - Smooth scale & fade transition (`elementMoveFast`).
  - Escape key handling to close the active dialog.
  - Centered card container (standard width: `Math.min(parent.width - 20, 420)`).

### 4.2 Seamless Integration Points
1. **New Dialog in `SidebarRightContent.qml`:**
   Add `property bool showInspectorDialog: false` and `property string inspectorTab: "wifi"` to `SidebarRightContent.qml`.
   Add `ToggleDialog` loading `ConnectivityInspector.qml`.
   Ensure `showInspectorDialog = false` in `onSidebarRightOpenChanged` to prevent stale overlays.
2. **Launch Triggers:**
   - **Quick Toggles:** Add an "inspect" or long-click / detail action to `NetworkToggle` and `BluetoothToggle`.
   - **Dialog "Details" Buttons:** In `WifiDialog.qml` and `BluetoothDialog.qml`, replace the external KDE `kcmshell6` invocation with opening `ConnectivityInspector` directly within the shell!
   - **Bar Widget Integration:** Network speed popup (`modules/ii/bar/NetworkSpeedPopup.qml`) or Bluetooth popup can offer an "Inspect" button that opens the sidebar and launches the inspector.

---

## 5. Network Subsystem Integration (`services/Network.qml`)

### 5.1 Real Data Sources
`Network.qml` interfaces with NetworkManager via persistent `nmcli monitor` and targeted `nmcli` queries:
- `Network.wifiEnabled`: Radio state (`bool`).
- `Network.wifi`: Wi-Fi connectivity flag (`bool`).
- `Network.ethernet`: Wired connectivity flag (`bool`).
- `Network.wifiStatus`: `"connected"`, `"connecting"`, `"disconnected"`, `"disabled"`, `"limited"`.
- `Network.networkName`: Active connection name / SSID.
- `Network.networkStrength`: Active Wi-Fi signal percentage (0–100).
- `Network.networkInterface`: Active adapter interface (e.g. `"wlan0"`, `"enp7s0"`).
- `Network.ipAddress`: Local IPv4 address (e.g. `"192.168.1.12"`).
- `Network.gateway`: Default IPv4 gateway (e.g. `"192.168.1.1"`).
- `Network.macAddress`: Hardware MAC address.
- `Network.publicIpAddress`: Public IP resolved from `https://api.ipify.org`.
- `Network.active`: Current active `WifiAccessPoint` instance:
  - `active.ssid`, `active.bssid`, `active.frequency` (MHz), `active.strength`, `active.security`.

### 5.2 Enhancements for the Inspector
1. **Band Derivation:**
   From `Network.active?.frequency`:
   - `< 3000 MHz` $\rightarrow$ `"2.4 GHz"`
   - `4900–5895 MHz` $\rightarrow$ `"5.0 GHz"`
   - `> 5900 MHz` $\rightarrow$ `"6.0 GHz"`
2. **DNS Extraction:**
   Currently omitted from `Network.qml`. Add extraction of `IP4.DNS` from `nmcli device show "$device"` so users can view primary & secondary DNS servers.
3. **Clean Connection Type:**
   Derive unified type: `"Wi-Fi"`, `"Ethernet"`, or `"Disconnected"`.

---

## 6. Bluetooth Subsystem Integration (`services/BluetoothStatus.qml`)

### 6.1 Real Data Sources
- `Quickshell.Bluetooth`: Exposes `Bluetooth.defaultAdapter` and `Bluetooth.devices.values`.
- `BluetoothStatus.qml`:
  - `enabled`: Adapter power state.
  - `discovering`: Discovery active state.
  - `isConnected(device)`: Workaround for BlueZ bug #2485 (checks `device.connected || device.batteryAvailable`).
  - `connectedDevices`: List of all actively connected Bluetooth devices.
  - `pairedButNotConnectedDevices`: Known paired devices.
  - `primaryConnectedDevice`: First connected device or audio device.
  - `hasBattery(device)`: Checks `device.batteryAvailable` and finite `device.battery`.
- Device properties (`BluetoothDevice`):
  - `name`, `deviceName`, `address` (MAC), `icon`, `connected`, `paired`, `battery` (0.0–1.0), `dbusPath`.
- Category mapping (`modules/common/Icons.qml`):
  - Resolves icon and category (Headphones, Earbuds, Speaker, Mouse, Keyboard, Gamepad, Phone, Computer).
- Audio routing (`services/Audio.qml`):
  - Matches PipeWire sink names (`bluez_output.*`) to determine if the device is currently receiving system audio.

---

## 7. Responsive Graph Layout Geometry

### 7.1 Geometry Model
In a standard sidebar width (~440px–460px), the inspector layout consists of:
```
+-------------------------------------------------------+
|  [Icon] Connection Inspector                     [X]  |
+-------------------------------------------------------+
|                                                       |
|   +---------------+               +---------------+   |
|   | Card: IP Addr |               | Card: Band    |   |
|   +-------+-------+               +-------+-------+   |
|            \                             /            |
|             \   ((((             ))))   /             |
|              \  ((  +-----------+  ))  /              |
|               -->>  |  Central  |  <<--               |
|              /  ((  |    Hub    |  ))  \              |
|             /   ((((+-----------+))))   \             |
|            /                             \            |
|   +-------+-------+               +-------+-------+   |
|   | Card: Gateway |               | Card: Signal  |   |
|   +---------------+               +---------------+   |
|                                                       |
|   +-----------------------------------------------+   |
|   | Bottom Detail Card (e.g. MAC / Security / DNS)|   |
|   +-----------------------------------------------+   |
|                                                       |
|  [ Wi-Fi | Bluetooth ]               (Power) (Scan)   |
+-------------------------------------------------------+
```

### 7.2 Bézier Curve Calculation
For a connector line between satellite card anchor $(x_1, y_1)$ and central hub anchor $(x_2, y_2)$:
- Midpoint distance $dx = x_2 - x_1$, $dy = y_2 - y_1$.
- Horizontal curve tension control points:
  - $cx_1 = x_1 + dx \times 0.5$
  - $cy_1 = y_1$
  - $cx_2 = x_2 - dx \times 0.1$
  - $cy_2 = y_2$
- Drawn via `QtQuick.Shapes`:
  ```qml
  ShapePath {
      strokeColor: Appearance.colors.colLayer0Border
      strokeWidth: 1.5
      fillColor: "transparent"
      startX: x1; startY: y1
      PathCubic {
          x: x2; y: y2
          control1X: cx1; control1Y: cy1
          control2X: cx2; control2Y: cy2
      }
  }
  ```

### 7.3 Responsive Modes
1. **Radial Mode ($\ge 390\text{px}$ width):** Full 2-column or orbital layout with bezier curve connectors.
2. **Compact Mode ($< 390\text{px}$ width):** Top hero circular hub with compact ripple, transitioning satellite cards into an elegant 2-column grid directly below, with connector lines fading gracefully.
