import QtQuick 2.12
import Lomiri.Components 1.3

// Check-box list of Pi-hole groups. Hidden when there is only the Default group.
//   groups:   [{ id, name, enabled }]
//   selected: [id, ...]   (updated as the user ticks boxes)
Column {
    id: picker

    property var groups: []
    property var selected: [0]

    visible: groups.length > 1
    spacing: units.gu(0.5)

    function isSelected(id) {
        return selected.indexOf(id) >= 0;
    }

    function toggle(id, on) {
        var next = selected.filter(function(x) { return x !== id; });
        if (on) next.push(id);
        next.sort(function(a, b) { return a - b; });
        selected = next;
    }

    Label {
        width: parent.width
        text: i18n.tr("Groups")
        font.bold: true
    }

    Repeater {
        model: picker.groups
        delegate: Row {
            spacing: units.gu(1)
            CheckBox {
                anchors.verticalCenter: parent.verticalCenter
                checked: picker.isSelected(modelData.id)
                onClicked: picker.toggle(modelData.id, checked)
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.name + (modelData.enabled === false ? " (" + i18n.tr("disabled") + ")" : "")
            }
        }
    }
}
