1|import qs.modules.common
2|import qs.services
3|import QtQuick
4|import Quickshell
5|import Quickshell.Hyprland
6|import Quickshell.Io
7|pragma Singleton
8|pragma ComponentBehavior: Bound
9|
10|Singleton {
11|    id: root
12|    property bool barOpen: true
13|    property bool crosshairOpen: false
14|    property bool sidebarLeftOpen: false
15|    property bool sidebarRightOpen: false
16|    property bool mediaControlsOpen: false
17|    property bool osdBrightnessOpen: false
18|    property bool settingsOpen: false
19|    property bool osdVolumeOpen: false
20|    property bool oskOpen: false
21|    property bool overlayOpen: false
22|    property bool overviewOpen: false
23|    property bool regionSelectorOpen: false
24|    property bool searchOpen: false
25|    property bool screenLocked: false
26|    property bool screenLockContainsCharacters: false
27|    property bool screenUnlockFailed: false
28|    property bool screenTranslatorOpen: false
29|    property bool sessionOpen: false
30|    property bool superDown: false
31|    property bool superReleaseMightTrigger: true
32|    property bool wallpaperSelectorOpen: false
33|    property bool workspaceShowNumbers: false
34|    property string settingsPage: ""
35|    property Item currentPageInstance: null
36|    property list<real> visualizerPoints: []
37|    property bool desktopWidgetKeyboardFocus: false
38|    property bool desktopMenuOpen: false
39|    property var desktopMenuScreen: null
40|    property real desktopMenuX: 0
41|    property real desktopMenuY: 0
42|    property string wallpaperSelectorTarget: "wallpaper"
43|    property bool dropShelfOpen: false
44|    property real dropShelfX: 0
45|    property real dropShelfY: 0
46|    property bool displayProjectionOpen: false
47|    property int displayProjectionCycleIndex: 0
48|    property bool displayProjectionSuperDown: false
49|
50|    onSidebarRightOpenChanged: {
51|        if (GlobalStates.sidebarRightOpen) {
52|            Notifications.timeoutAll();
53|            Notifications.markAllRead();
54|        }
55|    }
56|
57|    GlobalShortcut {
58|        name: "workspaceNumber"
59|        description: "Hold to show workspace numbers, release to show icons"
60|
61|        onPressed: {
62|            root.superDown = true
63|        }
64|        onReleased: {
65|            root.superDown = false
67|            // If display projection OSD is open, apply selected mode and close
68|            if (GlobalStates.displayProjectionOpen) {
69|                const modes = ["primary", "secondary", "extend", "mirror"]
70|                const mode = modes[GlobalStates.displayProjectionCycleIndex] ?? "extend"
72|                DisplayProjection.applyMode(mode)
73|                GlobalStates.displayProjectionOpen = false
74|            }
75|        }
76|    }
77|
78|    IpcHandler {
79|        target: "background"
80|        function toggleCenteredWallpaper(): void {
81|            Config.options.background.centeredWallpaper = !Config.options.background.centeredWallpaper
82|        }
83|    }
84|
85|    GlobalShortcut {
86|        name: "centeredWallpaperToggle"
87|        description: "Toggles centered wallpaper"
88|        onPressed: {
89|            Config.options.background.centeredWallpaper = !Config.options.background.centeredWallpaper
90|        }
91|    }
92|}