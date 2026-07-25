1|pragma Singleton
2|pragma ComponentBehavior: Bound
3|
4|import qs.modules.common
5|import qs.modules.common.models.hyprland
6|import QtQuick
7|import Quickshell
8|import Quickshell.Io
9|import Quickshell.Hyprland
10|
11|/**
12| * DisplayProjection controller.
13| * Reuses MonitorConfigOption as the single source of truth for monitor state.
14| * The OSD is only a UI layer — all monitor operations go through this controller,
15| * which delegates to MonitorConfigOption (fetch, update, apply, save).
16| *
17| * Modes:
18| *   "primary"   — only primary monitor enabled
19| *   "secondary" — only the selected external monitor enabled
20| *   "extend"    — all monitors enabled, restore saved positions
21| *   "mirror"    — clone primary onto all others via Hyprland mirror
22| */
23|Singleton {
24|    id: root
25|
26|    // ── Current state ──
27|    readonly property string currentMode: _internalMode
28|    property string _internalMode: "extend"
29|    readonly property var monitors: monitorConfig.monitors
30|    readonly property string primaryMonitor: _primary
31|    property string _primary: ""
32|    readonly property string secondaryMonitor: _secondary
33|    property string _secondary: ""
34|    readonly property bool hasMultipleMonitors: monitors.length > 1
35|
36|    // ── Persisted extended layout (for restore on Extend) ──
37|    property var savedExtendedLayout: []
38|
39|    // ── The single source of truth for monitor state ──
40|    MonitorConfigOption {
41|        id: monitorConfig
42|    }
43|
44|    signal modeChanged(string mode)
45|    signal monitorsUpdated()
46|
47|    Component.onCompleted: {
48|        fetchMonitors()
49|        readRulesProc.running = true
50|    }
51|
52|    // ── Fetch monitors from Hyprland (via MonitorConfigOption) ──
53|    function fetchMonitors() {
54|        monitorConfig.reload()
55|        // Detect primary/secondary after reload — can't rely on Connections
56|        // because MonitorConfigOption doesn't have a monitorsChanged signal.
57|        // Use a small delay to let the async fetchProc finish.
58|        detectTimer.restart()
59|    }
60|
61|    Timer {
62|        id: detectTimer
63|        interval: 200
64|        repeat: false
65|        onTriggered: {
66|            root._detectPrimarySecondary()
67|            root._detectCurrentMode()
68|        }
69|    }
70|
71|    // Detect primary/secondary from monitor list
72|    // IMPORTANT: detect from ALL monitors (including disabled), not just enabled.
73|    // This allows switching from Primary Only → Secondary Only directly.
74|    function _detectPrimarySecondary() {
75|        const ms = monitorConfig.monitors
76|        if (ms.length === 0) return
77|
79|        // Prefer laptop screen as primary — check ALL monitors regardless of disabled
80|        const laptopKeywords = ["edp", "lvds", "dsi"]
81|        for (const m of ms) {
82|            const lower = m.name.toLowerCase()
83|            if (laptopKeywords.some(k => lower.includes(k))) {
84|                root._primary = m.name
85|                // Secondary = first OTHER monitor (even if disabled)
86|                for (const m2 of ms) {
87|                    if (m2.name !== m.name) {
88|                        root._secondary = m2.name
89|                        root._detectCurrentMode()
91|                        return
92|                    }
93|                }
94|                root._secondary = ""
95|                root._detectCurrentMode()
97|                return
98|            }
99|        }
100|        // No laptop: first monitor = primary, second = secondary
101|        if (ms.length >= 1) root._primary = ms[0].name
102|        if (ms.length >= 2) root._secondary = ms[1].name
103|        root._detectCurrentMode()
105|    }
106|
107|    // Detect current mode from monitor states
108|    function _detectCurrentMode() {
109|        const ms = monitorConfig.monitors
110|        const enabled = ms.filter(m => !m.disabled)
111|        if (enabled.length <= 1) {
112|            if (enabled.length === 1) {
113|                root._internalMode = (enabled[0].name === root._primary) ? "primary" : "secondary"
114|            } else {
115|                root._internalMode = "primary"
116|            }
117|        } else {
118|            // Multiple enabled — check if any has mirror
119|            // Hyprland doesn't expose mirrorOf in hyprctl monitors, so check our saved state
120|            root._internalMode = root._internalMode === "mirror" ? "mirror" : "extend"
121|        }
122|    }
123|
124|    // Save current extended layout before switching away
125|    function saveExtendedLayout() {
126|        const layout = monitorConfig.monitors.filter(m => !m.disabled).map(m => ({
127|            name: m.name,
128|            x: m.x,
129|            y: m.y,
130|            scale: m.scale,
131|            currentMode: m.currentMode,
132|            transform: m.transform ?? 0,
133|        }))
134|        root.savedExtendedLayout = layout
135|    }
136|
137|    // ── Apply a mode (the ONLY entry point for mode switching) ──
138|    function applyMode(mode) {
139|        // Ensure primary/secondary are detected BEFORE applying
140|        root._detectPrimarySecondary()
141|        if (!root._primary) {
143|            return
144|        }
145|        if (!root.hasMultipleMonitors) {
146|            Quickshell.execDetached(["notify-send", "Display Projection",
147|                "Only one monitor detected", "-a", "Shell", "-t", "2000"])
148|            return
149|        }
150|
152|
153|        // Save current layout before switching (for extend restore)
154|        if (root._internalMode === "extend") root.saveExtendedLayout()
155|
156|        root._internalMode = mode
157|
158|        if (mode === "primary") _applyPrimaryOnly()
159|        else if (mode === "secondary") _applySecondaryOnly()
160|        else if (mode === "extend") _applyExtend()
161|        else if (mode === "mirror") _applyMirror()
162|
163|        root.modeChanged(mode)
164|        _notifyModeChange(mode)
165|    }
166|
167|    // Primary Only: enable primary, disable all others
168|    function _applyPrimaryOnly() {
169|        const ms = monitorConfig.monitors
171|        const lines = []
172|        for (let i = 0; i < ms.length; i++) {
173|            const enable = (ms[i].name === root._primary)
175|            monitorConfig.updateMonitor(i, { disabled: !enable, mirrorOf: "", x: 0, y: 0 })
176|            if (enable) {
177|                lines.push(`hl.monitor({ output = "${ms[i].name}", mode = "${ms[i].currentMode}", position = "0x0", scale = ${ms[i].scale}, transform = ${ms[i].transform ?? 0}, vrr = false })`)
178|            } else {
179|                lines.push(`hl.monitor({ output = "${ms[i].name}", disabled = true })`)
180|            }
181|        }
182|        _writeGeneralLua(lines)
183|    }
184|
185|    // Secondary Only: enable secondary, disable all others
186|    function _applySecondaryOnly() {
187|        if (!root._secondary) {
189|            _applyPrimaryOnly()
190|            return
191|        }
192|        const ms = monitorConfig.monitors
194|        const lines = []
195|        for (let i = 0; i < ms.length; i++) {
196|            const enable = (ms[i].name === root._secondary)
198|            monitorConfig.updateMonitor(i, { disabled: !enable, mirrorOf: "", x: 0, y: 0 })
199|            if (enable) {
200|                lines.push(`hl.monitor({ output = "${ms[i].name}", mode = "${ms[i].currentMode}", position = "0x0", scale = ${ms[i].scale}, transform = ${ms[i].transform ?? 0}, vrr = false })`)
201|            } else {
202|                lines.push(`hl.monitor({ output = "${ms[i].name}", disabled = true })`)
203|            }
204|        }
205|        _writeGeneralLua(lines)
206|    }
207|
208|    // Extend: enable all, restore saved positions or auto side-by-side
209|    function _applyExtend() {
210|        const ms = monitorConfig.monitors
211|        const lines = []
212|        if (root.savedExtendedLayout.length >= 2) {
213|            let minX = Infinity, minY = Infinity
214|            for (const s of root.savedExtendedLayout) {
215|                if (s.x < minX) minX = s.x
216|                if (s.y < minY) minY = s.y
217|            }
218|            for (let i = 0; i < ms.length; i++) {
219|                const saved = root.savedExtendedLayout.find(s => s.name === ms[i].name)
220|                let x = 0, y = 0, scale = ms[i].scale
221|                if (saved) {
222|                    x = saved.x - minX
223|                    y = saved.y - minY
224|                    scale = saved.scale
225|                }
226|                monitorConfig.updateMonitor(i, { disabled: false, mirrorOf: "", x: x, y: y, scale: scale })
227|                lines.push(`hl.monitor({ output = "${ms[i].name}", mode = "${ms[i].currentMode}", position = "${x}x${y}", scale = ${scale}, transform = ${ms[i].transform ?? 0}, vrr = false })`)
228|            }
229|        } else {
230|            let offsetX = 0
231|            for (let i = 0; i < ms.length; i++) {
232|                const m = ms[i]
233|                const w = (m.transform === 1 || m.transform === 3) ? m.height : m.width
234|                monitorConfig.updateMonitor(i, { disabled: false, mirrorOf: "", x: offsetX, y: 0 })
235|                lines.push(`hl.monitor({ output = "${m.name}", mode = "${m.currentMode}", position = "${offsetX}x0", scale = ${m.scale}, transform = ${m.transform ?? 0}, vrr = false })`)
236|                offsetX += w
237|            }
238|        }
239|        _writeGeneralLua(lines)
240|    }
241|
242|    // Mirror: enable primary, mirror others onto primary
243|    function _applyMirror() {
244|        const ms = monitorConfig.monitors
245|        const lines = []
246|        for (let i = 0; i < ms.length; i++) {
247|            if (ms[i].name === root._primary) {
248|                monitorConfig.updateMonitor(i, { disabled: false, mirrorOf: "" })
249|                lines.push(`hl.monitor({ output = "${ms[i].name}", mode = "${ms[i].currentMode}", position = "0x0", scale = ${ms[i].scale}, transform = ${ms[i].transform ?? 0}, vrr = false })`)
250|            } else {
251|                monitorConfig.updateMonitor(i, { disabled: false, mirrorOf: root._primary })
252|                lines.push(`hl.monitor({ output = "${ms[i].name}", mode = "${ms[i].currentMode}", position = "${ms[i].x}x${ms[i].y}", scale = ${ms[i].scale}, transform = ${ms[i].transform ?? 0}, vrr = false, mirror = "${root._primary}" })`)
253|            }
254|        }
255|        _writeGeneralLua(lines)
256|    }
257|
258|    // ── Toast notification ──
259|    function _notifyModeChange(mode) {
260|        const labels = {
261|            "primary": "Primary Only",
262|            "secondary": "Secondary Only",
263|            "extend": "Extend",
264|            "mirror": "Mirror",
265|        }
266|        Quickshell.execDetached(["notify-send", "Display Projection",
267|            `✓ Projection changed to ${labels[mode] || mode}`, "-a", "Shell", "-t", "2000",
268|            "-i", "preferences-display"])
269|    }
270|
271|    // ── Write to custom/general.lua (DisplaySet format) + reload ──
272|    // This is where illogical-impulse actually reads monitor config from.
273|    // monitors.lua is overridden by custom/general.lua.
274|    function _writeGeneralLua(monitorLines) {
275|        // Read existing workspace rules from general.lua to preserve them
276|        var existingRules = ""
277|        readRulesProc.running = false
278|        readRulesProc.running = true
279|
280|        const header = "-- ===== DisplayProjection generated monitor config =====\n-- This file is managed by DisplayProjection. Manual edits will be overwritten.\n\n"
281|        const footer = "\n-- ===== /DisplayProjection =====\n\n" + savedWorkspaceRules
282|        const content = header + monitorLines.join("\n\n") + footer
283|        const escaped = content.replace(/'/g, "'\\''")
284|        // 1. Write to general.lua
285|        writeProc.command = ["bash", "-c",
286|            `printf '%s\n' '${escaped}' > ~/.config/hypr/custom/general.lua`]
287|        writeProc.running = true
288|        // 2. Apply via hyprctl eval (runs hl.monitor() directly in lua)
289|        const evalCmd = monitorLines.join("; ")
290|        applyEvalProc.command = ["hyprctl", "eval", evalCmd]
291|        applyEvalProc.running = true
292|    }
293|
294|    // Preserve workspace rules from existing general.lua
295|    property string savedWorkspaceRules: ""
296|    Process {
297|        id: readRulesProc
298|        command: ["bash", "-c",
299|            "awk '/-- ===== DisplaySet workspace rules/,/-- ===== \\/DisplaySet workspace rules/' ~/.config/hypr/custom/general.lua 2>/dev/null || true"]
300|        stdout: StdioCollector {
301|            onStreamFinished: {
302|                if (text.trim().length > 0) {
303|                    root.savedWorkspaceRules = text.trim()
304|                } else {
305|                    // Default rules
306|                    root.savedWorkspaceRules = "-- ===== DisplaySet workspace rules =====\nhl.workspace_rule({ workspace = \"1\", monitor = \"eDP-1\" })\nhl.workspace_rule({ workspace = \"2\", monitor = \"eDP-1\" })\nhl.workspace_rule({ workspace = \"3\", monitor = \"eDP-1\" })\nhl.workspace_rule({ workspace = \"4\", monitor = \"eDP-1\" })\nhl.workspace_rule({ workspace = \"5\", monitor = \"eDP-1\" })\nhl.workspace_rule({ workspace = \"6\", monitor = \"eDP-1\" })\nhl.workspace_rule({ workspace = \"7\", monitor = \"HDMI-A-5\" })\nhl.workspace_rule({ workspace = \"8\", monitor = \"HDMI-A-5\" })\nhl.workspace_rule({ workspace = \"9\", monitor = \"HDMI-A-5\" })\nhl.workspace_rule({ workspace = \"10\", monitor = \"HDMI-A-5\" })\n-- ===== /DisplaySet workspace rules ====="
307|                }
308|            }
309|        }
310|    }
311|
312|    Process { id: writeProc }
313|
314|    Process {
315|        id: applyEvalProc
316|        onRunningChanged: if (!running) reloadProc.running = true
317|    }
318|
319|    Process {
320|        id: reloadProc
321|        command: ["hyprctl", "reload"]
322|    }
323|
324|    // ── React to monitor changes ──
325|    // MonitorConfigOption doesn't have a monitorsChanged signal,
326|    // so we use fetchMonitors() + detectTimer instead.
327|
328|    // ── IPC ──
329|    IpcHandler {
330|        target: "displayProjection"
331|        function toggle(): void {
332|            GlobalStates.displayProjectionOpen = !GlobalStates.displayProjectionOpen
333|        }
334|        function open(): void {
335|            root.fetchMonitors()
336|            GlobalStates.displayProjectionOpen = true
337|        }
338|        function close(): void {
339|            GlobalStates.displayProjectionOpen = false
340|        }
341|        function apply(mode: string): void {
342|            root.applyMode(mode)
343|        }
344|        function cycle(): void {
345|            const modes = ["primary", "secondary", "extend", "mirror"]
346|            const idx = modes.indexOf(root.currentMode)
347|            GlobalStates.displayProjectionCycleIndex = (idx + 1) % modes.length
348|        }
349|    }
350|}
351|