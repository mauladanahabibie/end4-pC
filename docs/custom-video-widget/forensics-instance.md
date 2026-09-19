# Forensics: Instance Collision (BUG C)

## Observed
1. Enable Custom Video toggle → instance A appears
2. Add Custom Video → A disappears, B appears
3. Expected: A + B

## Toggle State Path (PATH A)

```
Settings toggle ON
    ↓
Config.options.background.widgets.customVideo.enable = true
    ↓
Background.qml line537-549: FadeLoader shown when:
    enable ===true
    AND videos.length ===0
    ↓
CustomVideo { videoIndex: -1 }  ← LEGACY SINGLE INSTANCE
    ↓
Renders using Config.options.background.widgets.customVideo.path
```

## Dynamic Array Path (PATH B)

```
Desktop Menu → "Add Custom Video"
    ↓
DesktopMenu.qml line358-366:
    Config.options.background.widgets.customVideo.enable = true
    desktopMenuVideoPickerProc.command = ["python3", ".../images/pick-video.py"]
    desktopMenuVideoPickerProc.running = true
    ↓
User selects video
    ↓
DesktopMenu.qml line76-108: SplitParser.onRead
    Rebuilds videos array, APPENDS new entry
    Config.options.background.widgets.customVideo.videos = list
    ↓
Background.qml line555-572: Repeater model = videos.length
    ↓
CustomVideo { videoIndex: index }  ← ARRAY INSTANCE
```

## Root Cause

**The legacy single instance (videoIndex=-1) is hidden when the videos array becomes non-empty.**

Evidence:
- `Background.qml` line538-539:
  ```qml
  shown: Config.options.background.widgets.customVideo.enable
      && Config.options.background.widgets.customVideo.videos.length ===0
  ```
- When `videos.length === 0`: legacy instance IS shown (videoIndex=-1)
- When `videos.length >0`: legacy instance is NOT shown (condition fails)
- The Repeater (line555-572) shows array instances (videoIndex=0,1,2...)

**The toggle creates the LEGACY instance (videoIndex=-1).**
**Add Custom Video creates an ARRAY instance (videoIndex=0).**
**When the array becomes non-empty, the legacy instance's FadeLoader hides.**

So:
1. Toggle ON → `enable=true`, `videos=[]` → legacy instance shown (A)
2. Add Custom Video → `videos=[{path:...}]` → legacy instance hidden (A gone), array instance shown (B)

This is BY DESIGN in the current loader. The legacy instance and array instances are mutually exclusive.

## Exact Mutation
- **File:** `modules/ii/background/Background.qml`
- **Line:**539
- **Property:** `Config.options.background.widgets.customVideo.videos.length ===0`
- **Effect:** When videos array becomes non-empty, the condition evaluates to false, hiding the legacy instance.

## Instance ID Mechanism
- Legacy instance: `videoIndex =-1` (reads from `Config.options.background.widgets.customVideo` directly)
- Array instances: `videoIndex =0,1, 2...` (reads from `Config.options.background.widgets.customVideo.videos[videoIndex]`)

Both use the same `configEntryName: "customVideo"` and the same config entry. The legacy instance uses the top-level `path` property; array instances use `videos[i].path`.

## Why This Is Wrong
The toggle instance (A) uses `Config.options.background.widgets.customVideo.path` as its video path.
When Add Custom Video appends to the `videos` array, it does NOT touch `customVideo.path`.
But the loader HIDES the legacy instance when `videos.length > 0`.

So A's data still exists in config (`customVideo.path`), but A is not rendered because the FadeLoader condition requires `videos.length ===0`.

## Recommended Architecture-Preserving Fix
**Option 1 (minimal):** Change the legacy FadeLoader condition to also show when the legacy instance has a path:
```qml
shown: Config.options.background.widgets.customVideo.enable
    && (Config.options.background.widgets.customVideo.videos.length ===0
         || Config.options.background.widgets.customVideo.path !== "")
```
This keeps the legacy instance visible even when array instances exist, as long as it has its own path.

**Option 2 (cleaner):** When Add Custom Video is clicked, if the legacy instance has a path, migrate it to the array first (push it as videos[0]), then append the new entry. This unifies all instances under the array model. But this changes the toggle's behavior.

**Recommended:** Option1. It's minimal, preserves the toggle instance, and doesn't change the array model.
