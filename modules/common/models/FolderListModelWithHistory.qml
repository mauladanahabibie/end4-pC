import QtQuick
import Qt.labs.folderlistmodel

FolderListModel {
    id: root
    property list<url> folderHistory: []
    property int currentFolderHistoryIndex: -1
    property bool historyNavigationLock: false

    function lockNextNavigation() {
        historyNavigationLock = true;
    }

    function pushToHistory(path) {
        if (folderHistory[currentFolderHistoryIndex] === path)
            return;
        folderHistory = folderHistory.slice(0, currentFolderHistoryIndex + 1);
        folderHistory.push(path);
        currentFolderHistoryIndex = folderHistory.length - 1;
    }

    function navigateUp() {
        root.folder = root.parentFolder;
    }

    function navigateBack() {
        if (currentFolderHistoryIndex === 0)
            return;
        currentFolderHistoryIndex--;
        lockNextNavigation();
        root.folder = folderHistory[currentFolderHistoryIndex];
    }

    function navigateForward() {
        if (currentFolderHistoryIndex >= folderHistory.length - 1) return;
        currentFolderHistoryIndex++;
        lockNextNavigation();
        root.folder = folderHistory[currentFolderHistoryIndex];
    }

    property bool refreshing: false

    function refresh() {
        if (root.refreshing) return;
        root.refreshing = true;
        const cur = root.folder;
        root.folder = "";
        Qt.callLater(() => {
            root.folder = cur;
            root.refreshing = false;
        });
    }

    onFolderChanged: {
        if (refreshing) return;
        if (historyNavigationLock) {
            historyNavigationLock = false;
            return;
        }
        pushToHistory(folder);
    }

    Component.onCompleted: {
        root.folderHistory = [root.folder]
        root.currentFolderHistoryIndex = 0
    }
}
