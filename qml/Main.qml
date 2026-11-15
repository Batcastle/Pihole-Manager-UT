import QtQuick 2.12
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import Qt.labs.settings 1.0

MainView {
    id: root

    objectName: "mainView"
    applicationName: "piholemanager.batcastle"
    automaticOrientation: true
    anchorToKeyboard: true

    width: units.gu(45)
    height: units.gu(80)

    // ---- state ---------------------------------------------------------------

    property var servers: []
    property int activeIndex: 0
    property int refreshSecs: 10
    property string busyText: ""

    readonly property var currentServer: (activeIndex >= 0 && activeIndex < servers.length)
                                         ? servers[activeIndex] : null
    readonly property bool hasServer: currentServer !== null
    property var api: apiClient

    // Pi-hole groups, shared by the adlist and domain editors
    readonly property var defaultGroups: [{ id: 0, name: "Default", enabled: true }]
    property var groups: defaultGroups

    Settings {
        id: store
        category: "pihole-manager"
        property string serversJson: "[]"
        property int activeIndex: 0
        property int refreshSecs: 10
    }

    Api { id: apiClient }

    // ---- persistence & server management ----------------------------------------

    function loadSettings() {
        var list = [];
        try { list = JSON.parse(store.serversJson); } catch (e) { list = []; }
        if (!Array.isArray(list)) list = [];
        servers = list;
        activeIndex = Math.max(0, Math.min(store.activeIndex, list.length - 1));
        refreshSecs = store.refreshSecs;
        applyServer();
    }

    function persist() {
        store.serversJson = JSON.stringify(servers);
        store.activeIndex = activeIndex;
        store.refreshSecs = refreshSecs;
    }

    function applyServer() {
        apiClient.configure(hasServer ? currentServer.url : "", hasServer ? currentServer.password : "");
        groups = defaultGroups;
        dashboardView.reset();
        queriesView.reset();
        domainsView.reset();
        settingsView.reset();
        refreshCurrent();
    }

    function saveServer(index, server) {
        var list = servers.slice();
        if (index >= 0 && index < list.length) {
            list[index] = server;
        } else {
            list.push(server);
            index = list.length - 1;
        }
        servers = list;
        activeIndex = index;
        persist();
        applyServer();
    }

    function removeServer(index) {
        var list = servers.slice();
        list.splice(index, 1);
        servers = list;
        if (index < activeIndex) activeIndex--;
        if (activeIndex >= list.length) activeIndex = list.length - 1;
        if (activeIndex < 0) activeIndex = 0;
        persist();
        applyServer();
    }

    function selectServer(index) {
        if (index === activeIndex) return;
        activeIndex = index;
        persist();
        applyServer();
    }

    function setRefreshSecs(secs) {
        refreshSecs = secs;
        persist();
    }

    function refreshCurrent() {
        if (!hasServer) return;
        switch (sections.selectedIndex) {
        case 0: dashboardView.refresh(); break;
        case 1: queriesView.refresh(); break;
        case 2: domainsView.refresh(); break;
        case 3: settingsView.refresh(); break;
        }
    }

    function toast(message, isError) {
        toastItem.show(message, isError === true);
    }

    // ---- dialogs / shared actions ---------------------------------------------

    function openServerDialog(index) {
        var props = { editIndex: index };
        if (index >= 0 && index < servers.length) props.server = servers[index];
        var d = PopupUtils.open(serverDialog, root, props);
        d.saved.connect(function(i, s) { root.saveServer(i, s); });
    }

    function confirmRemoveServer(index) {
        var name = servers[index] ? servers[index].name : "";
        var d = PopupUtils.open(confirmDialog, root, {
            title: i18n.tr("Remove Pi-hole?"),
            text: i18n.tr("“%1” will be removed from this app. Nothing changes on the Pi-hole itself.").arg(name),
            confirmText: i18n.tr("Remove"),
            destructive: true
        });
        d.confirmed.connect(function() { root.removeServer(index); });
    }

    function confirmAction(title, text, confirmText, onConfirmed) {
        var d = PopupUtils.open(confirmDialog, root, { title: title, text: text, confirmText: confirmText });
        d.confirmed.connect(onConfirmed);
    }

    function openDisableDialog(dashboard) {
        var d = PopupUtils.open(disableDialog, root);
        d.chosen.connect(function(seconds) { dashboard.setBlocking(false, seconds); });
    }

    function openAddDomain(props) {
        var d = PopupUtils.open(addDomainDialog, root, props || {});
        d.submitted.connect(function(type, kind, domain, comment) {
            root.addDomain(type, kind, domain, comment);
        });
    }

    function openQueryFilterDialog(filters, suggestions) {
        return PopupUtils.open(queryFilterDialog, root, { filters: filters, suggestions: suggestions });
    }

    function openQueryDetail(query) {
        return PopupUtils.open(queryDetailDialog, root, { app: root, query: query });
    }

    // Offered when tapping a domain in a top list.
    function domainActions(domain) {
        PopupUtils.open(domainActionDialog, root, { domain: domain });
    }

    function addDomain(type, kind, domain, comment) {
        var body = { domain: domain, comment: comment || i18n.tr("Added from Pi-hole Manager"), enabled: true };
        apiClient.call("POST", "/domains/" + type + "/" + kind, body, function(err, data) {
            if (err) { toast(err.message, true); return; }
            var problem = processedError(data);
            if (problem !== "") { toast(problem, true); return; }
            toast(type === "deny" ? i18n.tr("Blocked %1").arg(domain) : i18n.tr("Allowed %1").arg(domain), false);
            if (sections.selectedIndex === 2) domainsView.refresh();
        });
    }

    // First error Pi-hole reported in a create/update response ("" when there was none).
    function processedError(data) {
        var errors = (data && data.processed && data.processed.errors) ? data.processed.errors : [];
        if (errors.length === 0) return "";
        return errors[0].error || i18n.tr("Pi-hole rejected that entry");
    }

    function refreshGroups() {
        if (!hasServer) return;
        apiClient.call("GET", "/groups", null, function(err, data) {
            if (!err && data && data.groups && data.groups.length > 0) groups = data.groups;
        });
    }

    function openDomainEditDialog(item, onSubmitted) {
        var d = PopupUtils.open(domainEditDialog, root, { item: item, groups: groups });
        d.submitted.connect(onSubmitted);
        return d;
    }

    function openAdlistDialog(props, onSubmitted) {
        var d = PopupUtils.open(adlistDialog, root, props || {});
        d.submitted.connect(onSubmitted);
        return d;
    }

    // POST an action endpoint (gravity, restart DNS, …) with a modal spinner.
    function runAction(busyLabel, path, doneText, timeoutMs, onDone) {
        busyText = busyLabel;
        apiClient.call("POST", path, null, function(err) {
            busyText = "";
            if (err) toast(err.message, true);
            else toast(doneText, false);
            if (onDone) onDone(err);
        }, { raw: true, timeout: timeoutMs });
    }

    Component { id: serverDialog; ServerDialog {} }
    Component { id: confirmDialog; ConfirmDialog {} }
    Component { id: disableDialog; DisableDialog {} }
    Component { id: addDomainDialog; AddDomainDialog {} }
    Component { id: adlistDialog; AdlistDialog {} }
    Component { id: domainEditDialog; DomainEditDialog {} }
    Component { id: queryDetailDialog; QueryDetailDialog {} }
    Component { id: queryFilterDialog; QueryFilterDialog {} }

    Component {
        id: domainActionDialog
        Dialog {
            id: dlg
            property string domain: ""
            title: dlg.domain
            text: i18n.tr("What should Pi-hole do with this domain?")
            Button {
                text: i18n.tr("Block")
                color: theme.palette.normal.negative
                onClicked: { root.addDomain("deny", "exact", dlg.domain, ""); PopupUtils.close(dlg); }
            }
            Button {
                text: i18n.tr("Allow")
                color: theme.palette.normal.positive
                onClicked: { root.addDomain("allow", "exact", dlg.domain, ""); PopupUtils.close(dlg); }
            }
            Button {
                text: i18n.tr("Cancel")
                onClicked: PopupUtils.close(dlg)
            }
        }
    }

    // ---- UI -----------------------------------------------------------------------

    Page {
        id: mainPage

        header: PageHeader {
            id: pageHeader
            title: root.hasServer ? root.currentServer.name : i18n.tr("Pi-hole Manager")

            trailingActionBar.actions: [
                Action {
                    iconName: "add"
                    text: domainsView.listType === "adlists" ? i18n.tr("Add adlist") : i18n.tr("Add domain")
                    visible: sections.selectedIndex === 2 && root.hasServer
                    onTriggered: domainsView.addDomain()
                },
                Action {
                    iconName: "reload"
                    text: i18n.tr("Refresh")
                    visible: root.hasServer
                    onTriggered: root.refreshCurrent()
                }
            ]

            extension: Sections {
                id: sections
                objectName: "sections"
                anchors {
                    left: parent.left
                    leftMargin: units.gu(2)
                    bottom: parent.bottom
                }
                model: [i18n.tr("Dashboard"), i18n.tr("Queries"), i18n.tr("Lists"), i18n.tr("More")]
            }
        }

        Item {
            id: content
            anchors {
                top: pageHeader.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }

            DashboardView {
                id: dashboardView
                objectName: "dashboardView"
                anchors.fill: parent
                app: root
                active: sections.selectedIndex === 0
                visible: active
            }
            QueriesView {
                id: queriesView
                objectName: "queriesView"
                anchors.fill: parent
                app: root
                active: sections.selectedIndex === 1
                visible: active
            }
            DomainsView {
                id: domainsView
                objectName: "domainsView"
                anchors.fill: parent
                app: root
                active: sections.selectedIndex === 2
                visible: active
            }
            SettingsView {
                id: settingsView
                objectName: "settingsView"
                anchors.fill: parent
                app: root
                active: sections.selectedIndex === 3
                visible: active
            }

            // first-run screen
            Rectangle {
                anchors.fill: parent
                visible: !root.hasServer && sections.selectedIndex !== 3
                color: theme.palette.normal.background

                Column {
                    anchors.centerIn: parent
                    width: parent.width - units.gu(8)
                    spacing: units.gu(2)

                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: units.gu(14)
                        height: width
                        source: Qt.resolvedUrl("../assets/logo.svg")
                        sourceSize: Qt.size(width * 2, height * 2)
                    }
                    Label {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: i18n.tr("Connect to your Pi-hole to see your stats and control blocking.")
                    }
                    Button {
                        width: parent.width
                        text: i18n.tr("Add a Pi-hole")
                        color: theme.palette.normal.positive
                        onClicked: root.openServerDialog(-1)
                    }
                }
            }
        }
    }

    Toast { id: toastItem; objectName: "toast" }

    // modal spinner for long-running actions
    Rectangle {
        anchors.fill: parent
        visible: root.busyText !== ""
        color: "#99000000"

        MouseArea { anchors.fill: parent }   // swallow touches

        Column {
            anchors.centerIn: parent
            spacing: units.gu(2)
            ActivityIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: parent.visible
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.busyText
                color: "white"
            }
        }
    }

    Component.onCompleted: loadSettings()
    Component.onDestruction: apiClient.logout()
}
