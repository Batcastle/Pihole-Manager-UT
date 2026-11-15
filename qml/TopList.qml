import QtQuick 2.12
import Lomiri.Components 1.3
import "Format.js" as Fmt

// A card with a title and up to N rows, each with a proportional bar.
Rectangle {
    id: card

    property string title: ""
    property var items: []
    property string nameKey: "domain"
    property string altKey: ""          // used when the name is empty (e.g. client IP)
    property color barColor: theme.palette.normal.positive
    property bool clickable: false
    property real percentOf: 0          // when > 0, rows also show their share of this total
    signal itemClicked(var item)

    height: head.height + rows.height + units.gu(3.5)
    radius: units.gu(1.5)
    color: theme.palette.normal.foreground

    readonly property real maxCount: {
        var m = 1;
        for (var i = 0; i < items.length; i++)
            m = Math.max(m, items[i].count || 0);
        return m;
    }

    function displayName(item) {
        var n = item[nameKey];
        if ((n === undefined || n === null || n === "") && altKey !== "")
            n = item[altKey];
        return (n === undefined || n === null || n === "") ? "?" : n;
    }

    Label {
        id: head
        text: card.title
        font.bold: true
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: units.gu(1.5)
        }
    }

    Column {
        id: rows
        anchors {
            left: parent.left
            right: parent.right
            top: head.bottom
            leftMargin: units.gu(1)
            rightMargin: units.gu(1)
            topMargin: units.gu(1)
        }

        Label {
            visible: card.items.length === 0
            width: parent.width
            height: units.gu(4)
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            text: i18n.tr("Nothing yet")
            color: theme.palette.normal.backgroundSecondaryText
        }

        Repeater {
            model: card.items
            delegate: Item {
                width: rows.width
                height: units.gu(4.5)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height - units.gu(0.6)
                    width: parent.width * ((modelData.count || 0) / card.maxCount)
                    radius: units.gu(0.6)
                    color: card.barColor
                    opacity: 0.22
                }
                Label {
                    anchors {
                        left: parent.left
                        leftMargin: units.gu(1)
                        right: countLabel.left
                        rightMargin: units.gu(1)
                        verticalCenter: parent.verticalCenter
                    }
                    text: card.displayName(modelData)
                    elide: Text.ElideMiddle
                    textSize: Label.Small
                }
                Label {
                    id: countLabel
                    anchors {
                        right: parent.right
                        rightMargin: units.gu(1)
                        verticalCenter: parent.verticalCenter
                    }
                    text: Fmt.num(modelData.count) + (card.percentOf > 0 ? "  ·  " + Fmt.pct(100 * (modelData.count || 0) / card.percentOf) : "")
                    textSize: Label.Small
                    font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: card.clickable
                    onClicked: card.itemClicked(modelData)
                }
            }
        }
    }
}
