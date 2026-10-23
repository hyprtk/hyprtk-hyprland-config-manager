import QtQuick
import "../theme"

Rectangle {
    id: root
    property real value: 0
    property real from: 0
    property real to: 100
    property real step: 1
    property int decimals: 0
    signal modified(real value)

    implicitWidth: 96
    implicitHeight: 30
    radius: 8
    color: Qt.rgba(1, 1, 1, 0.05)
    border.color: Theme.border

    function apply(v) {
        const clamped = Math.max(root.from, Math.min(root.to, v));
        root.value = clamped;
        input.text = clamped.toFixed(root.decimals);
    }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 22
        verticalAlignment: TextInput.AlignVCenter
        text: root.value.toFixed(root.decimals)
        color: Theme.text
        font.pixelSize: 12
        selectByMouse: true
        validator: DoubleValidator { bottom: root.from; top: root.to }
        onEditingFinished: {
            const v = parseFloat(text);
            if (!isNaN(v)) root.apply(v);
            else input.text = root.value.toFixed(root.decimals);
        }
    }
    Column {
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Repeater {
            model: ["+", "-"]
            Text {
                text: modelData
                color: Theme.dim
                font.pixelSize: 11
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.apply(root.value + (modelData === "+" ? root.step : -root.step));
                        root.modified(root.value);
                    }
                }
            }
        }
    }
}
