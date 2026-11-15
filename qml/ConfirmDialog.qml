import QtQuick 2.12
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3

Dialog {
    id: dlg

    property string confirmText: i18n.tr("OK")
    property bool destructive: false
    signal confirmed()

    Button {
        text: dlg.confirmText
        color: dlg.destructive ? theme.palette.normal.negative : theme.palette.normal.positive
        onClicked: {
            dlg.confirmed();
            PopupUtils.close(dlg);
        }
    }
    Button {
        text: i18n.tr("Cancel")
        onClicked: PopupUtils.close(dlg)
    }
}
