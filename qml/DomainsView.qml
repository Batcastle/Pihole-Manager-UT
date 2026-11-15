import QtQuick 2.12
import Lomiri.Components 1.3
import "Format.js" as Fmt

// Allow / deny list management.
Item {
    id: view

    property var app
    property bool active: false

    property var domains: []
    property bool loading: false
    property string errorText: ""
    property string listType: "deny"        // deny | allow

    readonly property var shown: ofType(domains, listType)

    function ofType(list, t) {
        var out = [];
        for (var i = 0; i < list.length; i++)
            if (list[i].type === t) out.push(list[i]);
        out.sort(function(a, b) { return String(a.domain).localeCompare(String(b.domain)); });
        return out;
    }

    function reset() {
        domains = [];
        errorText = "";
    }

    function refresh() {
        if (!app || !app.hasServer) return;
        loading = true;
        errorText = "";
        app.api.call("GET", "/domains", null, function(err, data) {
            loading = false;
            if (err) { errorText = err.message; return; }
            domains = data.domains || [];
        });
    }

    function addDomain() {
        app.openAddDomain({ listType: view.listType });
    }

    function removeDomain(item) {
        var path = "/domains/" + item.type + "/" + item.kind + "/" + encodeURIComponent(item.domain);
        app.api.call("DELETE", path, null, function(err) {
            if (err) { app.toast(err.message, true); return; }
            app.toast(i18n.tr("Removed %1").arg(item.domain), false);
            refresh();
        });
    }

    onActiveChanged: if (active) refresh()

    Sections {
        id: typeSections
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: units.gu(1) }
        model: [i18n.tr("Blocked"), i18n.tr("Allowed")]
        onSelectedIndexChanged: view.listType = (selectedIndex === 0 ? "deny" : "allow")
    }

    ListView {
        id: list
        anchors {
            top: typeSections.bottom
            topMargin: units.gu(1)
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        clip: true
        model: view.shown

        PullToRefresh {
            parent: list
            refreshing: view.loading
            onRefresh: view.refresh()
        }

        header: Item {
            width: list.width
            height: view.errorText !== "" ? errorLabel.paintedHeight + units.gu(2) : 0
            visible: view.errorText !== ""

            Label {
                id: errorLabel
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    leftMargin: units.gu(2)
                    rightMargin: units.gu(2)
                    topMargin: units.gu(1)
                }
                wrapMode: Text.WordWrap
                color: theme.palette.normal.negative
                text: view.errorText
            }
        }

        delegate: ListItem {
            id: row
            height: units.gu(7)

            leadingActions: ListItemActions {
                actions: [
                    Action {
                        iconName: "delete"
                        text: i18n.tr("Remove")
                        onTriggered: view.removeDomain(modelData)
                    }
                ]
            }

            Column {
                anchors {
                    left: parent.left
                    leftMargin: units.gu(2)
                    right: kindLabel.left
                    rightMargin: units.gu(1)
                    verticalCenter: parent.verticalCenter
                }
                spacing: units.gu(0.3)
                Label {
                    width: parent.width
                    text: modelData.domain
                    elide: Text.ElideMiddle
                    opacity: modelData.enabled === false ? 0.5 : 1
                }
                Label {
                    width: parent.width
                    visible: text !== ""
                    textSize: Label.Small
                    elide: Text.ElideRight
                    color: theme.palette.normal.backgroundSecondaryText
                    text: (modelData.enabled === false ? i18n.tr("Disabled") + (modelData.comment ? " · " : "") : "")
                          + (modelData.comment || "")
                }
            }
            Label {
                id: kindLabel
                anchors { right: parent.right; rightMargin: units.gu(2); verticalCenter: parent.verticalCenter }
                text: modelData.kind
                textSize: Label.Small
                color: modelData.kind === "regex" ? theme.palette.normal.activity : theme.palette.normal.backgroundTertiaryText
            }
        }
    }

    Label {
        anchors.centerIn: parent
        visible: !view.loading && view.errorText === "" && view.shown.length === 0
        horizontalAlignment: Text.AlignHCenter
        width: parent.width - units.gu(6)
        wrapMode: Text.WordWrap
        color: theme.palette.normal.backgroundSecondaryText
        text: view.listType === "deny"
              ? i18n.tr("Nothing on your denylist yet.\nTap + to block a domain.")
              : i18n.tr("Nothing on your allowlist yet.\nTap + to allow a domain.")
    }

    ActivityIndicator {
        anchors.centerIn: parent
        running: view.loading && view.domains.length === 0
        visible: running
    }
}
