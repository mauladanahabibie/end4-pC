# Root Cause

## 1. Drag Regression

### Observed
- Custom Video widget WITHOUT video → CAN drag
- Custom Video widget WITH video → CANNOT drag

### Root cause
CustomVideo has `onPressed`/`onPositionChanged`/`onReleased` handlers at root level (lines72-117) that CustomImage does NOT have. These handlers consume pointer events, preventing AbstractWidget's built-in `drag.target: dragProxy` mechanism from activating.

Additionally, `MaskMultiEffect` (line234-240) with `visible: true` and `anchors.fill: parent` creates a full-coverage visual layer when video is present. Combined with `layer.enabled: true` on `videoOut` (line222) and `videoMaskShape` (line231), this creates offscreen render surfaces that may interfere with pointer delivery.

CustomImage uses `StyledImage` (plain Image) which does NOT block pointer events, and has NO root-level onPressed/onReleased handlers.

### Evidence
- `AbstractWidget.qml` line8: `MouseArea` with `drag.target: draggable ? dragProxy : undefined` (line18)
- `AbstractWidget.qml` line17: `acceptedButtons: Qt.LeftButton | Qt.RightButton`
- `CustomVideo.qml` lines72-117: `onPressed`, `onPositionChanged`, `onReleased` handlers
- `CustomImage.qml`: NO `onPressed`, `onPositionChanged`, or `onReleased` at root level
- `CustomVideo.qml` line234: `MaskMultiEffect { anchors.fill: parent; visible: root.videoPath !== "" && root.videoValid }`
- `CustomImage.qml` line148: `StyledImage { anchors.fill: parent; visible: root.imagePath !== "" }` (Image, not Effect)

### Affected file
`modules/ii/background/widgets/videos/CustomVideo.qml`

### Minimal fix
1. Remove `onPressed`, `onPositionChanged`, `onReleased` handlers at root level (lines72-117). Let AbstractWidget handle drag natively.
2. Move click-to-fullscreen and click-to-picker logic into a child MouseArea that does NOT block drag — use `propagateComposedEvents: true` and only act on genuine clicks (no drag).
3. OR: simpler — remove root-level handlers entirely, add a transparent MouseArea inside contentItem with `propagateComposedEvents: true` that only handles clicks, letting drag pass through to parent.

##2. Empty Picker

### Observed
Clicking empty Custom Video widget does NOT open picker (or if it opens, selected video never loads).

### Root cause
`Quickshell.execDetached()` (line111) is fire-and-forget. The picker script's stdout (selected path) is NOT captured. The selected path is lost.

### Evidence
- `CustomVideo.qml` line111: `Quickshell.execDetached(["python3", `${Directories.scriptPath}/pick-video.py`])`
- `scripts/pick-video.py` line24: `print(json.dumps({"path": file_path}))` — outputs to stdout
- `execDetached` does NOT capture stdout
- Compare: `DesktopMenu.qml` line74-111 uses `Process` with `SplitParser` to capture stdout
- `scripts/images/pick-video.py` (working) outputs plain path string; `scripts/pick-video.py` (broken) outputs JSON

### Affected file
- `modules/ii/background/widgets/videos/CustomVideo.qml` (line111)
- `scripts/pick-video.py` (wrong output format, not captured)

### Minimal fix
Replace `Quickshell.execDetached()` with a `Process` + `SplitParser` that captures stdout. Use existing `scripts/images/pick-video.py` (zenity-based, plain path output). Call `root.setVideoPath(path)` in `onRead`.

##3. Instance Collision

### Observed
Toggle ON → instance A appears. Add Custom Video → A disappears, B appears. Expected: A + B.

### Root cause
The legacy single instance (videoIndex=-1) is hidden when the videos array becomes non-empty.

### Evidence
- `Background.qml` line538-539: `shown: ... && Config.options.background.widgets.customVideo.videos.length ===0`
- Toggle creates legacy instance (videoIndex=-1) using `customVideo.path`
- Add Custom Video appends to `customVideo.videos` array
- When `videos.length >0`, legacy FadeLoader condition fails → legacy instance hidden
- Array Repeater (line555-572) shows array instances instead

### Affected file
`modules/ii/background/Background.qml` (line539)

### Minimal fix
Change legacy FadeLoader condition to keep showing the legacy instance when it has its own path:
```qml
shown: Config.options.background.widgets.customVideo.enable
    && (Config.options.background.widgets.customVideo.videos.length ===0
         || Config.options.background.widgets.customVideo.path !== "")
```
This preserves the toggle instance even when array instances exist.
