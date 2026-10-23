import QtQuick
import "../theme"

Rectangle {
    id: root
    property string text: ""
    property bool primary: false
    property bool enabled: true
    signal clicked()

    implicitWidth: label.implicitWidth + 28
    implicitHeight: 32
    radius: 8
    color: !enabled ? Theme.card
         : primary ? Theme.accent
         : hover.hovered ? Qt.rgba(1, 1, 1, 0.10)
         : Qt.rgba(1, 1, 1, 0.05)
    border.color: primary ? "transparent" : Theme.border
    opacity: enabled ? 1 : 0.5

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.primary ? "#1a1420" : Theme.text
        font.pixelSize: 12
        font.bold: root.primary
    }
    HoverHandler { id: hover }
    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
