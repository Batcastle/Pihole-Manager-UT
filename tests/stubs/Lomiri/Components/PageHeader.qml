import QtQuick 2.15
Item {
    property string title
    property ActionBar trailingActionBar: ActionBar {}
    property Item extension
    onExtensionChanged: if (extension) extension.parent = this
    width: parent ? parent.width : 400
    height: 56
}
