import QtQuick 2.15
Item {
    property string text
    property string placeholderText
    property int echoMode
    property int inputMethodHints
    signal accepted()
    implicitWidth: 200; implicitHeight: 32
}
