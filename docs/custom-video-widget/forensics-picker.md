# Forensics: Empty Widget Picker (BUG B)

## Observed
Clicking empty Custom Video widget does NOT open file picker.

## Click Path Trace

```
Empty widget
    ↓
User left-clicks
    ↓
AbstractWidget (MouseArea) receives press
    ↓
CustomVideo.onPressed (line72) fires — records pressX/pressY
    ↓
User releases (no drag)
    ↓
CustomVideo.onReleased (line87) fires
    ↓
wasDragging = false (no drag detected)
    ↓
Checks: root.videoPath === "" || !root.videoValid → TRUE
    ↓
Calls: Quickshell.execDetached(["python3", `${Directories.scriptPath}/pick-video.py`])
    ↓
Executes: scripts/pick-video.py (PyQt6 QFileDialog)
    ↓
User selects video
    ↓
pick-video.py prints JSON: {"path": "/selected/video.mp4"}
    ↓
??? WHO RECEIVES THIS OUTPUT ???
```

## Root Cause

**The picker script's output goes NOWHERE. There is no path-return mechanism.**

Evidence:
1. `CustomVideo.qml` line111: `Quickshell.execDetached(["python3", `${Directories.scriptPath}/pick-video.py`])`
   - `execDetached` = fire-and-forget. stdout is NOT captured.
   - The script's JSON output is lost.

2. `scripts/pick-video.py` (line24): `print(json.dumps({"path": file_path}))`
   - Outputs JSON to stdout. But nobody reads it.

3. Compare with DesktopMenu's picker (`DesktopMenu.qml` line74-111):
   ```qml
   Process {
       id: desktopMenuVideoPickerProc
       stdout: SplitParser {
           onRead: data => {
               // APPENDS to videos array
               Config.options.background.widgets.customVideo.videos = list
           }
       }
   }
   ```
   - Uses `Process` with `StdioCollector`/`SplitParser` to capture stdout
   - The selected path IS received and persisted

4. Compare with `scripts/images/pick-video.py` (the script DesktopMenu actually calls):
   - Uses zenity/kdialog, outputs plain path string to stdout
   - DesktopMenu's `SplitParser.onRead` receives it

5. `scripts/pick-video.py` (the one CustomVideo calls) outputs JSON `{"path": "..."}`.
   - Even if stdout were captured, the JSON format doesn't match what SplitParser expects (plain path string).

## Exact Break Point
- **File:** `modules/ii/background/widgets/videos/CustomVideo.qml`
- **Line:**111
- **Problem:** `Quickshell.execDetached()` does not capture stdout. The selected path is lost.

## Secondary Issue
- **File:** `scripts/pick-video.py`
- **Problem:** Outputs JSON format `{"path": "..."}` instead of plain path string
- The working `scripts/images/pick-video.py` outputs plain path string

## Instance State at Click Time
- `videoIndex = -1` (legacy single mode) or `videoIndex >=0` (array mode)
- `videoPath = ""` (empty)
- `videoValid = false`
- The widget exists and is rendered (FadeLoader shown when `enable=true && videos.length===0`)

## Recommended Minimal Fix
Replace `Quickshell.execDetached()` with a `Process` that captures stdout via `SplitParser`, then call `root.setVideoPath(path)` in the `onRead` handler. Use the existing `scripts/images/pick-video.py` (zenity-based, outputs plain path) instead of the broken `scripts/pick-video.py` (PyQt6, outputs JSON).

Pattern to follow (from DesktopMenu.qml lines74-111):
```qml
Process {
    id: videoPickerProc
    stdout: SplitParser {
        onRead: data => {
            if (data.trim().length >0) {
                root.setVideoPath(data.trim())
            }
        }
    }
}
```
Then in onReleased: `videoPickerProc.command = ["python3", `${Directories.scriptPath}/images/pick-video.py`]; videoPickerProc.running = true`
