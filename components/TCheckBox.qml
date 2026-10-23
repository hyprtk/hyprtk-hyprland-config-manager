import QtQuick
import "../theme"

Rectangle {
    id: root
    property bool checked: false
    signal toggled(bool checked)

    implicitWidth: 36
    implicitHeight: 20
    radius: 10
    color: checked ? Theme.accent : Qt.rgba(1, 1, 1, 0.10)

    Rectangle {
        width: 16
        height: 16
        radius: 8
        y: 2
        x: root.checked ? root.width - width - 2 : 2
        color: root.checked ? "#1a1420" : Theme.dim
        Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: { root.checked = !root.checked; root.toggled(root.checked); }
    }
}
