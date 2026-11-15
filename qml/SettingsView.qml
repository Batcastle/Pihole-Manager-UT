import QtQuick 2.12
import Lomiri.Components 1.3
import "Format.js" as Fmt

// "More" tab: servers, refresh interval, maintenance tools, about.
Item {
    id: view

    property var app
    property bool active: false
    property string versionText: ""

    function reset() { versionText = ""; }

    function refresh() {
        if (!app || !app.hasServer) { versionText = ""; return; }
        app.api.call("GET", "/info/version", null, function(err, data) {
            if (err || !data || !data.version) { versionText = ""; return; }
            function v(part) {
                try { return data.version[part].local.version || "?"; } catch (e) { return "?"; }
            }
            versionText = "Core " + v("core") + " · Web " + v("web") + " · FTL " + v("ftl");
        });
    }

    onActiveChanged: if (active) refresh()

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.height + units.gu(4)
        clip: true

        Column {
            id: col
            y: units.gu(2)
            width: Math.min(flick.width - units.gu(3), units.gu(80))
            x: (flick.width - width) / 2
            spacing: units.gu(1.5)

            // ---- servers --------------------------------------------------
            Label {
                text: i18n.tr("Pi-holes")
                font.bold: true
                textSize: Label.Large
            }

            Repeater {
                model: view.app ? view.app.servers : []
                delegate: Rectangle {
                    id: card
                    readonly property bool isActive: index === view.app.activeIndex
                    width: col.width
                    height: units.gu(9)
                    radius: units.gu(1.5)
                    color: theme.palette.normal.foreground
                    border.width: isActive ? units.dp(2) : 0
                    border.color: theme.palette.normal.positive

                    MouseArea {
                        anchors.fill: parent
                        onClicked: view.app.selectServer(index)
                    }

                    Column {
                        anchors {
                            left: parent.left
                            leftMargin: units.gu(2)
                            right: buttons.left
                            rightMargin: units.gu(1)
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: units.gu(0.4)
                        Label {
                            width: parent.width
                            text: modelData.name
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Label {
                            width: parent.width
                            text: Fmt.hostOf(modelData.url)
                            textSize: Label.Small
                            elide: Text.ElideRight
                            color: theme.palette.normal.backgroundSecondaryText
                        }
                        Label {
                            visible: card.isActive
                            text: i18n.tr("In use")
                            textSize: Label.Small
                            color: theme.palette.normal.positive
                        }
                    }

                    Row {
                        id: buttons
                        spacing: units.gu(0.5)
                        anchors { right: parent.right; rightMargin: units.gu(1); verticalCenter: parent.verticalCenter }

                        AbstractButton {
                            width: units.gu(5); height: units.gu(5)
                            onClicked: view.app.openServerDialog(index)
                            Icon { anchors.centerIn: parent; width: units.gu(2.5); height: width; name: "edit" }
                        }
                        AbstractButton {
                            width: units.gu(5); height: units.gu(5)
                            onClicked: view.app.confirmRemoveServer(index)
                            Icon { anchors.centerIn: parent; width: units.gu(2.5); height: width; name: "delete" }
                        }
                    }
                }
            }

            Button {
                width: parent.width
                text: i18n.tr("Add a Pi-hole")
                color: theme.palette.normal.positive
                onClicked: view.app.openServerDialog(-1)
            }

            // ---- refresh interval -----------------------------------------
            Item { width: parent.width; height: units.gu(1) }
            Label {
                text: i18n.tr("Auto-refresh")
                font.bold: true
                textSize: Label.Large
            }
            Row {
                width: parent.width
                spacing: units.gu(0.8)
                Repeater {
                    model: [0, 5, 10, 30, 60]
                    delegate: Button {
                        width: (col.width - 4 * units.gu(0.8)) / 5
                        text: modelData === 0 ? i18n.tr("Off") : modelData + "s"
                        color: view.app.refreshSecs === modelData ? theme.palette.normal.activity : theme.palette.normal.base
                        onClicked: view.app.setRefreshSecs(modelData)
                    }
                }
            }

            // ---- tools ----------------------------------------------------
            Item { width: parent.width; height: units.gu(1) }
            Label {
                text: i18n.tr("Maintenance")
                font.bold: true
                textSize: Label.Large
            }
            Button {
                width: parent.width
                text: i18n.tr("Update gravity (blocklists)")
                enabled: view.app.hasServer
                onClicked: view.app.confirmAction(
                    i18n.tr("Update gravity?"),
                    i18n.tr("Pi-hole will download all blocklists again. This can take a minute."),
                    i18n.tr("Update"),
                    function() { view.app.runAction(i18n.tr("Updating gravity…"), "/action/gravity", i18n.tr("Gravity updated"), 240000); })
            }
            Button {
                width: parent.width
                text: i18n.tr("Restart DNS service")
                enabled: view.app.hasServer
                onClicked: view.app.confirmAction(
                    i18n.tr("Restart DNS?"),
                    i18n.tr("DNS lookups on your network will briefly stop working."),
                    i18n.tr("Restart"),
                    function() { view.app.runAction(i18n.tr("Restarting DNS…"), "/action/restartdns", i18n.tr("DNS restarted"), 30000); })
            }
            Button {
                width: parent.width
                text: i18n.tr("Flush query log")
                enabled: view.app.hasServer
                onClicked: view.app.confirmAction(
                    i18n.tr("Flush the query log?"),
                    i18n.tr("This clears today's log on the Pi-hole. Long-term statistics stay."),
                    i18n.tr("Flush"),
                    function() { view.app.runAction(i18n.tr("Flushing…"), "/action/flush/logs", i18n.tr("Log flushed"), 30000); })
            }

            // ---- about ----------------------------------------------------
            Item { width: parent.width; height: units.gu(1) }
            Label {
                text: i18n.tr("About")
                font.bold: true
                textSize: Label.Large
            }
            Label {
                width: parent.width
                wrapMode: Text.WordWrap
                visible: view.versionText !== ""
                text: view.versionText
                color: theme.palette.normal.backgroundSecondaryText
            }
            Label {
                width: parent.width
                wrapMode: Text.WordWrap
                textSize: Label.Small
                color: theme.palette.normal.backgroundSecondaryText
                text: i18n.tr("Pi-hole Manager 0.1.0. Works with Pi-hole v6. Passwords are stored on this device, in this app's private storage. If your Pi-hole uses two-factor authentication, create an app password in its web interface and use that.")
            }
        }
    }
}
