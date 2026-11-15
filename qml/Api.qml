import QtQuick 2.12

// Minimal client for the Pi-hole v6 REST API.
//
//   api.configure("pi.hole", "app-password")
//   api.call("GET", "/stats/summary", null, function(err, data) { ... })
//
// Handles login (POST /api/auth), keeps the session id (X-FTL-SID header),
// transparently re-logs-in once on a 401, and has its own request timeout
// (QML's XMLHttpRequest has none).
Item {
    id: api
    visible: false

    property string baseUrl: ""
    property string password: ""
    property string sid: ""
    // true when the Pi-hole has no password set: no session is needed
    property bool open: false
    property int pending: 0
    readonly property bool busy: pending > 0
    property int defaultTimeout: 10000

    property bool _loggingIn: false
    property var _waiters: []
    property var _inflight: []

    // ---- helpers ---------------------------------------------------------

    function normalizeUrl(u) {
        var s = (u || "").trim();
        if (s === "") return "";
        if (!/^https?:\/\//i.test(s)) s = "http://" + s;
        s = s.replace(/\/+$/, "");
        // people paste the admin URL: http://pi.hole/admin
        s = s.replace(/\/(admin|api)(\/.*)?$/i, "");
        return s;
    }

    function configure(url, pass) {
        logout();
        baseUrl = normalizeUrl(url);
        password = pass || "";
        sid = "";
        open = false;
    }

    // Best effort: free the session slot on the Pi-hole.
    function logout() {
        if (sid !== "" && baseUrl !== "") {
            _send("DELETE", "/auth", null, { auth: true, timeout: 3000 }, function() {});
        }
        sid = "";
        open = false;
    }

    Timer {
        interval: 1000
        repeat: true
        running: api._inflight.length > 0
        onTriggered: api._reap()
    }

    function _reap() {
        var now = Date.now();
        var list = _inflight.slice();
        for (var i = 0; i < list.length; i++) {
            if (now > list[i].deadline) {
                list[i].timedOut = true;     // abort() may fire DONE synchronously
                try { list[i].xhr.abort(); } catch (e) {}
                list[i].finish(0, "", true);
            }
        }
    }

    // ---- transport ---------------------------------------------------------

    // Low level: no login handling. cb(status, responseText, timedOut)
    function _send(method, path, body, opts, cb) {
        var xhr = new XMLHttpRequest();
        var entry = { xhr: xhr, done: false, timedOut: false, deadline: Date.now() + (opts.timeout || defaultTimeout) };
        entry.finish = function(status, text, timedOut) {
            if (entry.done) return;
            entry.done = true;
            timedOut = (timedOut === true) || entry.timedOut;
            var idx = _inflight.indexOf(entry);
            if (idx >= 0) {
                var copy = _inflight.slice();
                copy.splice(idx, 1);
                _inflight = copy;
            }
            cb(status, text, timedOut);
        };
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE)
                entry.finish(xhr.status, xhr.responseText, false);
        };
        try {
            xhr.open(method, baseUrl + "/api" + path);
            xhr.setRequestHeader("Accept", "application/json");
            if (body !== null && body !== undefined)
                xhr.setRequestHeader("Content-Type", "application/json");
            if (opts.auth && sid !== "")
                xhr.setRequestHeader("X-FTL-SID", sid);
        } catch (e) {
            cb(0, "", false);
            return;
        }
        _inflight = _inflight.concat([entry]);
        try {
            if (body !== null && body !== undefined) xhr.send(JSON.stringify(body));
            else xhr.send();
        } catch (e2) {
            entry.finish(0, "", false);
        }
    }

    function _parse(text) {
        if (!text) return null;
        try { return JSON.parse(text); } catch (e) { return null; }
    }

    function _error(status, data, timedOut, path) {
        var msg = "";
        if (status === 0) {
            msg = timedOut
                ? qsTr("Timed out talking to %1").arg(baseUrl)
                : qsTr("Can't reach %1. Check the address and that your phone is on the same network.").arg(baseUrl);
        } else if (data && data.error && data.error.message) {
            msg = data.error.message;
            if (data.error.hint) msg += " (" + data.error.hint + ")";
        } else if (status === 401) {
            msg = qsTr("Not authorised. Check the password.");
        } else if (status === 404) {
            msg = qsTr("Not found. Is this a Pi-hole v6 server?");
        } else {
            msg = qsTr("Server returned HTTP %1").arg(status);
        }
        return { status: status, message: msg, key: (data && data.error) ? data.error.key : "" };
    }

    // ---- login ---------------------------------------------------------------

    function _ensureLogin(cb) {
        if (sid !== "" || open) { cb(null); return; }
        _waiters = _waiters.concat([cb]);
        if (_loggingIn) return;
        _loggingIn = true;
        _send("POST", "/auth", { password: password }, { auth: false }, function(status, text, timedOut) {
            var data = _parse(text);
            var err = null;
            if (status === 200 && data && data.session) {
                if (data.session.valid) {
                    if (data.session.sid) sid = data.session.sid;
                    else open = true;
                } else if (data.session.totp) {
                    err = { status: 401, key: "totp", message: qsTr("Two-factor authentication is on. Create an app password in the Pi-hole web interface (Settings → Web interface / API) and use that here.") };
                } else {
                    err = { status: 401, key: "unauthorized", message: qsTr("Wrong password. If 2FA is enabled, use an app password.") };
                }
            } else if (status === 200) {
                err = { status: 200, key: "not_pihole", message: qsTr("That server answered, but it doesn't look like Pi-hole v6.") };
            } else if (status === 401) {
                err = { status: 401, key: "unauthorized", message: qsTr("Wrong password. If 2FA is enabled, use an app password.") };
            } else if (status === 404 || status === 405) {
                err = { status: status, key: "not_v6", message: qsTr("No Pi-hole v6 API found at %1. Pi-hole v5 isn't supported.").arg(baseUrl) };
            } else if (status === 429) {
                err = { status: 429, key: "rate_limited", message: qsTr("Too many login attempts. Wait a minute and try again.") };
            } else {
                err = _error(status, data, timedOut, "/auth");
            }
            _loggingIn = false;
            var waiters = _waiters;
            _waiters = [];
            for (var i = 0; i < waiters.length; i++) waiters[i](err);
        });
    }

    // ---- public request ------------------------------------------------------

    // cb(err, data). err is null on success, otherwise { status, message, key }.
    // opts: { raw: bool (return the text body), timeout: ms }
    function call(method, path, body, cb, opts) {
        opts = opts || {};
        if (baseUrl === "") {
            cb({ status: 0, key: "no_server", message: qsTr("No Pi-hole configured") }, null);
            return;
        }
        pending++;
        var done = function(err, data) {
            pending--;
            cb(err, data);
        };
        var send;
        var handle = function(status, text, timedOut, retried, usedSid) {
            if (status === 401 && !retried && !open) {
                // Session expired (or was evicted). Only drop it if it is still the
                // one that failed: a parallel request may already have logged in again.
                if (sid === usedSid) sid = "";
                _ensureLogin(function(err) {
                    if (err) { done(err, null); return; }
                    send(true);
                });
                return;
            }
            var data = opts.raw ? text : _parse(text);
            if (status >= 200 && status < 300) done(null, data);
            else done(_error(status, opts.raw ? _parse(text) : data, timedOut, path), null);
        };
        send = function(retried) {
            var used = sid;
            _send(method, path, body, { auth: true, timeout: opts.timeout }, function(s, t, to) {
                handle(s, t, to, retried, used);
            });
        };
        _ensureLogin(function(err) {
            if (err) { done(err, null); return; }
            send(false);
        });
    }
}
