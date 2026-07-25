pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.models.hyprland
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * DisplayProjection controller.
 * Reuses MonitorConfigOption as the single source of truth for monitor state.
 * The OSD is only a UI layer — all monitor operations go through this controller,
 * which delegates to MonitorConfigOption (fetch, update, apply, save).
 *
 * Modes:
 *   "primary"   — only primary monitor enabled
 *   "secondary" — only the selected external monitor enabled
 *   "extend"    — all monitors enabled, restore saved positions
 *   "mirror"    — clone primary onto all others via Hyprland mirror
 */
Singleton {
    id: root

    // ── Current state ──
    readonly property string currentMode: _internalMode
    property string _internalMode: "extend"
    readonly property var monitors: monitorConfig.monitors
    readonly property string primaryMonitor: _primary
    property string _primary: ""
    readonly property string secondaryMonitor: _secondary
    property string _secondary: ""
    readonly property bool hasMultipleMonitors: monitors.length > 1

    // ── Persisted extended layout (for restore on Extend) ──
    property var savedExtendedLayout: []

    // ── The single source of truth for monitor state ──
    MonitorConfigOption {
        id: monitorConfig
    }

    signal modeChanged(string mode)
    signal monitorsUpdated()

    Component.onCompleted: {
        fetchMonitors()
        readRulesProc.running = true
    }

    // ── Fetch monitors from Hyprland (via MonitorConfigOption) ──
    function fetchMonitors() {
        monitorConfig.reload()
        // Detect primary/secondary after reload — can't rely on Connections
        // because MonitorConfigOption doesn't have a monitorsChanged signal.
        // Use a small delay to let the async fetchProc finish.
        detectTimer.restart()
    }

    Timer {
        id: detectTimer
        interval: 200
        repeat: false
        onTriggered: {
            root._detectPrimarySecondary()
            root._detectCurrentMode()
        }
    }

    // Detect primary/secondary from monitor list
    // IMPORTANT: detect from ALL monitors (including disabled), not just enabled.
    // This allows switching from Primary Only → Secondary Only directly.
    function _detectPrimarySecondary() {
        const ms = monitorConfig.monitors
        if (ms.length === 0) return

        // Prefer laptop screen as primary — check ALL monitors regardless of disabled
        const laptopKeywords = ["edp", "lvds", "dsi"]
        for (const m of ms) {
            const lower = m.name.toLowerCase()
            if (laptopKeywords.some(k => lower.includes(k))) {
                root._primary = m.name
                // Secondary = first OTHER monitor (even if disabled)
                for (const m2 of ms) {
                    if (m2.name !== m.name) {
                        root._secondary = m2.name
                        root._detectCurrentMode()
                        return
                    }
                }
                root._secondary = ""
                root._detectCurrentMode()
                return
            }
        }
        // No laptop: first monitor = primary, second = secondary
        if (ms.length >= 1) root._primary = ms[0].name
        if (ms.length >= 2) root._secondary = ms[1].name
        root._detectCurrentMode()
    }

    // Detect current mode from monitor states
    function _detectCurrentMode() {
        const ms = monitorConfig.monitors
        const enabled = ms.filter(m => !m.disabled)
        if (enabled.length <= 1) {
            if (enabled.length === 1) {
                root._internalMode = (enabled[0].name === root._primary) ? "primary" : "secondary"
            } else {
                root._internalMode = "primary"
            }
        } else {
            // Multiple enabled — check if any has mirror
            // Hyprland doesn't expose mirrorOf in hyprctl monitors, so check our saved state
            root._internalMode = root._internalMode === "mirror" ? "mirror" : "extend"
        }
    }

    // Save current extended layout before switching away
    function saveExtendedLayout() {
        const layout = monitorConfig.monitors.filter(m => !m.disabled).map(m => ({
            name: m.name,
            x: m.x,
            y: m.y,
            scale: m.scale,
            currentMode: m.currentMode,
            transform: m.transform ?? 0,
        }))
        root.savedExtendedLayout = layout
    }

    // ── Apply a mode (the ONLY entry point for mode switching) ──
    function applyMode(mode) {
        // Ensure primary/secondary are detected BEFORE applying
        root._detectPrimarySecondary()
        if (!root._primary) {
            return
        }
        if (!root.hasMultipleMonitors) {
            Quickshell.execDetached(["notify-send", "Display Projection",
                "Only one monitor detected", "-a", "Shell", "-t", "2000"])
            return
        }


        // Save current layout before switching (for extend restore)
        if (root._internalMode === "extend") root.saveExtendedLayout()

        root._internalMode = mode

        if (mode === "primary") _applyPrimaryOnly()
        else if (mode === "secondary") _applySecondaryOnly()
        else if (mode === "extend") _applyExtend()
        else if (mode === "mirror") _applyMirror()

        root.modeChanged(mode)
        _notifyModeChange(mode)
    }

    // Primary Only: enable primary, disable all others
    function _applyPrimaryOnly() {
        const ms = monitorConfig.monitors
        const lines = []
        for (let i = 0; i < ms.length; i++) {
            const enable = (ms[i].name === root._primary)
            monitorConfig.updateMonitor(i, { disabled: !enable, mirrorOf: "", x: 0, y: 0 })
            if (enable) {
                lines.push(`hl.monitor({ output = "${ms[i].name}", mode = "${ms[i].currentMode}", position = "0x0", scale = ${ms[i].scale}, transform = ${ms[i].transform ?? 0}, vrr = false })`)
            } else {
                lines.push(`hl.monitor({ output = "${ms[i].name}", disabled = true })`)
            }
        }
        _writeGeneralLua(lines)
    }

    // Secondary Only: enable secondary, disable all others
    function _applySecondaryOnly() {
        if (!root._secondary) {
            _applyPrimaryOnly()
            return
        }
        const ms = monitorConfig.monitors
        const lines = []
        for (let i = 0; i < ms.length; i++) {
            const enable = (ms[i].name === root._secondary)
            monitorConfig.updateMonitor(i, { disabled: !enable, mirrorOf: "", x: 0, y: 0 })
            if (enable) {
                lines.push(`hl.monitor({ output = "${ms[i].name}", mode = "${ms[i].currentMode}", position = "0x0", scale = ${ms[i].scale}, transform = ${ms[i].transform ?? 0}, vrr = false })`)
            } else {
                lines.push(`hl.monitor({ output = "${ms[i].name}", disabled = true })`)
            }
        }
        _writeGeneralLua(lines)
    }

    // Extend: enable all, restore saved positions or auto side-by-side
    function _applyExtend() {
        const ms = monitorConfig.monitors
        const lines = []
        if (root.savedExtendedLayout.length >= 2) {
            let minX = Infinity, minY = Infinity
            for (const s of root.savedExtendedLayout) {
                if (s.x < minX) minX = s.x
                if (s.y < minY) minY = s.y
            }
            for (let i = 0; i < ms.length; i++) {
                const saved = root.savedExtendedLayout.find(s => s.name === ms[i].name)
                let x = 0, y = 0, scale = ms[i].scale
                if (saved) {
                    x = saved.x - minX
                    y = saved.y - minY
                    scale = saved.scale
                }
                monitorConfig.updateMonitor(i, { disabled: false, mirrorOf: "", x: x, y: y, scale: scale })
                lines.push(`hl.monitor({ output = "${ms[i].name}", mode = "${ms[i].currentMode}", position = "${x}x${y}", scale = ${scale}, transform = ${ms[i].transform ?? 0}, vrr = false })`)
            }
        } else {
            let offsetX = 0
            for (let i = 0; i < ms.length; i++) {
                const m = ms[i]
                const w = (m.transform === 1 || m.transform === 3) ? m.height : m.width
                monitorConfig.updateMonitor(i, { disabled: false, mirrorOf: "", x: offsetX, y: 0 })
                lines.push(`hl.monitor({ output = "${m.name}", mode = "${m.currentMode}", position = "${offsetX}x0", scale = ${m.scale}, transform = ${m.transform ?? 0}, vrr = false })`)
                offsetX += w
            }
        }
        _writeGeneralLua(lines)
    }

    // Mirror: enable primary, mirror others onto primary
    function _applyMirror() {
        const ms = monitorConfig.monitors
        const lines = []
        for (let i = 0; i < ms.length; i++) {
            if (ms[i].name === root._primary) {
                monitorConfig.updateMonitor(i, { disabled: false, mirrorOf: "" })
                lines.push(`hl.monitor({ output = "${ms[i].name}", mode = "${ms[i].currentMode}", position = "0x0", scale = ${ms[i].scale}, transform = ${ms[i].transform ?? 0}, vrr = false })`)
            } else {
                monitorConfig.updateMonitor(i, { disabled: false, mirrorOf: root._primary })
                lines.push(`hl.monitor({ output = "${ms[i].name}", mode = "${ms[i].currentMode}", position = "${ms[i].x}x${ms[i].y}", scale = ${ms[i].scale}, transform = ${ms[i].transform ?? 0}, vrr = false, mirror = "${root._primary}" })`)
            }
        }
        _writeGeneralLua(lines)
    }

    // ── Toast notification ──
    function _notifyModeChange(mode) {
        const labels = {
            "primary": "Primary Only",
            "secondary": "Secondary Only",
            "extend": "Extend",
            "mirror": "Mirror",
        }
        Quickshell.execDetached(["notify-send", "Display Projection",
            `✓ Projection changed to ${labels[mode] || mode}`, "-a", "Shell", "-t", "2000",
            "-i", "preferences-display"])
    }

    // ── Write to custom/general.lua (DisplaySet format) + reload ──
    // This is where illogical-impulse actually reads monitor config from.
    // monitors.lua is overridden by custom/general.lua.
    function _writeGeneralLua(monitorLines) {
        // Read existing workspace rules from general.lua to preserve them
        var existingRules = ""
        readRulesProc.running = false
        readRulesProc.running = true

        const header = "-- ===== DisplayProjection generated monitor config =====\n-- This file is managed by DisplayProjection. Manual edits will be overwritten.\n\n"
        const footer = "\n-- ===== /DisplayProjection =====\n\n" + savedWorkspaceRules
        const content = header + monitorLines.join("\n\n") + footer
        const escaped = content.replace(/'/g, "'\\''")
        // 1. Write to general.lua
        writeProc.command = ["bash", "-c",
            `printf '%s\n' '${escaped}' > ~/.config/hypr/custom/general.lua`]
        writeProc.running = true
        // 2. Apply via hyprctl eval (runs hl.monitor() directly in lua)
        const evalCmd = monitorLines.join("; ")
        applyEvalProc.command = ["hyprctl", "eval", evalCmd]
        applyEvalProc.running = true
    }

    // Preserve workspace rules from existing general.lua
    property string savedWorkspaceRules: ""
    Process {
        id: readRulesProc
        command: ["bash", "-c",
            "awk '/-- ===== DisplaySet workspace rules/,/-- ===== \\/DisplaySet workspace rules/' ~/.config/hypr/custom/general.lua 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0) {
                    root.savedWorkspaceRules = text.trim()
                } else {
                    // Default rules
                    root.savedWorkspaceRules = "-- ===== DisplaySet workspace rules =====\nhl.workspace_rule({ workspace = \"1\", monitor = \"eDP-1\" })\nhl.workspace_rule({ workspace = \"2\", monitor = \"eDP-1\" })\nhl.workspace_rule({ workspace = \"3\", monitor = \"eDP-1\" })\nhl.workspace_rule({ workspace = \"4\", monitor = \"eDP-1\" })\nhl.workspace_rule({ workspace = \"5\", monitor = \"eDP-1\" })\nhl.workspace_rule({ workspace = \"6\", monitor = \"eDP-1\" })\nhl.workspace_rule({ workspace = \"7\", monitor = \"HDMI-A-5\" })\nhl.workspace_rule({ workspace = \"8\", monitor = \"HDMI-A-5\" })\nhl.workspace_rule({ workspace = \"9\", monitor = \"HDMI-A-5\" })\nhl.workspace_rule({ workspace = \"10\", monitor = \"HDMI-A-5\" })\n-- ===== /DisplaySet workspace rules ====="
                }
            }
        }
    }

    Process { id: writeProc }

    Process {
        id: applyEvalProc
        onRunningChanged: if (!running) reloadProc.running = true
    }

    Process {
        id: reloadProc
        command: ["hyprctl", "reload"]
    }

    // ── React to monitor changes ──
    // MonitorConfigOption doesn't have a monitorsChanged signal,
    // so we use fetchMonitors() + detectTimer instead.

    // ── IPC ──
    IpcHandler {
        target: "displayProjection"
        function toggle(): void {
            GlobalStates.displayProjectionOpen = !GlobalStates.displayProjectionOpen
        }
        function open(): void {
            root.fetchMonitors()
            GlobalStates.displayProjectionOpen = true
        }
        function close(): void {
            GlobalStates.displayProjectionOpen = false
        }
        function apply(mode: string): void {
            root.applyMode(mode)
        }
        function cycle(): void {
            const modes = ["primary", "secondary", "extend", "mirror"]
            const idx = modes.indexOf(root.currentMode)
            GlobalStates.displayProjectionCycleIndex = (idx + 1) % modes.length
        }
    }
}
