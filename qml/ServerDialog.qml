import QtQuick 2.12
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3

Dialog {
    id: dlg

    // -1 = adding a new server
    property int editIndex: -1
    property var server: ({ name: "", url: "", password: "" })
    property string testResult: ""
    property bool testOk: false

    signal saved(int index, var server)

    title: editIndex >= 0 ? i18n.tr("Edit Pi-hole") : i18n.tr("Add a Pi-hole")

    Api { id: testApi }

    function runTest() {
        testApi.configure(urlField.text, passField.text);
        testOk = false;
        testResult = i18n.tr("Connecting…");
        testApi.call("GET", "/info/version", null, function(err, data) {
            if (err) {
                testOk = false;
                testResult = err.message;
            } else {
                var v = "";
                try { v = data.version.core.local.version; } catch (e) {}
                testOk = true;
                testResult = i18n.tr("Connected") + (v ? " — Pi-hole " + v : "");
            }
            testApi.logout();
        });
    }

    function save() {
        var url = testApi.normalizeUrl(urlField.text);
        var name = nameField.text.trim();
        if (name === "") name = url.replace(/^https?:\/\//i, "");
        dlg.saved(editIndex, { name: name, url: url, password: passField.text });
        PopupUtils.close(dlg);
    }

    TextField {
        id: nameField
        placeholderText: i18n.tr("Name (e.g. Home)")
        text: dlg.server.name
    }
    TextField {
        id: urlField
        placeholderText: i18n.tr("Address (e.g. pi.hole)")
        text: dlg.server.url
        inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
    }
    TextField {
        id: passField
        placeholderText: i18n.tr("Password or app password")
        echoMode: TextInput.Password
        text: dlg.server.password
        onAccepted: if (urlField.text.trim() !== "") dlg.save()
    }

    Label {
        visible: dlg.testResult !== ""
        width: parent.width
        wrapMode: Text.WordWrap
        text: dlg.testResult
        color: dlg.testOk ? theme.palette.normal.positive : theme.palette.normal.negative
    }

    Button {
        text: i18n.tr("Test connection")
        enabled: urlField.text.trim() !== ""
        onClicked: dlg.runTest()
    }
    Button {
        text: i18n.tr("Save")
        color: theme.palette.normal.positive
        enabled: urlField.text.trim() !== ""
        onClicked: dlg.save()
    }
    Button {
        text: i18n.tr("Cancel")
        onClicked: PopupUtils.close(dlg)
    }
}
