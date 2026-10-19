import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Qt5Compat.GraphicalEffects
import QtQuick.Controls
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: islandRoot
    property bool mirrored: false

    readonly property real pillHeight: 32
    readonly property real idleCollapsedWidth: 144
    readonly property real sessionWidth: 164
    property real idleTextContentWidth: 0
    readonly property real idleExtraHoverWidth: idleHoverHandler.hovered ? 16 : 0
    readonly property real idleWidth: Math.max(islandRoot.idleCollapsedWidth, islandRoot.idleTextContentWidth) + islandRoot.idleExtraHoverWidth
    
    readonly property real mediaNormalWidth: 260
    readonly property real mediaHoveredWidth: 290
    readonly property real mediaWidth: mediaHoverHandler.hovered ? islandRoot.mediaHoveredWidth : islandRoot.mediaNormalWidth
    readonly property alias mediaHoverHandler: mediaHoverHandler

    readonly property real timerWidth: 130
    readonly property real osdWidth: 132
    readonly property real notificationWidth: 340
    readonly property real batteryWidth: 170
    readonly property real recordingWidth: 120
    readonly property real badgeSize: 32
    readonly property real badgeSpacing: 6
    readonly property bool isMaterial: Config.options.bar.cornerStyle === 3 || Config.options.bar.cornerStyle === 4
    property bool vertical: Config.options.bar.vertical

    readonly property var barGroup: {
        let p = islandRoot.parent;
        while (p) {
            if (p.hasOwnProperty("currentRadius") || p.hasOwnProperty("widgetName")) return p;
            p = p.parent;
        }
        return null;
    }

    readonly property real configuredRadius: {
        // 1. Explicit per-widget style override (from right-click style editor)
        if (islandRoot.barGroup?.style?.radius !== undefined) {
            const r = islandRoot.barGroup.style.radius;
            if (r >= 9999 || r >= islandRoot.pillHeight / 2) return islandRoot.pillHeight / 2;
            return Math.max(Appearance.rounding.unsharpenmore, r);
        }
        // 2. Specific Dynamic Island radius setting (e.g. from slider)
        if (Config.options.bar?.dynamicIsland?.radius !== undefined && Config.options.bar.dynamicIsland.radius > 0) {
            const r = Config.options.bar.dynamicIsland.radius;
            if (r >= 9999 || r >= islandRoot.pillHeight / 2) return islandRoot.pillHeight / 2;
            return Math.max(Appearance.rounding.unsharpenmore, r);
        }
        // 3. Dynamic Island shape preset setting from Settings -> Bar -> Dynamic Island
        const shape = Config.options.bar?.dynamicIsland?.shape ?? "pill";
        if (shape === "subtle") return Appearance.rounding.unsharpenmore; // 6px
        if (shape === "rounded") return Appearance.rounding.small; // 12px
        // 4. Bar-wide group radius fallback if set
        if (Config.options.bar?.groupRadius !== undefined && Config.options.bar.groupRadius < 9999) {
            return Math.max(Appearance.rounding.unsharpenmore, Math.min(islandRoot.pillHeight / 2, Config.options.bar.groupRadius));
        }
        // 5. Default is "pill" (original rounded capsule)
        return islandRoot.pillHeight / 2;
    }

    readonly property real effectivePillRadius: {
        const raw = islandRoot.configuredRadius;
        const maxRadius = islandRoot.pillHeight / 2;
        const minRadius = Appearance.rounding.unsharpenmore;
        if (raw >= maxRadius) return maxRadius;
        return Math.max(minRadius, raw);
    }

    function calculateImageRadius(imageHeight) {
        const maxCircle = imageHeight / 2;
        const minRound = Math.min(Appearance.rounding.unsharpenmore, maxCircle);
        const maxPill = islandRoot.pillHeight / 2;
        const minPill = Appearance.rounding.unsharpenmore;
        const current = islandRoot.effectivePillRadius;

        if (current >= maxPill) return maxCircle;
        if (current <= minPill) return minRound;
        const ratio = (current - minPill) / (maxPill - minPill);
        return minRound + (maxCircle - minRound) * ratio;
    }

    property string manualFocusId: ""
    property bool forceIdle: false

    readonly property var displayedProvider: islandRoot.forceIdle ? null : islandRoot.activeProvider

    onActiveProviderChanged: {
        if (islandRoot.activeProvider && islandRoot.alwaysWinIds.includes(islandRoot.activeProvider.id)) {
            islandRoot.forceIdle = false
        }
    }

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool hasMedia: islandRoot.activePlayer !== null
        && ((islandRoot.activePlayer.trackTitle ?? "") !== "")
        && (islandRoot.activePlayer.isPlaying || mediaPausedKeepAliveTimer.running || mediaHoverHandler.hovered)

    Timer {
        id: mediaPausedKeepAliveTimer
        interval: 10000
        repeat: false
    }

    Connections {
        target: islandRoot.activePlayer
        function onIsPlayingChanged() {
            if (islandRoot.activePlayer?.isPlaying) {
                mediaPausedKeepAliveTimer.stop()
            } else {
                mediaPausedKeepAliveTimer.restart()
            }
        }
    }
    readonly property var latestNotification: Notifications.popupList.length > 0
        ? Notifications.popupList[Notifications.popupList.length - 1]
        : null
    readonly property bool isRecording: Persistent.states.record.enable
    property int recordingElapsedSeconds: 0

    onIsRecordingChanged: {
        if (!isRecording) recordingElapsedSeconds = 0
    }

    function formatRecordingTime(s) {
        return Math.floor(s / 60).toString().padStart(2, '0') + ":" + (s % 60).toString().padStart(2, '0')
    }

    Timer {
        interval: 1000
        repeat: true
        running: islandRoot.isRecording
        onTriggered: islandRoot.recordingElapsedSeconds++
    }

    property string engagedTimerKind: ""
    readonly property bool hasActiveTimer: islandRoot.engagedTimerKind !== ""

    Connections {
        target: TimerService
        function onPomodoroRunningChanged() { if (TimerService.pomodoroRunning) islandRoot.engagedTimerKind = "pomodoro" }
        function onCountdownRunningChanged() { if (TimerService.countdownRunning) islandRoot.engagedTimerKind = "countdown" }
        function onStopwatchRunningChanged() { if (TimerService.stopwatchRunning) islandRoot.engagedTimerKind = "stopwatch" }
    }

    function timerIcon() {
        switch (islandRoot.engagedTimerKind) {
            case "pomodoro":  return TimerService.pomodoroBreak ? "coffee" : "visibility"
            case "countdown": return "hourglass_top"
            case "stopwatch": return "timer"
            default:          return "timer"
        }
    }

    function timerValueText() {
        switch (islandRoot.engagedTimerKind) {
            case "pomodoro":  return TimerService.formatSeconds(TimerService.pomodoroSecondsLeft)
            case "countdown": return TimerService.formatSeconds(TimerService.countdownSecondsLeft)
            case "stopwatch": return TimerService.formatSeconds(TimerService.stopwatchTime / 100)
            default:          return ""
        }
    }

    function timerRunning() {
        switch (islandRoot.engagedTimerKind) {
            case "pomodoro":  return TimerService.pomodoroRunning
            case "countdown": return TimerService.countdownRunning
            case "stopwatch": return TimerService.stopwatchRunning
            default:          return false
        }
    }

    function toggleActiveTimer() {
        switch (islandRoot.engagedTimerKind) {
            case "pomodoro":  TimerService.togglePomodoro(); break
            case "countdown": TimerService.toggleCountdown(); break
            case "stopwatch": TimerService.toggleStopwatch(); break
        }
    }

    function resetActiveTimer() {
        switch (islandRoot.engagedTimerKind) {
            case "pomodoro":  TimerService.resetPomodoro(); break
            case "countdown": TimerService.resetCountdown(); break
            case "stopwatch": TimerService.stopwatchReset(); break
        }
        islandRoot.engagedTimerKind = ""
    }

    property bool batteryAlertActive: false
    property string batteryAlertKind: "" 
    readonly property int batteryAlertDuration: 4000

    Timer {
        id: batteryAlertTimer
        interval: islandRoot.batteryAlertDuration
        repeat: false
        onTriggered: islandRoot.batteryAlertActive = false
    }

    function triggerBatteryAlert(kind) {
        islandRoot.batteryAlertKind = kind
        islandRoot.batteryAlertActive = true
        batteryAlertTimer.restart()
    }

    Connections {
        target: Battery
        function onIsCriticalAndNotChargingChanged() {
            if (Battery.isCriticalAndNotCharging) islandRoot.triggerBatteryAlert("critical")
        }
        function onIsLowAndNotChargingChanged() {
            if (Battery.isLowAndNotCharging && !Battery.isCriticalAndNotCharging) islandRoot.triggerBatteryAlert("low")
        }
        function onIsPluggedInChanged() {
            if (Battery.isPluggedIn) islandRoot.triggerBatteryAlert("charging")
        }
    }

    function batteryStatusText() {
        switch (islandRoot.batteryAlertKind) {
            case "critical": return Translation.tr("Critical Battery")
            case "charging": return Translation.tr("Charging")
            default:         return Translation.tr("Low Battery")
        }
    }

    function batteryIcon() {
        if (islandRoot.batteryAlertKind === "charging" || Battery.isCharging) return "battery_android_frame_bolt"
        const pct = Battery.percentage
        if (pct <= 0.1) return "battery_android_frame_alert"
        if (pct <= 0.2) return "battery_android_frame_1"
        if (pct <= 0.4) return "battery_android_frame_2"
        if (pct <= 0.6) return "battery_android_frame_3"
        if (pct <= 0.8) return "battery_android_frame_4"
        if (pct < 1)    return "battery_android_frame_5"
        return "battery_android_full"
    }

    function batteryAlertColor() {
        return islandRoot.batteryAlertKind === "charging" ? Appearance.m3colors.m3success : Appearance.colors.colError
    }

    // Dynamic Notification tracking (transient 5s display)
    property var activeDynamicNotification: null
    Timer {
        id: dynamicNotifTimer
        interval: 5000
        repeat: false
        onTriggered: islandRoot.activeDynamicNotification = null
    }

    Connections {
        target: Notifications
        function onNotify(notif) {
            islandRoot.activeDynamicNotification = notif
            dynamicNotifTimer.restart()
        }
        function onDiscard(id) {
            if (islandRoot.activeDynamicNotification?.notificationId === id) {
                islandRoot.activeDynamicNotification = null
            }
        }
        function onDiscardAll() {
            islandRoot.activeDynamicNotification = null
        }
    }

    // Quick alert for status notifications (mic, bluetooth, audio mute, clipboard)
    property bool quickAlertActive: false
    property string quickAlertIcon: "info"
    property string quickAlertText: ""
    property color quickAlertColor: Appearance.colors.colPrimary
    TextMetrics {
        id: quickAlertTextMetrics
        text: islandRoot.quickAlertText
        font.pixelSize: Appearance.font.pixelSize.small
        font.weight: Font.DemiBold
    }
    readonly property real quickAlertWidth: Math.min(320, Math.max(180, quickAlertTextMetrics.width + 64))

    Timer {
        id: quickAlertTimer
        interval: 2500
        repeat: false
        onTriggered: islandRoot.quickAlertActive = false
    }

    function triggerQuickAlert(icon, text, color) {
        islandRoot.quickAlertIcon = icon
        islandRoot.quickAlertText = text
        islandRoot.quickAlertColor = color || Appearance.colors.colPrimary
        islandRoot.quickAlertActive = true
        quickAlertTimer.restart()
    }

    Connections {
        target: Audio.source?.audio ?? null
        function onMutedChanged() {
            if (!Audio.source?.audio) return
            if (Audio.source.audio.muted) {
                islandRoot.triggerQuickAlert("mic_off", Translation.tr("Microphone Muted"), Appearance.colors.colError)
            } else {
                islandRoot.triggerQuickAlert("mic", Translation.tr("Microphone Active"), Appearance.m3colors.m3success)
            }
        }
    }

    Connections {
        target: BluetoothStatus
        function onConnectedChanged() {
            if (BluetoothStatus.connected && BluetoothStatus.primaryConnectedDevice) {
                const name = BluetoothStatus.primaryConnectedDevice.name || Translation.tr("Device")
                islandRoot.triggerQuickAlert("bluetooth_connected", `${name} ${Translation.tr("Connected")}`, Appearance.colors.colPrimary)
            }
        }
    }

    Connections {
        target: Audio.sink?.audio ?? null
        function onMutedChanged() {
            if (!Audio.sink?.audio) return
            if (Audio.sink.audio.muted) {
                islandRoot.triggerQuickAlert("volume_off", Translation.tr("Audio Muted"), Appearance.colors.colError)
            }
        }
    }

    Connections {
        target: Cliphist
        function onItemCopied(text) {
            if (!(Config.options?.bar?.dynamicIsland?.enableClipboardAlert ?? true)) return
            const clean = text.replace(/[\r\n\t]+/g, " ")
            const preview = clean.length > 22 ? clean.substring(0, 21) + "…" : clean
            islandRoot.triggerQuickAlert("content_copy", `${Translation.tr("Copied")}: "${preview}"`, Appearance.colors.colPrimary)
        }
    }

    readonly property var contentProviders: [
        { id: "quickAlert",   active: islandRoot.quickAlertActive,                     component: quickAlertComponent,   width: islandRoot.quickAlertWidth },
        { id: "notification", active: islandRoot.activeDynamicNotification !== null,   component: notificationComponent, width: islandRoot.notificationWidth },
        { id: "battery",      active: islandRoot.batteryAlertActive,                   component: batteryComponent,      width: islandRoot.batteryWidth },
        { id: "recording",    active: islandRoot.isRecording,                          component: recordingComponent,    width: islandRoot.recordingWidth },
        { id: "timer",        active: islandRoot.hasActiveTimer,                       component: timerComponent,        width: islandRoot.timerWidth },
        { id: "osd",          active: GlobalStates.osdVolumeOpen || GlobalStates.osdBrightnessOpen, component: osdComponent, width: islandRoot.osdWidth },
        { id: "media",        active: islandRoot.hasMedia,                             component: mediaComponent,        width: islandRoot.mediaWidth },
        { id: "session",      active: GlobalStates.diSessionOpen,                      component: sessionComponent,      width: islandRoot.sessionWidth },
    ]

    readonly property var alwaysWinIds: ["session", "quickAlert", "notification", "battery", "osd"]

    readonly property var activeOthers: islandRoot.contentProviders.filter(p => !islandRoot.alwaysWinIds.includes(p.id) && p.active)

    readonly property var activeProvider: {
        const forcedTop = islandRoot.contentProviders.find(p => islandRoot.alwaysWinIds.includes(p.id) && p.active)
        if (forcedTop) return forcedTop
        if (islandRoot.manualFocusId !== "") {
            const forced = islandRoot.activeOthers.find(p => p.id === islandRoot.manualFocusId)
            if (forced) return forced
        }
        return islandRoot.activeOthers[0] ?? null
    }

    readonly property var badgeProviders: {
        if (islandRoot.alwaysWinIds.some(id => islandRoot.contentProviders.find(p => p.id === id)?.active)) return []
        return islandRoot.activeOthers.filter(p => p.id !== islandRoot.activeProvider?.id)
    }

    function iconForProviderId(id) {
        switch (id) {
            case "quickAlert": return islandRoot.quickAlertIcon
            case "media":     return "music_note"
            case "recording": return "screen_record"
            case "timer":     return islandRoot.timerIcon()
            case "battery":   return islandRoot.batteryIcon()
            case "osd":
                switch (GlobalStates.osdIndicatorType) {
                    case "brightness": return Hyprsunset.temperatureActive ? "routine" : "light_mode"
                    case "gamma":      return "wb_twilight"
                    default:           return "volume_up"
                }
            default: return "circle"
        }
    }

    readonly property string activeContentId: islandRoot.displayedProvider?.id ?? "idle"

    implicitHeight: islandRoot.pillHeight
    implicitWidth: (islandRoot.displayedProvider?.width ?? islandRoot.idleWidth)
        + (!islandRoot.vertical && islandRoot.badgeProviders.length > 0
            ? islandRoot.badgeProviders.length * (islandRoot.badgeSpacing + islandRoot.badgeSize)
            : 0)

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 350
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
        }
    }

    Rectangle {
        id: pill
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: islandRoot.displayedProvider?.width ?? islandRoot.idleWidth
        height: islandRoot.pillHeight
        color: islandRoot.isMaterial || (GlobalStates.barCenterOnly && Config.options.bar.cornerStyle === 0) ? "transparent" : Config.options.bar.followFrameColor
            ? Appearance.getColorFromName(Config.options.bar.frameColor)
            : Appearance.colors.colUiBackground
        radius: islandRoot.effectivePillRadius
        clip: true
        visible: !islandRoot.vertical

        Behavior on radius {
            NumberAnimation {
                duration: 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: 350
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
            }
        }

        border.width: idleHoverHandler.hovered ? 1 : 0
        border.color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.45)

        Behavior on border.color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        HoverHandler {
            id: idleHoverHandler
            enabled: islandRoot.activeContentId === "idle"
        }

        HoverHandler {
            id: mediaHoverHandler
            enabled: islandRoot.activeContentId === "media"
        }

        WheelHandler {
            id: idleToggleWheelHandler
            target: pill
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            property bool coolingDown: false
            onWheel: (event) => {
                if (coolingDown) return
                coolingDown = true
                idleToggleDebounceTimer.restart()
                islandRoot.forceIdle = !islandRoot.forceIdle
            }
        }

        Timer {
            id: idleToggleDebounceTimer
            interval: 200
            onTriggered: idleToggleWheelHandler.coolingDown = false
        }

        Loader {
            id: contentLoader
            anchors.fill: parent
            sourceComponent: islandRoot.displayedProvider?.component ?? idleComponent
            active: !islandRoot.vertical

            onLoaded: {
                if (islandRoot.displayedProvider?.id === "session" && item) {
                    item.forceActiveFocus()
                }
            }
        }

        Component {
            id: idleComponent
            DiIdle { di: islandRoot }
        }

        Component {
            id: mediaComponent
            DiMedia { di: islandRoot }
        }

        Component {
            id: osdComponent
            DiOsd { di: islandRoot }
        }

        Component {
            id: notificationComponent
            DiNotifs {
                di: islandRoot
                notif: islandRoot.activeDynamicNotification
            }
        }

        Component {
            id: timerComponent
            DiTimers { di: islandRoot }
        }

        Component {
            id: sessionComponent
            DiSession { di: islandRoot }
        }

        Component {
            id: recordingComponent
            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: islandRoot.isMaterial ? 4 : 8
                    rightMargin: 10
                }
                spacing: 6

                Item {
                    id: stopButton
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 16
                    implicitHeight: 16

                    MaterialSymbol {
                        anchors.fill: parent
                        text: "stop_circle"
                        fill: 1
                        iconSize: islandRoot.isMaterial ? 26 : 16
                        color: Appearance.colors.colError
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached([Directories.recordScriptPath])
                    }
                }

                Item { Layout.fillWidth: true }

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    text: islandRoot.formatRecordingTime(islandRoot.recordingElapsedSeconds)
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.features: { "tnum": 1 }
                    color: Appearance.colors.colOnLayer0
                }
            }
        }

        Component {
            id: batteryComponent
            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 10
                    rightMargin: 10
                }
                spacing: 6

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    text: islandRoot.batteryStatusText()
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: islandRoot.batteryAlertColor()
                }

                Item { Layout.fillWidth: true }

                MaterialSymbol {
                    Layout.alignment: Qt.AlignVCenter
                    text: islandRoot.batteryIcon()
                    fill: 1
                    iconSize: 16
                    color: islandRoot.batteryAlertColor()
                }

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    text: `${Math.round(Battery.percentage * 100)}`
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.features: { "tnum": 1 }
                    color: islandRoot.batteryAlertColor()
                }
            }
        }

        Component {
            id: quickAlertComponent
            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 12
                    rightMargin: 12
                }
                spacing: 8

                MaterialSymbol {
                    Layout.alignment: Qt.AlignVCenter
                    text: islandRoot.quickAlertIcon
                    fill: 1
                    iconSize: 18
                    color: islandRoot.quickAlertColor
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: islandRoot.quickAlertText
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                    elide: Text.ElideRight
                }
            }
        }
    }

    Row {
        id: badgesRow
        visible: islandRoot.badgeProviders.length > 0 && !islandRoot.vertical
        anchors {
            left: pill.right
            leftMargin: islandRoot.badgeSpacing
            verticalCenter: pill.verticalCenter
        }
        spacing: islandRoot.badgeSpacing

        Repeater {
            model: islandRoot.badgeProviders
            delegate: Item {
                id: badgeItem
                required property var modelData
                width: islandRoot.badgeSize
                height: islandRoot.badgeSize

                MaterialShapeWrappedMaterialSymbol {
                    anchors.fill: parent
                    wrappedShape: MaterialShape.Shape.Cookie7Sided
                    color: islandRoot.isMaterial ? Appearance.colors.colPrimary : Appearance.colors.colLayer0
                    colSymbol: islandRoot.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0
                    text: islandRoot.iconForProviderId(badgeItem.modelData.id)
                    iconSize: 16
                    fill: 1
                    padding: 4
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: islandRoot.manualFocusId = badgeItem.modelData.id
                }
            }
        }
    }
}