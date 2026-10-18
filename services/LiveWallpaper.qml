pragma Singleton

import qs
import qs.services
import qs.modules.common
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick

/*
 * Control surface for the mpvpaper live wallpaper.
 *
 * switchwall.sh gives every output an mpv IPC socket, so the wallpaper can be
 * paused and resumed instead of only being killed and relaunched. Commands go
 * to every socket at once: one wallpaper, however many screens.
 *
 * mpvpaper also pauses on its own when the wallpaper is hidden (its -p flag).
 * That one is invisible from here and does not change `paused`, which tracks
 * what was asked for, not what mpv is doing behind a maximised window.
 */
Singleton {
    id: root

    function load() {} // For forcing singleton initialization on shell startup

    readonly property string socketPrefix:
        `${Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000"}/mpvpaper-`

    // A live wallpaper is running and reachable
    property bool available: false
    // What we last asked for
    property bool paused: false

    readonly property bool pauseOnBattery: Config.options?.background.liveWallpaper.pauseOnBattery ?? false
    readonly property bool resumeWhenCharging: Config.options?.background.liveWallpaper.resumeWhenCharging ?? true
    readonly property real pauseBelowPercent: Config.options?.background.liveWallpaper.pauseBelowPercent ?? 0

    readonly property bool lockLiveEnabled: Config.options?.lock?.liveWallpaper?.enable ?? true
    readonly property bool lockPlayVideo: Config.options?.lock?.liveWallpaper?.playVideo ?? true

    property bool autoPausedByBattery: false
    property bool autoPausedByLock: false

    readonly property bool isExternalPowerConnected: {
        if (!Battery.available) return true;
        if (typeof UPower !== "undefined" && UPower.onBattery !== undefined) {
            return !UPower.onBattery;
        }
        return Battery.isPluggedIn;
    }

    function sendCommand(json) {
        if (!root.available) return;
        Quickshell.execDetached(["bash", "-c",
            `for s in ${root.socketPrefix}*.sock; do [ -S "$s" ] || continue; `
            + `printf '%s\\n' '${json}' | socat - UNIX-CONNECT:"$s" >/dev/null 2>&1; done`]);
    }

    function setPaused(value) {
        root.paused = value;
        root.sendCommand(`{"command":["set_property","pause",${value}]}`);
    }

    function toggle() { root.setPaused(!root.paused) }
    function pause()  { root.setPaused(true) }
    function resume() { root.setPaused(false) }

    // Reads back the real state, so a wallpaper change or a restart does not
    // leave the button lying about what is playing.
    Process {
        id: pollProc
        running: true
        command: ["bash", "-c",
            `for s in ${root.socketPrefix}*.sock; do [ -S "$s" ] || continue; `
            + `printf '%s\\n' '{"command":["get_property","pause"]}' | socat -T1 - UNIX-CONNECT:"$s" 2>/dev/null | head -1; exit 0; done`]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim();
                if (line === "") {
                    root.available = false;
                    return;
                }
                try {
                    const reply = JSON.parse(line);
                    root.available = reply.error === "success";
                    if (root.available) {
                        root.paused = reply.data === true;
                        root.evaluatePolicy();
                    }
                } catch (e) {
                    root.available = false;
                }
            }
        }
    }

    Timer {
        running: true
        repeat: true
        interval: 3000
        onTriggered: pollProc.running = true
    }

    // Policies: a laptop on battery has better things to do than loop a video
    readonly property bool shouldPauseForPower: root.available
        && Battery.available && !root.isExternalPowerConnected
        && (root.pauseOnBattery
            || (root.pauseBelowPercent > 0 && Battery.percentage * 100 <= root.pauseBelowPercent))

    readonly property bool shouldPauseForLock: root.available
        && GlobalStates.screenLocked
        && (!root.lockLiveEnabled || !root.lockPlayVideo)

    function evaluatePolicy() {
        if (!root.available) return;

        // 1. Power condition triggers pause
        if (root.shouldPauseForPower) {
            if (!root.paused) {
                root.autoPausedByBattery = true;
                root.pause();
            }
            return;
        }

        // 2. Lock condition triggers pause
        if (root.shouldPauseForLock) {
            if (!root.paused) {
                root.autoPausedByLock = true;
                root.pause();
            }
            return;
        }

        // 3. Power condition cleared (plugged in / above threshold)
        if (root.autoPausedByBattery) {
            root.autoPausedByBattery = false;
            if (root.resumeWhenCharging && root.paused && !root.shouldPauseForLock) {
                root.resume();
            }
        }

        // 4. Lock condition cleared (unlocked)
        if (root.autoPausedByLock) {
            root.autoPausedByLock = false;
            if (root.paused && !root.shouldPauseForPower) {
                root.resume();
            }
        }
    }

    onShouldPauseForPowerChanged: evaluatePolicy()
    onShouldPauseForLockChanged: evaluatePolicy()
    onAvailableChanged: if (root.available) evaluatePolicy()
    onIsExternalPowerConnectedChanged: evaluatePolicy()

    Connections {
        target: GlobalStates
        function onScreenLockedChanged() {
            root.evaluatePolicy();
        }
    }

    Connections {
        target: Battery
        function onIsPluggedInChanged() {
            root.evaluatePolicy();
        }
        function onPercentageChanged() {
            root.evaluatePolicy();
        }
    }

    Connections {
        target: UPower
        function onOnBatteryChanged() {
            root.evaluatePolicy();
        }
    }
}
