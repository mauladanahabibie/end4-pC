import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "CalculatorEngine.js" as CalcEngine

Item {
    id: root

    property string expression: ""
    property string liveResult: ""
    property string errorMessage: ""
    property bool showHistory: false

    focus: true

    Component.onCompleted: {
        root.forceActiveFocus();
    }

    function append(val) {
        root.errorMessage = "";
        root.expression += val;
        updateLiveResult();
    }

    function backspace() {
        root.errorMessage = "";
        if (root.expression.length > 0) {
            root.expression = root.expression.slice(0, -1);
            updateLiveResult();
        }
    }

    function clear() {
        root.expression = "";
        root.liveResult = "";
        root.errorMessage = "";
    }

    function negate() {
        root.errorMessage = "";
        if (root.expression.length === 0) {
            root.expression = "-";
            return;
        }
        if (root.expression.startsWith("-(")) {
            root.expression = root.expression.slice(2, -1);
        } else if (root.expression.startsWith("-")) {
            root.expression = root.expression.slice(1);
        } else {
            root.expression = "-(" + root.expression + ")";
        }
        updateLiveResult();
    }

    function updateLiveResult() {
        if (root.expression.trim().length === 0) {
            root.liveResult = "";
            return;
        }
        const res = CalcEngine.evaluate(root.expression);
        if (res.success) {
            root.liveResult = String(res.result);
        }
    }

    function calculate() {
        if (root.expression.trim().length === 0) return;
        const res = CalcEngine.evaluate(root.expression);
        if (res.success) {
            historyDrawer.addEntry(root.expression, res.result);
            root.expression = String(res.result);
            root.liveResult = String(res.result);
            root.errorMessage = "";
        } else {
            root.errorMessage = res.error;
        }
    }

    Keys.onPressed: event => {
        // Digits
        if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
            root.append(event.text);
            event.accepted = true;
            return;
        }

        // Operators & punctuation
        if (event.key === Qt.Key_Plus) { root.append("+"); event.accepted = true; return; }
        if (event.key === Qt.Key_Minus) { root.append("-"); event.accepted = true; return; }
        if (event.key === Qt.Key_Asterisk) { root.append("×"); event.accepted = true; return; }
        if (event.key === Qt.Key_Slash) { root.append("÷"); event.accepted = true; return; }
        if (event.key === Qt.Key_Percent) { root.append("%"); event.accepted = true; return; }
        if (event.key === Qt.Key_ParenLeft) { root.append("("); event.accepted = true; return; }
        if (event.key === Qt.Key_ParenRight) { root.append(")"); event.accepted = true; return; }
        if (event.key === Qt.Key_Period || event.key === Qt.Key_Comma) { root.append("."); event.accepted = true; return; }

        // Actions
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Equal) {
            root.calculate();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Backspace) {
            root.backspace();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Escape) {
            if (root.showHistory) {
                root.showHistory = false;
            } else {
                root.clear();
            }
            event.accepted = true;
            return;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        // Display
        CalculatorDisplay {
            Layout.fillWidth: true
            Layout.preferredHeight: 74
            expression: root.expression
            result: root.liveResult
            errorMessage: root.errorMessage
            onHistoryToggled: {
                root.showHistory = !root.showHistory;
            }
        }

        // Keypad
        CalculatorKeypad {
            Layout.fillWidth: true
            Layout.fillHeight: true
            onButtonPressed: (action, val) => {
                root.forceActiveFocus();
                switch (action) {
                    case "append":
                        root.append(val);
                        break;
                    case "clear":
                        root.clear();
                        break;
                    case "negate":
                        root.negate();
                        break;
                    case "calculate":
                        root.calculate();
                        break;
                }
            }
        }
    }

    // History Drawer Overlay
    CalculatorHistoryDrawer {
        id: historyDrawer
        anchors.fill: parent
        z: 99
        visible: opacity > 0
        opacity: root.showHistory ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }
        onCloseRequested: root.showHistory = false
        onItemSelected: (expr, res) => {
            root.expression = expr;
            root.liveResult = res;
            root.errorMessage = "";
            root.showHistory = false;
        }
    }
}
