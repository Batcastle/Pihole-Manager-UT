import QtQuick 2.12
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import "Format.js" as Fmt

// Pick exact-match filters that Pi-hole applies on the server, so they work across the whole query log
// and not just the rows already loaded. Choices come from /queries/suggestions.
Dialog {
    id: dlg

    property var filters: ({})
    property var suggestions: ({})

    signal applied(var filters)

    title: i18n.tr("Filter queries")

    // [{ key, label, values: [], texts: [] }]
    readonly property var fields: buildFields()

    function names(list) { return list || []; }

    function buildFields() {
        var s = suggestions || {};
        var clients = names(s.client_name).filter(function(x) { return x !== ""; }).concat(names(s.client_ip));
        return [
            { key: "status", label: i18n.tr("Status"), values: names(s.status), texts: names(s.status).map(Fmt.statusLabel) },
            { key: "type", label: i18n.tr("Query type"), values: names(s.type), texts: names(s.type) },
            { key: "client", label: i18n.tr("Client"), values: clients, texts: clients },
            { key: "upstream", label: i18n.tr("Upstream"), values: names(s.upstream), texts: names(s.upstream) },
            { key: "reply", label: i18n.tr("Reply"), values: names(s.reply), texts: names(s.reply).map(Fmt.replyLabel) },
            { key: "dnssec", label: i18n.tr("DNSSEC"), values: names(s.dnssec), texts: names(s.dnssec).map(Fmt.dnssecLabel) }
        ].filter(function(f) { return f.values.length > 0; });
    }

    // selections[key] = chosen value ("" = any)
    property var selections: copy(filters)

    function copy(o) {
        var out = {};
        for (var k in o) out[k] = o[k];
        return out;
    }

    function choose(key, value) {
        var next = copy(selections);
        if (value === "") delete next[key]; else next[key] = value;
        selections = next;
    }

    // Scrolls on its own so Apply / Cancel stay on screen on small phones.
    Flickable {
        width: parent.width
        height: Math.min(fieldColumn.height, units.gu(44))
        contentHeight: fieldColumn.height
        clip: true
        visible: dlg.fields.length > 0

        Column {
            id: fieldColumn
            width: parent.width
            spacing: units.gu(1)

            Repeater {
                model: dlg.fields
                delegate: OptionSelector {
                    width: fieldColumn.width
                    text: modelData.label
                    model: [i18n.tr("Any")].concat(modelData.texts)
                    selectedIndex: {
                        var i = modelData.values.indexOf(dlg.selections[modelData.key]);
                        return i + 1;       // 0 = Any
                    }
                    onDelegateClicked: dlg.choose(modelData.key, index === 0 ? "" : modelData.values[index - 1])
                }
            }
        }
    }

    Label {
        visible: dlg.fields.length === 0
        width: parent.width
        wrapMode: Text.WordWrap
        text: i18n.tr("Pi-hole hasn't logged any queries to choose from yet.")
    }

    Button {
        text: i18n.tr("Apply")
        color: theme.palette.normal.positive
        onClicked: { dlg.applied(dlg.selections); PopupUtils.close(dlg); }
    }
    Button {
        text: i18n.tr("Clear all")
        visible: Object.keys(dlg.selections).length > 0
        onClicked: { dlg.applied({}); PopupUtils.close(dlg); }
    }
    Button {
        text: i18n.tr("Cancel")
        onClicked: PopupUtils.close(dlg)
    }
}
