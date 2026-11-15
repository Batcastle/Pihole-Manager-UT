import QtQuick 2.15

Item {
    id: h
    width: 450
    height: 900

    signal finished(int failures)
    signal snapshot(string name)

    Main { id: app; anchors.fill: parent }
    Api { id: apiA }

    property int failures: 0
    property int checks: 0

    function check(name, cond, extra) {
        checks++;
        if (cond) console.log("PASS " + name);
        else { failures++; console.log("FAIL " + name + (extra !== undefined ? "  -> " + JSON.stringify(extra) : "")); }
    }

    function find(root, name) {
        if (root.objectName === name) return root;
        var kids = root.children;
        for (var i = 0; i < kids.length; i++) {
            var r = find(kids[i], name);
            if (r) return r;
        }
        return null;
    }

    function waitFor(cond, ms, cb) {
        var t = Qt.createQmlObject('import QtQuick 2.15; Timer { interval: 25; repeat: true }', h);
        var start = Date.now();
        t.triggered.connect(function() {
            var ok = false;
            try { ok = cond(); } catch (e) { ok = false; }
            if (ok || Date.now() - start > ms) { t.stop(); t.destroy(); cb(ok); }
        });
        t.start();
    }

    // call helper for the standalone client
    function callA(method, path, body, opts, cb) {
        apiA.call(method, path, body, function(err, data) { cb(err, data); }, opts);
    }

    property var dash: find(app, "dashboardView")
    property var qv: find(app, "queriesView")
    property var dv: find(app, "domainsView")
    property var sv: find(app, "settingsView")
    property var sec: find(app, "sections")
    property var toastItem: find(app, "toast")

    property var steps: [
        // 1. add a server -> dashboard loads, one login only
        function(next) {
            check("starts without a server", !app.hasServer);
            app.saveServer(-1, { name: "Home", url: "127.0.0.1:" + T.port() + "/admin/", password: "secret" });
            check("server saved + active", app.hasServer && app.currentServer.name === "Home");
            waitFor(function() { return dash.summary !== null && dash.history.length > 0 && dash.topClients.length > 0 && dash.topBlocked.length > 0 && dash.blocking !== "unknown"; }, 4000, function(ok) {
                check("dashboard loaded", ok, { err: dash.errorText });
                check("url normalised", app.api.baseUrl === "http://127.0.0.1:" + T.port(), app.api.baseUrl);
                check("summary total", dash.summary && dash.summary.queries.total === 1234567);
                check("history has 144 points", dash.history.length === 144);
                check("top blocked", dash.topBlocked[0].domain === "ads.example.com");
                check("no error banner", dash.errorText === "", dash.errorText);
                check("6 parallel calls shared 1 login", T.logins() === 1, T.logins());
                check("blocking enabled", dash.blocking === "enabled");
                h.snapshot("dashboard");
                next();
            });
        },
        // 2. disable with timer then enable
        function(next) {
            dash.setBlocking(false, 30);
            waitFor(function() { return dash.blocking === "disabled"; }, 3000, function(ok) {
                check("disabled via API", ok && T.blockingState() === "disabled");
                check("countdown running", dash.remaining > 25 && dash.remaining <= 30, dash.remaining);
                dash.setBlocking(true, 0);
                waitFor(function() { return dash.blocking === "enabled"; }, 3000, function(ok2) {
                    check("re-enabled via API", ok2 && T.blockingState() === "enabled");
                    check("countdown cleared", dash.remaining === 0);
                    next();
                });
            });
        },
        // 3. session expiry -> transparent re-login
        function(next) {
            T.expire();
            dash.summary = null;
            dash.refresh();
            waitFor(function() { return dash.summary !== null && dash.pendingCalls === 0; }, 4000, function(ok) {
                check("recovers after session expiry", ok && dash.errorText === "", dash.errorText);
                check("exactly one extra login", T.logins() === 2, T.logins());
                next();
            });
        },
        // 4. query log
        function(next) {
            sec.selectedIndex = 1;
            waitFor(function() { return qv.queries.length === 100; }, 4000, function(ok) {
                check("queries loaded", ok, qv.queries.length);
                check("all filter", qv.shown.length === 100);
                qv.filter = "blocked";
                check("blocked filter", qv.shown.length === 60, qv.shown.length);
                qv.filter = "allowed";
                check("allowed filter", qv.shown.length === 40, qv.shown.length);
                qv.filter = "all";
                qv.search = "d7";
                check("search filter", qv.shown.length === 11, qv.shown.length);
                qv.search = "host1";
                check("search by client name", qv.shown.length > 0 && qv.shown[0].client.name === "host1", qv.shown.length);
                qv.search = "";
                h.snapshot("queries");
                qv.limit = 200; qv.refresh();
                waitFor(function() { return qv.queries.length === 200; }, 4000, function(ok2) {
                    check("load more", ok2, qv.queries.length);
                    next();
                });
            });
        },
        // 5. domains
        function(next) {
            sec.selectedIndex = 2;
            waitFor(function() { return dv.domains.length === 3; }, 4000, function(ok) {
                check("domains loaded", ok, dv.domains.length);
                check("deny list", dv.shown.length === 2);
                dv.listType = "allow";
                check("allow list", dv.shown.length === 1 && dv.shown[0].domain === "good.example.org");
                dv.listType = "deny";
                app.addDomain("deny", "exact", "new.example.com", "");
                waitFor(function() { return T.domainCount() === 4; }, 3000, function(ok2) {
                    check("domain added", ok2, T.domainCount());
                    app.addDomain("deny", "exact", "new.example.com", "");   // duplicate -> processed.errors
                    waitFor(function() { return toastItem.opacity > 0; }, 2000, function(ok3) {
                        check("duplicate shows error toast, no extra entry", ok3 && T.domainCount() === 4, T.domainCount());
                        dv.refresh();
                        waitFor(function() { return dv.domains.length === 4; }, 3000, function(ok4) {
                            check("list refreshed", ok4);
                            h.snapshot("domains");
                            // regex entry has characters that must be URL-encoded
                            dv.removeDomain({ type: "deny", kind: "regex", domain: "(\\.|^)tracker\\.net$" });
                            waitFor(function() { return T.domainCount() === 3; }, 3000, function(ok5) {
                                check("regex domain deleted (url-encoded)", ok5, T.domainCount());
                                next();
                            });
                        });
                    });
                });
            });
        },
        // 6. actions with spinner
        function(next) {
            sec.selectedIndex = 3;
            app.runAction("Updating gravity…", "/action/gravity", "Gravity updated", 5000);
            check("spinner shown", app.busyText !== "");
            waitFor(function() { return app.busyText === ""; }, 4000, function(ok) {
                check("spinner cleared after gravity", ok);
                check("gravity endpoint hit", T.reqCount("/api/action/gravity") === 1);
                sv.refresh();
                waitFor(function() { return sv.versionText !== ""; }, 3000, function(ok2) {
                    check("version info", ok2 && sv.versionText.indexOf("Core v6.1") === 0, sv.versionText);
                    h.snapshot("more");
                    next();
                });
            });
        },
        // 7. error handling on a standalone client
        function(next) {
            apiA.configure("127.0.0.1:" + T.port(), "nope");
            callA("GET", "/stats/summary", null, {}, function(err) {
                check("wrong password -> unauthorized", err && err.key === "unauthorized" && err.message.indexOf("Wrong password") === 0, err);
                apiA.configure("127.0.0.1:" + T.v5port(), "x");
                callA("GET", "/stats/summary", null, {}, function(err2) {
                    check("v5 server detected", err2 && err2.key === "not_v6", err2);
                    apiA.configure("127.0.0.1:" + T.deadport(), "x");
                    callA("GET", "/stats/summary", null, {}, function(err3) {
                        check("unreachable host", err3 && err3.status === 0 && err3.message.indexOf("Can't reach") === 0, err3);
                        apiA.configure("127.0.0.1:" + T.port(), "secret");
                        var t0 = Date.now();
                        callA("GET", "/slow", null, { timeout: 1000 }, function(err4) {
                            var dt = Date.now() - t0;
                            check("request timeout", err4 && err4.message.indexOf("Timed out") === 0 && dt < 2600, { err: err4, dt: dt });
                            apiA.configure("127.0.0.1:" + T.nopassport(), "");
                            callA("GET", "/stats/summary", null, {}, function(err5, d5) {
                                check("password-less pi-hole", err5 === null && apiA.open === true && d5.queries.total === 1234567, err5);
                                apiA.configure("127.0.0.1:" + T.port(), "secret");
                                callA("POST", "/action/gravity", null, { raw: true, timeout: 4000 }, function(err6, d6) {
                                    check("raw text response", err6 === null && typeof d6 === "string" && d6.indexOf("Done") > 0, d6);
                                    apiA.configure("", "");
                                    callA("GET", "/x", null, {}, function(err7) {
                                        check("no server configured", err7 && err7.key === "no_server", err7);
                                        next();
                                    });
                                });
                            });
                        });
                    });
                });
            });
        },
        // 8. removing the last server resets everything
        function(next) {
            app.removeServer(0);
            check("server removed", !app.hasServer && app.api.baseUrl === "");
            check("views reset", dash.summary === null && qv.queries.length === 0 && dv.domains.length === 0);
            h.snapshot("empty");
            next();
        }
    ]

    function runFrom(i) {
        if (i >= steps.length) { finished(failures); return; }
        steps[i](function() { runFrom(i + 1); });
    }

    Component.onCompleted: Qt.callLater(function() { runFrom(0); })
}
