import QtQuick 2.12
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3

// Tells the user that their Pi-hole has updates and points them to the Pi-hole documentation.
// The app cannot (and deliberately does not try to) run the update itself.
//   info:   result of Fmt.updateInfo()
//   server: name of the Pi-hole
Dialog {
    id: dlg

    property var info: ({ components: [], docker: false, url: "" })
    property string serverName: ""
    // "Dismiss" asks Main to remember that this set of updates has been seen
    signal dismissed()
    // emitted when the dialog goes away for any reason
    signal gone()
    Component.onDestruction: gone()

    readonly property var names: ({
        core: i18n.tr("Pi-hole core"), web: i18n.tr("Web interface"), ftl: i18n.tr("FTL (DNS engine)"),
        docker: i18n.tr("Docker image")
    })

    title: i18n.tr("Pi-hole update available")
    text: dlg.serverName !== ""
          ? i18n.tr("\"%1\" is running older software than the latest Pi-hole release.").arg(dlg.serverName)
          : i18n.tr("Your Pi-hole is running older software than the latest release.")

    Column {
        width: parent.width
        spacing: units.gu(0.8)

        Repeater {
            model: dlg.info.components
            delegate: Item {
                width: parent.width
                height: units.gu(3)
                Label {
                    anchors { left: parent.left; right: versions.left; rightMargin: units.gu(1); verticalCenter: parent.verticalCenter }
                    text: dlg.names[modelData.key] || modelData.key
                    elide: Text.ElideRight
                }
                Label {
                    id: versions
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: modelData.local + "  →  " + modelData.remote
                    textSize: Label.Small
                    color: theme.palette.normal.backgroundSecondaryText
                }
            }
        }

        Label {
            width: parent.width
            wrapMode: Text.WordWrap
            textSize: Label.Small
            color: theme.palette.normal.backgroundSecondaryText
            text: dlg.info.docker
                  ? i18n.tr("This Pi-hole runs in Docker, so it is updated by pulling a new image. The Pi-hole documentation explains how.")
                  : i18n.tr("Updates are run on the Pi-hole itself (usually with \"pihole -up\" over SSH). This app can't do it for you; the Pi-hole documentation explains how.")
        }
    }

    Button {
        text: i18n.tr("Open update guide")
        color: theme.palette.normal.positive
        onClicked: Qt.openUrlExternally(dlg.info.url)
    }
    Button {
        text: i18n.tr("Dismiss")
        onClicked: {
            dlg.dismissed();
            PopupUtils.close(dlg);
        }
    }
}
