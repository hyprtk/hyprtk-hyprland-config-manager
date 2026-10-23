import QtQuick
import QtQuick.Layouts
import "../theme"

RowLayout {
    id: root
    property var opt: ({})
    property var value
    signal changed(var value)

    spacing: 12

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        Text {
            text: root.opt.label || root.opt.path
            color: Theme.text
            font.pixelSize: 13
        }
        Text {
            text: root.opt.path || ""
            color: Theme.dim
            font.pixelSize: 10
        }
    }

    TCheckBox {
        visible: root.opt.type === "bool"
        checked: root.value === true
        onToggled: v => root.changed(v)
    }

    TSpinBox {
        visible: root.opt.type === "int" || root.opt.type === "float"
        from: root.opt.min !== undefined ? root.opt.min : 0
        to: root.opt.max !== undefined ? root.opt.max : 1000
        step: root.opt.step !== undefined ? root.opt.step : 1
        decimals: root.opt.type === "float" ? 2 : 0
        value: Number(root.value) || 0
        onModified: v => root.changed(v)
    }

    TComboBox {
        visible: root.opt.type === "enum"
        model: root.opt.choices || []
        currentIndex: (root.opt.choices || []).indexOf(String(root.value))
        onActivated: i => root.changed(model[i])
    }

    TTextField {
        visible: root.opt.type === "str" || root.opt.type === "color"
        Layout.preferredWidth: 220
        text: root.value === undefined || root.value === null ? "" : String(root.value)
        onEdited: v => root.changed(v)
    }
}
