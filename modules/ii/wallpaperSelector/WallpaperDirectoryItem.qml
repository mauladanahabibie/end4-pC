import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import qs
import Quickshell.Widgets

Item {
    id: root

    required property var fileModelData
    property bool isDirectory: fileModelData ? Boolean(fileModelData.fileIsDir) : false
    readonly property bool isVideo: fileModelData ? Images.isValidVideoByName(fileModelData.fileName) : false
    property bool useThumbnail: fileModelData ? Images.isValidMediaByName(fileModelData.fileName) : false
    property alias colBackground: background.color
    property alias colText: wallpaperItemName.color
    property alias radius: background.radius
    property alias margins: background.anchors.margins
    property bool showLabel: true
    property alias padding: wallpaperItemColumnLayout.anchors.margins
    readonly property real imageWidth: Math.max(1, root.width - 2 * (root.margins + root.padding))
    readonly property real imageHeight: Math.max(1, root.height - 2 * (root.margins + root.padding)
        - (root.showLabel ? wallpaperItemColumnLayout.spacing + wallpaperItemName.implicitHeight : 0))

    signal activated()
    signal previewRequested()

    margins: Appearance.sizes.wallpaperSelectorItemMargins
    padding: Appearance.sizes.wallpaperSelectorItemPadding

    Rectangle {
        id: background

        anchors.fill: parent
        radius: Appearance.rounding.normal

        ColumnLayout {
            id: wallpaperItemColumnLayout

            anchors.fill: parent
            spacing: 4

            Item {
                id: wallpaperItemImageContainer

                Layout.fillHeight: true
                Layout.fillWidth: true

                Loader {
                    id: thumbnailShadowLoader

                    active: thumbnailImageLoader.active && thumbnailImageLoader.item.status === Image.Ready
                    asynchronous: true
                    anchors.fill: thumbnailImageLoader

                    sourceComponent: StyledRectangularShadow {
                        target: thumbnailImageLoader
                        anchors.fill: undefined
                        radius: Appearance.rounding.small
                    }

                }

                Loader {
                    id: thumbnailImageLoader

                    anchors.fill: parent
                    active: root.useThumbnail && root.width > 0 && root.height > 0

                    sourceComponent: ClippingRectangle {
                        readonly property alias status: thumbnailImage.status
                        radius: Appearance.rounding.small
                        color: "transparent"

                    ThumbnailImage {
                        id: thumbnailImage
                        anchors.fill: parent
                        generateThumbnail: true
                        sourcePath: (fileModelData && fileModelData.filePath) ? fileModelData.filePath : ""
                        cache: false
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: root.imageWidth
                        sourceSize.height: root.imageHeight

                        Connections {
                            function onThumbnailGenerated(directory) {
                                if (thumbnailImage.status !== Image.Error)
                                    return ;

                                if (FileUtils.parentDirectory(thumbnailImage.sourcePath) !== FileUtils.trimFileProtocol(directory))
                                    return ;

                                thumbnailImage.source = "";
                                thumbnailImage.source = thumbnailImage.thumbnailPath;
                            }

                            function onThumbnailGeneratedFile(filePath) {
                                if (thumbnailImage.status !== Image.Error)
                                    return ;

                                if (Qt.resolvedUrl(thumbnailImage.sourcePath) !== Qt.resolvedUrl(filePath))
                                    return ;

                                thumbnailImage.source = "";
                                thumbnailImage.source = thumbnailImage.thumbnailPath;
                            }

                            target: Wallpapers
                        }
                    }
                    }

                }

                Loader {
                    id: iconLoader

                    active: !root.useThumbnail
                    anchors.fill: parent

                    sourceComponent: DirectoryIcon {
                        fileModelData: root.fileModelData
                        sourceSize.width: root.imageWidth
                        sourceSize.height: root.imageHeight
                    }

                }

                // Video indicator badge
                Rectangle {
                    visible: root.isVideo
                    anchors {
                        top: parent.top
                        right: parent.right
                        margins: 6
                    }
                    width: 24
                    height: 24
                    radius: 12
                    color: Appearance.colors.colLayer1
                    opacity: 0.9
                    z: 5

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "play_arrow"
                        iconSize: 15
                        color: Appearance.colors.colPrimary
                        fill: 1
                    }
                }

            }

            StyledText {
                id: wallpaperItemName

                visible: root.showLabel
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.smaller
                text: (fileModelData && fileModelData.fileName) ? fileModelData.fileName : ""

                Behavior on color {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }

            }

        }

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

    }

}
