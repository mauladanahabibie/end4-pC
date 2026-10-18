# Connection Inspector Layout Research

## 1. Overview & Architectural Scope

The Connectivity Inspector (`modules/ii/sidebarRight/connectivity/`) provides real-time connection inspection for both Network (Wi-Fi / Ethernet) and Bluetooth subsystems. It is presented inside a `WindowDialog` popup anchored to the right sidebar (`SidebarRightContent.qml`).

### Identified Components & Hierarchy
- **Root Dialog**: `ConnectivityInspector.qml` (extends `WindowDialog.qml`)
- **Main Views**:
  - `NetworkGraphView.qml`: Network status, IPv4, Frequency/Band, Gateway/DNS, Signal, Interface/Security.
  - `BluetoothGraphView.qml`: Bluetooth device status, Battery, Category, Audio route, Security/Trust, Hardware MAC/Adapter.
- **Shared Components**:
  - `CentralNode.qml`: Circular connection hub with pulsing ripple rings and icon/title/subtitle.
  - `DetailCard.qml`: Metric card displaying icon badge, label, value, subtext, optional tag, and click-to-copy.
  - `ConnectorLines.qml`: Vector bezier spline lines connecting the central hub to satellite cards.
  - `PillSwitcher.qml`: Footer mode switcher (Wi-Fi / Bluetooth) plus action buttons (refresh, power toggle, list view).

---

## 2. Quantitative Constraint Analysis

### Available Space in Sidebar Popup
- **Display Scale & Resolution**: Primary monitor is 1920x1080 / 2560x1440.
- **Sidebar Width**: `Appearance.sizes.sidebarWidth = 460px`.
- **Sidebar Content Inner Width**: `460 - (2 * 10 gaps) = 440px`.
- **WindowDialog Constraints**:
  - `backgroundWidth: Math.min(parent.width - 24, 430) = 416px`.
  - `WindowDialog.qml` applies `anchors.margins: dialogBackground.radius` (24px) to `contentColumn`.
  - **Actual available width for content**: `416 - (2 * 24) = 368px` (up to 382px depending on rounding).
- **Height Constraints**:
  - `ConnectivityInspector.qml` hardcoded `backgroundHeight: 430px`.
  - `contentColumn` has 16px item spacing.
  - Header (`RowLayout`) ~36px + Separator 1px + Graph Area (260px) + Separator 1px + Footer (46px) = 344px + 64px layout spacing + 48px margins = **456px**!
  - Because `backgroundHeight` was set to `430px`, the dialog background clamped the bottom, leaving insufficient vertical clearance for footer controls.

---

## 3. Root Cause Investigation

### Cause 1: Physical Impossibility of 5-Satellite Orbital Layout in 368px Width
In `NetworkGraphView.qml` and `BluetoothGraphView.qml`:
- Left card: `width: 136px`, `x: 0` (spans 0 to 136).
- Right card: `width: 136px`, `x: width - 136` (spans 232 to 368).
- Gap between left and right cards: `232 - 136 = 96px`.
- In `CentralNode.qml`:
  - `hubDiameter: 122px`
  - Horizontal center is `368 / 2 = 184px`.
  - Hub spans `184 - 61 = 123px` to `184 + 61 = 245px`.
  - Ripple Ring 1 (`hubDiameter + 20`): spans `113px` to `255px`.
  - Ripple Ring 2 (`hubDiameter + 42`): spans `102px` to `266px`.
- **Result**: The central hub directly collides with the left cards by 13px and the right cards by 13px. The ripple rings penetrate up to 34px into the cards.

### Cause 2: Text Clipping & Truncation Inside 136px Satellite Cards
In `DetailCard.qml`:
- Total card width: 136px.
- Padding/margins: 8px left + 8px right = 16px.
- Icon container: 30px width + 8px spacing = 38px.
- **Available width for text column**: `136 - 16 - 38 = 82px`!
- At font size `small` (13px DemiBold):
  - IP address (`192.168.1.12` or `192.168.1.105`): requires ~95–110px. Elides to `192.168.1...`.
  - Audio output (`ALC257 Analog` or `WH-1000XM4`): requires >110px. Elides to `ALC257 A...`.
  - Frequency / Signal (`100% (Wired)` or `5 GHz (802.11ac)`): requires >100px. Elides to `100% (Wi...`.
  - Labels with badges (`IPV4 ADDRESS [IPv4]`): overflows 82px, truncating labels to `IPV4 AD...` and `FREQ...`.
- In Card 5 (Interface & Security):
  - Height was fixed at `implicitHeight: 56px`.
  - Contains 3 rows of text (Label + Badge, Value, Subtext). Minimum height needed is ~68px. Text overflows or cuts into the bottom padding.

### Cause 3: Connector Lines Crossing Text
In `ConnectorLines.qml`:
- Lines are drawn using `PathCubic` from card edge (`sx = 136`) to hub circumference (`ex = 123`).
- Because `sx > ex`, `dx = ex - sx = -13px` (negative!).
- The cubic bezier control points `c1x = sx + dx * 0.45` and `c2x = ex - dx * 0.15` create an inflection curve that bends backwards through the card body before entering the hub, slicing directly across card labels and values.

### Cause 4: Bluetooth Multi-Device Selector Overflow
In `BluetoothGraphView.qml`:
- `multiDeviceRow` was positioned at `y: -24`.
- Because the parent `Item` in `ConnectivityInspector.qml` has `clip: true`, this selector was placed outside bounds and clipped out of visibility.

### Cause 5: Footer & Pill Switcher Squeeze
In `PillSwitcher.qml`:
- Segmented switch (Wi-Fi + Bluetooth) and 3 action buttons (Refresh, Power, List) are packed into a single `RowLayout`.
- 3 buttons @ 44px + 4 spacings @ 10px = 172px.
- In 368px total width, only 196px is left for the segmented switcher (98px per tab). "Bluetooth" label (13px) + icon (18px) + spacing + padding barely fits with 0 margins, causing text crowding.

### Cause 6: Mode-Switching Reactivity
- `ConnectivityInspector.qml` only synchronized `activeTab = initialTab` inside `onShowChanged`.
- When switching modes externally or via IPC while the dialog was already open (`show: true`), `onShowChanged` did not re-fire, causing state desynchronization.

---

## 4. Conclusion & Architectural Decision

An orbital graph that positions cards to the left and right of a central hub is mathematically unviable for a container width of ~368–400px.
Per the project guidelines and prompt specifications:
> **Option B: Central Node Plus Detail Grid**
> - A smaller central connection node in a dedicated area.
> - Detail cards in a two-column grid below or beside it.
> - Connector lines reduced or omitted if they make the content harder to read.
> - Consistent card spacing and padding.
> - Readability and usability take priority over decorative lines.

Option B is the appropriate, robust architecture:
1. **Hero Node Header**: Dedicated central node zone at top of content area (clean hub with animated ripple rings, connection identity, status chip, no flanking cards competing for width).
2. **Spacious 2-Column Detail Grid**: 4 satellite cards in a 2x2 grid below the hub, where each card has `(width - 10) / 2 ≈ 180px` width (over double the previous 82px text width!).
3. **Full-Width Summary Card**: 5th card spans full width (370px) with generous height for multi-line interface/security/MAC/adapter details.
4. **Clean Flow Hierarchy**: Header -> Hero Hub -> Metrics Grid -> Summary Card -> Footer.
5. **Generous Dialog Geometry**: Adapt `backgroundHeight` dynamically or provide 520–540px height so content and footer have ample breathing room.
