# Productivity Tools Integration: Implementation Plan

## 1. Objectives

Integrate a unified suite of productivity tools inside the existing Quickshell sidebar:
1. **Notepad**: Multi-note document manager with persistent storage, full search, multiline editor, and integrated Quick Notes / Scratchpad.
2. **Calculator**: Safe arithmetic expression evaluator (Dijkstra Shunting-Yard, zero eval()), clean keypad, keyboard support, and history.
3. **Unit Converter**: Category-based unit conversion (Length, Mass, Temperature, Time, Data, Speed) with swapping and instant copy.
4. **Cohesive Navigation**: Seamlessly extended navigation rail in `BottomWidgetGroup.qml` alongside Calendar, To Do, and Timer.

---

## 2. Directory & Component Structure

```
modules/ii/sidebarRight/
├── BottomWidgetGroup.qml              [EXTENDED: 6 tabs + compact nav rail]
├── calendar/                          [PRESERVED]
├── todo/                              [PRESERVED]
├── pomodoro/                          [PRESERVED]
│
├── notepad/                           [NEW MODULE]
│   ├── NotepadWidget.qml              (Main widget with SecondaryTabBar: Notes vs Scratchpad)
│   ├── NotesStore.qml                 (Data store, FileView to notepad.json, CRUD, search)
│   ├── NoteListView.qml               (List of notes, search bar, + FAB button)
│   ├── NoteEditorView.qml             (Title editing, multiline text, word count, back button)
│   └── ScratchpadView.qml             (Instant scratchpad synced to ~/.local/state/quickshell/user/notes.txt)
│
├── calculator/                        [NEW MODULE]
│   ├── CalculatorEngine.js            (Pure JS Shunting-Yard & RPN safe math evaluator)
│   ├── CalculatorWidget.qml           (Display, keypad, history toggle, keyboard handling)
│   ├── CalculatorDisplay.qml          (Expression input line, result preview line, error state)
│   ├── CalculatorKeypad.qml           (Grid of styled operator and numeric buttons)
│   └── CalculatorHistoryDrawer.qml    (List of previous calculations with tap-to-reuse)
│
└── converter/                         [NEW MODULE]
    ├── ConverterEngine.js             (Formulas, unit definitions, and conversion functions)
    ├── ConverterWidget.qml            (Category selector, from/to units, live conversion, swap)
    └── UnitSelector.qml               (Pill or dropdown selector styled to rice theme)
```

---

## 3. Detailed Component Designs

### 3.1 BottomWidgetGroup Navigation Extension
- Extend `tabs` array in `BottomWidgetGroup.qml`:
  - `calendar` -> `calendar/CalendarWidget.qml` (icon: `calendar_month`)
  - `todo` -> `todo/TodoWidget.qml` (icon: `done_outline`)
  - `timer` -> `pomodoro/PomodoroWidget.qml` (icon: `schedule`)
  - `notepad` -> `notepad/NotepadWidget.qml` (icon: `edit_note`)
  - `calculator` -> `calculator/CalculatorWidget.qml` (icon: `calculate`)
  - `converter` -> `converter/ConverterWidget.qml` (icon: `sync_alt`)
- Adjust `NavigationRailButton`:
  - Set `baseSize: 46` and `baseHighlightHeight: 30` when tabs count > 3, ensuring all 6 buttons consume only 276px total, fitting inside the 350px container with clear breathing room.
- Update `Directories.qml`:
  - Add `property string notepadPath: FileUtils.trimFileProtocol('${Directories.state}/user/notepad.json')`.
  - Add `property string calculatorHistoryPath: FileUtils.trimFileProtocol('${Directories.state}/user/calculator_history.json')`.

### 3.2 Notepad Module (`modules/ii/sidebarRight/notepad/`)
- **NotesStore.qml**:
  - `property var notes: []`
  - `property int activeNoteId: -1`
  - Methods: `createNote()`, `updateNote(id, title, content)`, `deleteNote(id)`, `searchNotes(query)`.
  - Storage: `FileView` bound to `Directories.notepadPath`.
  - Debounced auto-save timer (500ms) with immediate `flush()` on note switch or destruction.
- **NotepadWidget.qml**:
  - Top bar: `SecondaryTabBar` with two tabs:
    - Tab 0: "Notes" (Multi-note notebook)
    - Tab 1: "Scratchpad" (Quick note synced directly to `Directories.notesPath`)
  - In Notes mode:
    - When `activeNoteId === -1`: Shows `NoteListView` (Search bar, list of notes with titles, snippet, date, and FloatingActionButton `+` to create note).
    - When `activeNoteId !== -1`: Shows `NoteEditorView` (Back arrow `arrow_back`, editable title field, multiline text editor inside `StyledFlickable`, delete button `delete` with confirmation, word/character count).
- **ScratchpadView.qml**:
  - Direct multiline text editor bound to `Directories.notesPath`, with copy button and bullet point support.

### 3.3 Calculator Module (`modules/ii/sidebarRight/calculator/`)
- **CalculatorEngine.js**:
  - Tokenizer: Regex/scanner for floats, negative numbers, operators (`+`, `-`, `*`, `/`, `%`), parentheses (`(`, `)`).
  - Shunting-Yard Parser: Infix to Postfix RPN.
  - Evaluator: Stack-based RPN evaluation.
  - Zero `eval()`, zero `Function()`, zero shell commands.
  - Error protection: Division by zero returns `{ success: false, error: "Division by zero" }`.
  - Syntax check: Mismatched parentheses or dangling operators return `{ success: false, error: "Invalid syntax" }`.
- **CalculatorWidget.qml**:
  - Display area:
    - Active expression text with horizontal scrolling if long.
    - Live result preview in secondary color while typing.
    - Primary result display upon pressing `=` or Enter.
    - Copy result button with feedback tooltip.
  - Keypad area:
    - Row 1: `C` / `AC`, `(`, `)`, `÷`
    - Row 2: `7`, `8`, `9`, `×`
    - Row 3: `4`, `5`, `6`, `-`
    - Row 4: `1`, `2`, `3`, `+`
    - Row 5: `±` (negate), `0`, `.`, `=`
  - History drawer:
    - Toggleable panel showing recent calculations with timestamp/expression/result.
    - Clicking any item recalls the result or expression into the display.
  - Keyboard focus:
    - `Keys.onPressed` handles digits `0-9`, `.`, operators `+`, `-`, `*`, `/`, `%`, `(`, `)`, Enter (`=`), Backspace, and Escape (`C`).

### 3.4 Unit Converter Module (`modules/ii/sidebarRight/converter/`)
- **ConverterEngine.js**:
  - Definitions of categories, units, and conversion formulas.
  - Linear conversions use base-unit factor ($V_{\text{target}} = V_{\text{source}} \times F_{\text{source}} / F_{\text{target}}$).
  - Temperature conversions use exact formulas for Celsius, Fahrenheit, and Kelvin.
- **ConverterWidget.qml**:
  - Category selector: Pill/tab bar for Length, Mass, Temp, Time, Data, Speed.
  - From & To selection rows: `StyledComboBox` with unit names and symbols.
  - Swap button (`swap_vert` / `swap_horiz`) to quickly flip source and target units.
  - Input field: `StyledTextInput` with numeric validator and clear button.
  - Converted output card: Large readable result with unit symbol and one-click copy button.

---

## 4. Phased Implementation Roadmap

- **Phase A**: Audit, Research, and Plan Documentation (Current)
- **Phase B**: BottomWidgetGroup Navigation Expansion & Layout Tuning
- **Phase C**: Notepad Implementation (Multi-note store, editor, search, scratchpad)
- **Phase D**: Calculator Implementation (Shunting-Yard engine, keypad, keyboard, history)
- **Phase E**: Unit Converter Implementation (Categories, formulas, swapping)
- **Phase F**: Runtime Verification, Visual Polish & Documentation Update
