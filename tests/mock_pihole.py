"""Mock Pi-hole v6 API server for testing the app's API layer."""
import json, threading, time, urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class State:
    def __init__(self, password="secret", mode="v6"):
        self.password = password
        self.mode = mode            # v6 | v5 | nopass
        self.sessions = set()
        self.logins = 0
        self.blocking = "enabled"
        self.timer = None
        self.log = []               # (method, path)
        self.domains = [
            {"domain": "ads.example.com", "type": "deny", "kind": "exact", "comment": "x", "groups": [0], "enabled": True, "id": 1},
            {"domain": "(\\.|^)tracker\\.net$", "type": "deny", "kind": "regex", "comment": None, "groups": [0], "enabled": False, "id": 2},
            {"domain": "good.example.org", "type": "allow", "kind": "exact", "comment": None, "groups": [0], "enabled": True, "id": 3},
        ]
        now = int(time.time())
        self.lists = [
            {"address": "https://example.com/hosts.txt", "type": "block", "comment": "Main list", "groups": [0], "enabled": True, "id": 1,
             "date_added": now - 90000, "date_modified": now - 90000, "date_updated": now - 7200, "number": 120345, "invalid_domains": 0, "abp_entries": 0, "status": 2},
            {"address": "https://bad.example.net/list?x=1&y=2", "type": "block", "comment": None, "groups": [0], "enabled": True, "id": 2,
             "date_added": now - 5000, "date_modified": now - 5000, "date_updated": 0, "number": 0, "invalid_domains": 0, "abp_entries": 0, "status": 4},
            {"address": "https://allow.example.org/allow.txt", "type": "allow", "comment": None, "groups": [0], "enabled": False, "id": 3,
             "date_added": now - 5000, "date_modified": now - 5000, "date_updated": now - 100, "number": 12, "invalid_domains": 0, "abp_entries": 0, "status": 1},
        ]
        self.groups = [{"name": "Default", "comment": None, "enabled": True, "id": 0}, {"name": "Kids", "comment": "children", "enabled": True, "id": 1}]
        self.next_id = 10
        self.lock = threading.Lock()


def make_server(state, port=0):
    class H(BaseHTTPRequestHandler):
        def log_message(self, *a):
            pass

        def _send(self, code, obj=None, raw=None):
            body = b""
            if raw is not None:
                body = raw.encode()
            elif obj is not None:
                body = json.dumps(obj).encode()
            self.send_response(code)
            self.send_header("Content-Type", "application/json" if raw is None else "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def _body(self):
            n = int(self.headers.get("Content-Length") or 0)
            if not n:
                return None
            try:
                return json.loads(self.rfile.read(n))
            except Exception:
                return None

        def _authed(self):
            if state.mode == "nopass":
                return True
            return self.headers.get("X-FTL-SID") in state.sessions

        def _handle(self, method):
            u = urllib.parse.urlparse(self.path)
            path, q = u.path, urllib.parse.parse_qs(u.query)
            body = self._body()
            with state.lock:
                state.log.append((method, self.path, self.headers.get("X-FTL-SID")))

            if state.mode == "v5":
                return self._send(404, {"error": "not found"})

            if path == "/api/auth":
                if method == "POST":
                    if state.mode == "nopass":
                        return self._send(200, {"session": {"valid": True, "totp": False, "sid": None, "csrf": None, "validity": -1}})
                    if body and body.get("password") == state.password:
                        with state.lock:
                            state.logins += 1
                            sid = "SID%d" % state.logins
                            state.sessions.add(sid)
                        return self._send(200, {"session": {"valid": True, "totp": False, "sid": sid, "csrf": "c", "validity": 300}})
                    return self._send(401, {"session": {"valid": False, "totp": False, "sid": None, "csrf": None, "validity": -1, "message": "password incorrect"}})
                if method == "DELETE":
                    state.sessions.discard(self.headers.get("X-FTL-SID"))
                    self.send_response(204); self.send_header("Content-Length", "0"); self.end_headers(); return

            if not self._authed():
                return self._send(401, {"error": {"key": "unauthorized", "message": "Unauthorized", "hint": None}})

            if path == "/api/stats/summary":
                return self._send(200, {"queries": {"total": 1234567, "blocked": 234567, "percent_blocked": 19.0001, "unique_domains": 4321, "forwarded": 5000, "cached": 6000, "frequency": 1.4,
                                                    "replies": {"IP": 5000, "NODATA": 400, "NXDOMAIN": 120, "CNAME": 0, "SERVFAIL": 3}},
                                        "clients": {"active": 7, "total": 9}, "gravity": {"domains_being_blocked": 987654, "last_update": 1}})
            if path == "/api/dns/blocking":
                if method == "POST":
                    en = body.get("blocking")
                    state.blocking = "enabled" if en else "disabled"
                    state.timer = body.get("timer") if not en else None
                return self._send(200, {"blocking": state.blocking, "timer": state.timer})
            if path == "/api/history":
                now = int(time.time())
                return self._send(200, {"history": [{"timestamp": now - (144 - i) * 600, "total": 50 + (i * 7) % 90, "cached": 10, "blocked": (i * 3) % 30, "forwarded": 20} for i in range(144)]})
            if path == "/api/stats/top_domains":
                blocked = q.get("blocked", ["false"])[0] == "true"
                names = ["ads.example.com", "tracker.net", "telemetry.foo"] if blocked else ["example.com", "good.example.org", "cdn.thing.io"]
                return self._send(200, {"domains": [{"domain": n, "count": 100 - i * 20} for i, n in enumerate(names)]})
            if path == "/api/stats/top_clients":
                return self._send(200, {"clients": [{"name": "laptop", "ip": "192.168.1.5", "count": 90}, {"name": "", "ip": "192.168.1.9", "count": 40}]})
            if path == "/api/queries/suggestions":
                return self._send(200, {"suggestions": {"domain": [], "client_ip": ["192.168.1.2", "192.168.1.3", "192.168.1.4"], "client_name": ["host1", "host2"],
                                                        "upstream": ["1.1.1.1#53"], "type": ["A", "AAAA"],
                                                        "status": ["GRAVITY", "FORWARDED", "CACHE", "REGEX", "DENYLIST"],
                                                        "reply": ["IP", "NODATA"], "dnssec": ["INSECURE", "UNKNOWN"]}})
            if path == "/api/queries":
                n = int(q.get("length", ["100"])[0])
                sts = ["GRAVITY", "FORWARDED", "CACHE", "REGEX", "DENYLIST"]
                list_ids = {"GRAVITY": 1, "REGEX": 2, "DENYLIST": 1}
                items = []
                for i in range(250):
                    st = sts[i % 5]
                    items.append({"id": i, "time": time.time() - i * 5, "type": "A" if i % 7 else "AAAA", "domain": "d%d.example.com" % i, "status": st,
                                  "client": {"ip": "192.168.1.%d" % (i % 3 + 2), "name": "host%d" % (i % 3) if i % 3 else None},
                                  "cname": None, "dnssec": "INSECURE" if i % 5 == 1 else "UNKNOWN",
                                  "reply": {"type": "IP", "time": 0.4 + i} if st != "CACHE" else {"type": "NODATA", "time": -1},
                                  "list_id": list_ids.get(st), "upstream": "1.1.1.1#53" if st == "FORWARDED" else None,
                                  "ede": {"code": -1, "text": None}})
                get = lambda k: q.get(k, [None])[0]
                items = [it for it in items
                         if (not get("status") or it["status"] == get("status"))
                         and (not get("type") or it["type"] == get("type"))
                         and (not get("client_ip") or it["client"]["ip"] == get("client_ip"))
                         and (not get("client_name") or it["client"]["name"] == get("client_name"))
                         and (not get("upstream") or it["upstream"] == get("upstream"))
                         and (not get("reply") or it["reply"]["type"] == get("reply"))
                         and (not get("dnssec") or it["dnssec"] == get("dnssec"))]
                return self._send(200, {"queries": items[:n], "recordsTotal": len(items)})
            if path in ("/api/domains/deny", "/api/domains/allow") and method == "GET":
                return self._send(200, {"domains": [d for d in state.domains if d["type"] == path.rsplit("/", 1)[1]]})
            if path == "/api/domains" and method == "GET":
                return self._send(200, {"domains": state.domains})
            if path.startswith("/api/domains/") and method == "POST":
                _, _, _, t, k = path.split("/")[:5]
                dom = body.get("domain")
                if any(d["domain"] == dom and d["type"] == t and d["kind"] == k for d in state.domains):
                    return self._send(201, {"domains": [], "processed": {"success": [], "errors": [{"item": dom, "error": "UNIQUE constraint failed: domainlist.domain, domainlist.type"}]}})
                state.next_id += 1
                state.domains.append({"domain": dom, "type": t, "kind": k, "comment": body.get("comment"), "groups": [0], "enabled": True, "id": state.next_id})
                return self._send(201, {"domains": [], "processed": {"success": [{"item": dom}], "errors": []}})
            if path.startswith("/api/domains/") and method == "PUT":
                parts = path.split("/")
                t, k, dom = parts[3], parts[4], urllib.parse.unquote("/".join(parts[5:]))
                found = [d for d in state.domains if d["domain"] == dom and d["type"] == t and d["kind"] == k]
                if not found:
                    return self._send(404, {"error": {"key": "not_found", "message": "Item not found", "hint": dom}})
                for key in ("comment", "groups", "enabled"):
                    if key in body:
                        found[0][key] = body[key]
                return self._send(200, {"domains": [found[0]], "processed": {"success": [{"item": dom}], "errors": []}})
            if path.startswith("/api/domains/") and method == "DELETE":
                parts = path.split("/")
                t, k, dom = parts[3], parts[4], urllib.parse.unquote("/".join(parts[5:]))
                before = len(state.domains)
                state.domains = [d for d in state.domains if not (d["domain"] == dom and d["type"] == t and d["kind"] == k)]
                if len(state.domains) == before:
                    return self._send(404, {"error": {"key": "not_found", "message": "Item not found", "hint": dom}})
                self.send_response(204); self.send_header("Content-Length", "0"); self.end_headers(); return
            if path == "/api/groups" and method == "GET":
                return self._send(200, {"groups": state.groups})
            if path == "/api/lists" and method == "GET":
                want = q.get("type", [None])[0]
                return self._send(200, {"lists": [l for l in state.lists if want in (None, l["type"])]})
            if path == "/api/lists" and method == "POST":
                t = q.get("type", ["block"])[0]
                addr = body.get("address")
                if any(l["address"] == addr and l["type"] == t for l in state.lists):
                    return self._send(201, {"lists": [], "processed": {"success": [], "errors": [{"item": addr, "error": "UNIQUE constraint failed: adlist.address, adlist.type"}]}})
                state.next_id += 1
                state.lists.append({"address": addr, "type": t, "comment": body.get("comment"), "groups": body.get("groups", [0]), "enabled": body.get("enabled", True),
                                    "id": state.next_id, "date_added": int(time.time()), "date_modified": int(time.time()), "date_updated": 0, "number": 0,
                                    "invalid_domains": 0, "abp_entries": 0, "status": 0})
                return self._send(201, {"lists": [], "processed": {"success": [{"item": addr}], "errors": []}})
            if path.startswith("/api/lists/") and method in ("PUT", "DELETE"):
                addr = urllib.parse.unquote(path[len("/api/lists/"):])
                t = q.get("type", [None])[0]
                found = [l for l in state.lists if l["address"] == addr and t in (None, l["type"])]
                if not found:
                    return self._send(404, {"error": {"key": "not_found", "message": "Item not found", "hint": addr}})
                if method == "DELETE":
                    state.lists.remove(found[0])
                    self.send_response(204); self.send_header("Content-Length", "0"); self.end_headers(); return
                for k in ("comment", "groups", "enabled"):
                    if k in body:
                        found[0][k] = body[k]
                return self._send(200, {"lists": [found[0]], "processed": {"success": [{"item": addr}], "errors": []}})
            if path == "/api/history/clients":
                ips = ["192.168.1.%d" % n for n in range(10, 17)]
                names = ["laptop", None, "phone", "tv", None, "printer", "nas"]
                now = int(time.time()) // 300 * 300
                hist = []
                for i in range(24):
                    hist.append({"timestamp": now - (23 - i) * 300,
                                 "data": {ip: (7 - j) * 3 + (i + j) % 4 for j, ip in enumerate(ips)}})
                totals = {ip: sum(h["data"][ip] for h in hist) for ip in ips}
                return self._send(200, {"history": hist, "clients": {ip: {"name": names[j], "total": totals[ip]} for j, ip in enumerate(ips)}})
            if path == "/api/stats/query_types":
                return self._send(200, {"types": {"A": 700, "AAAA": 200, "PTR": 50, "HTTPS": 30, "SRV": 0, "OTHER": 20}})
            if path == "/api/stats/upstreams":
                return self._send(200, {"upstreams": [
                    {"ip": "cache", "name": None, "port": -1, "count": 600, "statistics": {"response": 0, "variance": 0}},
                    {"ip": "1.1.1.1", "name": "one.one.one.one", "port": 53, "count": 300, "statistics": {"response": 0.0254856, "variance": 0.02}},
                    {"ip": "127.0.0.1", "name": None, "port": 5335, "count": 100, "statistics": {"response": 1.5, "variance": 0.1}}],
                    "forwarded_queries": 400, "total_queries": 1000})
            if path == "/api/info/version":
                v = lambda s: {"local": {"version": s}}
                return self._send(200, {"version": {"core": v("v6.1"), "web": v("v6.1"), "ftl": v("v6.1.2")}})
            if path == "/api/action/gravity" and method == "POST":
                time.sleep(0.6)
                return self._send(200, raw="[i] Neutrino emissions detected...\n[✓] Done.\n")
            if path in ("/api/action/restartdns", "/api/action/flush/logs") and method == "POST":
                return self._send(200, {"status": "success"})
            if path == "/api/slow":
                time.sleep(3)
                return self._send(200, {"ok": True})
            return self._send(404, {"error": {"key": "not_found", "message": "Not found", "hint": path}})

        def do_GET(self): self._handle("GET")
        def do_POST(self): self._handle("POST")
        def do_DELETE(self): self._handle("DELETE")
        def do_PUT(self): self._handle("PUT")

    srv = ThreadingHTTPServer(("127.0.0.1", port), H)
    srv.daemon_threads = True
    t = threading.Thread(target=srv.serve_forever, daemon=True)
    t.start()
    return srv
