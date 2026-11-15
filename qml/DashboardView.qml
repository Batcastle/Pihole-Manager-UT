import QtQuick 2.12
import Lomiri.Components 1.3
import "Format.js" as Fmt

Item {
    id: view

    property var app
    property bool active: false

    property int pendingCalls: 0
    readonly property bool loading: pendingCalls > 0
    property string errorText: ""

    property var summary: null
    property string blocking: "unknown"
    property real blockingUntil: 0          // epoch ms, 0 = no timer
    property int tick: 0
    property var history: []
    property var topPermitted: []
    property var topBlocked: []
    property var topClients: []

    readonly property int remaining: {
        tick;   // re-evaluate every second while a timer is running
        return blockingUntil > 0 ? Math.max(0, Math.round((blockingUntil - Date.now()) / 1000)) : 0;
    }

    function reset() {
        summary = null;
        blocking = "unknown";
        blockingUntil = 0;
        history = [];
        topPermitted = [];
        topBlocked = [];
        topClients = [];
        errorText = "";
    }

    function _get(path, onData) {
        pendingCalls++;
        app.api.call("GET", path, null, function(err, data) {
            pendingCalls--;
            if (err) { errorText = err.message; return; }
            onData(data);
        });
    }

    function _applyBlocking(d) {
        if (!d) return;
        blocking = d.blocking || "unknown";
        blockingUntil = (d.timer !== null && d.timer !== undefined && d.timer > 0)
            ? Date.now() + d.timer * 1000 : 0;
    }

    function refresh() {
        if (!app || !app.hasServer) return;
        errorText = "";
        _get("/stats/summary", function(d) { summary = d; });
        _get("/dns/blocking", _applyBlocking);
        _get("/history", function(d) { history = d.history || []; });
        _get("/stats/top_domains?count=10", function(d) { topPermitted = d.domains || []; });
        _get("/stats/top_domains?blocked=true&count=10", function(d) { topBlocked = d.domains || []; });
        _get("/stats/top_clients?count=10", function(d) { topClients = d.clients || []; });
    }

    function setBlocking(enable, seconds) {
        var body = { blocking: enable };
        if (!enable && seconds > 0) body.timer = seconds;
        app.api.call("POST", "/dns/blocking", body, function(err, d) {
            if (err) { app.toast(err.message, true); return; }
            _applyBlocking(d);
            app.toast(enable ? i18n.tr("Blocking enabled") : i18n.tr("Blocking disabled"), false);
        });
    }

    function blockingLabel() {
        switch (blocking) {
        case "enabled": return i18n.tr("Blocking is on");
        case "disabled": return i18n.tr("Blocking is off");
        case "failed": return i18n.tr("Blocking failed");
        default: return i18n.tr("Status unknown");
        }
    }

    onActiveChanged: if (active) refresh()

    Timer {
        interval: 1000
        repeat: true
        running: view.blockingUntil > 0 && view.active
        onTriggered: {
            view.tick++;
            if (view.remaining === 0) {
                view.blockingUntil = 0;
                view.refresh();
            }
        }
    }

    Timer {
        interval: Math.max(1, app ? app.refreshSecs : 10) * 1000
        repeat: true
        running: view.active && !!app && app.hasServer && app.refreshSecs > 0
                 && Qt.application.state === Qt.ApplicationActive
        onTriggered: view.refresh()
    }

    Connections {
        target: Qt.application
        onStateChanged: {
            if (Qt.application.state === Qt.ApplicationActive && view.active)
                view.refresh();
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.height + units.gu(4)
        clip: true
        boundsBehavior: Flickable.DragAndOvershootBounds

        PullToRefresh {
            refreshing: view.loading
            onRefresh: view.refresh()
        }

        Column {
            id: col
            y: units.gu(2)
            width: Math.min(flick.width - units.gu(3), units.gu(80))
            x: (flick.width - width) / 2
            spacing: units.gu(1.5)

            // ---- error banner -------------------------------------------
            Rectangle {
                visible: view.errorText !== ""
                width: parent.width
                height: visible ? errLabel.paintedHeight + units.gu(3) : 0
                radius: units.gu(1.5)
                color: theme.palette.normal.negative
                Label {
                    id: errLabel
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: units.gu(1.5)
                    }
                    wrapMode: Text.WordWrap
                    text: view.errorText
                    color: theme.palette.normal.negativeText
                }
            }

            // ---- blocking switch ----------------------------------------
            Rectangle {
                width: parent.width
                height: blockCol.height + units.gu(3)
                radius: units.gu(1.5)
                color: theme.palette.normal.foreground

                Column {
                    id: blockCol
                    spacing: units.gu(1.2)
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: units.gu(1.5)
                    }

                    Row {
                        spacing: units.gu(1)
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: units.gu(1.6)
                            height: width
                            radius: width / 2
                            color: view.blocking === "enabled" ? theme.palette.normal.positive
                                 : view.blocking === "disabled" ? theme.palette.normal.negative
                                 : theme.palette.normal.backgroundTertiaryText
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: view.blockingLabel()
                            textSize: Label.Large
                            font.bold: true
                        }
                    }

                    Label {
                        visible: view.remaining > 0
                        text: i18n.tr("Turns back on in %1").arg(Fmt.countdown(view.remaining))
                        color: theme.palette.normal.backgroundSecondaryText
                    }

                    Button {
                        width: parent.width
                        text: view.blocking === "enabled" ? i18n.tr("Disable blocking…") : i18n.tr("Enable blocking")
                        color: view.blocking === "enabled" ? theme.palette.normal.base : theme.palette.normal.positive
                        enabled: view.blocking !== "unknown"
                        onClicked: {
                            if (view.blocking === "enabled") app.openDisableDialog(view);
                            else view.setBlocking(true, 0);
                        }
                    }
                }
            }

            // ---- headline numbers ---------------------------------------
            Grid {
                width: parent.width
                columns: 2
                spacing: units.gu(1.5)
                property real tileWidth: (width - spacing) / 2

                StatTile {
                    width: parent.tileWidth
                    title: i18n.tr("Total queries")
                    value: view.summary ? Fmt.num(view.summary.queries.total) : "–"
                    accent: theme.palette.normal.activity
                }
                StatTile {
                    width: parent.tileWidth
                    title: i18n.tr("Queries blocked")
                    value: view.summary ? Fmt.num(view.summary.queries.blocked) : "–"
                    accent: theme.palette.normal.negative
                }
                StatTile {
                    width: parent.tileWidth
                    title: i18n.tr("Percent blocked")
                    value: view.summary ? Fmt.pct(view.summary.queries.percent_blocked) : "–"
                    accent: theme.palette.normal.negative
                }
                StatTile {
                    width: parent.tileWidth
                    title: i18n.tr("On blocklists")
                    value: view.summary ? Fmt.num(view.summary.gravity.domains_being_blocked) : "–"
                    accent: theme.palette.normal.positive
                }
            }

            Label {
                visible: view.summary !== null
                width: parent.width
                wrapMode: Text.WordWrap
                textSize: Label.Small
                color: theme.palette.normal.backgroundSecondaryText
                text: view.summary
                    ? i18n.tr("%1 active clients · %2 unique domains · %3 forwarded · %4 cached")
                        .arg(Fmt.num(view.summary.clients.active))
                        .arg(Fmt.num(view.summary.queries.unique_domains))
                        .arg(Fmt.num(view.summary.queries.forwarded))
                        .arg(Fmt.num(view.summary.queries.cached))
                    : ""
            }

            ActivityChart {
                width: parent.width
                points: view.history
            }

            TopList {
                width: parent.width
                title: i18n.tr("Top blocked domains")
                items: view.topBlocked
                barColor: theme.palette.normal.negative
                clickable: true
                onItemClicked: app.domainActions(item.domain)
            }
            TopList {
                width: parent.width
                title: i18n.tr("Top permitted domains")
                items: view.topPermitted
                barColor: theme.palette.normal.positive
                clickable: true
                onItemClicked: app.domainActions(item.domain)
            }
            TopList {
                width: parent.width
                title: i18n.tr("Top clients")
                items: view.topClients
                nameKey: "name"
                altKey: "ip"
                barColor: theme.palette.normal.activity
            }
        }
    }

    ActivityIndicator {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: units.gu(1) }
        running: view.loading && view.summary === null
        visible: running
    }
}
