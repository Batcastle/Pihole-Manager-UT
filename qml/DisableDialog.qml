import QtQuick 2.12
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3

Dialog {
    id: dlg

    title: i18n.tr("Disable blocking")
    text: i18n.tr("For how long?")

    // seconds; 0 means "until I turn it back on"
    signal chosen(int seconds)

    function pick(seconds) {
        dlg.chosen(seconds);
        PopupUtils.close(dlg);
    }

    Button { text: i18n.tr("30 seconds"); onClicked: dlg.pick(30) }
    Button { text: i18n.tr("5 minutes"); onClicked: dlg.pick(300) }
    Button { text: i18n.tr("30 minutes"); onClicked: dlg.pick(1800) }
    Button { text: i18n.tr("1 hour"); onClicked: dlg.pick(3600) }
    Button {
        text: i18n.tr("Until I turn it back on")
        color: theme.palette.normal.negative
        onClicked: dlg.pick(0)
    }

    TextField {
        id: custom
        placeholderText: i18n.tr("Custom time in minutes")
        inputMethodHints: Qt.ImhDigitsOnly
    }
    Button {
        text: i18n.tr("Disable for custom time")
        enabled: parseInt(custom.text) > 0
        onClicked: dlg.pick(parseInt(custom.text) * 60)
    }

    Button { text: i18n.tr("Cancel"); onClicked: PopupUtils.close(dlg) }
}
