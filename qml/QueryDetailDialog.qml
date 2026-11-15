import QtQuick 2.12
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import "Format.js" as Fmt

// Everything Pi-hole knows about one query, with quick block / allow buttons.
Dialog {
    id: dlg

    property var app
    property var query: ({})
    property string matched: ""          // adlist address / domain entry that caused a block

    readonly property var rows: Fmt.queryDetails(query)
    readonly property var labels: ({
        domain: i18n.tr("Domain"), time: i18n.tr("Time"), type: i18n.tr("Type"), status: i18n.tr("Status"),
        client: i18n.tr("Client"), reply: i18n.tr("Reply"), replyTime: i18n.tr("Reply time"),
        upstream: i18n.tr("Upstream"), cname: i18n.tr("CNAME"), dnssec: i18n.tr("DNSSEC"), ede: i18n.tr("Extended error")
    })
    readonly property string matchedKind: Fmt.matchedList(query.status)

    title: i18n.tr("Query details")

    // Work out which list entry blocked this query (Pi-hole only gives us its numeric id).
    Component.onCompleted: {
        if (!app || query.list_id === null || query.list_id === undefined) return;
        var id = query.list_id;
        if (matchedKind === "adlist") {
            app.api.call("GET", "/lists?type=block", null, function(err, data) {
                if (err || !data) return;
                var l = (data.lists || []).filter(function(x) { return x.id === id; })[0];
                if (l) dlg.matched = l.address;
            });
        } else if (matchedKind === "domain") {
            app.api.call("GET", "/domains/deny", null, function(err, data) {
                if (err || !data) return;
                var d = (data.domains || []).filter(function(x) { return x.id === id; })[0];
                if (d) dlg.matched = d.domain + (d.kind === "regex" ? " (" + i18n.tr("regex") + ")" : "");
            });
        }
    }

    Repeater {
        model: dlg.rows
        delegate: detailRow
    }

    Component {
        id: detailRow
        Row {
            property string key: modelData.key
            width: parent ? parent.width : 0
            spacing: units.gu(1)
            Label {
                width: units.gu(10)
                textSize: Label.Small
                color: theme.palette.normal.backgroundSecondaryText
                text: dlg.labels[modelData.key] || modelData.key
            }
            Label {
                width: parent.width - units.gu(11)
                wrapMode: Text.WrapAnywhere
                text: modelData.value
            }
        }
    }

    Row {
        width: parent.width
        spacing: units.gu(1)
        visible: dlg.matched !== ""
        Label {
            width: units.gu(10)
            textSize: Label.Small
            color: theme.palette.normal.backgroundSecondaryText
            text: i18n.tr("Blocked by")
        }
        Label {
            width: parent.width - units.gu(11)
            wrapMode: Text.WrapAnywhere
            text: dlg.matched
        }
    }

    Row {
        width: parent.width
        spacing: units.gu(1)
        Button {
            width: (parent.width - parent.spacing) / 2
            text: i18n.tr("Block")
            color: theme.palette.normal.negative
            onClicked: { dlg.app.addDomain("deny", "exact", dlg.query.domain, ""); PopupUtils.close(dlg); }
        }
        Button {
            width: (parent.width - parent.spacing) / 2
            text: i18n.tr("Allow")
            color: theme.palette.normal.positive
            onClicked: { dlg.app.addDomain("allow", "exact", dlg.query.domain, ""); PopupUtils.close(dlg); }
        }
    }
    Button {
        text: i18n.tr("Close")
        onClicked: PopupUtils.close(dlg)
    }
}
