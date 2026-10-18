import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
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

    // Clicking on artwork or track info opens the detailed media controls popup
    MouseArea {
        id: openDetailsMouseArea
        anchors {
            left: parent.left
            right: mediaControlsRow.left
            top: parent.top
            bottom: parent.bottom
        }
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const targetPos = "center"
            const targetScr = root.QsWindow?.window?.screen
            if (GlobalStates.mediaControlsOpen && GlobalStates.mediaControlsPosition === targetPos && GlobalStates.mediaControlsScreen === targetScr) {
                GlobalStates.mediaControlsOpen = false
            } else {
                GlobalStates.mediaControlsScreen = targetScr
                GlobalStates.mediaControlsPosition = targetPos
                GlobalStates.mediaControlsOpen = true
            }
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
        radius: di?.calculateImageRadius ? di.calculateImageRadius(height) : (height / 2)
        color: Appearance.colors.colLayer1

        Behavior on radius {
            NumberAnimation {
                duration: 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
        }

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: artContainer.width
                height: artContainer.height
                radius: artContainer.radius
            }
        }

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

    // 3. Playback Controls
    RowLayout {
        id: mediaControlsRow
        anchors {
            right: parent.right
            rightMargin: isMaterial ? 4 : 8
            verticalCenter: parent.verticalCenter
        }
        spacing: isMaterial ? -2 : 0

        // Skip Previous
        RippleButton {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            implicitWidth: 24
            implicitHeight: 24
            buttonRadius: 12
            colBackground: "transparent"
            colBackgroundHover: Appearance.colors.colLayer1Hover
            visible: (activePlayer?.canGoPrevious ?? false) && (island?.mediaHoverHandler?.hovered || Config.options.bar.dynamicIsland.showMediaControls)
            onClicked: activePlayer?.previous()

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "skip_previous"
                fill: 1
                iconSize: isMaterial ? 20 : 16
                color: Appearance.colors.colOnLayer0
            }
        }

        // Play / Pause Button
        RippleButton {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            implicitWidth: 26
            implicitHeight: 26
            buttonRadius: 13
            colBackground: "transparent"
            colBackgroundHover: Appearance.colors.colLayer1Hover
            onClicked: activePlayer?.togglePlaying()

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: activePlayer?.isPlaying ? "pause" : "play_arrow"
                fill: 1
                iconSize: isMaterial ? 20 : 18
                color: Appearance.colors.colOnLayer0
            }
        }

        // Skip Next
        RippleButton {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            implicitWidth: 24
            implicitHeight: 24
            buttonRadius: 12
            colBackground: "transparent"
            colBackgroundHover: Appearance.colors.colLayer1Hover
            visible: (activePlayer?.canGoNext ?? false) && (island?.mediaHoverHandler?.hovered || Config.options.bar.dynamicIsland.showMediaControls)
            onClicked: activePlayer?.next()

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "skip_next"
                fill: 1
                iconSize: isMaterial ? 20 : 16
                color: Appearance.colors.colOnLayer0
            }
        }
    }
}