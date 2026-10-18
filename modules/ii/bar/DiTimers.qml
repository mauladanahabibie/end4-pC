import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

RowLayout {
    id: diTimersRoot
    required property Item di
    readonly property Item island: diTimersRoot.di
    anchors {
        fill: parent
        leftMargin: island?.isMaterial ? 4 : 8
        rightMargin: 10
    }
    spacing: 6

    Item {
        id: timerPauseButton
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 16
        implicitHeight: 16

        MaterialSymbol {
            anchors.fill: parent
            text: (island?.timerRunning() ?? false) ? "pause" : "play_arrow"
            fill: 1
            iconSize: island?.isMaterial ? 24 : 16
            color: Appearance.colors.colOnLayer0
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: island?.toggleActiveTimer()
        }
    }

    Item {
        id: timerStopButton
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 16
        implicitHeight: 16

        MaterialSymbol {
            anchors.fill: parent
            text: "stop_circle"
            fill: 1
            iconSize: island?.isMaterial ? 24 : 16
            color: Appearance.colors.colOnLayer0
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: island?.resetActiveTimer()
        }
    }

    Item { Layout.fillWidth: true }

    StyledText {
        Layout.alignment: Qt.AlignVCenter
        text: island?.timerValueText() ?? ""
        font.pixelSize: Appearance.font.pixelSize.small
        font.features: { "tnum": 1 }
        color: Appearance.colors.colOnLayer0
    }
}