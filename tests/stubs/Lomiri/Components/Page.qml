import QtQuick 2.15
Item { id: page; anchors.fill: parent; property Item header; onHeaderChanged: if (header) header.parent = page }
