import os, sys, shutil, json, tempfile, time
os.environ["QT_QPA_PLATFORM"] = "offscreen"
os.environ["QT_QUICK_BACKEND"] = "software"
tmp_home = tempfile.mkdtemp()
os.environ["HOME"] = tmp_home
os.environ["XDG_CONFIG_HOME"] = tmp_home + "/.config"

from PySide6.QtCore import QObject, Slot, QUrl, QCoreApplication, QTimer, qInstallMessageHandler, QtMsgType
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickView

sys.path.insert(0, os.path.dirname(__file__))
from mock_pihole import State, make_server

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
APP_QML = os.path.join(ROOT, "qml")
STUBS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "stubs")
work = tempfile.mkdtemp()
shutil.copytree(APP_QML, os.path.join(work, "qml")); shutil.copytree(os.path.join(ROOT, "assets"), os.path.join(work, "assets"))
shutil.copy(os.path.join(os.path.dirname(__file__), "Harness.qml"), os.path.join(work, "qml", "Harness.qml"))

warnings = []
def handler(mode, ctx, msg):
    if mode in (QtMsgType.QtWarningMsg, QtMsgType.QtCriticalMsg, QtMsgType.QtFatalMsg):
        warnings.append(msg)
        print("QTWARN:", msg)
    else:
        print(msg)
qInstallMessageHandler(handler)

s_v6 = State(); s_v5 = State(mode="v5"); s_np = State(mode="nopass")
srv = make_server(s_v6); srv5 = make_server(s_v5); srvnp = make_server(s_np)
import socket
dead = socket.socket(); dead.bind(("127.0.0.1", 0)); dead_port = dead.getsockname()[1]; dead.close()

class Units(QObject):
    @Slot(float, result=float)
    def gu(self, v): return v * 8
    @Slot(float, result=float)
    def dp(self, v): return v * 1.0

class I18n(QObject):
    @Slot(str, result=str)
    def tr(self, s): return s

class Bridge(QObject):
    @Slot(result=int)
    def port(self): return srv.server_address[1]
    @Slot(result=int)
    def v5port(self): return srv5.server_address[1]
    @Slot(result=int)
    def nopassport(self): return srvnp.server_address[1]
    @Slot(result=int)
    def deadport(self): return dead_port
    @Slot(result=int)
    def logins(self): return s_v6.logins
    @Slot()
    def expire(self): s_v6.sessions.clear()
    @Slot(str, result=int)
    def reqCount(self, sub): return sum(1 for m, p, _ in s_v6.log if sub in p)
    @Slot(result=int)
    def domainCount(self): return len(s_v6.domains)
    @Slot(result=str)
    def blockingState(self): return s_v6.blocking
    @Slot(str, str, result=int)
    def reqCountM(self, method, sub): return sum(1 for m, p, _ in s_v6.log if m == method and sub in p)
    @Slot(bool)
    def setSensorsFail(self, v): s_v6.sensors_fail = v
    @Slot(str)
    def setUpdateMode(self, m): s_v6.update_mode = m
    @Slot(str, result=str)
    def domainRec(self, name):
        for d in s_v6.domains:
            if d["domain"] == name:
                return json.dumps(d)
        return ""
    @Slot(result=int)
    def adlistCount(self): return len(s_v6.lists)
    @Slot(str, result=str)
    def adlist(self, addr):
        for l in s_v6.lists:
            if l["address"] == addr:
                return json.dumps(l)
        return ""

app = QGuiApplication(sys.argv)
QCoreApplication.setOrganizationName("t"); QCoreApplication.setApplicationName("t")

view = QQuickView()
view.engine().addImportPath(STUBS)
ctx = view.rootContext()
units, i18n, bridge = Units(), I18n(), Bridge()
ctx.setContextProperty("units", units)
ctx.setContextProperty("i18n", i18n)
ctx.setContextProperty("T", bridge)
pal = {"background": "#f5f5f5", "backgroundText": "#111", "backgroundSecondaryText": "#555", "backgroundTertiaryText": "#888",
       "foreground": "#e6e6e6", "base": "#cccccc", "positive": "#3eb34f", "negative": "#ed3146", "negativeText": "#ffffff",
       "activity": "#19b6ee", "overlay": "#333333", "overlayText": "#ffffff"}
ctx.setContextProperty("theme", {"palette": {"normal": pal}})
view.setSource(QUrl.fromLocalFile(os.path.join(work, "qml", "Harness.qml")))
if view.status() != QQuickView.Ready:
    print("LOAD ERRORS:", [e.toString() for e in view.errors()]); sys.exit(2)
view.resize(450, 900)
view.show()

shots = os.path.join(tempfile.gettempdir(), "pihole-manager-shots")
os.makedirs(shots, exist_ok=True)
result = {"failures": None}
root = view.rootObject()
def on_snapshot(name):
    QTimer.singleShot(0, lambda: view.grabWindow().save(os.path.join(shots, name + ".png")))
root.snapshot.connect(on_snapshot)
def on_finished(f):
    result["failures"] = f
    QTimer.singleShot(500, app.quit)
root.finished.connect(on_finished)
QTimer.singleShot(40000, lambda: (print("TIMEOUT"), app.quit()))
app.exec()
print("logins:", s_v6.logins, "requests:", len(s_v6.log))
print("failures:", result["failures"], "qt warnings:", len(warnings))
sys.exit(0 if result["failures"] == 0 else 1)
