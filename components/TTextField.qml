import QtQuick
import "../theme"

Rectangle {
    id: root
    property string text: ""
    signal edited(string value)

    implicitHeight: 30
    implicitWidth: 180
    radius: 8
    color: Qt.rgba(1, 1, 1, 0.05)
    border.color: Theme.border

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: TextInput.AlignVCenter
        text: root.text
        color: Theme.text
        font.pixelSize: 12
        selectByMouse: true
        onEditingFinished: if (text !== root.text) root.edited(text)
    }
    onTextChanged: if (input.text !== text) input.text = text
}
