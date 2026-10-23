// hyprtk palette, optionally warmed by live pywal colours.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""
    property var wal: ({})

    FileView {
        path: root.home + "/.cache/wal/colors.json"
        printErrors: false
        onLoaded: {
            try {
                const data = JSON.parse(text()) || ({});
                root.wal = data.colors || ({});
            } catch (e) {
                root.wal = ({});
            }
        }
    }

    function walColor(key, fallback) {
        const v = root.wal ? root.wal[key] : undefined;
        return (typeof v === "string" && v.length > 0) ? v : fallback;
    }

    readonly property color accent: walColor("color5", "#c084fc")
    readonly property color accent2: walColor("color6", "#22d3ee")
    readonly property color background: walColor("color0", "#12101a")
    readonly property color panel: Qt.darker(background, 1.15)
    readonly property color card: "#221d2e"
    readonly property color text: "#e8e6f0"
    readonly property color dim: "#9a94ab"
    readonly property color border: Qt.rgba(1, 1, 1, 0.08)
    readonly property color danger: "#f87171"
    readonly property int radius: 12
    readonly property int pad: 16
}
