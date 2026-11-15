import QtQuick 2.15
Item { signal clicked(); MouseArea { anchors.fill: parent; onClicked: parent.clicked() } }
