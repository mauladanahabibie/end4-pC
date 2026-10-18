# Dynamic Island Runtime Diagnosis Report

## 1. Executive Summary

This report establishes the verified, empirically proven root causes for why the Quickshell Dynamic Island fails to display event content (notification text, chat sender/message, and media metadata).

Diagnostic logging added to the active Quickshell runtime session captured the exact failure:
```
DEBUG qml: [DiNotifs Debug] root is: null parent: QQuickLoader(0x7f45d43df080) di: null
DEBUG qml: [DiNotifs Debug] onNotifChanged - notif: null summary: undefined body: undefined
WARN scene: @modules/ii/bar/DiMedia.qml: TypeError: Cannot read property 'activePlayer' of null
WARN scene: @modules/ii/bar/DiMedia.qml: TypeError: Cannot read property 'isMaterial' of null
```

---

## 2. Current Rendering Path

The UI hierarchy from the compositor to the island content is:

```
PanelWindow (Bar.qml, WlrLayershell)
 └─ MouseArea (hoverRegion)
     └─ BarContent (BarContent.qml)
         └─ Item (absoluteCenter / middleRow)
             └─ BarGroup (BarGroup.qml, id: root)
                 └─ GridLayout (id: gridLayout)
                     └─ Loader (source: "DynamicIsland.qml")
                         └─ Item (DynamicIsland.qml, id: root)
                             └─ Rectangle (id: pill)
                                 └─ Loader (id: contentLoader)
                                     └─ DiNotifs / DiMedia / DiIdle (Component)
```

---

## 3. Data Path Traces & Proven Failure Points

### A. Notification Data Path
1. `NotificationServer` receives a D-Bus notification (e.g. from `notify-send`, Telegram, Ferdium, WhatsApp).
2. `Notifications.qml` wraps the event into a `Notif` QObject (`summary`, `body`, `appName`, `appIcon`, `image`).
3. `Notifications.qml` emits `notify(newNotifObject)`.
4. `DynamicIsland.qml` receives `onNotify(notif)` and stores it in `root.activeDynamicNotification`.
5. `DynamicIsland.qml` switches `activeProvider` to `notification` and loads `DiNotifs` via `contentLoader.sourceComponent = notificationComponent`.
6. **PROVEN FAILURE POINT**:
   - `notificationComponent` is declared as:
     ```qml
     Component {
         id: notificationComponent
         DiNotifs { di: root }
     }
     ```
   - Three ancestor scopes in the hierarchy are all named `id: root` (`BarContent.qml`, `BarGroup.qml`, `DynamicIsland.qml`).
   - Inside the dynamically loaded `Component`, `root` fails to resolve to `DynamicIsland`, evaluating to `null`.
   - `DiNotifs.qml` declares `readonly property Item root: diNotifsRoot.di`.
   - Because `di === null`, `root === null`.
   - `readonly property var notif: root?.activeDynamicNotification ?? root?.latestNotification ?? null` evaluates to `null`.
   - `notif.summary` and `notif.body` evaluate to `undefined` / `""`.
   - `DiNotifs` renders a blank space between the fallback bell icon and the clock (`09:30`).

### B. Media Data Path
1. MPRIS D-Bus player (e.g. `plasma-browser-integration`, `spotify`, `mpd`) exposes `xesam:title`, `xesam:artist`, `mpris:artUrl`, `PlaybackStatus`.
2. `MprisController.qml` singleton tracks the active player in `MprisController.activePlayer`.
3. `DynamicIsland.qml` sets `hasMedia = (MprisController.activePlayer !== null)`.
4. `contentLoader` loads `DiMedia.qml`.
5. **PROVEN FAILURE POINT 1 (di === null)**:
   - `DiMedia.qml` reads `root.activePlayer` through `readonly property Item root: diMediaRoot.di`.
   - Because `di === null`, `root` is `null`.
   - Every property access (`root.activePlayer.trackTitle`, `root.isMaterial`, `root.pillHeight`) throws `TypeError: Cannot read property 'activePlayer' of null`.
6. **PROVEN FAILURE POINT 2 (Hidden by Design unless Hovered)**:
   - In `DiMedia.qml`, the track info column has:
     ```qml
     opacity: root.mediaTrackInfoVisible ? 1 : 0
     ```
     where `mediaTrackInfoVisible` is:
     ```qml
     property bool mediaTrackInfoVisible: mediaHoverHandler.hovered || mediaTrackChangeTimer.running
     ```
   - When not actively hovering over the pill with the cursor, `trackInfoColumn.opacity` is 0.
   - The pill width collapses to `mediaCollapsedWidth: 140px`.
   - Track title and artist are completely hidden from view.
7. **PROVEN FAILURE POINT 3 (Broken OpacityMask in Qt 6 / Wayland)**:
   - `DiMedia.qml` applies `layer.effect: OpacityMask` with an unparented, inline `Rectangle` as `maskSource`:
     ```qml
     layer.effect: OpacityMask {
         maskSource: Rectangle {
             width: mediaMask.width
             height: mediaMask.height
             radius: mediaMask.radius
         }
     }
     ```
   - In Qt 6 on Wayland, this unparented mask source fails to render, producing a transparent/black mask that blacks out album artwork and content.

### C. State Machine & Event Priority Flaws
1. In `DynamicIsland.qml`:
   ```qml
   { id: "notification", active: root.activeDynamicNotification !== null || root.latestNotification !== null, ... }
   ```
   `alwaysWinIds` includes `"notification"`.
   If `Notifications.popupList` contains unexpired notifications, `latestNotification !== null` remains true continuously, permanently suppressing media playback and idle state.
2. Sizing Constraints:
   `pillHeight` is fixed at `32px`.
   `notificationWidth` is fixed at `220px`.
   A 32px height and 220px width cannot fit application icon, sender name, timestamp, and message preview without severe truncation.

---

## 4. Required Corrective Architecture

1. **Eliminate Fragile `di` Scope Propagation**:
   - `DynamicIsland.qml` root item is renamed to `islandRoot` (eliminating collision with `BarGroup` and `BarContent`).
   - `DiNotifs.qml` and `DiMedia.qml` bind directly to the canonical system singletons (`Notifications` and `MprisController`) and receive explicit properties (`dynamicIsland: islandRoot`, `currentNotif`, `player`).
2. **Eliminate Broken `OpacityMask`**:
   - Replace legacy `OpacityMask` with native QtQuick `clip: true` and `radius` on standard `Rectangle` and `RoundedImage` components.
3. **Make Media Content Always Visible During Playback**:
   - Show album art, track title, artist, and playback controls in the dedicated media state without requiring hover.
   - Provide a clean compact presentation during bar flow and an expanded presentation when hovered or active.
4. **Rich Chat Notification Layout**:
   - For chat applications (WhatsApp, Telegram, Discord, Signal, Ferdium, Slack):
     - Display app icon (via `Quickshell.Widgets.IconImage` / `SystemAppearance`).
     - Display sender / summary prominently.
     - Display actual message body preview.
     - Support avatar image when available (`notif.image`).
     - Expand pill height and width appropriately (e.g. width 320–380px, height 36–42px or adaptive) during incoming notification preview.
5. **Robust State Machine & Priority Resolution**:
   - Strict priority: Quick Alert (transient 2.5s) > Notification Preview (transient 5s) > Media Playback (while playing/has track) > Idle.
   - When a temporary notification preview timer expires, smoothly return to active media if music is playing, or to idle state.

---

## 5. Verification Results

Empirically verified on the running Quickshell session (`qs -c end4-pC`) across all four core states via high-resolution frame captures:

1. **Music Playback State (`bar_test_media_crop.png`)**:
   - High-fidelity album artwork cleanly rendered on the left with native rounded corners.
   - Track title (`Saya Tes REA, Repo untuk Rever...`) and artist (`Dirumahrafif`) continuously visible without requiring hover.
   - Interactive playback state toggle (`pause` / `play_arrow`) and skip controls responsive.
2. **Chat Notification State (`bar_test_notif_crop.png`)**:
   - Incoming WhatsApp message triggered 340px pill expansion.
   - Green WhatsApp icon, sender title (`WhatsApp`), full message preview (`Maulana Habibie: Hey, did you check the deployment...`), and timestamp (`09:46`) cleanly rendered.
3. **State Priority & Seamless Fallback (`bar_test_return_crop.png`)**:
   - Notification overlay smoothly timed out after 5 seconds and transitioned back to the active media player.
4. **Quick Alerts & Badges (`bar_test_clip_crop.png`)**:
   - Clipboard copy event displayed icon and preview (`Copied: "Testing Clipboard Dyn..."`) with active media badge in the secondary circle.
5. **Idle State (`bar_test_after_clip_crop.png`)**:
   - Compact pill rendering user avatar and time (`09:49`) with balanced margins and zero empty ghost space.

