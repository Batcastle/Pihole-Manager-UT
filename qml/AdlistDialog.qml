import QtQuick 2.12
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3

// Add a new adlist, or edit an existing one (the address can't change when editing).
Dialog {
    id: dlg

    property bool editing: false
    property var item: ({ address: "", type: "block", comment: "", enabled: true, groups: [0] })
    property var groups: []
    property string listType: item.type || "block"

    signal submitted(var result)
    signal removeRequested()

    title: editing ? i18n.tr("Edit adlist") : i18n.tr("Add adlist")

    function submit() {
        var address = addressField.text.trim();
        if (address === "") return;
        dlg.submitted({
            address: address,
            type: listType,
            comment: commentField.text.trim(),
            enabled: enabledSwitch.checked,
            groups: picker.selected
        });
        PopupUtils.close(dlg);
    }

    TextField {
        id: addressField
        placeholderText: i18n.tr("https://example.com/list.txt")
        text: dlg.item.address
        readOnly: dlg.editing
        enabled: !dlg.editing
        inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
    }

    Row {
        visible: !dlg.editing
        width: parent.width
        spacing: units.gu(1)
        Button {
            width: (parent.width - parent.spacing) / 2
            text: i18n.tr("Blocklist")
            color: dlg.listType === "block" ? theme.palette.normal.negative : theme.palette.normal.base
            onClicked: dlg.listType = "block"
        }
        Button {
            width: (parent.width - parent.spacing) / 2
            text: i18n.tr("Allowlist")
            color: dlg.listType === "allow" ? theme.palette.normal.positive : theme.palette.normal.base
            onClicked: dlg.listType = "allow"
        }
    }

    TextField {
        id: commentField
        placeholderText: i18n.tr("Comment (optional)")
        text: dlg.item.comment || ""
    }

    Row {
        width: parent.width
        spacing: units.gu(1)
        Label {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - enabledSwitch.width - parent.spacing
            text: i18n.tr("Enabled")
        }
        Switch {
            id: enabledSwitch
            anchors.verticalCenter: parent.verticalCenter
            checked: dlg.item.enabled !== false
        }
    }

    GroupPicker {
        id: picker
        width: parent.width
        groups: dlg.groups
        selected: dlg.item.groups || [0]
    }

    Button {
        text: dlg.editing ? i18n.tr("Save") : i18n.tr("Add")
        color: theme.palette.normal.positive
        enabled: addressField.text.trim() !== ""
        onClicked: dlg.submit()
    }
    Button {
        visible: dlg.editing
        text: i18n.tr("Delete adlist")
        color: theme.palette.normal.negative
        onClicked: { dlg.removeRequested(); PopupUtils.close(dlg); }
    }
    Button {
        text: i18n.tr("Cancel")
        onClicked: PopupUtils.close(dlg)
    }
}
