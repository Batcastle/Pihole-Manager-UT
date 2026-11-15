import QtQuick 2.15
Text {
    enum TextSize { XxSmall, XSmall, Small, Medium, Large, XLarge }
    property int textSize: 3
    color: "#222"
    font.pixelSize: [8, 10, 12, 14, 18, 24][textSize]
}
