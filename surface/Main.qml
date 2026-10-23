// Main window: sidebar + page stack + pending-changes bar.
// Talks to the Python backend over the JSON-lines RPC (config_manager.cli serve).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme"
import "../config"
import "../components"
import "pages"

PanelWindow {
    id: win

    visible: true
    color: "transparent"
    focusable: true
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: Config.windowWidth
    implicitHeight: Config.windowHeight

    property var model: ({})
    property var schemaData: ({})
    property var barValues: ({})
    property var pending: ({})
    property var targetModel: ({})
    property string targetFile: ""
    property string status: "connecting…"
    property int reqId: 0
    property var inflight: ({})
    property bool busy: false

    readonly property var pages: (schemaData && schemaData.pages) || []
    readonly property string currentPage: Config.page
    readonly property int pendingCount: Object.keys(pending).length
    readonly property string backendDir:
        Qt.resolvedUrl("../backend").toString().replace("file://", "")

    function call(method, params) {
        const id = ++reqId;
        const map = Object.assign({}, inflight);
        map[id] = method;
        inflight = map;
        busy = true;
        rpc.write(JSON.stringify({ id: id, method: method, params: params || ({}) }) + "\n");
    }

    function onLine(line) {
        let res = null;
        try {
            res = JSON.parse(line);
        } catch (e) {
            status = line;
            return;
        }
        const method = inflight[res.id];
        const map = Object.assign({}, inflight);
        delete map[res.id];
        inflight = map;
        busy = false;

        if (res.error) {
            status = "error: " + res.error;
            return;
        }
        const r = res.result;
        if (method === "schema") {
            schemaData = r;
        } else if (method === "dump") {
            model = r;
            status = r.error ? ("error: " + r.error)
                             : ("ok · " + r.requires.length + " modules · "
                                + r.animation_order.length + " animations");
        } else if (method === "bar.get") {
            barValues = r;
        } else if (method === "module.dump") {
            if (r && r.model) {
                targetModel = r.model;
                targetFile = r.file;
            }
        } else if (method === "apply") {
            pending = ({});
            status = "applied " + r.files.length + " file(s)"
                     + (r.backup ? (" · backup " + r.backup.stamp) : " · no backup");
            call("schema");
            call("dump");
            call("bar.get");
            if (targetFile)
                call("module.dump", { file: targetFile });
        }
    }

    function selectPage(id) {
        Config.page = id;
    }

    function stage(key, descriptor) {
        const map = Object.assign({}, pending);
        map[key] = descriptor;
        pending = map;
    }

    function unstage(key) {
        const map = Object.assign({}, pending);
        delete map[key];
        pending = map;
    }

    function setPending(path, value, kind) {
        stage(path, { type: "config", path: path, value: value, kind: kind });
    }

    function revertAll() {
        pending = ({});
    }

    function applyEdits(edits, reason) {
        if (!edits || edits.length === 0)
            return;
        call("apply", { edits: edits, reason: reason || "config-manager GUI" });
    }

    function applyPending() {
        const edits = [];
        for (const key of Object.keys(pending))
            edits.push(pending[key]);
        applyEdits(edits, "config-manager GUI");
    }

    function loadTarget(file) {
        if (!file)
            return;
        targetFile = file;
        status = "reading " + file + "…";
        call("module.dump", { file: file });
    }

    function reload() {
        status = "reading config…";
        call("schema");
        call("dump");
        call("bar.get");
        if (targetFile)
            call("module.dump", { file: targetFile });
    }

    Process {
        id: rpc
        running: true
        stdinEnabled: true
        command: ["python3", "-m", "config_manager.cli", "serve"]
        clearEnvironment: false
        environment: ({ "PYTHONPATH": win.backendDir })
        stdout: SplitParser { onRead: line => win.onLine(line) }
        stderr: SplitParser { onRead: line => console.warn("config-manager:", line) }
        onStarted: {
            console.log("config-manager: backend started");
            win.call("schema");
            win.reload();
        }
        onExited: (code, status) => {
            if (code !== 0)
                win.status = "backend exited (" + code + ")";
        }
    }

    onStatusChanged: console.log("config-manager:", status)

    Shortcut {
        sequence: "Escape"
        onActivated: Qt.quit()
    }

    // ── chrome ─────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Qt.rgba(0.07, 0.06, 0.10, 0.97)
        border.width: 1
        border.color: Theme.border

        Rectangle {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.5
            height: 2
            radius: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: Theme.accent }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            // header
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                ColumnLayout {
                    spacing: 0
                    Text {
                        text: "Hyprland Settings"
                        color: Theme.text
                        font.pixelSize: 18
                        font.bold: true
                    }
                    Text {
                        text: "hyprtk · Lua config manager"
                        color: Theme.dim
                        font.pixelSize: 11
                    }
                }
                Item { Layout.fillWidth: true }
                TButton { text: "Reload"; enabled: !win.busy; onClicked: win.reload() }
                TButton { text: "Close"; onClicked: Qt.quit() }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 16

                // sidebar
                Rectangle {
                    Layout.preferredWidth: 200
                    Layout.fillHeight: true
                    radius: 10
                    color: Qt.rgba(1, 1, 1, 0.03)
                    border.color: Theme.border

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        Repeater {
                            model: win.pages
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 36
                                radius: 8
                                color: win.currentPage === modelData.id
                                       ? Qt.rgba(0.75, 0.52, 0.99, 0.18)
                                       : (navHover.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                                Rectangle {
                                    visible: win.currentPage === modelData.id
                                    width: 3
                                    height: 18
                                    radius: 2
                                    anchors.left: parent.left
                                    anchors.leftMargin: 3
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Theme.accent
                                }
                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.title
                                    color: win.currentPage === modelData.id ? Theme.text : Theme.dim
                                    font.pixelSize: 13
                                    font.bold: win.currentPage === modelData.id
                                }
                                HoverHandler { id: navHover }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.selectPage(modelData.id)
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        Text {
                            Layout.fillWidth: true
                            text: win.status
                            color: win.status.startsWith("error") ? Theme.danger : Theme.dim
                            font.pixelSize: 10
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                // content
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    Text {
                        text: {
                            const p = win.pages.find(x => x.id === win.currentPage);
                            return p ? p.title : "";
                        }
                        color: Theme.text
                        font.pixelSize: 15
                        font.bold: true
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Animations {
                            id: animPage
                            anchors.fill: parent
                            visible: win.currentPage === "animations"
                            model: win.model
                            schemaData: win.schemaData
                            bar: win.barValues
                            targetModel: win.targetModel
                            targetFile: win.targetFile
                            pending: win.pending
                            onStage: (key, descriptor) => win.stage(key, descriptor)
                            onRequestTarget: file => win.loadTarget(file)
                            onApplyNow: (edits, reason) => win.applyEdits(edits, reason)
                        }

                        ConfigPage {
                            anchors.fill: parent
                            visible: win.currentPage !== "animations"
                            pageId: win.currentPage
                            model: win.model
                            schemaData: win.schemaData
                            pending: win.pending
                            onChange: (path, value, kind) => win.setPending(path, value, kind)
                        }
                    }

                    // pending changes bar
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 46
                        radius: 10
                        visible: win.pendingCount > 0
                        color: Qt.rgba(0.13, 0.75, 0.85, 0.10)
                        border.color: Theme.accent2

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 10
                            Text {
                                Layout.fillWidth: true
                                text: win.pendingCount + " pending change" + (win.pendingCount === 1 ? "" : "s")
                                      + " · writes go to the owning Lua module"
                                color: Theme.text
                                font.pixelSize: 12
                            }
                            TButton { text: "Revert"; onClicked: win.revertAll() }
                            TButton {
                                text: "Apply"
                                primary: true
                                enabled: !win.busy
                                onClicked: win.applyPending()
                            }
                        }
                    }
                }
            }
        }
    }
}
