// Themed combo box with a themed popup list.
import QtQuick
import QtQuick.Controls.Basic
import "../theme"

ComboBox {
    id: root

    implicitHeight: 30
    implicitWidth: 180
    font.pixelSize: 12
    leftPadding: 10
    rightPadding: 24

    contentItem: Text {
        text: root.displayText
        font: root.font
        color: root.enabled ? Theme.text : Theme.dim
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Text {
        x: root.width - width - 8
        anchors.verticalCenter: parent.verticalCenter
        text: "\u25be"
        color: Theme.dim
        font.pixelSize: 11
    }

    background: Rectangle {
        radius: 8
        color: Qt.rgba(1, 1, 1, 0.05)
        border.color: root.activeFocus ? Theme.accent : Theme.border
    }

    delegate: ItemDelegate {
        id: item
        required property var modelData
        required property int index
        width: root.width
        implicitHeight: 28
        highlighted: root.highlightedIndex === index
        contentItem: Text {
            text: item.modelData
            color: Theme.text
            font.pixelSize: 12
            verticalAlignment: Text.AlignVCenter
            leftPadding: 8
            elide: Text.ElideRight
        }
        background: Rectangle {
            color: item.highlighted ? Qt.rgba(0.13, 0.75, 0.85, 0.20) : "transparent"
        }
    }

    popup: Popup {
        y: root.height + 2
        width: root.width
        implicitHeight: Math.min(260, contentItem.implicitHeight + 2)
        padding: 1
        background: Rectangle {
            radius: 8
            color: Theme.panel
            border.width: 1
            border.color: Qt.rgba(0.13, 0.75, 0.85, 0.35)
        }
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
        }
    }
}
