import QtQuick 2.12
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3

// Edit an existing allow/deny entry: enabled, comment and groups.
// (The domain, list and kind can't be changed; remove and re-add for that.)
Dialog {
    id: dlg

    property var item: ({ domain: "", type: "deny", kind: "exact", comment: "", enabled: true, groups: [0] })
    property var groups: []

    signal submitted(var result)

    title: dlg.item.domain
    text: (dlg.item.type === "deny" ? i18n.tr("Blocked") : i18n.tr("Allowed")) + " · "
          + (dlg.item.kind === "regex" ? i18n.tr("regular expression") : i18n.tr("exact match"))

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
        text: i18n.tr("Save")
        color: theme.palette.normal.positive
        onClicked: {
            dlg.submitted({ comment: commentField.text.trim(), enabled: enabledSwitch.checked, groups: picker.selected });
            PopupUtils.close(dlg);
        }
    }
    Button {
        text: i18n.tr("Cancel")
        onClicked: PopupUtils.close(dlg)
    }
}
