pragma Singleton
import QtQuick 2.15
QtObject {
    function open(comp, parent, props) { return comp.createObject(parent, props || {}); }
    function close(o) { o.destroy(); }
}
