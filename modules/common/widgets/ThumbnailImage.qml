import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * Thumbnail image. It currently generates to the right place at the right size, but does not handle metadata/maintenance on modification.
 * See Freedesktop's spec: https://specifications.freedesktop.org/thumbnail-spec/thumbnail-spec-latest.html
 */
StyledImage {
    id: root

    property bool generateThumbnail: true
    required property string sourcePath
    property string thumbnailSizeName: Images.thumbnailSizeNameForDimensions(sourceSize.width, sourceSize.height)

    readonly property string fileMd5: {
        if (!sourcePath || sourcePath.length === 0) return "";
        const clean = FileUtils.trimFileProtocol(`${Qt.resolvedUrl(sourcePath)}`);
        const encoded = clean.split("/").map(part => encodeURIComponent(part)).join("/");
        return Qt.md5(`file://${encoded}`);
    }

    property int fallbackStage: 0
    property string currentThumbSize: thumbnailSizeName

    onThumbnailSizeNameChanged: {
        currentThumbSize = thumbnailSizeName;
        fallbackStage = 0;
        root.source = root.computeThumbnailPath(currentThumbSize);
    }

    onSourcePathChanged: {
        currentThumbSize = thumbnailSizeName;
        fallbackStage = 0;
        root.source = root.computeThumbnailPath(currentThumbSize);
    }

    function computeThumbnailPath(sizeName) {
        if (!sourcePath || sourcePath.length === 0 || !fileMd5) return "";
        return `${Directories.genericCache}/thumbnails/${sizeName}/${fileMd5}.png`;
    }

    property string thumbnailPath: computeThumbnailPath(thumbnailSizeName)
    source: thumbnailPath

    asynchronous: true
    smooth: true
    mipmap: false

    opacity: status === Image.Ready ? 1 : 0
    Behavior on opacity {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    onStatusChanged: {
        if (status === Image.Error) {
            const sizes = ["x-large", "large", "normal"];
            if (fallbackStage === 0) {
                // Try next smaller cached thumbnail size
                for (let i = 0; i < sizes.length; i++) {
                    if (sizes[i] !== currentThumbSize) {
                        currentThumbSize = sizes[i];
                        fallbackStage = 1;
                        root.source = computeThumbnailPath(currentThumbSize);
                        return;
                    }
                }
            } else if (fallbackStage === 1) {
                // Try last size
                for (let i = 0; i < sizes.length; i++) {
                    if (sizes[i] !== currentThumbSize && sizes[i] !== thumbnailSizeName) {
                        currentThumbSize = sizes[i];
                        fallbackStage = 2;
                        root.source = computeThumbnailPath(currentThumbSize);
                        return;
                    }
                }
            }

            // If thumbnail not found in any cache size:
            if (Images.isValidImageByName(root.sourcePath)) {
                // For images: directly show the image file downscaled! Never blank!
                fallbackStage = 3;
                root.source = Qt.resolvedUrl(root.sourcePath);
            }

            // Also trigger thumbnail generation in cache if enabled
            if (root.generateThumbnail && !thumbnailGeneration.running) {
                thumbnailGeneration.running = true;
            }
        }
    }

    onSourceSizeChanged: {
        if (!root.generateThumbnail) return;
        thumbnailGeneration.running = false;
        thumbnailGeneration.running = true;
    }

    Process {
        id: thumbnailGeneration
        command: {
            const maxSize = Images.thumbnailSizes[root.thumbnailSizeName] || 512;
            const thumbPath = FileUtils.trimFileProtocol(root.thumbnailPath);
            const cleanSource = FileUtils.trimFileProtocol(root.sourcePath);
            const isVid = Images.isValidVideoByName(cleanSource);
            if (isVid) {
                return ["bash", "-c",
                    `[ -f '${thumbPath}' ] && exit 0; mkdir -p "$(dirname '${thumbPath}')"; ffmpegthumbnailer -i '${cleanSource}' -o '${thumbPath}' -s ${maxSize} 2>/dev/null && exit 1; ffmpeg -y -ss 00:00:02 -i '${cleanSource}' -vframes 1 -vf "scale=${maxSize}:${maxSize}:force_original_aspect_ratio=decrease" -update 1 '${thumbPath}' 2>/dev/null && exit 1; exit 2`
                ];
            } else {
                return ["bash", "-c",
                    `[ -f '${thumbPath}' ] && exit 0; mkdir -p "$(dirname '${thumbPath}')"; tmp='${thumbPath}.$$.tmp.png'; magick '${cleanSource}' -resize ${maxSize}x${maxSize} "\${tmp}" 2>/dev/null && mv "\${tmp}" '${thumbPath}' && exit 1; exit 2`
                ];
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 || exitCode === 1) {
                root.source = "";
                root.source = root.thumbnailPath;
            }
        }
    }
}
