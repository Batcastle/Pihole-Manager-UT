import QtQuick 2.15
Rectangle {
    id: s
    property bool checked: false
    signal clicked()
    width: 40; height: 22; radius: 11; color: checked ? "#3eb34f" : "#bbb"
    MouseArea { anchors.fill: parent; onClicked: { s.checked = !s.checked; s.clicked(); } }
}
