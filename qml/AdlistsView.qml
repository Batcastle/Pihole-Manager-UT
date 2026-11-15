import QtQuick 2.12
import Lomiri.Components 1.3
import "Format.js" as Fmt

// Adlists (blocklists / allowlists that feed gravity).
Item {
    id: view

    property var app
    property bool active: false

    property var lists: []
    property var groups: [{ id: 0, name: "Default", enabled: true }]
    property bool loading: false
    property string errorText: ""

    function reset() {
        lists = [];
        groups = [{ id: 0, name: "Default", enabled: true }];
        errorText = "";
    }

    function refresh() {
        if (!app || !app.hasServer) return;
        loading = true;
        errorText = "";
        app.api.call("GET", "/lists", null, function(err, data) {
            loading = false;
            if (err) { errorText = err.message; return; }
            lists = data.lists || [];
        });
        app.api.call("GET", "/groups", null, function(err, data) {
            if (!err && data && data.groups && data.groups.length > 0) groups = data.groups;
        });
    }

    function path(item) {
        return "/lists/" + encodeURIComponent(item.address) + app.api.qs({ type: item.type });
    }

    // Replace an adlist's editable fields (Pi-hole's PUT replaces the whole record).
    function update(item, changes) {
        var body = {
            type: item.type,
            comment: item.comment === undefined ? null : item.comment,
            groups: item.groups || [0],
            enabled: item.enabled !== false
        };
        for (var k in changes) body[k] = changes[k];
        app.api.call("PUT", path(item), body, function(err, data) {
            if (err) { app.toast(err.message, true); refresh(); return; }
            var problem = app.processedError(data);
            if (problem !== "") { app.toast(problem, true); refresh(); return; }
            app.toast(i18n.tr("Saved"), false);
            refresh();
        });
    }

    function create(result) {
        var body = { address: result.address, comment: result.comment || null, groups: result.groups, enabled: result.enabled };
        app.api.call("POST", "/lists" + app.api.qs({ type: result.type }), body, function(err, data) {
            if (err) { app.toast(err.message, true); return; }
            var problem = app.processedError(data);
            if (problem !== "") { app.toast(problem, true); return; }
            app.toast(i18n.tr("Adlist added. Update gravity to download it."), false);
            refresh();
        });
    }

    function remove(item) {
        app.api.call("DELETE", path(item), null, function(err) {
            if (err) { app.toast(err.message, true); return; }
            app.toast(i18n.tr("Adlist removed"), false);
            refresh();
        });
    }

    function addAdlist() {
        app.openAdlistDialog({ editing: false, groups: view.groups }, function(result) { view.create(result); });
    }

    function editAdlist(item) {
        var d = app.openAdlistDialog({ editing: true, item: item, groups: view.groups }, function(result) {
            view.update(item, { comment: result.comment || null, enabled: result.enabled, groups: result.groups });
        });
        d.removeRequested.connect(function() { view.remove(item); });
    }

    function updateGravity() {
        app.confirmAction(
            i18n.tr("Update gravity?"),
            i18n.tr("Pi-hole will download all enabled adlists again. This can take a minute."),
            i18n.tr("Update"),
            function() {
                app.runAction(i18n.tr("Updating gravity…"), "/action/gravity", i18n.tr("Gravity updated"), 240000,
                              function() { view.refresh(); });
            });
    }

    // Short status line under the address.
    function describe(item) {
        var parts = [];
        if (item.enabled === false) parts.push(i18n.tr("Disabled"));
        parts.push(i18n.tr("%1 domains").arg(Fmt.num(item.number || 0)));
        parts.push(item.date_updated > 0 ? i18n.tr("updated %1").arg(Fmt.ago(item.date_updated))
                                         : i18n.tr("not downloaded yet"));
        return parts.join(" · ");
    }

    // Download problems (status 3 = cached copy used, 4 = nothing usable)
    function problem(item) {
        if (item.enabled === false) return "";
        if (item.status === 3) return i18n.tr("Couldn't download, using the cached copy");
        if (item.status === 4) return i18n.tr("Couldn't download and nothing is cached");
        return "";
    }

    Column {
        id: topBar
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: units.gu(1.5) }
        spacing: units.gu(1)

        Button {
            width: parent.width
            text: i18n.tr("Update gravity")
            enabled: view.app && view.app.hasServer
            onClicked: view.updateGravity()
        }
        Label {
            visible: view.errorText !== ""
            width: parent.width
            wrapMode: Text.WordWrap
            color: theme.palette.normal.negative
            text: view.errorText
        }
    }

    ListView {
        id: list
        anchors {
            top: topBar.bottom
            topMargin: units.gu(1)
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        clip: true
        model: view.lists

        PullToRefresh {
            parent: list
            refreshing: view.loading
            onRefresh: view.refresh()
        }

        delegate: ListItem {
            id: row
            height: units.gu(9)

            onClicked: view.editAdlist(modelData)

            leadingActions: ListItemActions {
                actions: [
                    Action {
                        iconName: "delete"
                        text: i18n.tr("Remove")
                        onTriggered: view.remove(modelData)
                    }
                ]
            }

            Column {
                anchors {
                    left: parent.left
                    leftMargin: units.gu(2)
                    right: enabledSwitch.left
                    rightMargin: units.gu(1)
                    verticalCenter: parent.verticalCenter
                }
                spacing: units.gu(0.3)
                Label {
                    width: parent.width
                    text: modelData.address
                    elide: Text.ElideMiddle
                    opacity: modelData.enabled === false ? 0.5 : 1
                }
                Label {
                    width: parent.width
                    textSize: Label.Small
                    elide: Text.ElideRight
                    color: theme.palette.normal.backgroundSecondaryText
                    text: (modelData.type === "allow" ? i18n.tr("Allowlist") + " · " : "") + view.describe(modelData)
                }
                Label {
                    visible: text !== ""
                    width: parent.width
                    textSize: Label.XSmall
                    elide: Text.ElideRight
                    color: theme.palette.normal.negative
                    text: view.problem(modelData) || ""
                }
            }

            Switch {
                id: enabledSwitch
                anchors { right: parent.right; rightMargin: units.gu(2); verticalCenter: parent.verticalCenter }
                checked: modelData.enabled !== false
                onClicked: view.update(modelData, { enabled: checked })
            }
        }
    }

    Label {
        anchors.centerIn: parent
        visible: !view.loading && view.errorText === "" && view.lists.length === 0
        horizontalAlignment: Text.AlignHCenter
        width: parent.width - units.gu(6)
        wrapMode: Text.WordWrap
        color: theme.palette.normal.backgroundSecondaryText
        text: i18n.tr("No adlists yet.\nTap + to add one.")
    }

    ActivityIndicator {
        anchors.centerIn: parent
        running: view.loading && view.lists.length === 0
        visible: running
    }
}
