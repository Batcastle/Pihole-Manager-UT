import QtQuick 2.12
import Lomiri.Components 1.3
import "Format.js" as Fmt

// Stacked bars of queries over time, one colour per client, with a legend.
// Tap or drag across the bars to see the numbers for one time slot.
//   series: [{ name, total, color }]            (from Fmt.clientSeries)
//   slots:  [{ timestamp, total, values: [] }]
Rectangle {
    id: chart

    property string title: ""
    property var series: []
    property var slots: []
    property int selected: -1

    height: content.height + units.gu(3)
    radius: units.gu(1.5)
    color: theme.palette.normal.foreground

    onSlotsChanged: { selected = -1; canvas.requestPaint(); }
    onSeriesChanged: canvas.requestPaint()

    readonly property string tooltip: {
        if (selected < 0 || selected >= slots.length) return i18n.tr("Last 24 hours, by client");
        var s = slots[selected];
        return Fmt.clock(s.timestamp) + "  ·  " + i18n.tr("%1 queries").arg(Fmt.num(s.total));
    }

    function valueFor(index) {
        if (selected >= 0 && selected < slots.length) return slots[selected].values[index] || 0;
        return series[index] ? series[index].total : 0;
    }

    Column {
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: units.gu(1.5) }
        spacing: units.gu(1)

        Label {
            width: parent.width
            text: chart.title
            visible: text !== ""
            font.bold: true
        }
        Label {
            width: parent.width
            text: chart.tooltip
            textSize: Label.Small
            elide: Text.ElideRight
            color: theme.palette.normal.backgroundSecondaryText
        }

        Canvas {
            id: canvas
            width: parent.width
            height: units.gu(18)

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                var d = chart.slots, n = d.length;
                if (n === 0) return;
                var max = 1, i;
                for (i = 0; i < n; i++) max = Math.max(max, d[i].total || 0);
                var bw = width / n, gap = bw > 3 ? 1 : 0;
                for (i = 0; i < n; i++) {
                    var y = height, x = i * bw;
                    for (var k = 0; k < chart.series.length; k++) {
                        var v = d[i].values[k] || 0;
                        if (v <= 0) continue;
                        var h = (v / max) * height;
                        y -= h;
                        ctx.fillStyle = chart.series[k].color;
                        ctx.globalAlpha = (chart.selected < 0 || chart.selected === i) ? 1 : 0.45;
                        ctx.fillRect(x, y, Math.max(1, bw - gap), h);
                    }
                }
                ctx.globalAlpha = 1;
            }

            MouseArea {
                anchors.fill: parent
                function pick(mouse) {
                    var n = chart.slots.length;
                    if (n === 0) return;
                    chart.selected = Math.max(0, Math.min(n - 1, Math.floor(mouse.x / (width / n))));
                    canvas.requestPaint();
                }
                onPressed: pick(mouse)
                onPositionChanged: pick(mouse)
            }
        }

        Column {
            width: parent.width
            spacing: units.gu(0.5)
            Repeater {
                model: chart.series
                delegate: Item {
                    width: parent.width
                    height: units.gu(2.6)
                    Rectangle {
                        id: swatch
                        width: units.gu(1.4); height: width; radius: width / 2
                        color: modelData.color
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    }
                    Label {
                        anchors { left: swatch.right; leftMargin: units.gu(1); right: count.left; rightMargin: units.gu(1); verticalCenter: parent.verticalCenter }
                        text: modelData.name
                        elide: Text.ElideRight
                        textSize: Label.Small
                    }
                    Label {
                        id: count
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: Fmt.num(chart.valueFor(index))
                        textSize: Label.Small
                        color: theme.palette.normal.backgroundSecondaryText
                    }
                }
            }
        }
    }
}
