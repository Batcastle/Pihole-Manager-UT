import QtQuick 2.12
import Lomiri.Components 1.3

Rectangle {
    id: tile

    property string title: ""
    property string value: ""
    property color accent: theme.palette.normal.backgroundText

    height: units.gu(11)
    radius: units.gu(1.5)
    color: theme.palette.normal.foreground

    Rectangle {
        width: units.gu(0.5)
        height: parent.height - units.gu(3)
        radius: width / 2
        color: tile.accent
        anchors {
            left: parent.left
            leftMargin: units.gu(1)
            verticalCenter: parent.verticalCenter
        }
    }

    Column {
        spacing: units.gu(0.5)
        anchors {
            left: parent.left
            right: parent.right
            leftMargin: units.gu(2.5)
            rightMargin: units.gu(1)
            verticalCenter: parent.verticalCenter
        }

        Label {
            width: parent.width
            text: tile.title
            textSize: Label.Small
            elide: Text.ElideRight
            color: theme.palette.normal.backgroundSecondaryText
        }
        Label {
            width: parent.width
            text: tile.value
            textSize: Label.Large
            font.bold: true
            elide: Text.ElideRight
            color: tile.accent
        }
    }
}
