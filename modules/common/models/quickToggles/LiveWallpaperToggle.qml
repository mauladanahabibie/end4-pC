import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

QuickToggleModel {
    name: Translation.tr("Live Wallpaper")
    statusText: LiveWallpaper.paused ? Translation.tr("Paused") : Translation.tr("Playing")
    toggled: !LiveWallpaper.paused
    available: LiveWallpaper.available
    icon: LiveWallpaper.paused ? "play_arrow" : "pause"

    mainAction: () => {
        LiveWallpaper.toggle()
    }

    tooltipText: Translation.tr("Toggle live wallpaper playback")
}
