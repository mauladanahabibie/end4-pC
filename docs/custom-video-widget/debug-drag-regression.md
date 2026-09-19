# Debug: Custom Video Drag Regression

**Date:** 2026-08-22  
**Severity:** CRITICAL — Widget cannot be moved at all  
**Status:** FOUND → FIXING

---

## Bug Description

The Custom Video widget is **completely immobile**. Users cannot drag it to reposition anywhere on the desktop.

This is a regression from the expected behavior where the widget should move using the same drag mechanism as Custom Image and other background widgets.

---

## Root Cause Analysis

### Investigation Steps

1. **Compare with Working Widgets:**
   - Examined `CustomImage.qml` (working multi-instance widget)
   - Examined `AbstractWidget.qml` (base class with drag logic)
   - Examined `AbstractBackgroundWidget.qml` (extends AbstractWidget)

2. **Found Inheritance Chain:**
   ```
   AbstractWidget extends MouseArea (has drag capability)
     ↓
   AbstractBackgroundWidget extends AbstractWidget (overrides draggable property)
     ↓
   CustomVideo.qml extends AbstractBackgroundWidget (should inherit drag)
   ```

3. **Identified Interference:**
   - `AbstractBackgroundWidget.qml` L35:
     ```qml
     draggable: placementStrategy === "free" && !Config.options.background.widgetsLocked
     ```
   - This property is properly defined in the base class
   - CustomVideo inherits this but something is **intercepting pointer events**

4. **Found Culprit:** DropArea intercepting ALL clicks/drag

### The Problem Area

**File:** `modules/ii/background/widgets/videos/CustomVideo.qml`  
**Line:** 256-277

```qml
DropArea {
    anchors.fill: parent        // ← COVERS ENTIRE WIDGET
    keys: ["text/uri-list"]
    onEntered: (drag) => {
        drag.accept(Qt.CopyAction)
        root.dropHover = true
    }
    onExited: {
        root.dropHover = false
    }
    onDropped: (drop) => {
        if (drop.hasUrls && drop.urls.length > 0) {
            var cleanPath = decodeURIComponent(drop.urls[0].toString()).replace(/^file:\/\//, "")
            // ... handles video path assignment
        }
        root.dropHover =false
    }
}
```

### Why This Breaks Drag

1. **DropArea covers entire widget** (`anchors.fill: parent`)
2. **DropArea intercepts ALL pointer events** by default
3. Parent's MouseArea (from AbstractWidget) never sees mouse press/release
4. Drag detection fails because:
   - No `pressed` event reaches MouseArea
   - No position tracking during movement
   - Cannot trigger drag animation

### Comparison with CustomImage

**CustomImage.qml structure:**
```qml
AbstractBackgroundWidget {      // ← Has drag via AbstractWidget.MouseArea
    id: root
    
    Item {                        // Container for content
        MaterialShape {           // Shape overlay
        }
        
        Image {                   // Main image
            SourceLoader {...}
        }
        
        // NO DropArea covering parent
        // Click opens file picker
    }
    
    // Explicit click handler does NOT consume all events
    onClicked: (mouse) => {
        if (mouse.button !== Qt.LeftButton) return
        // Opens picker for empty state
    }
}
```

**Key difference:** CustomImage has no full-coverage DropArea that blocks drag.

---

## Fix Strategy

### Option A: Remove DropArea Entirely (NOT recommended)
- Would lose drag-drop functionality
- User must use explicit file picker only
- Too restrictive UX

### Option B: Make DropArea Non-Interceptive (RECOMMENDED)
Change DropArea to accept drops without blocking pointer events:

```qml
DropArea {
    anchors.fill: parent
    keys: ["text/uri-list"]
    hoverEnabled: true            // ← Allow hover detection
    
    // Accept drops but don't block underlying interactions
    onEntered: (drag) => {
        drag.accept(Qt.CopyAction)
        root.dropHover = true
    }
    onExited: {
        root.dropHover = false
    }
    onDropped: (drop) => {
        // Handle drop
        root.dropHover = false
    }
    
    // CRITICAL: Allow events to pass through when not dropping
    // Use preventStealing and acceptedButtons properly
}
```

However, QML DropArea doesn't have built-in "pass-through" mode.

### Option C: Split DropArea into Hover Zone Only (BEST SOLUTION)

Remove DropArea entirely and handle drop detection differently:

1. Use **MouseArea with `onPositionChanged` check for dropped URLs**
2. OR keep DropArea but make it smaller (just for visual feedback)
3. OR wrap drop target inside the shape layer only, not over entire widget

After analysis, I'll implement **Option C variant**: Move DropArea inside the shape container (line 206-278), NOT over the entire widget. This way:
- Video output can still receive drops (visual feedback makes sense there)
- Outer widget area remains draggable via parent's MouseArea
- Hover effect stays visible on shape, not entire widget

---

## Code Changes Required

### Before (BROKEN):
```qml
MaterialShape {                    // Line 206
    id: videoShape
    anchors.fill: parent
    // ...
    
    VideoOutput {...}              // Lines218-224
    MaskMultiEffect {...}          // Lines 235-241
    
    // DropArea OVER EVERYTHING (L256-277)
    DropArea {
        anchors.fill: parent       // ← BREAKS DRAG
        // ...
    }
}
```

### After (FIXED):
```qml
MaterialShape {                    // Line206
    id: videoShape
    anchors.fill: parent
    // ...
    
    VideoOutput {...}              // Lines218-224
    MaskMultiEffect {...}          // Lines 235-241
    
    // DropArea INSIDE VIDEO SHAPE ONLY
    DropArea {
        // Still covers video shape, NOT entire widget
        // Widget outer edges remain draggable
        anchors.fill: parent
        // ...
    }
    
    // Placeholder icon OUTSIDE drop area
    MaterialSymbol {               // Lines 244-253
        // ...
    }
}

// Add separate hover indicator if needed
// But ensure it doesn't cover full widget
```

Actually, looking more carefully: DropArea needs to be inside videoShape so it only affects the video display area. The widget container itself should remain free for dragging.

Let me refine the solution...

**Better approach:** Keep DropArea at widget level BUT add `Drag.allowDrop: true` and use `onDropped` without blocking parent interaction. Actually, the real issue is that DropArea in QML always blocks underlying interactions when active.

**Final solution:** Replace DropArea with custom drag detection using a lightweight approach that doesn't intercept all events.

Wait, let me reconsider. Looking at AbstractWidget.qml structure again:

```qml
MouseArea {                          // Line 8 - ROOT OF INHERITANCE
    id: root
    drag.target: draggable ? dragProxy : undefined
    // ...
    
    // ... pointer handling ...
    
    Item {                            // Line 56 - CONTENT
        id: dragProxy
        parent: root.parent
        x: root.x
        y: root.y
        
        // THIS IS WHERE CustomVideo's visual content goes
        // If CustomVideo has its own MouseArea/DropArea here, it BLOCKS drag
    }
}
```

The correct fix is: **Make sure nothing inside dragProxy blocks the parent MouseArea's ability to detect drag.**

DropArea in QML will always capture pointer events. The solution is to either:

1. **Remove DropArea completely** and use explicit picker for all file selection (like before multi-instance was added)
2. **Use a smaller, non-full-size drop area** just for visual feedback, combined with manual explicit picker
3. **Check if DropArea has `preventStealing` or similar property to allow event propagation**

After checking QML docs: DropArea has NO built-in "pass-through" mode. It ALWAYS intercepts.

**REAL SOLUTION:** We need to handle drop detection WITHOUT DropArea. Use MouseArea with position tracking and URL detection.

Let me implement this now.

---

## Implementation Plan

### Step 1: Remove Full-Size DropArea
Delete lines 256-277 (DropArea covering entire widget).

### Step 2: Implement MouseArea-based Drop Detection
Replace with MouseArea that:
- Detects dropped files via `urls` property on mouse release
- Only activates when file types match video extensions
- Does NOT interfere with parent drag detection

Example:
```qml
MouseArea {
    anchors.fill: parent
    hoverEnabled:true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    
    // This MouseArea sits INSIDE the widget but outside the drop zone
    // So it won't block parent drag
    
    onReleased: (mouse) => {
        if (mouse.accepted) return
        // Check if any files were dropped
        // If video files, call setVideoPath()
    }
    
    // For hover feedback on drop zone, use a separate small element
}
```

Actually wait, let me check AbstractWidget implementation one more time to understand how it allows inner elements to be interactive while maintaining drag...

Looking at line 18 of AbstractWidget.qml:
```qml
acceptedButtons: Qt.LeftButton | Qt.RightButton
drag.target: draggable ? dragProxy : undefined
cursorShape: (draggable && containsPress) ? Qt.ClosedHandCursor : draggable ? Qt.OpenHandCursor : Qt.ArrowCursor
```

And line 19: cursor shape changes based on `containsPress`. This means MouseArea detects press releases.

If CustomVideo has a child MouseArea/DropArea that sets `anchors.fill: parent`, it captures ALL presses and prevents parent MouseArea from seeing them.

**Solution confirmed:** DropArea MUST NOT cover full widget. Need to make it part of inner content layer only, NOT at widget root level.

### Final Architecture

```qml
AbstractBackgroundWidget {             // Extends AbstractWidget.MouseArea
    id: root
    
    // Outer layer: handled by parent, supports drag
    
    Item {                             // Content container
        // Inner layer: video playback + drop zone
        
        MaterialShape {                 // Video mask
            VideoOutput {...}
            MaskMultiEffect {...}
            
            // DropArea HERE only covers VIDEO SHAPE, not whole widget
            // So dragging widget edges still works
            DropArea {
                anchors.fill: parent   // Covers video shape only
                // ...
            }
        }
        
        // Delete button, controls at corners
        // These shouldn't block drag either
    }
}
```

But currently, DropArea is INSIDE contentItem which is INSIDE MaterialShape, which is INSIDE AbstractBackgroundWidget...

Let me trace the exact nesting again...

From read output:
```
contentItem (line179)
└── shadowShape (line194)
└── StyledDropShadow (line201)
└── videoShape (line 206)
    ├── VideoOutput (line 218)
    ├── videoMaskShape (line 227)
    ├── MaskMultiEffect (line235)
    ├── DropArea (line 256)  ← THIS IS THE PROBLEM
    └── MaterialSymbol (line 244)
```

So DropArea is nested inside videoShape, which is inside contentItem...

But contentItem itself doesn't cover the full widget! Let me check what's between AbstractBackgroundWidget and contentItem...

Looking at lines 49-63, there are overrides for targetX/targetY, but no wrapper item. So AbstractBackgroundWidget's implicitWidth/implicitHeight come from contentItem...

AH! I see it now. The widget's actual size is `implicitWidth: contentItem.implicitWidth` (line 51-52). So contentItem defines the widget dimensions. And DropArea covers contentItem's parent, which is the widget itself.

**Confirmed:** DropArea needs to move to ONLY cover the video display area, not the full widget bounding box.

---

## Next Steps

Implement fix by:
1. Remove DropArea from current location (line 256-277)
2. Either:
   - Replace with smaller drop zone (just for visual feedback)
   - Or remove entirely and require explicit picker
3. Ensure delete button and resize handle work correctly
4. Test drag functionality after fix

Write test plan to verify fix works.
