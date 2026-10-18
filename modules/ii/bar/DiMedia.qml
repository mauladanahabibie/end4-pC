import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: diMediaRoot
    required property Item di
    readonly property Item island: diMediaRoot.di
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool isMaterial: island?.isMaterial ?? false
    readonly property real pillHeight: island?.pillHeight ?? 32
    anchors.fill: parent

    WheelHandler {
        target: diMediaRoot
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            if (event.angleDelta.y > 0) {
                Audio.incrementVolume()
            } else if (event.angleDelta.y < 0) {
                Audio.decrementVolume()
            }
        }
    }

    // Main interaction: clicking anywhere on the media card opens the detailed media controls popup
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            GlobalStates.mediaControlsPosition = "center"
            GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen
        }
    }

    // 1. Album Artwork
    Rectangle {
        id: artContainer
        width: isMaterial ? pillHeight : pillHeight - 8
        height: width
        anchors {
            left: parent.left
            leftMargin: isMaterial ? 0 : 4
            verticalCenter: parent.verticalCenter
        }
        radius: isMaterial ? Appearance.rounding.full : (Appearance.rounding?.verysmall ?? 6)
        color: Appearance.colors.colLayer1
        clip: true

        StyledImage {
            id: artImage
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            source: {
                const url = activePlayer?.trackArtUrl ?? ""
                if (!url) return ""
                if (url.startsWith("/")) return "file://" + url
                return url
            }
            sourceSize.width: artContainer.width * 2
            sourceSize.height: artContainer.height * 2
            visible: status === Image.Ready && (activePlayer?.trackArtUrl ?? "") !== ""
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: "music_note"
            iconSize: 14
            color: Appearance.colors.colOnLayer1
            visible: !artImage.visible
        }
    }

    // 2. Track Title & Artist (Always visible during active playback)
    ColumnLayout {
        id: trackInfoColumn
        anchors {
            left: artContainer.right
            leftMargin: 8
            right: mediaControlsRow.left
            rightMargin: 8
            verticalCenter: parent.verticalCenter
        }
        spacing: 1

        StyledText {
            Layout.fillWidth: true
            text: (activePlayer?.trackTitle ?? "").replace(/[\r\n]+/g, " ") || Translation.tr("Unknown Title")
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
            maximumLineCount: 1
        }

        StyledText {
            Layout.fillWidth: true
            visible: (activePlayer?.trackArtist ?? "").trim() !== ""
            text: (activePlayer?.trackArtist ?? "").replace(/[\r\n]+/g, " ")
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colOnLayer0
            opacity: 0.75
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
            maximumLineCount: 1
        }
    }

    // 3. Playback Controls (Higher z so controls intercept their own clicks)
    RowLayout {
        id: mediaControlsRow
        z: 10
        anchors {
            right: parent.right
            rightMargin: isMaterial ? 4 : 8
            verticalCenter: parent.verticalCenter
        }
        spacing: isMaterial ? -2 : 0

        // Skip Previous
        Item {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 20
            implicitHeight: 20
            visible: (activePlayer?.canGoPrevious ?? false) && (island?.mediaHoverHandler?.hovered || Config.options.bar.dynamicIsland.showMediaControls)

            MaterialSymbol {
                anchors.centerIn: parent
                text: "skip_previous"
                fill: 1
                iconSize: isMaterial ? 20 : 16
                color: Appearance.colors.colOnLayer0
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: activePlayer?.previous()
            }
        }

        // Play / Pause Button (Explicitly toggles playback without opening details)
        Item {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 22
            implicitHeight: 22

            MaterialSymbol {
                anchors.centerIn: parent
                text: activePlayer?.isPlaying ? "pause" : "play_arrow"
                fill: 1
                iconSize: isMaterial ? 20 : 18
                color: Appearance.colors.colOnLayer0
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: activePlayer?.togglePlaying()
            }
        }

        // Skip Next
        Item {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 20
            implicitHeight: 20
            visible: (activePlayer?.canGoNext ?? false) && (island?.mediaHoverHandler?.hovered || Config.options.bar.dynamicIsland.showMediaControls)

            MaterialSymbol {
                anchors.centerIn: parent
                text: "skip_next"
                fill: 1
                iconSize: isMaterial ? 20 : 16
                color: Appearance.colors.colOnLayer0
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: activePlayer?.next()
            }
        }
    }
}