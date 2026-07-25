1|import qs
2|import qs.services
3|import qs.modules.common
4|import qs.modules.common.widgets
5|import QtQuick
6|import QtQuick.Controls
7|import QtQuick.Layouts
8|import Quickshell
9|import Quickshell.Hyprland
10|import Quickshell.Wayland
11|
12|/**
13| * Display Projection OSD — Windows + P style, Material Design 3.
14| * Floating centered panel with 4 mode buttons, keyboard nav, auto-close.
15| */
16|Scope {
17|    id: root
18|
19|    // ── Global shortcut: Super+P cycling ──
20|    GlobalShortcut {
21|        name: "displayProjectionToggle"
22|        description: "Opens/cycles display projection OSD"
23|
24|        onPressed: {
26|            const modes = ["primary", "secondary", "extend", "mirror"]
27|            if (!GlobalStates.displayProjectionOpen) {
28|                DisplayProjection.fetchMonitors()
29|                const idx = modes.indexOf(DisplayProjection.currentMode)
30|                GlobalStates.displayProjectionCycleIndex = idx >= 0 ? idx : 2
31|                GlobalStates.displayProjectionOpen = true
32|                // Prevent searchToggleRelease from opening overview on Super release
33|                GlobalStates.superReleaseMightTrigger = false
34|            } else {
35|                GlobalStates.displayProjectionCycleIndex = (GlobalStates.displayProjectionCycleIndex + 1) % modes.length
36|                // Keep preventing overview on each cycle
37|                GlobalStates.superReleaseMightTrigger = false
38|            }
39|        }
40|    }
41|
42|    property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
43|    property var modeList: [
44|        { id: "primary",   label: "Primary Only",   icon: "laptop_windows" },
45|        { id: "secondary", label: "Secondary Only",  icon: "connected_tv" },
46|        { id: "extend",    label: "Extend",          icon: "horizontal_split" },
47|        { id: "mirror",    label: "Mirror",           icon: "desktop_portrait" },
48|    ]
49|    readonly property int selectedModeIndex: GlobalStates.displayProjectionCycleIndex
50|
51|    // Sync cycle index to current mode (sets GlobalStates property, not local)
52|    function _syncSelectedMode() {
53|        const modes = ["primary", "secondary", "extend", "mirror"]
54|        const idx = modes.indexOf(DisplayProjection.currentMode)
55|        GlobalStates.displayProjectionCycleIndex = idx >= 0 ? idx : 2
56|    }
57|
58|    function _applySelected() {
59|        const mode = modeList[root.selectedModeIndex].id
60|        DisplayProjection.applyMode(mode)
61|        GlobalStates.displayProjectionOpen = false
62|    }
63|
64|    function _close() {
65|        GlobalStates.displayProjectionOpen = false
66|    }
67|
68|    Loader {
69|        id: osdLoader
70|        active: GlobalStates.displayProjectionOpen
71|
72|        sourceComponent: PanelWindow {
73|            id: osdRoot
74|            color: "transparent"
75|
76|            WlrLayershell.namespace: "quickshell:displayProjection"
77|            WlrLayershell.layer: WlrLayer.Overlay
78|
79|            exclusionMode: ExclusionMode.Ignore
80|            exclusiveZone: 0
81|
82|            implicitWidth: 340
83|            implicitHeight: osdContent.height
84|
85|            visible: osdLoader.active
86|
87|            // ── Auto-close timeout ──
88|            Timer {
89|                id: autoCloseTimer
90|                interval: 5000
91|                repeat: false
92|                running: true
93|                onTriggered: GlobalStates.displayProjectionOpen = false
94|            }
95|
96|            // ── Restart timer on interaction ──
97|            Connections {
98|                target: root
99|                function onSelectedModeIndexChanged() { autoCloseTimer.restart() }
100|            }
101|
102|            // ── Keyboard navigation ──
103|            Item {
104|                focus: true
105|                Keys.onPressed: (event) => {
106|                    autoCloseTimer.restart()
107|                    if (event.key === Qt.Key_Escape) {
108|                        root._close()
109|                        event.accepted = true
110|                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
111|                        root._applySelected()
112|                        event.accepted = true
113|                    } else if (event.key === Qt.Key_Up) {
114|                        GlobalStates.displayProjectionCycleIndex = (GlobalStates.displayProjectionCycleIndex - 1 + root.modeList.length) % root.modeList.length
115|                        event.accepted = true
116|                    } else if (event.key === Qt.Key_Down) {
117|                        GlobalStates.displayProjectionCycleIndex = (GlobalStates.displayProjectionCycleIndex + 1) % root.modeList.length
118|                        event.accepted = true
119|                    }
120|                }
121|                Component.onCompleted: forceActiveFocus()
122|            }
123|
124|            // ── Animated container ──
125|            Rectangle {
126|                id: osdContent
127|                width: 340
128|                height: contentColumn.implicitHeight + 32
129|                x: (osdRoot.width - width) / 2
130|                y: (osdRoot.height - height) / 2
131|                radius: Appearance.rounding.normal
132|                color: Appearance.colors.colLayer1
133|
134|                // Entrance animation
135|                scale: osdLoader.active ? 1 : 0.85
136|                opacity: osdLoader.active ? 1 : 0
137|
138|                Behavior on scale {
139|                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
140|                }
141|                Behavior on opacity {
142|                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
143|                }
144|
145|                // Shadow
146|                StyledRectangularShadow {
147|                    target: osdContent
148|                }
149|
150|                // ── Content ──
151|                ColumnLayout {
152|                    id: contentColumn
153|                    anchors.fill: parent
154|                    anchors.margins: 16
155|                    spacing: 10
156|
157|                    // Header
158|                    RowLayout {
159|                        Layout.fillWidth: true
160|                        spacing: 8
161|
162|                        MaterialSymbol {
163|                            text: "desktop_windows"
164|                            iconSize: Appearance.font.pixelSize.large
165|                            color: Appearance.colors.colOnSurface
166|                        }
167|
168|                        StyledText {
169|                            text: "Display Projection"
170|                            font.pixelSize: Appearance.font.pixelSize.normal
171|                            font.weight: Font.Medium
172|                            color: Appearance.colors.colOnSurface
173|                            Layout.fillWidth: true
174|                        }
175|
176|                        // Close button
177|                        RippleButton {
178|                            implicitWidth: 28
179|                            implicitHeight: 28
180|                            buttonRadius: height / 2
181|                            colBackground: "transparent"
182|                            colBackgroundHover: Appearance.colors.colSurfaceContainerHigh
183|                            onClicked: root._close()
184|                            contentItem: MaterialSymbol {
185|                                text: "close"
186|                                iconSize: Appearance.font.pixelSize.normal
187|                                color: Appearance.colors.colOnSurfaceVariant
188|                            }
189|                        }
190|                    }
191|
192|                    // ── Current config ──
193|                    Rectangle {
194|                        Layout.fillWidth: true
195|                        implicitHeight: configRow.implicitHeight + 12
196|                        radius: Appearance.rounding.small
197|                        color: Appearance.colors.colSurfaceContainerLow
198|
199|                        RowLayout {
200|                            id: configRow
201|                            anchors.fill: parent
202|                            anchors.margins: 6
203|                            spacing: 8
204|
205|                            StyledText {
206|                                text: "Primary:"
207|                                font.pixelSize: Appearance.font.pixelSize.smallest
208|                                color: Appearance.colors.colOnSurfaceVariant
209|                            }
210|                            StyledText {
211|                                text: DisplayProjection.primaryMonitor || "—"
212|                                font.pixelSize: Appearance.font.pixelSize.smallest
213|                                font.features: { "tnum": 1 }
214|                                color: Appearance.colors.colOnSurface
215|                            }
216|                            Item { Layout.fillWidth: true }
217|                            StyledText {
218|                                text: "External:"
219|                                font.pixelSize: Appearance.font.pixelSize.smallest
220|                                color: Appearance.colors.colOnSurfaceVariant
221|                            }
222|                            StyledText {
223|                                text: DisplayProjection.secondaryMonitor || "—"
224|                                font.pixelSize: Appearance.font.pixelSize.smallest
225|                                font.features: { "tnum": 1 }
226|                                color: Appearance.colors.colOnSurface
227|                                visible: DisplayProjection.secondaryMonitor.length > 0
228|                            }
229|                            StyledText {
230|                                text: "None"
231|                                font.pixelSize: Appearance.font.pixelSize.smallest
232|                                color: Appearance.colors.colOnSurfaceVariant
233|                                visible: DisplayProjection.secondaryMonitor.length === 0
234|                            }
235|                        }
236|                    }
237|
238|                    // ── Mode buttons ──
239|                    Repeater {
240|                        model: root.modeList
241|                        delegate: Rectangle {
242|                            required property var modelData
243|                            required property int index
244|
245|                            Layout.fillWidth: true
246|                            implicitHeight: modeRow.implicitHeight + 16
247|                            radius: Appearance.rounding.small
248|                            color: index === root.selectedModeIndex
249|                                ? Appearance.colors.colPrimary
250|                                : Appearance.colors.colSurfaceContainerLow
251|
252|                            Behavior on color {
253|                                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
254|                            }
255|
256|                            RowLayout {
257|                                id: modeRow
258|                                anchors.fill: parent
259|                                anchors.margins: 8
260|                                spacing: 10
261|
262|                                // Radio indicator
263|                                Item {
264|                                    Layout.alignment: Qt.AlignVCenter
265|                                    implicitWidth: 20
266|                                    implicitHeight: 20
267|
268|                                    Rectangle {
269|                                        anchors.centerIn: parent
270|                                        width: index === root.selectedModeIndex ? 10 : 16
271|                                        height: width
272|                                        radius: width / 2
273|                                        color: index === root.selectedModeIndex
274|                                            ? Appearance.colors.colOnPrimary
275|                                            : "transparent"
276|                                        border.width: index === root.selectedModeIndex ? 0 : 2
277|                                        border.color: Appearance.colors.colOnSurfaceVariant
278|
279|                                        Behavior on width {
280|                                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
281|                                        }
282|                                        Behavior on color {
283|                                            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
284|                                        }
285|                                    }
286|                                }
287|
288|                                MaterialSymbol {
289|                                    text: modelData.icon
290|                                    iconSize: Appearance.font.pixelSize.large
291|                                    color: index === root.selectedModeIndex
292|                                        ? Appearance.colors.colOnPrimary
293|                                        : Appearance.colors.colOnSurfaceVariant
294|
295|                                    Behavior on color {
296|                                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
297|                                    }
298|                                }
299|
300|                                StyledText {
301|                                    text: modelData.label
302|                                    font.pixelSize: Appearance.font.pixelSize.small
303|                                    font.weight: index === root.selectedModeIndex ? Font.DemiBold : Font.Normal
304|                                    color: index === root.selectedModeIndex
305|                                        ? Appearance.colors.colOnPrimary
306|                                        : Appearance.colors.colOnSurface
307|                                    Layout.fillWidth: true
308|
309|                                    Behavior on color {
310|                                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
311|                                    }
312|                                }
313|
314|                                // Check mark for current mode
315|                                MaterialSymbol {
316|                                    text: "check"
317|                                    iconSize: Appearance.font.pixelSize.normal
318|                                    color: Appearance.colors.colOnPrimary
319|                                    visible: index === root.selectedModeIndex
320|                                    opacity: visible ? 1 : 0
321|
322|                                    Behavior on opacity {
323|                                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
324|                                    }
325|                                }
326|                            }
327|
328|                            // Mouse interaction
329|                            MouseArea {
330|                                anchors.fill: parent
331|                                hoverEnabled: true
332|                                cursorShape: Qt.PointingHandCursor
333|                                onEntered: {
334|                                    autoCloseTimer.restart()
335|                                    GlobalStates.displayProjectionCycleIndex = index
336|                                }
337|                                onClicked: root._applySelected()
338|                            }
339|                        }
340|                    }
341|                }
342|            }
343|
344|            Component.onCompleted: {
345|                DisplayProjection.fetchMonitors()
346|                root._syncSelectedMode()
347|            }
348|        }
349|    }
350|
351|    Connections {
352|        target: GlobalStates
353|        function onDisplayProjectionOpenChanged() {
354|            if (GlobalStates.displayProjectionOpen) {
355|                DisplayProjection.fetchMonitors()
356|                root._syncSelectedMode()
357|            }
358|        }
359|    }
360|}
361|