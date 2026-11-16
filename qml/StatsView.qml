import QtQuick 2.12
import Lomiri.Components 1.3
import "Format.js" as Fmt

// Long-form statistics: query types, upstream servers, reply types and cache behaviour.
Item {
    id: view

    property var app
    property bool active: false

    property int pendingCalls: 0
    readonly property bool loading: pendingCalls > 0
    property string errorText: ""

    property var summary: null
    property var queryTypes: []         // [{ name, count }]
    property var upstreams: []          // [{ name, count }]
    property var replies: []            // [{ name, count }]

    readonly property real totalQueries: summary ? summary.queries.total : 0
    readonly property real forwardedTotal: {
        var n = 0;
        for (var i = 0; i < upstreams.length; i++) n += upstreams[i].count;
        return n;
    }

    function reset() {
        summary = null;
        queryTypes = [];
        upstreams = [];
        replies = [];
        errorText = "";
    }

    // { A: 5, AAAA: 0, PTR: 9 } -> [{ name: "PTR", count: 9 }, { name: "A", count: 5 }]  (zeros dropped, biggest first)
    function mapToItems(map, labeler) {
        var out = [];
        for (var k in (map || {})) {
            var c = map[k];
            if (c > 0) out.push({ name: labeler ? labeler(k) : k, count: c });
        }
        out.sort(function(a, b) { return b.count - a.count; });
        return out;
    }

    // /stats/upstreams entries -> rows labelled "name · avg reply time"
    function upstreamItems(list) {
        var out = [];
        for (var i = 0; i < (list || []).length; i++) {
            var u = list[i];
            var name = u.name || u.ip || "?";
            if (u.port > 0 && u.port !== 53) name += "#" + u.port;      // special entries (cache, blocklist) have port -1
            var rt = (u.statistics && u.statistics.response > 0) ? Fmt.replyTime(u.statistics.response * 1000) : "";
            out.push({ name: rt !== "" ? name + " · " + rt : name, count: u.count || 0 });
        }
        out.sort(function(a, b) { return b.count - a.count; });
        return out;
    }

    function _get(path, onData) {
        pendingCalls++;
        app.api.call("GET", path, null, function(err, data) {
            pendingCalls--;
            if (err) { errorText = err.message; return; }
            onData(data);
        });
    }

    function refresh() {
        if (!app || !app.hasServer) return;
        errorText = "";
        _get("/stats/summary", function(d) {
            summary = d;
            replies = mapToItems(d && d.queries ? d.queries.replies : null, Fmt.replyLabel);
        });
        _get("/stats/query_types", function(d) { queryTypes = mapToItems(d.types, null); });
        _get("/stats/upstreams", function(d) { upstreams = upstreamItems(d.upstreams); });
    }

    function pctOfTotal(n) {
        return totalQueries > 0 ? Fmt.pct(100 * n / totalQueries) : "–";
    }

    onActiveChanged: if (active) refresh()

    Timer {
        interval: Math.max(1, app ? app.refreshSecs : 10) * 1000
        repeat: true
        running: view.active && !!app && app.hasServer && app.refreshSecs > 0
                 && Qt.application.state === Qt.ApplicationActive
        onTriggered: view.refresh()
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.height + units.gu(4)
        clip: true
        boundsBehavior: Flickable.DragAndOvershootBounds

        PullToRefresh {
            parent: flick
            refreshing: view.loading
            onRefresh: view.refresh()
        }

        Column {
            id: col
            y: units.gu(2)
            width: Math.min(flick.width - units.gu(3), units.gu(80))
            x: (flick.width - width) / 2
            spacing: units.gu(1.5)

            Rectangle {
                visible: view.errorText !== ""
                width: parent.width
                height: visible ? errLabel.paintedHeight + units.gu(3) : 0
                radius: units.gu(1.5)
                color: theme.palette.normal.negative
                Label {
                    id: errLabel
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: units.gu(1.5) }
                    wrapMode: Text.WordWrap
                    text: view.errorText
                    color: theme.palette.normal.negativeText
                }
            }

            Grid {
                width: parent.width
                columns: 2
                spacing: units.gu(1.5)
                property real tileWidth: (width - spacing) / 2

                StatTile {
                    width: parent.tileWidth
                    title: i18n.tr("Queries per second")
                    value: view.summary && view.summary.queries.frequency !== undefined ? Number(view.summary.queries.frequency).toFixed(2) : "–"
                    accent: theme.palette.normal.activity
                }
                StatTile {
                    width: parent.tileWidth
                    title: i18n.tr("Unique domains")
                    value: view.summary ? Fmt.num(view.summary.queries.unique_domains) : "–"
                    accent: theme.palette.normal.activity
                }
                StatTile {
                    width: parent.tileWidth
                    title: i18n.tr("Answered from cache")
                    value: view.summary ? view.pctOfTotal(view.summary.queries.cached) : "–"
                    accent: theme.palette.normal.positive
                }
                StatTile {
                    width: parent.tileWidth
                    title: i18n.tr("Forwarded upstream")
                    value: view.summary ? view.pctOfTotal(view.summary.queries.forwarded) : "–"
                    accent: theme.palette.normal.positive
                }
            }

            TopList {
                width: parent.width
                title: i18n.tr("Query types")
                items: view.queryTypes
                nameKey: "name"
                percentOf: view.totalQueries
                barColor: theme.palette.normal.activity
            }
            TopList {
                width: parent.width
                title: i18n.tr("Upstream servers")
                items: view.upstreams
                nameKey: "name"
                percentOf: view.forwardedTotal
                barColor: theme.palette.normal.positive
            }
            TopList {
                width: parent.width
                title: i18n.tr("Reply types")
                items: view.replies
                nameKey: "name"
                percentOf: view.totalQueries
                barColor: theme.palette.normal.negative
            }
        }
    }

    ActivityIndicator {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: units.gu(1) }
        running: view.loading && view.summary === null
        visible: running
    }
}
