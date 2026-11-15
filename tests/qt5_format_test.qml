import QtQuick 2.12
import "../qml/Format.js" as Fmt

// Run with the Qt 5 qmlscene (same JS engine as Ubuntu Touch):
//   qmlscene tests/qt5_format_test.qml
Item {
    Component.onCompleted: {
        var ok = Fmt.num(1234567) === "1,234,567" && Fmt.num(987654) === "987,654"
              && Fmt.num(1000) === "1,000" && Fmt.num(12) === "12" && Fmt.num(-12345) === "-12,345"
              && Fmt.pct(19.0001) === "19.0%" && Fmt.countdown(272) === "4:32"
              && Fmt.isBlocked("GRAVITY") && !Fmt.isBlocked("FORWARDED");
        console.log(ok ? "FORMAT TEST PASS" : "FORMAT TEST FAIL: " + Fmt.num(1234567));
        Qt.quit();
    }
}
