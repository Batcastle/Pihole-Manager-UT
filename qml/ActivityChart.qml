import QtQuick 2.12
import Lomiri.Components 1.3
import "Format.js" as Fmt

// Stacked bars of permitted vs blocked queries over time.
// points: [{ timestamp, total, cached, blocked, forwarded }, ...]
Rectangle {
    id: chart

    property var points: []
    property int selected: -1

    height: units.gu(24)
    radius: units.gu(1.5)
    color: theme.palette.normal.foreground

    onPointsChanged: { selected = -1; canvas.requestPaint(); }

    readonly property string tooltip: {
        if (selected < 0 || selected >= points.length) return i18n.tr("Queries over the last 24 hours");
        var p = points[selected];
        var blocked = p.blocked || 0;
        var allowed = Math.max(0, (p.total || 0) - blocked);
        return Fmt.clock(p.timestamp) + "  ·  " + Fmt.num(allowed) + " " + i18n.tr("allowed") + "  ·  " + Fmt.num(blocked) + " " + i18n.tr("blocked");
    }

    Label {
        id: caption
        text: chart.tooltip
        textSize: Label.Small
        elide: Text.ElideRight
        color: theme.palette.normal.backgroundSecondaryText
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: units.gu(1.5)
        }
    }

    Canvas {
        id: canvas
        anchors {
            left: parent.left
            right: parent.right
            top: caption.bottom
            bottom: parent.bottom
            margins: units.gu(1.5)
            topMargin: units.gu(1)
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            var d = chart.points;
            var n = d.length;
            if (n === 0) return;

            var max = 1;
            for (var i = 0; i < n; i++)
                max = Math.max(max, d[i].total || 0);

            var bw = width / n;
            var gap = bw > 3 ? 1 : 0;
            for (var j = 0; j < n; j++) {
                var total = d[j].total || 0;
                var blocked = Math.min(total, d[j].blocked || 0);
                var hTotal = (total / max) * height;
                var hBlocked = (blocked / max) * height;
                var x = j * bw;
                var selectedBar = (j === chart.selected);

                ctx.fillStyle = selectedBar ? theme.palette.normal.activity : theme.palette.normal.positive;
                ctx.fillRect(x, height - hTotal, Math.max(1, bw - gap), hTotal - hBlocked);
                ctx.fillStyle = theme.palette.normal.negative;
                ctx.fillRect(x, height - hBlocked, Math.max(1, bw - gap), hBlocked);
            }
        }

        MouseArea {
            anchors.fill: parent
            function pick(mouse) {
                var n = chart.points.length;
                if (n === 0) return;
                var i = Math.floor(mouse.x / (width / n));
                chart.selected = Math.max(0, Math.min(n - 1, i));
                canvas.requestPaint();
            }
            onPressed: pick(mouse)
            onPositionChanged: pick(mouse)
        }
    }
}
