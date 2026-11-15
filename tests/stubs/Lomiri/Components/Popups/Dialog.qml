import QtQuick 2.15
Item {
    id: d
    property string title
    property string text
    default property alias contents: col.data
    Column { id: col; width: 300 }
}
