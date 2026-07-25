pragma ComponentBehavior: Bound
import QtQml
import QtQuick
import Quickshell.Io
import qs.services
import "../"

NestableObject {
    id: root

    property var monitors: []

    Component.onCompleted: fetchProc.running = true

    function reload() {
        fetchProc.running = true
    }

    function updateMonitor(index, changes) {
        let m = root.monitors.slice()
        m[index] = Object.assign({}, m[index], changes)
        root.monitors = m
    }

    function _buildLuaLine(m) {
        if (m.disabled)
            return `hl.monitor({ output = "${m.name}", disabled = true })`

        // Mirror mode: monitor mirrors another
        if (m.mirrorOf && m.mirrorOf.length > 0)
            return `hl.monitor({ output = "${m.name}", mode = "${m.currentMode}", position = "${m.x}x${m.y}", scale = ${m.scale}, mirror = "${m.mirrorOf}" })`

        const pos = `${m.x}x${m.y}`
        let line = `hl.monitor({ output = "${m.name}", mode = "${m.currentMode}", position = "${pos}", scale = ${m.scale}`

        if (m.transform && m.transform !== 0)
            line += `, transform = ${m.transform}`

        line += ` })`
        return line
    }

    function save() {
        if (root.monitors.length === 0) return
        if (root.monitors.some(m => !m.name)) return

        const lines = root.monitors.map(m => {
            const line = root._buildLuaLine(m)
            console.log(`[MonitorConfig] saving line: "${line}"`)
            return line
        }).join("\n")

        console.log(`[MonitorConfig] full file:\n${lines}`)

        const escaped = lines.replace(/'/g, "'\\''")
        saveProc.command = ["bash", "-c",
            `printf '%s\n' '${escaped}' > ~/.config/hypr/monitors.lua`]
        saveProc.running = true
    }

    function applyMonitor(m) {
        if (!m.name) return
        const base = `${m.name},${m.currentMode},${m.x}x${m.y},${m.scale}`
        // Mirror mode: append mirror,<target>
        if (m.mirrorOf && m.mirrorOf.length > 0) {
            applyProc.command = ["hyprctl", "keyword", "monitor", `${base},mirror,${m.mirrorOf}`]
        } else if (m.disabled) {
            applyProc.command = ["hyprctl", "keyword", "monitor", `${m.name},disable`]
        } else if (m.transform && m.transform !== 0) {
            applyProc.command = ["hyprctl", "keyword", "monitor", `${base},transform,${m.transform}`]
        } else {
            applyProc.command = ["hyprctl", "keyword", "monitor", base]
        }
        applyProc.running = true
    }

    // Apply ALL monitors at once via a single bash command.
    // This avoids the race condition where applyProc overwrites itself.
    function applyAllMonitors(monitors) {
        // With illogical-impulse's lua parser, hyprctl keyword doesn't work.
        // Instead, write to monitors.lua (save()) and reload Hyprland.
        // This function is a no-op — save() already handles everything via saveProc → reloadProc.
        // Kept for API compatibility but does nothing.
    }

    function applyAndSave(index) {
        root.applyMonitor(root.monitors[index])
        root.save()
    }

    function logicalWidth(m) {
        return (m.transform === 1 || m.transform === 3) ? m.height : m.width
    }

    function logicalHeight(m) {
        return (m.transform === 1 || m.transform === 3) ? m.width : m.height
    }

    Process {
        id: fetchProc
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.monitors = JSON.parse(text).map(m => ({
                        name:          m.name,
                        description:   m.description,
                        width:         m.width,
                        height:        m.height,
                        refreshRate:   m.refreshRate,
                        x:             m.x,
                        y:             m.y,
                        scale:         m.scale,
                        transform:     m.transform ?? 0,
                        disabled:      m.disabled,
                        mirrorOf:      m.mirrorOf ?? "",
                        availableModes: m.availableModes,
                        currentMode:   `${m.width}x${m.height}@${m.refreshRate.toFixed(2)}Hz`
                    }))
                } catch(e) {
                    console.log("[MonitorConfig] Error parseando JSON:", e)
                }
            }
        }
    }

    Process { id: applyProc }

    Process { id: applyAllProc }

    Process {
        id: saveProc
        onRunningChanged: if (!running) reloadProc.running = true
    }

    Process {
        id: reloadProc
        command: ["hyprctl", "reload"]
    }
}
