import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: diIdleRoot
    required property Item di
    anchors.fill: parent

    readonly property bool systemIconsElsewhere:
        Config.options.bar.layouts.leftLayout.includes("systemIcons")
        || Config.options.bar.layouts.rightLayout.includes("systemIcons")

    Rectangle {
        id: avatarRect
        width: di?.isMaterial ? di.pillHeight : ((di?.pillHeight ?? 32) - 8)
        height: width
        anchors {
            left: parent.left
            leftMargin: di?.isMaterial ? 0 : 4
            verticalCenter: parent.verticalCenter
        }
        radius: di?.calculateImageRadius ? di.calculateImageRadius(height) : (height / 2)
        color: Appearance.colors.colPrimaryContainer

        Behavior on radius {
            NumberAnimation {
                duration: 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
        }

        Rectangle {
            id: avatarMask
            anchors.fill: parent
            radius: avatarRect.radius
            visible: false
        }

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: avatarMask
        }

        Image {
            id: avatarImage
            anchors.fill: parent
            source: {
                const pic = Config.options.profile.avatarPicture ?? ""
                if (pic !== "") return pic.startsWith("/") ? "file://" + pic : pic
                return `file://${FileUtils.trimFileProtocol(Directories.home)}/.face`
            }
            sourceSize.width: avatarRect.width * 2
            sourceSize.height: avatarRect.height * 2
            fillMode: Image.PreserveAspectCrop
            visible: status === Image.Ready
            onStatusChanged: {
                if (status === Image.Error)
                    visible = false
            }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: "person"
            iconSize: di?.isMaterial ? 18 : 14
            color: Appearance.colors.colOnPrimaryContainer
            visible: !avatarImage.visible
        }

        scale: avatarMouseArea.pressed ? 0.92 : (avatarMouseArea.containsMouse ? 1.1 : 1.0)
        Behavior on scale {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutBack
                easing.overshoot: 1.8
            }
        }

        MouseArea {
            id: avatarMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                GlobalStates.settingsOpen = !GlobalStates.settingsOpen
            }
        }
    }

    readonly property real clockVerticalOffset: (Config.options.bar?.dynamicIsland?.clockVerticalOffset ?? 0)

    readonly property string formattedDate: {
        if (!Config.options.bar?.dynamicIsland?.showDate) return ""
        const fmt = Config.options.bar?.dynamicIsland?.dateFormat ?? "short"
        const d = DateTime.clock.date
        if (fmt === "dayShort") {
            return Qt.locale().toString(d, "ddd, dd/MM")
        } else if (fmt === "dayMonth") {
            return Qt.locale().toString(d, "ddd, d MMM")
        } else if (fmt === "monthDay") {
            return Qt.locale().toString(d, "d MMM")
        } else if (fmt === "long") {
            return Qt.locale().toString(d, "dddd, d MMMM")
        } else {
            return Qt.locale().toString(d, Config.options?.time?.shortDateFormat ?? "dd/MM")
        }
    }

    readonly property string formattedTime: {
        const showSec = Config.options.bar?.dynamicIsland?.showSeconds ?? false
        if (showSec) {
            const baseFmt = Config.options?.time?.format ?? "hh:mm"
            const apIdx = baseFmt.toLowerCase().indexOf("ap")
            const secFmt = apIdx !== -1
                ? (baseFmt.slice(0, apIdx).trim() + ":ss " + baseFmt.slice(apIdx).trim())
                : (baseFmt + ":ss")
            return Qt.locale().toString(DateTime.clock.date, secFmt)
        }
        return DateTime.time
    }

    RowLayout {
        id: rightSideRow
        anchors {
            right: parent.right
            rightMargin: 10
            verticalCenter: parent.verticalCenter
        }
        spacing: 8

        RowLayout {
            id: idleIconsRow
            Layout.alignment: Qt.AlignVCenter
            spacing: 4

            Revealer {
                reveal: !diIdleRoot.systemIconsElsewhere && (Audio.source?.audio?.muted ?? false)
                MaterialSymbol {
                    text: "mic_off"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer0
                }
            }

            Revealer {
                reveal: !diIdleRoot.systemIconsElsewhere && (Audio.sink?.audio?.muted ?? false)
                MaterialSymbol {
                    text: "volume_off"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer0
                }
            }

            Revealer {
                reveal: !diIdleRoot.systemIconsElsewhere
                    && !Network.ethernet
                    && (Network.wifiStatus === "disconnected" || Network.wifiStatus === "disabled")
                MaterialSymbol {
                    text: "wifi_off"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colError
                }
            }

            Revealer {
                reveal: (Notifications.unread ?? 0) > 0
                Item {
                    implicitWidth: notifRow.implicitWidth
                    implicitHeight: notifRow.implicitHeight

                    RowLayout {
                        id: notifRow
                        spacing: 2
                        MaterialSymbol {
                            text: "notifications"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnLayer0
                        }
                        StyledText {
                            text: `${Notifications.unread}`
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.features: { "tnum": 1 }
                            color: Appearance.colors.colOnLayer0
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen
                    }
                }
            }
        }

        Loader {
            Layout.alignment: Qt.AlignVCenter
            sourceComponent: Config.options.bar.dynamicIsland.leftWidget === "clockWidget" ? weatherComponent : clockComponent

            Component {
                id: clockComponent
                Item {
                    implicitWidth: clockRow.implicitWidth
                    implicitHeight: clockRow.implicitHeight

                    RowLayout {
                        id: clockRow
                        anchors {
                            centerIn: parent
                            verticalCenterOffset: diIdleRoot.clockVerticalOffset
                        }
                        spacing: 5

                        StyledText {
                            id: dateText
                            visible: (Config.options.bar?.dynamicIsland?.showDate ?? false) && text.length > 0
                            text: diIdleRoot.formattedDate
                            font.pixelSize: di?.isMaterial ? Appearance.font.pixelSize.small : Appearance.font.pixelSize.smaller
                            font.features: { "tnum": 1 }
                            color: clockMouseArea.containsMouse ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer0
                            opacity: clockMouseArea.containsMouse ? 1.0 : 0.8
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color {
                                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                            }
                        }

                        StyledText {
                            id: dateSeparator
                            visible: dateText.visible
                            text: "•"
                            font.pixelSize: di?.isMaterial ? Appearance.font.pixelSize.smaller : Appearance.font.pixelSize.smallest
                            color: clockMouseArea.containsMouse ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer0
                            opacity: clockMouseArea.containsMouse ? 0.8 : 0.5
                            Layout.alignment: Qt.AlignVCenter
                        }

                        StyledText {
                            id: timeText
                            text: diIdleRoot.formattedTime
                            font.pixelSize: di?.isMaterial ? Appearance.font.pixelSize.normal : Appearance.font.pixelSize.small
                            font.features: { "tnum": 1 }
                            color: clockMouseArea.containsMouse ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer0
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color {
                                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                            }
                        }
                    }

                    MouseArea {
                        id: clockMouseArea
                        anchors.fill: parent
                        hoverEnabled: !Config.options.bar.tooltips.clickToShow
                        cursorShape: Qt.PointingHandCursor
                        onClicked: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen

                        ClockWidgetPopup {
                            hoverTarget: clockMouseArea
                            today: new Date()
                        }
                    }
                }
            }

            Component {
                id: weatherComponent
                Item {
                    implicitWidth: weatherLayout.implicitWidth
                    implicitHeight: weatherLayout.implicitHeight
                    RowLayout {
                        id: weatherLayout
                        anchors {
                            centerIn: parent
                            verticalCenterOffset: 0.5
                        }
                        spacing: 4

                        MaterialSymbol {
                            fill: 0
                            text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                            iconSize: Appearance.font.pixelSize.normal
                            color: weatherMouseArea.containsMouse ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer0
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color {
                                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                            }
                        }

                        StyledText {
                            font.pixelSize: di?.isMaterial ? Appearance.font.pixelSize.normal : Appearance.font.pixelSize.small
                            font.features: { "tnum": 1 }
                            color: weatherMouseArea.containsMouse ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer0
                            text: Weather.data?.temp ?? "--°"
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color {
                                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                            }
                        }
                    }
                    MouseArea {
                        id: weatherMouseArea
                        anchors.fill: parent
                        hoverEnabled: !Config.options.bar.tooltips.clickToShow
                        cursorShape: Qt.PointingHandCursor
                        onClicked: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen

                        WeatherPopup {
                            hoverTarget: weatherMouseArea
                        }
                    }
                }
            }
        }

        readonly property real computedIdleWidth: avatarRect.width
            + (di?.isMaterial ? 0 : 4)
            + 10
            + rightSideRow.implicitWidth
            + 10

        onComputedIdleWidthChanged: {
            if (di) di.idleTextContentWidth = rightSideRow.computedIdleWidth
        }
        Component.onCompleted: {
            if (di) di.idleTextContentWidth = rightSideRow.computedIdleWidth
        }
    }
}