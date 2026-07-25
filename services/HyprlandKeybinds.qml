pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * A service that provides access to Hyprland keybinds.
 * Uses the `get_keybinds.py` script to parse comments in config files in a certain format and convert to JSON.
 *
 * Data model (tree):
 *   Each node = { name: string, children: [node], keybinds: [bind] }
 *   Each bind = { mods: [string], key: string, dispatcher: string, params: string, comment: string }
 *
 * Derived views (re-evaluate automatically when `keybinds` changes):
 *   - flatKeybinds: recursive flatten of all binds across the tree
 *   - keybindCategories: ordered list of category names from leaf-level named nodes
 *     (anonymous nodes with name="" are transparent — their named children are the categories)
 */
Singleton {
    id: root
    property string keybindParserPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/hyprland/get_keybinds.py`)
    property string defaultKeybindConfigPath: FileUtils.trimFileProtocol(`${Directories.config}/hypr/hyprland/keybinds.lua`)
    property string userKeybindConfigPath: FileUtils.trimFileProtocol(`${Directories.config}/hypr/custom/keybinds.lua`)
    property var defaultKeybinds: ({"children": []})
    property var userKeybinds: ({"children": []})
    property var keybinds: ({
        children: [
            ...(defaultKeybinds.children ?? []),
            ...(userKeybinds.children ?? []),
        ]
    })

    /**
     * Flat list of all keybinds, recursively flattened from `keybinds` tree.
     * Each entry: { mods: [string], key, dispatcher, params, comment }
     */
    property var flatKeybinds: {
        const out = [];
        const walk = (node) => {
            if (!node) return;
            if (node.keybinds) for (const b of node.keybinds) out.push(b);
            if (node.children) for (const c of node.children) walk(c);
        };
        walk(root.keybinds);
        return out;
    }

    /**
     * Ordered list of category names derived from bind comment prefixes.
     * A category is the substring before the first ":" in a bind's comment.
     * Binds without ":" are uncategorized (represented by "" — appended by the cheatsheet).
     * This matches the original end-4 cheatsheet semantics: the tree structure groups
     * binds in the config file, but the *category* is the comment prefix.
     * Anonymous tree nodes are transparent — only the comment prefix matters.
     */
    property var keybindCategories: {
        const names = [];
        const seen = new Set();
        const add = (n) => { if (!seen.has(n)) { seen.add(n); names.push(n); } };
        for (const b of root.flatKeybinds) {
            const cm = b.comment ?? "";
            const i = cm.indexOf(":");
            if (i >= 0) {
                const cat = cm.slice(0, i).trim();
                if (cat.length > 0) add(cat);
            }
        }
        return names;
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name == "configreloaded") {
                getDefaultKeybinds.running = true
                getUserKeybinds.running = true
            }
        }
    }

    Process {
        id: getDefaultKeybinds
        running: true
        command: [root.keybindParserPath, "--path", root.defaultKeybindConfigPath]

        stdout: SplitParser {
            onRead: data => {
                try {
                    root.defaultKeybinds = JSON.parse(data)
                } catch (e) {
                    console.error("[HyprlandKeybinds] Error parsing default keybinds:", e)
                }
            }
        }
    }

    Process {
        id: getUserKeybinds
        running: true
        command: [root.keybindParserPath, "--path", root.userKeybindConfigPath]

        stdout: SplitParser {
            onRead: data => {
                try {
                    root.userKeybinds = JSON.parse(data)
                } catch (e) {
                    console.error("[HyprlandKeybinds] Error parsing user keybinds:", e)
                }
            }
        }
    }
}
