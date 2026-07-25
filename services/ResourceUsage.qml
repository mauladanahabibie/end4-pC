pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Simple polled resource usage service with RAM, Swap, CPU and Disk usage.
 */
Singleton {
    id: root
    property real memoryTotal: 1
    property real memoryFree: 0
    property real memoryUsed: memoryTotal - memoryFree
    property real memoryUsedPercentage: memoryUsed / memoryTotal
    property real swapTotal: 1
    property real swapFree: 0
    property real swapUsed: swapTotal - swapFree
    property real swapUsedPercentage: swapTotal > 0 ? (swapUsed / swapTotal) : 0
    property real cpuUsage: 0
    property var previousCpuStats

    property string maxAvailableMemoryString: kbToGbString(ResourceUsage.memoryTotal)
    property string maxAvailableSwapString: kbToGbString(ResourceUsage.swapTotal)
    property string maxAvailableCpuString: "--"

    readonly property int historyLength: Config?.options.resources.historyLength ?? 60
    property list<real> cpuUsageHistory: []
    property list<real> memoryUsageHistory: []
    property list<real> swapUsageHistory: []

    property real cpuTemp: 0

    property real diskTotal: 1
    property real diskUsed: 0
    property real diskFree: 0
    property real diskUsedPercentage: diskTotal > 0 ? diskUsed / diskTotal : 0
    property list<real> diskUsageHistory: []
    property string maxAvailableDiskString: kbToGbString(diskTotal)

    // ── Network ──
    property string localIp: ""
    property string tailscaleIp: ""
    property string warpStatus: ""
    property string publicIp: ""
    property real networkDownloadSpeed: 0  // bytes/sec
    property real networkUploadSpeed: 0   // bytes/sec
    property var prevNetworkRx: 0
    property var prevNetworkTx: 0
    property var prevNetworkTime: 0
    property string activeInterface: ""
    property list<real> networkDownloadHistory: []
    property list<real> networkUploadHistory: []

    Process {
        id: tempProc
        command: ["bash", "-c", "sensors 2>/dev/null | grep -E 'Package id 0|Tctl|Tdie' | grep -oP '\\+\\K[0-9.]+(?=°C)' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.cpuTemp = parseFloat(text.trim())
            }
        }
    }

    // Network info processes (refreshed every 10s)
    Process {
        id: localIpProc
        command: ["bash", "-c", "ip -4 addr show 2>/dev/null | grep -E 'inet ' | grep -v '127.0.0.1' | grep -v 'tailscale' | grep -v 'docker' | awk '{print $2}' | cut -d/ -f1 | head -1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { root.localIp = text.trim() }
        }
    }

    Process {
        id: tailscaleProc
        command: ["bash", "-c", "tailscale ip -4 2>/dev/null | head -1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { root.tailscaleIp = text.trim() }
        }
    }

    Process {
        id: warpProc
        command: ["bash", "-c", "warp-cli status 2>/dev/null | grep -i status | head -1 | sed 's/Status update: //'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { root.warpStatus = text.trim() }
        }
    }

    Process {
        id: publicIpProc
        command: ["bash", "-c", "curl -s --max-time 3 ifconfig.me 2>/dev/null || echo ''"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { root.publicIp = text.trim() }
        }
    }

    Process {
        id: ifaceProc
        command: ["bash", "-c", "ip route show default 2>/dev/null | awk '{print $5}' | head -1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { root.activeInterface = text.trim() }
        }
    }

    // Network speed (from /proc/net/dev delta)
    Process {
        id: netDevProc
        command: ["bash", "-c", "cat /proc/net/dev | grep -E '" + (root.activeInterface || "enp") + "' | head -1 | awk '{print $2, $10}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/)
                if (parts.length >= 2) {
                    const rx = parseInt(parts[0]) || 0
                    const tx = parseInt(parts[1]) || 0
                    const now = Date.now()
                    if (root.prevNetworkRx > 0 && root.prevNetworkTime > 0) {
                        const dt = (now - root.prevNetworkTime) / 1000
                        if (dt > 0) {
                            root.networkDownloadSpeed = Math.max(0, (rx - root.prevNetworkRx) / dt)
                            root.networkUploadSpeed = Math.max(0, (tx - root.prevNetworkTx) / dt)
                        }
                    }
                    root.prevNetworkRx = rx
                    root.prevNetworkTx = tx
                    root.prevNetworkTime = now
                    root.updateNetworkHistory()
                }
            }
        }
    }

    Process {
        id: diskProc
        command: ["bash", "-c", "df -k / | awk 'NR==2{print $2,$3,$4}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(" ").map(Number)
                if (parts.length >= 3) {
                    root.diskTotal = parts[0]
                    root.diskUsed  = parts[1]
                    root.diskFree  = parts[2]
                }
            }
        }
    }

    Timer {
        interval: Config?.options.resources.updateInterval ?? 3000
        running: true
        repeat: true
        onTriggered: {
            tempProc.running = false
            tempProc.running = true
            diskProc.running = false
            diskProc.running = true
            netDevProc.running = false
            netDevProc.running = true
        }
    }

    // Slow refresh for IP/network info (every 30s)
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: {
            localIpProc.running = false; localIpProc.running = true
            tailscaleProc.running = false; tailscaleProc.running = true
            warpProc.running = false; warpProc.running = true
            ifaceProc.running = false; ifaceProc.running = true
            publicIpProc.running = false; publicIpProc.running = true
        }
    }

    function kbToGbString(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB"
    }

    function updateMemoryUsageHistory() {
        memoryUsageHistory = [...memoryUsageHistory, memoryUsedPercentage]
        if (memoryUsageHistory.length > historyLength) memoryUsageHistory.shift()
    }
    function updateSwapUsageHistory() {
        swapUsageHistory = [...swapUsageHistory, swapUsedPercentage]
        if (swapUsageHistory.length > historyLength) swapUsageHistory.shift()
    }
    function updateCpuUsageHistory() {
        cpuUsageHistory = [...cpuUsageHistory, cpuUsage]
        if (cpuUsageHistory.length > historyLength) cpuUsageHistory.shift()
    }
    function updateDiskUsageHistory() {
        diskUsageHistory = [...diskUsageHistory, diskUsedPercentage]
        if (diskUsageHistory.length > historyLength) diskUsageHistory.shift()
    }
    function updateNetworkHistory() {
        networkDownloadHistory = [...networkDownloadHistory, networkDownloadSpeed]
        networkUploadHistory = [...networkUploadHistory, networkUploadSpeed]
        if (networkDownloadHistory.length > historyLength) networkDownloadHistory.shift()
        if (networkUploadHistory.length > historyLength) networkUploadHistory.shift()
    }
    function updateHistories() {
        updateMemoryUsageHistory()
        updateSwapUsageHistory()
        updateCpuUsageHistory()
        updateDiskUsageHistory()
    }

    Timer {
        interval: 1
        running: true
        repeat: true
        onTriggered: {
            fileMeminfo.reload()
            fileStat.reload()

            const textMeminfo = fileMeminfo.text()
            memoryTotal = Number(textMeminfo.match(/MemTotal: *(\d+)/)?.[1] ?? 1)
            memoryFree  = Number(textMeminfo.match(/MemAvailable: *(\d+)/)?.[1] ?? 0)
            swapTotal   = Number(textMeminfo.match(/SwapTotal: *(\d+)/)?.[1] ?? 1)
            swapFree    = Number(textMeminfo.match(/SwapFree: *(\d+)/)?.[1] ?? 0)

            const textStat = fileStat.text()
            const cpuLine  = textStat.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)
            if (cpuLine) {
                const stats = cpuLine.slice(1).map(Number)
                const total = stats.reduce((a, b) => a + b, 0)
                const idle  = stats[3]
                if (previousCpuStats) {
                    const totalDiff = total - previousCpuStats.total
                    const idleDiff  = idle  - previousCpuStats.idle
                    cpuUsage = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0
                }
                previousCpuStats = { total, idle }
            }

            root.updateHistories()
            interval = Config.options?.resources?.updateInterval ?? 3000
        }
    }

    FileView { id: fileMeminfo; path: "/proc/meminfo" }
    FileView { id: fileStat;    path: "/proc/stat" }

    Process {
        id: findCpuMaxFreqProc
        environment: ({ LANG: "C", LC_ALL: "C" })
        command: ["bash", "-c", "lscpu | grep 'CPU max MHz' | awk '{print $4}'"]
        running: true
        stdout: StdioCollector {
            id: outputCollector
            onStreamFinished: {
                root.maxAvailableCpuString = (parseFloat(outputCollector.text) / 1000).toFixed(0) + " GHz"
            }
        }
    }
}
