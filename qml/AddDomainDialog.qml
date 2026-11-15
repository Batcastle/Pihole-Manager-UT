import QtQuick 2.12
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3

Dialog {
    id: dlg

    property string presetDomain: ""
    property string listType: "deny"     // "deny" | "allow"
    property string kind: "exact"        // "exact" | "regex"

    signal submitted(string listType, string kind, string domain, string comment)

    title: i18n.tr("Add domain")

    function submit() {
        var d = domainField.text.trim();
        if (d === "") return;
        dlg.submitted(listType, kind, d, commentField.text.trim());
        PopupUtils.close(dlg);
    }

    TextField {
        id: domainField
        placeholderText: kind === "regex" ? i18n.tr("Regular expression") : i18n.tr("example.com")
        text: dlg.presetDomain
        inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
    }

    Row {
        width: parent.width
        spacing: units.gu(1)
        Button {
            width: (parent.width - parent.spacing) / 2
            text: i18n.tr("Block")
            color: dlg.listType === "deny" ? theme.palette.normal.negative : theme.palette.normal.base
            onClicked: dlg.listType = "deny"
        }
        Button {
            width: (parent.width - parent.spacing) / 2
            text: i18n.tr("Allow")
            color: dlg.listType === "allow" ? theme.palette.normal.positive : theme.palette.normal.base
            onClicked: dlg.listType = "allow"
        }
    }

    Row {
        width: parent.width
        spacing: units.gu(1)
        Button {
            width: (parent.width - parent.spacing) / 2
            text: i18n.tr("Exact")
            color: dlg.kind === "exact" ? theme.palette.normal.activity : theme.palette.normal.base
            onClicked: dlg.kind = "exact"
        }
        Button {
            width: (parent.width - parent.spacing) / 2
            text: i18n.tr("Regex")
            color: dlg.kind === "regex" ? theme.palette.normal.activity : theme.palette.normal.base
            onClicked: dlg.kind = "regex"
        }
    }

    TextField {
        id: commentField
        placeholderText: i18n.tr("Comment (optional)")
        onAccepted: dlg.submit()
    }

    Button {
        text: i18n.tr("Add")
        color: theme.palette.normal.positive
        enabled: domainField.text.trim() !== ""
        onClicked: dlg.submit()
    }
    Button {
        text: i18n.tr("Cancel")
        onClicked: PopupUtils.close(dlg)
    }
}
