import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    required property var canvas
    required property var doc

    signal saveRequested()
    signal openRequested()
    signal exportRequested()

    implicitWidth: background.implicitWidth
    implicitHeight: 52

    property string openPopup: "" // "color", "stroke", "shape", "settings", or ""

    function closeAllPopups() {
        root.openPopup = "";
    }

    Rectangle {
        id: background
        anchors.fill: parent
        color: Appearance.colors.colUiBackground
        border.width: 1
        border.color: Appearance.colors.colLayer0Border
        radius: height / 2
        implicitWidth: mainRow.implicitWidth + 16

        // Prevent mouse clicks on toolbar from bleeding through to canvas
        MouseArea {
            anchors.fill: parent
            z: 0
            acceptedButtons: Qt.AllButtons
            onClicked: root.closeAllPopups()
        }

        RowLayout {
            id: mainRow
            z: 1
            anchors.centerIn: parent
            spacing: 4

            // Select Tool
            IconToolbarButton {
                text: "arrow_selector_tool"
                toggled: root.canvas.activeTool === "select"
                StyledToolTip { text: Translation.tr("Select (V)") }
                onClicked: {
                    root.closeAllPopups();
                    root.canvas.activeTool = "select";
                }
            }

            // Pan Tool
            IconToolbarButton {
                text: "pan_tool"
                toggled: root.canvas.activeTool === "pan"
                StyledToolTip { text: Translation.tr("Pan Canvas (H / Space)") }
                onClicked: {
                    root.closeAllPopups();
                    root.canvas.activeTool = "pan";
                }
            }

            // Pen Tool
            IconToolbarButton {
                text: "edit"
                toggled: root.canvas.activeTool === "pen"
                StyledToolTip { text: Translation.tr("Pen (P)") }
                onClicked: {
                    root.closeAllPopups();
                    root.canvas.activeTool = "pen";
                }
            }

            // Highlighter Tool
            IconToolbarButton {
                text: "ink_highlighter"
                toggled: root.canvas.activeTool === "highlighter"
                StyledToolTip { text: Translation.tr("Highlighter") }
                onClicked: {
                    root.closeAllPopups();
                    root.canvas.activeTool = "highlighter";
                }
            }

            // Eraser Tool
            IconToolbarButton {
                text: "ink_eraser"
                toggled: root.canvas.activeTool === "eraser"
                StyledToolTip { text: Translation.tr("Eraser (E)") }
                onClicked: {
                    root.closeAllPopups();
                    root.canvas.activeTool = "eraser";
                }
            }

            // Shapes Tool
            ToolbarButton {
                id: shapeBtn
                implicitWidth: 40
                toggled: ["line", "arrow", "rectangle", "ellipse"].includes(root.canvas.activeTool)
                colBackgroundToggled: Appearance.colors.colSecondaryContainer
                StyledToolTip { text: Translation.tr("Shapes") }

                contentItem: RowLayout {
                    anchors.centerIn: parent
                    spacing: 2
                    MaterialSymbol {
                        text: {
                            if (root.canvas.activeTool === "line") return "horizontal_rule";
                            if (root.canvas.activeTool === "arrow") return "arrow_right_alt";
                            if (root.canvas.activeTool === "ellipse") return "circle";
                            return "crop_square";
                        }
                        iconSize: 18
                        color: shapeBtn.toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurfaceVariant
                    }
                    MaterialSymbol {
                        text: "arrow_drop_down"
                        iconSize: 14
                        color: shapeBtn.toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurfaceVariant
                        opacity: 0.7
                    }
                }

                onClicked: {
                    if (root.openPopup === "shape") root.openPopup = "";
                    else root.openPopup = "shape";
                }
            }

            // Text Tool
            IconToolbarButton {
                text: "title"
                toggled: root.canvas.activeTool === "text"
                StyledToolTip { text: Translation.tr("Text (T)") }
                onClicked: {
                    root.closeAllPopups();
                    root.canvas.activeTool = "text";
                }
            }

            // Separator
            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 22
                color: Appearance.colors.colLayer0Border
                opacity: 0.6
            }

            // Color Swatch Button
            ToolbarButton {
                id: colorBtn
                implicitWidth: 36
                StyledToolTip { text: Translation.tr("Color") }

                contentItem: Item {
                    anchors.fill: parent
                    Rectangle {
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        color: root.canvas ? root.canvas.strokeColor : "#ffffff"
                        border.width: 1.5
                        border.color: "#66ffffff"
                    }
                }

                onClicked: {
                    if (root.openPopup === "color") root.openPopup = "";
                    else root.openPopup = "color";
                }
            }

            // Stroke Width Button
            ToolbarButton {
                id: strokeBtn
                implicitWidth: 36
                StyledToolTip { text: Translation.tr("Stroke Width") }

                contentItem: Item {
                    anchors.fill: parent
                    Rectangle {
                        anchors.centerIn: parent
                        width: 18
                        height: Math.max(2, Math.min(10, root.canvas.strokeWidth))
                        radius: height / 2
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                }

                onClicked: {
                    if (root.openPopup === "stroke") root.openPopup = "";
                    else root.openPopup = "stroke";
                }
            }

            // Separator
            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 22
                color: Appearance.colors.colLayer0Border
                opacity: 0.6
            }

            // Undo Button
            IconToolbarButton {
                text: "undo"
                opacity: root.doc.canUndo ? 1.0 : 0.35
                pointingHandCursor: root.doc.canUndo
                StyledToolTip { text: Translation.tr("Undo (Ctrl+Z)") }
                onClicked: {
                    root.closeAllPopups();
                    if (root.doc.canUndo) {
                        root.doc.undo();
                    }
                }
            }

            // Redo Button
            IconToolbarButton {
                text: "redo"
                opacity: root.doc.canRedo ? 1.0 : 0.35
                pointingHandCursor: root.doc.canRedo
                StyledToolTip { text: Translation.tr("Redo (Ctrl+Y)") }
                onClicked: {
                    root.closeAllPopups();
                    if (root.doc.canRedo) {
                        root.doc.redo();
                    }
                }
            }

            // Separator
            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 22
                color: Appearance.colors.colLayer0Border
                opacity: 0.6
            }

            // Zoom Out
            IconToolbarButton {
                text: "remove"
                StyledToolTip { text: Translation.tr("Zoom Out (-)") }
                onClicked: {
                    root.closeAllPopups();
                    root.canvas.zoomOut();
                }
            }

            // Zoom Percentage Display (click to reset)
            RippleButton {
                Layout.preferredWidth: 46
                Layout.fillHeight: true
                buttonRadius: 6
                colBackground: "transparent"
                StyledToolTip { text: Translation.tr("Reset Zoom (100%)") }

                contentItem: StyledText {
                    anchors.centerIn: parent
                    text: `${Math.round(root.canvas.zoom * 100)}%`
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnSurfaceVariant
                }

                onClicked: {
                    root.closeAllPopups();
                    root.canvas.resetView();
                }
            }

            // Zoom In
            IconToolbarButton {
                text: "add"
                StyledToolTip { text: Translation.tr("Zoom In (+)") }
                onClicked: {
                    root.closeAllPopups();
                    root.canvas.zoomIn();
                }
            }

            // Separator
            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 22
                color: Appearance.colors.colLayer0Border
                opacity: 0.6
            }

            // Settings / More Actions Button
            IconToolbarButton {
                id: settingsBtn
                text: "more_vert"
                toggled: root.openPopup === "settings"
                StyledToolTip { text: Translation.tr("Options & Actions") }
                onClicked: {
                    if (root.openPopup === "settings") root.openPopup = "";
                    else root.openPopup = "settings";
                }
            }
        }
    }

    // Popups Anchor Point (above the toolbar)
    Item {
        anchors.bottom: background.top
        anchors.bottomMargin: 8
        anchors.horizontalCenter: background.horizontalCenter

        // Shape Popup
        Loader {
            active: root.openPopup === "shape"
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            sourceComponent: WhiteboardShapePopup {
                selectedShape: ["line", "arrow", "rectangle", "ellipse"].includes(root.canvas.activeTool)
                    ? root.canvas.activeTool : "rectangle"
                onShapeChosen: (s) => {
                    root.canvas.activeTool = s;
                    root.closeAllPopups();
                }
            }
        }

        // Color Popup
        Loader {
            active: root.openPopup === "color"
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            sourceComponent: WhiteboardColorPopup {
                selectedColor: root.canvas.strokeColor
                onColorChosen: (c) => {
                    root.canvas.strokeColor = c;
                    root.closeAllPopups();
                }
            }
        }

        // Stroke Width Popup
        Loader {
            active: root.openPopup === "stroke"
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            sourceComponent: WhiteboardStrokePopup {
                strokeWidth: root.canvas.strokeWidth
                onWidthChosen: (w) => {
                    root.canvas.strokeWidth = w;
                }
            }
        }

        // Settings / More Actions Popup
        Loader {
            active: root.openPopup === "settings"
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            sourceComponent: WhiteboardSettingsPopup {
                gridMode: root.canvas.gridMode
                backgroundMode: root.canvas.backgroundMode
                onGridChosen: (g) => { root.canvas.gridMode = g; }
                onBackgroundChosen: (b) => { root.canvas.backgroundMode = b; }
                onNewBoardRequested: {
                    root.closeAllPopups();
                    root.doc.clearBoard(true);
                }
                onClearRequested: {
                    root.closeAllPopups();
                    root.doc.clearBoard(true);
                }
                onSaveRequested: {
                    root.closeAllPopups();
                    root.saveRequested();
                }
                onOpenRequested: {
                    root.closeAllPopups();
                    root.openRequested();
                }
                onExportRequested: {
                    root.closeAllPopups();
                    root.exportRequested();
                }
            }
        }
    }
}
