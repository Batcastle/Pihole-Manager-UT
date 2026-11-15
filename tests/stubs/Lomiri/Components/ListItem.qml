import QtQuick 2.15
Item {
    property var leadingActions
    property var trailingActions
    signal clicked()
    width: ListView.view ? ListView.view.width : 300
    MouseArea { anchors.fill: parent; z: -1; onClicked: parent.clicked() }
}
