pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

// Notes:
// We deal with keybinds being numbered 1, 2, etc by discarding 2+, keeping 1 and replacing it with a generic "<Number>"
Column {
    id: root
    required property string categoryName
    readonly property bool isCategorized: categoryName?.length > 0
    property int maxBindWidth: 0
    property real columnSpacing: 40
    property real titleSpacing: 7

    // Excellent symbol explaination and source :
    // http://xahlee.info/comp/unicode_computing_symbols.html
    // https://www.nerdfonts.com/cheat-sheet
    property var macSymbolMap: ({
        "Ctrl": "󰘴",
        "Alt": "󰘵",
        "Shift": "󰘶",
        "Space": "󱁐",
        "Tab": "↹",
        "Equal": "󰇼",
        "Minus": "",
        "Print": "",
        "BackSpace": "󰭜",
        "Delete": "⌦",
        "Return": "󰌑",
        "Period": ".",
        "Escape": "⎋"
      })
    property var functionSymbolMap: ({
        "F1":  "󱊫",
        "F2":  "󱊬",
        "F3":  "󱊭",
        "F4":  "󱊮",
        "F5":  "󱊯",
        "F6":  "󱊰",
        "F7":  "󱊱",
        "F8":  "󱊲",
        "F9":  "󱊳",
        "F10": "󱊴",
        "F11": "󱊵",
        "F12": "󱊶",
    })

    property var mouseSymbolMap: ({
        "mouse_up": "󱕐",
        "mouse_down": "󱕑",
        "mouse:272": "L󰍽",
        "mouse:273": "R󰍽",
        "Scroll ↑/↓": "󱕒",
        "Page_↑/↓": "⇞/⇟",
    })

    property var keyBlacklist: ["SUPER_L", "SUPER_R"]
    property var keySubstitutions: Object.assign({
        "Super": "",
        "mouse_up": "Scroll ↓",    // ikr, weird
        "mouse_down": "Scroll ↑",  // trust me bro
        "mouse:272": "LMB",
        "mouse:273": "RMB",
        "mouse:275": "MouseBack",
        "Slash": "/",
        "Hash": "#",
        "Return": "Enter",
        // "Shift": "",
      },
      !!Config.options.cheatsheet.superKey ? {
          "Super": Config.options.cheatsheet.superKey,
      }: {},
      Config.options.cheatsheet.useMacSymbol ? macSymbolMap : {},
      Config.options.cheatsheet.useFnSymbol ? functionSymbolMap : {},
      Config.options.cheatsheet.useMouseSymbol ? mouseSymbolMap : {},
    )

    /**
     * Normalize parser mod strings to Title Case for keySubstitutions lookup.
     * Parser gives uppercase: ["SUPER", "SHIFT", "CTRL", "ALT", "SUPER_L", "META"]
     * Symbol maps use Title Case: "Super", "Ctrl", "Alt", "Shift"
     * SUPER_L / SUPER_R → "Super" (they're still the Super key)
     */
    function normalizeMod(mod) {
        const s = String(mod).toLowerCase();
        if (s === "super_l" || s === "super_r") return "Super";
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    /**
     * Convert the parser's mods array to an ordered list of display-ready mod strings.
     * Returns Title Case names that keySubstitutions can look up.
     */
    function modsToStringList(mods) {
        if (!mods || mods.length === 0) return [];
        const order = ["Ctrl", "Super", "Shift", "Alt", "Caps", "Mod2", "Mod3", "Mod5", "Meta"];
        const present = new Set(mods.map(m => normalizeMod(m)));
        return order.filter(m => present.has(m));
    }

    visible: repeater.model.length > 0
    spacing: titleSpacing

    StyledText {
        text: root.isCategorized ? root.categoryName : "Uncategorized"
        font.pixelSize: Appearance.font.pixelSize.title
    }

    /**
     * A bind is "displayable" if it has a non-empty comment.
     * Pseudo-binds (key starts with "bind " or "binde ") also need a comment.
     */
    function hasDescription(bind) {
        return (bind.comment ?? "").length > 0;
    }

    /**
     * Check if a bind belongs to a given category by examining the comment prefix.
     * "Utilities: Screen snip" with categoryName="Utilities" → true.
     */
    function isCategory(bind, categoryName) {
        const c = bind.comment ?? "";
        const idx = c.indexOf(":");
        if (idx < 0) return false;
        return c.substring(0, idx) === categoryName;
    }

    /**
     * Uncategorized = comment has no ":" prefix.
     */
    function isUncategorized(bind) {
        return (bind.comment ?? "").indexOf(":") === -1;
    }

    /**
     * Detect pseudo-binds: the parser stores these with key starting "bind " or "binde ".
     * These represent loop-generated binds (e.g. arrow keys, workspace numbers).
     */
    function isPseudoBind(bind) {
        const k = bind.key ?? "";
        return k.startsWith("bind ") || k.startsWith("binde ");
    }

    /**
     * Skip binds with non-first repetitive keys (e.g. "2", "3", "Right", "Down").
     * We keep "1" and "Left" as representatives and replace them with <Number>/<Direction>.
     */
    function containsNonFirstRepetitive(bind) {
        const key = extractKey(bind);
        if (key.includes("mouse") || key.includes("page")) return false;
        // Contains non-1 number
        if (/\d/.test(key) && !key.includes("1")) return true;
        // Contains non-left direction
        if (/^(right|up|down)\b/i.test(key)) return true;
        return false;
    }

    function containsFirstRepetitive(bind) {
        const key = extractKey(bind);
        return key.includes("1") || /left/i.test(key);
    }

    /**
     * Extract the actual key from a bind.
     * For pseudo-binds (key = "bind = SUPER + ←/↑/→/↓,,"), extract the key hint.
     * For normal binds, return bind.key as-is.
     */
    function extractKey(bind) {
        const k = bind.key ?? "";
        if (isPseudoBind(bind)) {
            // Pseudo-bind key format: "bind = MODS + KEY,," or "bind = MODS, KEY,,"
            // Extract the part after the last "+" or the last "," before ",,"
            const cleanKey = k.replace(/,,\s*$/, "").trim();
            // Try to get the key part after last "+" or last ","
            const parts = cleanKey.split(/[+,]/);
            const lastPart = parts[parts.length - 1].trim();
            return lastPart;
        }
        return k;
    }

    /**
     * Extract mods from a pseudo-bind key string.
     * "bind = SUPER + SHIFT, ←/↑/→/↓,," → ["SUPER", "SHIFT"]
     * "bind = SUPER, Hash,," → ["SUPER"]
     */
    function extractPseudoMods(bind) {
        const k = bind.key ?? "";
        if (!isPseudoBind(bind)) return bind.mods ?? [];
        // Remove "bind " or "binde " prefix and trailing ",,"
        const stripped = k.replace(/^(bind|binde)\s*=\s*/, "").replace(/,,\s*$/, "").trim();
        // Split by "+" and "," — everything except the last segment is mods
        const parts = stripped.split(/[+,]/).map(p => p.trim()).filter(p => p.length > 0);
        if (parts.length <= 1) return [];
        // All parts except last are mods (they should be uppercase mod names)
        const knownMods = ["SUPER", "SHIFT", "CTRL", "ALT", "META", "SUPER_L", "SUPER_R"];
        return parts.slice(0, -1).filter(p => knownMods.includes(p.toUpperCase()));
    }

    /**
     * Transform a key name for display: apply substitutions, denumber, dedirection.
     */
    function transformKey(key) {
        const replaced = root.keySubstitutions[key] || key;
        const denumbered = replaced.replace("1", "<Number>");
        const dedirectioned = denumbered.replace("Left", "<Direction>");
        return dedirectioned;
    }

    /**
     * Transform a bind's comment for display: strip category prefix, denumber, dedirection.
     */
    function transformDescription(bind, categoryName) {
        let description = bind.comment ?? "";
        if (categoryName.length > 0) {
            const regex = new RegExp("\\s*" + categoryName + "\\s*:\\s*");
            description = description.replace(regex, "");
        }
        if (!containsFirstRepetitive(bind)) return description;
        const denumbered = description.replace("1", "<Number>");
        const dedirectioned = denumbered.replace(/ \b(left|right|up|down)\b/i, " <Direction>");
        return dedirectioned;
    }

    Column {
        spacing: 4
        Repeater {
            id: repeater
            model: {
                if (!root.isCategorized) {
                    return HyprlandKeybinds.flatKeybinds.filter(bind =>
                        root.hasDescription(bind) && root.isUncategorized(bind) && !root.containsNonFirstRepetitive(bind));
                }
                return HyprlandKeybinds.flatKeybinds.filter(bind =>
                    root.hasDescription(bind) && root.isCategory(bind, root.categoryName) && !root.containsNonFirstRepetitive(bind));
            }
            delegate: BindLine {
                required property var modelData
                keyData: modelData
                categoryName: root.categoryName
            }
        }
    }

    component BindLine: Row {
        id: bindLine
        required property var keyData
        property string categoryName: ""

        // Resolve effective mods: pseudo-binds need extraction from the key field
        readonly property var effectiveMods: {
            if (root.isPseudoBind(keyData)) return root.extractPseudoMods(keyData);
            return keyData.mods ?? [];
        }
        // Resolve effective key: pseudo-binds need extraction from the key field
        readonly property string effectiveKey: root.extractKey(keyData)

        Row {
            spacing: 16
            Row {
                id: modRow
                Component.onCompleted: root.maxBindWidth = Math.max(root.maxBindWidth, implicitWidth)
                width: root.maxBindWidth
                spacing: 4
                Repeater {
                    model: {
                        const modList = root.modsToStringList(bindLine.effectiveMods).map(mod => root.keySubstitutions[mod] || mod)
                        if (modList.length == 0) return []
                        if (Config.options.cheatsheet.splitButtons) return modList;
                        return [modList.join(" ")]
                    }
                    delegate: KeyboardKey {
                        required property var modelData
                        key: root.transformKey(modelData)
                        pixelSize: Config.options.cheatsheet.fontSize.key
                    }
                }
                StyledText {
                    id: keybindPlus
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.keyBlacklist.includes(bindLine.effectiveKey) && bindLine.effectiveMods.length > 0
                    text: "+"
                }
                KeyboardKey {
                    id: keybindKey
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.keyBlacklist.includes(bindLine.effectiveKey)
                    key: root.transformKey(bindLine.effectiveKey)
                    pixelSize: Config.options.cheatsheet.fontSize.key
                    color: Appearance.colors.colOnLayer0
                }
            }
            Item {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: commentText.implicitWidth + root.columnSpacing
                implicitHeight: commentText.implicitHeight
                StyledText {
                    id: commentText
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    font.pixelSize: Config.options.cheatsheet.fontSize.comment || Appearance.font.pixelSize.smaller
                    text: root.transformDescription(bindLine.keyData, bindLine.categoryName)
                }
            }
        }
    }
}
