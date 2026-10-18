import qs.services
import qs.modules.common
import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    property string filePath: Directories.notepadPath
    property var notes: []
    property var activeNoteId: -1
    property string searchQuery: ""
    property bool hasUnsavedChanges: false
    property bool isSaving: false

    signal notesSaved()

    Component.onCompleted: {
        noteFileView.reload();
    }

    Component.onDestruction: {
        flush();
    }

    function flush() {
        if (root.hasUnsavedChanges) {
            saveTimer.stop();
            writeToDisk();
        }
    }

    function scheduleSave() {
        root.hasUnsavedChanges = true;
        saveTimer.restart();
    }

    Timer {
        id: saveTimer
        interval: 500
        repeat: false
        onTriggered: {
            root.writeToDisk();
        }
    }

    function writeToDisk() {
        if (!noteFileView) return;
        root.isSaving = true;
        try {
            const dataStr = JSON.stringify(root.notes, null, 2);
            noteFileView.setText(dataStr);
            root.hasUnsavedChanges = false;
            root.notesSaved();
        } catch (e) {
            console.error("[NotesStore] Failed to write notes:", e);
        }
        root.isSaving = false;
    }

    function createNote(title, content) {
        root.flush();
        const now = new Date().toISOString();
        const newId = Date.now();
        const newNote = {
            "id": newId,
            "title": title && title.trim().length > 0 ? title.trim() : Translation.tr("Untitled Note"),
            "content": content ?? "",
            "createdAt": now,
            "updatedAt": now,
            "pinned": false
        };

        const updated = [newNote].concat(root.notes);
        root.notes = updated;
        root.activeNoteId = newId;
        root.scheduleSave();
        return newId;
    }

    function updateNote(id, newTitle, newContent) {
        let found = false;
        const now = new Date().toISOString();
        const updated = root.notes.map(note => {
            if (note.id === id) {
                found = true;
                return {
                    "id": note.id,
                    "title": newTitle !== undefined ? newTitle : note.title,
                    "content": newContent !== undefined ? newContent : note.content,
                    "createdAt": note.createdAt ?? now,
                    "updatedAt": now,
                    "pinned": note.pinned ?? false
                };
            }
            return note;
        });

        if (found) {
            root.notes = updated;
            root.scheduleSave();
        }
    }

    function togglePin(id) {
        root.flush();
        const updated = root.notes.map(note => {
            if (note.id === id) {
                return Object.assign({}, note, { "pinned": !note.pinned });
            }
            return note;
        });
        root.notes = updated;
        root.scheduleSave();
    }

    function deleteNote(id) {
        root.flush();
        const updated = root.notes.filter(n => n.id !== id);
        root.notes = updated;
        if (root.activeNoteId === id) {
            root.activeNoteId = -1;
        }
        root.scheduleSave();
    }

    function getNoteById(id) {
        if (id === -1) return null;
        for (let i = 0; i < root.notes.length; i++) {
            if (root.notes[i].id === id) return root.notes[i];
        }
        return null;
    }

    function filteredNotes() {
        const query = (root.searchQuery ?? "").trim().toLowerCase();
        let list = root.notes.slice();

        if (query.length > 0) {
            list = list.filter(n => {
                const t = (n.title ?? "").toLowerCase();
                const c = (n.content ?? "").toLowerCase();
                return t.includes(query) || c.includes(query);
            });
        }

        // Sort: pinned notes first, then latest updatedAt
        list.sort((a, b) => {
            if (a.pinned && !b.pinned) return -1;
            if (!a.pinned && b.pinned) return 1;
            const dateA = new Date(a.updatedAt ?? a.createdAt ?? 0).getTime();
            const dateB = new Date(b.updatedAt ?? b.createdAt ?? 0).getTime();
            return dateB - dateA;
        });

        return list;
    }

    FileView {
        id: noteFileView
        path: Qt.resolvedUrl(root.filePath)
        onLoaded: {
            const raw = noteFileView.text();
            if (!raw || raw.trim().length === 0) {
                root.initDefaultNotes();
                return;
            }
            try {
                const parsed = JSON.parse(raw);
                if (Array.isArray(parsed)) {
                    root.notes = parsed;
                } else {
                    root.initDefaultNotes();
                }
            } catch (e) {
                console.warn("[NotesStore] Error parsing JSON, using defaults:", e);
                root.initDefaultNotes();
            }
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                root.initDefaultNotes();
            } else {
                console.warn("[NotesStore] Load failed:", error);
            }
        }
    }

    function initDefaultNotes() {
        const now = new Date().toISOString();
        root.notes = [
            {
                "id": 1,
                "title": Translation.tr("Welcome to Notepad"),
                "content": Translation.tr("Welcome to your sidebar notepad!\n\n• Type notes here with auto-save\n• Search notes with the search bar\n• Use the Scratchpad tab for quick pastes\n• All notes persist across restarts"),
                "createdAt": now,
                "updatedAt": now,
                "pinned": true
            }
        ];
        root.scheduleSave();
    }
}
