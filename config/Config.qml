// App-local preferences (independent of the bar's config.json).
// M0 keeps these in memory; persistence lands with the app state work.
pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property string page: Quickshell.env("HYPR_CM_PAGE") || "animations"
    property int windowWidth: 1020
    property int windowHeight: 720
    property real previewSpeedScale: 1.0
}
