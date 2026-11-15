import QtQuick 2.12
import Lomiri.Components 1.3

// Small transient message at the bottom of the screen.
Rectangle {
    id: toast

    function show(message, isError) {
        label.text = message;
        color = isError ? theme.palette.normal.negative : theme.palette.normal.overlay;
        label.color = isError ? theme.palette.normal.negativeText : theme.palette.normal.overlayText;
        opacity = 1;
        hideTimer.restart();
    }

    opacity: 0
    visible: opacity > 0
    radius: units.gu(1)
    width: Math.min(parent.width - units.gu(4), label.implicitWidth + units.gu(4))
    height: label.paintedHeight + units.gu(2.5)
    anchors {
        horizontalCenter: parent.horizontalCenter
        bottom: parent.bottom
        bottomMargin: units.gu(3)
    }

    Behavior on opacity { NumberAnimation { duration: 200 } }

    Label {
        id: label
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            margins: units.gu(2)
        }
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
    }

    Timer {
        id: hideTimer
        interval: 4000
        onTriggered: toast.opacity = 0
    }
}
