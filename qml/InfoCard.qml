import QtQuick 2.12
import Lomiri.Components 1.3

// A card with a title and label / value rows.
Rectangle {
    id: card

    property string title: ""
    property var rows: []           // [{ label, value }]

    height: body.height + units.gu(3)
    radius: units.gu(1.5)
    color: theme.palette.normal.foreground

    Column {
        id: body
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: units.gu(1.5) }
        spacing: units.gu(0.8)

        Label {
            width: parent.width
            text: card.title
            font.bold: true
        }

        Repeater {
            model: card.rows
            delegate: Item {
                width: body.width
                height: Math.max(name.implicitHeight, value.implicitHeight)

                Label {
                    id: name
                    width: parent.width * 0.4
                    text: modelData.label
                    textSize: Label.Small
                    wrapMode: Text.WordWrap
                    color: theme.palette.normal.backgroundSecondaryText
                }
                Label {
                    id: value
                    anchors { left: name.right; leftMargin: units.gu(1); right: parent.right }
                    text: modelData.value
                    textSize: Label.Small
                    horizontalAlignment: Text.AlignRight
                    wrapMode: Text.WrapAnywhere
                }
            }
        }
    }
}
