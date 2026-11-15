import QtQuick 2.15
Rectangle {
    id: b
    property string text
    property color strokeColor
    signal clicked()
    implicitWidth: 120; implicitHeight: 36; radius: 6; color: "#ddd"
    property bool enabledFlag: enabled
    opacity: enabled ? 1 : 0.4
    Text { anchors.centerIn: parent; text: b.text }
    MouseArea { anchors.fill: parent; onClicked: b.clicked() }
}
