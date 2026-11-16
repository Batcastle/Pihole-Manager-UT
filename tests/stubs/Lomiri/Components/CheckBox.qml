import QtQuick 2.15
Rectangle {
    id: c
    property bool checked: false
    signal clicked()
    width: 24; height: 24; border.width: 1; color: checked ? "#3eb34f" : "white"
    MouseArea { anchors.fill: parent; onClicked: { c.checked = !c.checked; c.clicked(); } }
}
