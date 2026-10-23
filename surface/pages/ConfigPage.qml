// Generic option page driven entirely by schema.py + the probed model.
import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../components"

Item {
    id: page
    property string pageId: ""
    property var model: ({})
    property var schemaData: ({})
    property var pending: ({})
    signal change(string path, var value, string kind)

    readonly property var meta: {
        const pages = (schemaData && schemaData.pages) || [];
        return pages.find(p => p.id === pageId) || ({ options: [] });
    }

    function valueFor(path) {
        if (pending && pending.hasOwnProperty(path))
            return pending[path].value;
        if (path.indexOf("env.") === 0)
            return model && model.env ? model.env[path.substring(4)] : undefined;
        let node = model ? model.config : null;
        for (const part of path.split(".")) {
            if (node === null || node === undefined || typeof node !== "object")
                return undefined;
            node = node[part];
        }
        return node;
    }

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight + 24
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            width: parent.width
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    text: page.meta.description || ""
                    color: Theme.dim
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
                Rectangle {
                    visible: !!page.meta.file
                    implicitWidth: fileLabel.implicitWidth + 16
                    implicitHeight: 22
                    radius: 6
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.color: Theme.border
                    Text {
                        id: fileLabel
                        anchors.centerIn: parent
                        text: page.meta.file || ""
                        color: Theme.dim
                        font.pixelSize: 10
                    }
                }
                Rectangle {
                    visible: page.meta.file !== undefined && page.meta.file !== null
                    implicitWidth: activeLabel.implicitWidth + 16
                    implicitHeight: 22
                    radius: 6
                    color: page.meta.active ? Qt.rgba(0.13, 0.75, 0.85, 0.15)
                                            : Qt.rgba(1, 1, 1, 0.04)
                    border.color: page.meta.active ? Theme.accent2 : Theme.border
                    Text {
                        id: activeLabel
                        anchors.centerIn: parent
                        text: page.meta.active ? "loaded" : "inactive"
                        color: page.meta.active ? Theme.accent2 : Theme.dim
                        font.pixelSize: 10
                    }
                }
            }

            Repeater {
                model: page.meta.options || []
                delegate: Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: row.implicitHeight + 20
                    radius: 10
                    color: Qt.rgba(1, 1, 1, 0.03)
                    border.color: (page.pending || {}).hasOwnProperty(modelData.path)
                                  ? Theme.accent2 : Theme.border

                    OptionRow {
                        id: row
                        anchors.fill: parent
                        anchors.margins: 10
                        opt: modelData
                        value: page.valueFor(modelData.path)
                        onChanged: v => page.change(modelData.path, v, modelData.type)
                    }
                }
            }

            Text {
                visible: (page.meta.options || []).length === 0
                         && (page.meta.items || []).length === 0
                Layout.fillWidth: true
                text: "No editable settings in this file."
                color: Theme.dim
                font.pixelSize: 12
            }

            // Discovered (read-only) calls owned by this module.
            Text {
                visible: (page.meta.items || []).length > 0
                text: "Discovered"
                color: Theme.accent
                font.pixelSize: 12
                font.bold: true
                Layout.topMargin: 6
            }
            Repeater {
                model: page.meta.items || []
                delegate: Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: itemRow.implicitHeight + 16
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.02)
                    border.color: Theme.border

                    RowLayout {
                        id: itemRow
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 12
                        Text {
                            Layout.preferredWidth: 210
                            text: modelData.label || ""
                            color: Theme.text
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.value === "" ? "—" : (modelData.value || "")
                            color: Theme.dim
                            font.pixelSize: 11
                            wrapMode: Text.WrapAnywhere
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
