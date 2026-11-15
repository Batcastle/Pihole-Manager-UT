import QtQuick 2.12
import Lomiri.Components 1.3
import "Format.js" as Fmt

Item {
    id: view

    property var app
    property bool active: false

    property var queries: []
    property int limit: 100
    property bool loading: false
    property string errorText: ""
    property string filter: "all"       // all | blocked | allowed
    property string search: ""

    // Server-side filters (exact matches): status, type, client, upstream, reply, dnssec
    property var serverFilters: ({})
    property var suggestions: null
    readonly property int filterCount: Object.keys(serverFilters).length

    readonly property var shown: applyFilter(queries, filter, search)

    function applyFilter(list, f, s) {
        var needle = s.trim().toLowerCase();
        var out = [];
        for (var i = 0; i < list.length; i++) {
            var q = list[i];
            var blocked = Fmt.isBlocked(q.status);
            if (f === "blocked" && !blocked) continue;
            if (f === "allowed" && blocked) continue;
            if (needle !== "") {
                var hay = (q.domain + " " + (q.client ? (q.client.name || "") + " " + (q.client.ip || "") : "")).toLowerCase();
                if (hay.indexOf(needle) < 0) continue;
            }
            out.push(q);
        }
        return out;
    }

    function reset() {
        queries = [];
        limit = 100;
        errorText = "";
        serverFilters = ({});
        suggestions = null;
    }

    // filters -> query-string params. A client is either a hostname or an IP; Pi-hole filters them separately.
    function filterParams(f, sugg) {
        var p = { length: limit };
        if (f.status) p.status = f.status;
        if (f.type) p.type = f.type;
        if (f.upstream) p.upstream = f.upstream;
        if (f.reply) p.reply = f.reply;
        if (f.dnssec) p.dnssec = f.dnssec;
        if (f.client) {
            var ips = (sugg && sugg.client_ip) ? sugg.client_ip : [];
            if (ips.indexOf(f.client) >= 0)
                p.client_ip = f.client;
            else
                p.client_name = f.client;
        }
        return p;
    }

    function loadSuggestions(cb) {
        if (suggestions !== null) { if (cb) cb(); return; }
        app.api.call("GET", "/queries/suggestions", null, function(err, data) {
            if (!err && data && data.suggestions) suggestions = data.suggestions;
            if (cb) cb();
        });
    }

    function openFilters() {
        loadSuggestions(function() {
            var d = app.openQueryFilterDialog(serverFilters, suggestions || {});
            d.applied.connect(function(filters) { view.setFilters(filters); });
        });
    }

    function setFilters(filters) {
        serverFilters = filters;
        limit = 100;
        refresh();
    }

    function refresh() {
        if (!app || !app.hasServer) return;
        loading = true;
        errorText = "";
        app.api.call("GET", "/queries" + app.api.qs(filterParams(serverFilters, suggestions)), null, function(err, data) {
            loading = false;
            if (err) { errorText = err.message; return; }
            queries = data.queries || [];
        });
    }

    onActiveChanged: if (active) refresh()

    Timer {
        interval: Math.max(1, app ? app.refreshSecs : 10) * 1000
        repeat: true
        running: view.active && !!app && app.hasServer && app.refreshSecs > 0
                 && Qt.application.state === Qt.ApplicationActive
                 && list.contentY < units.gu(2)   // don't shuffle rows while scrolled down
        onTriggered: view.refresh()
    }

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        model: view.shown

        PullToRefresh {
            parent: list
            refreshing: view.loading
            onRefresh: view.refresh()
        }

        header: Item {
            width: list.width
            height: headerCol.height + units.gu(1)

            Column {
                id: headerCol
                y: units.gu(1)
                width: parent.width - units.gu(3)
                x: units.gu(1.5)
                spacing: units.gu(1)

                Row {
                    width: parent.width
                    spacing: units.gu(1)
                    TextField {
                        width: parent.width - filtersButton.width - parent.spacing
                        placeholderText: i18n.tr("Filter by domain or client")
                        inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                        onTextChanged: view.search = text
                    }
                    Button {
                        id: filtersButton
                        width: units.gu(13)
                        text: view.filterCount > 0 ? i18n.tr("Filters (%1)").arg(view.filterCount) : i18n.tr("Filters")
                        color: view.filterCount > 0 ? theme.palette.normal.activity : theme.palette.normal.base
                        onClicked: view.openFilters()
                    }
                }

                Row {
                    width: parent.width
                    spacing: units.gu(1)
                    Button {
                        width: (parent.width - 2 * parent.spacing) / 3
                        text: i18n.tr("All")
                        color: view.filter === "all" ? theme.palette.normal.activity : theme.palette.normal.base
                        onClicked: view.filter = "all"
                    }
                    Button {
                        width: (parent.width - 2 * parent.spacing) / 3
                        text: i18n.tr("Blocked")
                        color: view.filter === "blocked" ? theme.palette.normal.negative : theme.palette.normal.base
                        onClicked: view.filter = "blocked"
                    }
                    Button {
                        width: (parent.width - 2 * parent.spacing) / 3
                        text: i18n.tr("Allowed")
                        color: view.filter === "allowed" ? theme.palette.normal.positive : theme.palette.normal.base
                        onClicked: view.filter = "allowed"
                    }
                }

                Label {
                    visible: view.errorText !== ""
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: theme.palette.normal.negative
                    text: view.errorText
                }
            }
        }

        delegate: ListItem {
            id: row
            height: units.gu(8)
            readonly property bool blocked: Fmt.isBlocked(modelData.status)

            onClicked: view.app.openQueryDetail(modelData)

            Rectangle {
                id: dot
                anchors { left: parent.left; leftMargin: units.gu(2); verticalCenter: parent.verticalCenter }
                width: units.gu(1.4)
                height: width
                radius: width / 2
                color: row.blocked ? theme.palette.normal.negative : theme.palette.normal.positive
            }
            Column {
                anchors {
                    left: dot.right
                    leftMargin: units.gu(1.5)
                    right: timeLabel.left
                    rightMargin: units.gu(1)
                    verticalCenter: parent.verticalCenter
                }
                spacing: units.gu(0.3)
                Label {
                    width: parent.width
                    text: modelData.domain
                    elide: Text.ElideMiddle
                }
                Label {
                    width: parent.width
                    textSize: Label.Small
                    elide: Text.ElideRight
                    color: theme.palette.normal.backgroundSecondaryText
                    text: (modelData.client ? (modelData.client.name || modelData.client.ip) : "?")
                          + " · " + modelData.type
                }
                Label {
                    width: parent.width
                    textSize: Label.XSmall
                    elide: Text.ElideRight
                    color: row.blocked ? theme.palette.normal.negative : theme.palette.normal.backgroundTertiaryText
                    text: Fmt.statusLabel(modelData.status)
                }
            }
            Label {
                id: timeLabel
                anchors { right: parent.right; rightMargin: units.gu(2); verticalCenter: parent.verticalCenter }
                textSize: Label.Small
                color: theme.palette.normal.backgroundSecondaryText
                text: Fmt.dateTime(modelData.time)
            }
        }

        footer: Item {
            width: list.width
            height: view.queries.length >= view.limit ? units.gu(8) : units.gu(2)
            Button {
                visible: view.queries.length >= view.limit
                anchors.centerIn: parent
                text: i18n.tr("Load more")
                onClicked: { view.limit += 100; view.refresh(); }
            }
        }
    }

    Label {
        anchors.centerIn: parent
        visible: !view.loading && view.errorText === "" && view.shown.length === 0
        text: view.queries.length === 0 ? i18n.tr("No queries yet") : i18n.tr("No queries match")
        color: theme.palette.normal.backgroundSecondaryText
    }

    ActivityIndicator {
        anchors.centerIn: parent
        running: view.loading && view.queries.length === 0
        visible: running
    }
}
