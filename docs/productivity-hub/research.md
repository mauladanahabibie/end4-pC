# Productivity Tools Integration: Architecture & System Audit

## 1. Executive Summary

This document audits the existing Quickshell desktop rice sidebar architecture in order to cleanly integrate additional productivity tools:
1. **Notepad** (with multiple notes, search, multiline editing, debounced auto-save, and integrated Quick Notes / Scratchpad syncing to `notes.txt`)
2. **Calculator** (with safe Dijkstra Shunting-Yard arithmetic evaluation, operator precedence, parentheses, decimal/negative support, division-by-zero protection, keyboard input, and calculation history)
3. **Unit Converter** (with Length, Mass, Temperature, Time, Data Storage, Speed, correct formulas, unit swapping, and instant copying)

All tools integrate into the existing **BottomWidgetGroup** productivity hub alongside **Calendar**, **To Do**, and **Timer**, preserving existing functionality, theme styling, and persistence.

---

## 2. Existing Sidebar Architecture & Navigation

### 2.1 Component Hierarchy
```
SidebarRight.qml (Layer-shell PanelWindow, exclusiveZone: 0, keyboardFocus: OnDemand)
 └── SidebarRightContent.qml (ReorderableColumn with fillKey: "notifications")
      ├── bannerSection (Quick summary & user profile)
      ├── quickTogglesSection (Classic/Android toggles & dialog triggers)
      ├── slidersSection (Volume, Mic, Brightness)
      ├── mediaSection (MPRIS Player with visualizer)
      ├── notificationsSection (CenterWidgetGroup, flexible height)
      └── bottomSection -> BottomWidgetGroup.qml (Productivity Hub)
```

### 2.2 BottomWidgetGroup.qml
Located at `modules/ii/sidebarRight/BottomWidgetGroup.qml`:
- Container: Rounded rectangle with `Appearance.colors.colLayer1`, `radius: Appearance.rounding.normal`, `implicitHeight: collapsed ? collapsedHeight : 350`.
- Collapse state: Controlled by `Persistent.states.sidebar.bottomGroup.collapsed`.
- Selected tab: Controlled by `Persistent.states.sidebar.bottomGroup.tab`.
- Layout:
  - Left: Navigation rail with `CalendarHeaderButton` (collapse toggle) and `NavigationRailTabArray` hosting `NavigationRailButton` items.
  - Right: Content area hosting a `Loader` with smooth fade/slide `TabSwitchAnim`.
- Existing Tabs:
  1. `calendar` -> `calendar/CalendarWidget.qml`
  2. `todo` -> `todo/TodoWidget.qml`
  3. `timer` -> `pomodoro/PomodoroWidget.qml`

### 2.3 Navigation Rail Sizing & Adaptability
- `NavigationRailButton` has a default `baseSize: 56` and `baseHighlightHeight: 32`.
- `NavigationRailTabArray` reads `children[0]?.baseSize` to determine vertical step and pill positioning.
- When extending from 3 tabs to 6 tabs (Calendar, To Do, Timer, Notes, Calculator, Converter):
  - Setting `baseSize: 46` ensures 6 tabs consume only $6 \times 46 = 276\,\text{px}$, fitting cleanly within the 350px height container without crowding or overlapping the collapse button.

---

## 3. Existing Productivity Widgets Audit

### 3.1 Todo (`TodoWidget.qml` & `services/Todo.qml`)
- Tab bar: `SecondaryTabBar` with `SecondaryTabButton` ("Unfinished" and "Done").
- Content: `SwipeView` hosting `TaskList` with `StyledListView` and `ScriptModel`.
- Persistence: Handled via `FileView` from `Quickshell.Io` writing JSON to `Directories.todoPath` (`~/.local/state/quickshell/user/todo.json`).
- Adding: `FloatingActionButton` with an animated popup overlay.
- Keyboard: `PageUp`/`PageDown` tab cycling, `N` to open add dialog, `Escape` to close.

### 3.2 Pomodoro & Stopwatch (`PomodoroWidget.qml`)
- Tab bar: `SecondaryTabBar` with `SecondaryTabButton` ("Pomodoro" and "Stopwatch").
- Content: `SwipeView` with interactive countdown and lap timers.
- Keyboard: `Space`/`S` (play/pause), `R` (reset), `L` (record lap).

### 3.3 Quick Notes (`modules/ii/overlay/notes/NotesContent.qml`)
- Defined in overlay system reading/writing raw text to `Directories.notesPath` (`~/.local/state/quickshell/user/notes.txt`).
- Features debounced autosave and bullet point extraction.

---

## 4. Design System, Theme Tokens & Reusable Controls

### 4.1 Theme Tokens (`Appearance.qml`)
- Colors:
  - `Appearance.colors.colLayer1`: Primary widget container background.
  - `Appearance.colors.colLayer2`: Card / list item / input field background.
  - `Appearance.colors.colLayer2Active` / `colLayer2Hover`: Interaction feedback.
  - `Appearance.colors.colPrimary`: Accent / active highlight color.
  - `Appearance.colors.colOnPrimary`: Text on primary accent.
  - `Appearance.colors.colOnLayer1`: Text on Layer 1.
  - `Appearance.colors.colSecondaryContainer`: Pill highlight background.
  - `Appearance.colors.colOnSecondaryContainer`: Active icon/text color.
  - `Appearance.colors.colError` & `colOnError`: Error states / delete warnings.
- Rounding:
  - `Appearance.rounding.normal`: 16-24px for major cards.
  - `Appearance.rounding.small`: 8-12px for items and buttons.
  - `Appearance.rounding.full`: 9999px for pills and FABs.
- Typography:
  - `Appearance.font.family.main`, `pixelSize.small`, `pixelSize.normal`, `pixelSize.large`.

### 4.2 Available Reusable Widgets
- Inputs: `StyledTextInput.qml`, `StyledTextArea.qml`, `MaterialTextField.qml`.
- Tabs: `SecondaryTabBar.qml`, `SecondaryTabButton.qml`.
- Buttons: `RippleButton.qml`, `FloatingActionButton.qml`, `IconToolbarButton.qml`.
- Lists & Scrolling: `StyledListView.qml`, `StyledFlickable.qml`, `ScrollEdgeFade.qml`.
- Icons: `MaterialSymbol.qml` (Material Symbols font).
- Feedback: `StyledToolTip.qml`, `PointingHandInteraction.qml`.

---

## 5. Storage & Persistence Analysis

- Path conventions in `Directories.qml`:
  - `Directories.state`: `StandardPaths.standardLocations(StandardPaths.StateLocation)[0]` -> `~/.local/state/quickshell`.
  - Stored files:
    - Todo: `~/.local/state/quickshell/user/todo.json`.
    - Active Whiteboard: `~/.local/state/quickshell/user/whiteboard/active.json`.
    - Quick Notes: `~/.local/state/quickshell/user/notes.txt`.
- Proposed storage paths:
  - Multi-note Notepad: `~/.local/state/quickshell/user/notepad.json`.
  - Calculator History: `~/.local/state/quickshell/user/calculator_history.json`.
  - Converter Preferences: `~/.local/state/quickshell/user/converter_prefs.json` (or in-memory with last category).
- Persistence Engine:
  - Use `Quickshell.Io.FileView` with atomic/clean JSON write, debounced timers, and safe JSON parsing with try/catch fallback.

---

## 6. Safe Math Expression Evaluation

### 6.1 Security & Robustness Constraints
- **CRITICAL**: The user prompt explicitly forbids `eval()`, `Function()`, shell commands, or arbitrary JS code execution.
- Naive string replacement is inadequate for parentheses and operator precedence.

### 6.2 Chosen Algorithm: Shunting-Yard Parser & RPN Evaluator
- **Tokenization**:
  - Regular expression or character scanner extracting numbers (including floats like `3.14`, negative values like `-5` after operators), operators (`+`, `-`, `*`, `×`, `/`, `÷`, `%`), and parentheses (`(`, `)`).
- **Shunting-Yard Algorithm**:
  - Converts infix notation to postfix (Reverse Polish Notation - RPN) using an operator stack and output queue.
  - Handles operator precedence (`*`, `/`, `%` have precedence 2; `+`, `-` have precedence 1).
  - Handles left-associativity and nested parentheses.
- **RPN Evaluation**:
  - Evaluates postfix tokens using an operand stack.
  - Division by zero: Explicit check if denominator is `0` (or `abs(d) < 1e-15`), returning a structured error `{ success: false, error: "Cannot divide by zero" }`.
  - Malformed expressions: Unbalanced parentheses, consecutive invalid operators, or empty expressions return `{ success: false, error: "Invalid expression" }`.
- **Pure JavaScript implementation**:
  - Self-contained in `CalculatorEngine.js` with zero external dependencies, verifiable with unit tests.

---

## 7. Unit Converter Formulas & Specifications

- **Length**:
  - Base unit: Meter (m).
  - Units: mm ($10^{-3}$), cm ($10^{-2}$), m ($1$), km ($10^3$), in ($0.0254$), ft ($0.3048$), yd ($0.9144$), mi ($1609.344$).
- **Mass / Weight**:
  - Base unit: Gram (g).
  - Units: mg ($10^{-3}$), g ($1$), kg ($10^3$), t ($10^6$), oz ($28.349523125$), lb ($453.59237$).
- **Temperature**:
  - Non-linear conversions:
    - Celsius to Fahrenheit: $F = C \times \frac{9}{5} + 32$
    - Fahrenheit to Celsius: $C = (F - 32) \times \frac{5}{9}$
    - Celsius to Kelvin: $K = C + 273.15$
    - Kelvin to Celsius: $C = K - 273.15$
    - Fahrenheit to Kelvin: $K = (F - 32) \times \frac{5}{9} + 273.15$
    - Kelvin to Fahrenheit: $F = (K - 273.15) \times \frac{9}{5} + 32$
- **Time**:
  - Base unit: Second (s).
  - Units: ms ($0.001$), s ($1$), min ($60$), h ($3600$), d ($86400$), wk ($604800$).
- **Data Storage**:
  - Base unit: Byte (B).
  - Units: B ($1$), KB ($10^3$), MB ($10^6$), GB ($10^9$), TB ($10^{12}$), KiB ($1024$), MiB ($1024^2$), GiB ($1024^3$), TiB ($1024^4$).
- **Speed**:
  - Base unit: m/s.
  - Units: m/s ($1$), km/h ($\frac{1}{3.6}$), mph ($0.44704$), knots ($0.514444$).
