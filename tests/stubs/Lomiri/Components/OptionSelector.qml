import QtQuick 2.15
Rectangle {
    id: o
    property string text
    property var model: []
    property int selectedIndex: 0
    property bool expanded: false
    signal delegateClicked(int index)
    implicitWidth: 200; implicitHeight: 40; color: "#eee"
}
