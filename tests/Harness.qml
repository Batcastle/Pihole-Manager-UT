import QtQuick 2.15
import "Format.js" as Fmt

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
    function rowOf2(secs, title, label) {
        for (var i = 0; i < secs.length; i++) if (secs[i].title === title)
            for (var j = 0; j < secs[i].rows.length; j++) if (secs[i].rows[j].label === label) return secs[i].rows[j].value;
        return undefined;
    }


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
    property var stv: find(app, "statsView")
    property var sec: find(app, "sections")
    property var toastItem: find(app, "toast")

    property var steps: [
        // 0. formatting helpers
        function(next) {
            check("num() thousands separators", Fmt.num(1234567) === "1,234,567" && Fmt.num(999) === "999" && Fmt.num(1000) === "1,000" && Fmt.num(0) === "0" && Fmt.num(-12345) === "-12,345", [Fmt.num(1234567), Fmt.num(-12345)]);
            next();
        },
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
        // 4b. server-side query filters
        function(next) {
            var sugg = { client_ip: ["192.168.1.2"], client_name: ["host1"] };
            var fp = qv.filterParams({ status: "GRAVITY", client: "host1", type: "A" }, sugg);
            check("filterParams: hostname -> client_name", fp.client_name === "host1" && fp.client_ip === undefined && fp.status === "GRAVITY" && fp.length === qv.limit, fp);
            check("filterParams: ip -> client_ip", qv.filterParams({ client: "192.168.1.2" }, sugg).client_ip === "192.168.1.2");
            check("filterParams: empty filters send only length", Object.keys(qv.filterParams({}, null)).join() === "length");
            check("filterCount starts at 0", qv.filterCount === 0);
            qv.limit = 100;
            qv.loadSuggestions(function() {
                check("suggestions loaded", qv.suggestions && qv.suggestions.status.length === 5 && qv.suggestions.client_ip.length === 3);
                var reqs = T.reqCount("/api/queries/suggestions");
                qv.loadSuggestions(function() { check("suggestions are cached", T.reqCount("/api/queries/suggestions") === reqs); });
                qv.setFilters({ status: "GRAVITY" });
                waitFor(function() { return qv.queries.length === 50; }, 3000, function(ok1) {
                    check("status filter applied by the server", ok1 && qv.queries.every(function(x) { return x.status === "GRAVITY"; }) && qv.filterCount === 1, qv.queries.length);
                    check("status filter sent as ?status=", T.reqCount("status=GRAVITY") >= 1);
                    qv.setFilters({ client: "192.168.1.3", upstream: "1.1.1.1#53" });
                    waitFor(function() { return qv.queries.length > 0 && qv.queries.length < 50; }, 3000, function(ok2) {
                        check("client_ip + upstream filters combine",
                              ok2 && qv.queries.every(function(x) { return x.client.ip === "192.168.1.3" && x.status === "FORWARDED"; }) && qv.filterCount === 2, qv.queries.length);
                        check("upstream with # is URL-encoded", T.reqCount("upstream=1.1.1.1%2353") >= 1);
                        qv.setFilters({ client: "host2" });
                        waitFor(function() { return qv.queries.length > 0 && qv.queries.every(function(x) { return x.client.name === "host2"; }); }, 3000, function(ok3) {
                            check("client_name filter", ok3 && T.reqCount("client_name=host2") >= 1);
                            qv.setFilters({});
                            waitFor(function() { return qv.queries.length === 100; }, 3000, function(ok4) {
                                check("clearing filters restores the full log", ok4 && qv.filterCount === 0);
                                qv.limit = 200; qv.refresh();
                                waitFor(function() { return qv.queries.length === 200; }, 3000, function() { next(); });
                            });
                        });
                    });
                });
            });
        },
        // 4b'. filter dialog logic
        function(next) {
            var d = app.openQueryFilterDialog({ status: "GRAVITY" }, qv.suggestions);
            check("filter dialog lists every filterable field", d.fields.length === 6 && d.fields[0].key === "status" && d.fields[2].key === "client", d.fields.length);
            check("client choices are names then IPs", d.fields[2].values.join() === "host1,host2,192.168.1.2,192.168.1.3,192.168.1.4", d.fields[2].values);
            check("status choices get readable labels", d.fields[0].texts[0] === "Blocked (blocklist)" && d.fields[0].texts[1] === "Allowed (forwarded)", d.fields[0].texts);
            check("dialog starts from the active filters", d.selections.status === "GRAVITY" && Object.keys(d.selections).length === 1);
            d.choose("client", "host1"); d.choose("status", "");
            check("choose() sets and clears selections", d.selections.client === "host1" && d.selections.status === undefined && qv.serverFilters.status === undefined);
            var got = null;
            d.applied.connect(function(f) { got = f; });
            d.applied(d.selections);
            check("applied signal carries selections", got && got.client === "host1");
            var empty = app.openQueryFilterDialog({}, {});
            check("no suggestions -> no fields", empty.fields.length === 0);
            next();
        },
        // 4c. query detail rows
        function(next) {
            var fwd = qv.queries[1];
            var rows = Fmt.queryDetails(fwd), byKey = {};
            for (var i = 0; i < rows.length; i++) byKey[rows[i].key] = rows[i].value;
            check("detail rows: client, reply, upstream, dnssec",
                  byKey.client === "host1 (192.168.1.3)" && byKey.reply === "IP address" && byKey.upstream === "1.1.1.1#53" && byKey.dnssec === "Insecure" && byKey.replyTime === "1.4 ms" && byKey.cname === undefined && byKey.ede === undefined, byKey);
            check("detail rows: unknown reply time dropped", Fmt.queryDetails(qv.queries[2]).every(function(r) { return r.key !== "replyTime"; }));
            check("replyTime formatting", Fmt.replyTime(0.01) === "<0.1 ms" && Fmt.replyTime(48.4) === "48 ms" && Fmt.replyTime(1300) === "1.3 s" && Fmt.replyTime(-1) === "");
            // which list blocked it
            var dlgG = app.openQueryDetail(qv.queries[0]);      // GRAVITY, list_id 1
            var dlgR = app.openQueryDetail(qv.queries[3]);      // REGEX, domain id 2
            waitFor(function() { return dlgG.matched !== "" && dlgR.matched !== ""; }, 3000, function(ok3) {
                check("blocking adlist resolved from list_id", ok3 && dlgG.matched === "https://example.com/hosts.txt", dlgG.matched);
                check("blocking regex entry resolved from list_id", ok3 && dlgR.matched.indexOf("tracker") > 0 && dlgR.matched.indexOf("(regex)") > 0, dlgR.matched);
                var dlgC = app.openQueryDetail(qv.queries[2]);  // CACHE: nothing to resolve
                check("allowed query has no 'blocked by'", dlgC.matched === "" && dlgC.matchedKind === "");
                next();
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
                            // editing: regex entry has characters that must be URL-encoded; PUT replaces the whole record
                            var RX = "(\\.|^)tracker\\.net$";
                            var rx = { domain: RX, type: "deny", kind: "regex", comment: null, groups: [0], enabled: false };
                            dv.update(rx, { enabled: true, comment: "edited", groups: [0, 1] });
                            waitFor(function() { var r = T.domainRec(RX); return r !== "" && JSON.parse(r).enabled === true; }, 3000, function(okE) {
                                var rec = JSON.parse(T.domainRec(RX));
                                check("domain entry edited (enabled/comment/groups, encoded path)", okE && rec.comment === "edited" && rec.groups.length === 2 && rec.kind === "regex", rec);
                                check("edit sent as PUT", T.reqCountM("PUT", "/api/domains/deny/regex/") === 1);
                                check("groups loaded for editors", app.groups.length === 2, app.groups);
                                // removing it also needs the encoded path
                                dv.removeDomain(rx);
                                waitFor(function() { return T.domainCount() === 3; }, 3000, function(ok5) {
                                    check("regex domain deleted (url-encoded)", ok5, T.domainCount());
                                    next();
                                });
                            });
                        });
                    });
                });
            });
        },
        // 5b. adlists
        function(next) {
            var al = find(app, "adlistsView");
            dv.listType = "adlists";
            dv.refresh();
            waitFor(function() { return al.lists.length === 3 && app.groups.length === 2; }, 4000, function(ok) {
                check("adlists + groups loaded", ok, [al.lists.length, app.groups.length]);
                check("adlist description", al.describe(al.lists[0]).indexOf("120,345 domains") === 0 && al.describe(al.lists[2]).indexOf("Disabled") === 0, al.describe(al.lists[0]));
                check("failed download is flagged", al.problem(al.lists[1]) !== "" && al.problem(al.lists[0]) === "" && al.problem(al.lists[2]) === "");
                h.snapshot("adlists");
                al.update(al.lists[0], { enabled: false });
                waitFor(function() { return JSON.parse(T.adlist("https://example.com/hosts.txt")).enabled === false; }, 3000, function(ok2) {
                    var rec = JSON.parse(T.adlist("https://example.com/hosts.txt"));
                    check("toggle disables adlist and keeps comment/groups", ok2 && rec.comment === "Main list" && rec.groups[0] === 0, rec);
                    al.create({ address: "https://new.example.com/a b.txt", type: "block", comment: "mine", groups: [0, 1], enabled: true });
                    waitFor(function() { return T.adlistCount() === 4; }, 3000, function(ok3) {
                        var n = JSON.parse(T.adlist("https://new.example.com/a b.txt"));
                        check("adlist created with groups", ok3 && n.groups.length === 2 && n.comment === "mine", n);
                        al.create({ address: "https://new.example.com/a b.txt", type: "block", comment: "", groups: [0], enabled: true });
                        waitFor(function() { return toastItem.opacity > 0; }, 2000, function(ok4) {
                            check("duplicate adlist rejected with toast", ok4 && T.adlistCount() === 4);
                            al.remove(al.lists[1]);   // address contains ? & = that must be encoded
                            waitFor(function() { return T.adlistCount() === 3; }, 3000, function(ok5) {
                                check("adlist deleted (url-encoded address + type)", ok5, T.adlistCount());
                                check("PUT/DELETE carried ?type=", T.reqCount("/api/lists/https%3A%2F%2Fbad.example.net%2Flist%3Fx%3D1%26y%3D2?type=block") === 1);
                                dv.listType = "deny";
                                next();
                            });
                        });
                    });
                });
            });
        },
        // 5c. statistics tab
        function(next) {
            sec.selectedIndex = 3;
            waitFor(function() { return stv.summary !== null && stv.queryTypes.length > 0 && stv.upstreams.length > 0; }, 4000, function(ok) {
                check("stats loaded", ok);
                check("query types: zeros dropped, biggest first", stv.queryTypes.length === 5 && stv.queryTypes[0].name === "A" && stv.queryTypes[4].name === "OTHER" && stv.queryTypes.every(function(t) { return t.count > 0; }), stv.queryTypes);
                check("reply types labelled and sorted", stv.replies[0].name === "IP address" && stv.replies[1].name === "No data" && stv.replies.length === 4, stv.replies);
                check("upstreams: names, ports, avg reply time",
                      stv.upstreams[0].name === "cache" && stv.upstreams[1].name === "one.one.one.one · 25 ms" && stv.upstreams[2].name === "127.0.0.1#5335 · 1.5 s", stv.upstreams);
                check("forwardedTotal sums upstream counts", stv.forwardedTotal === 1000);
                check("cache share of all queries", stv.pctOfTotal(stv.summary.queries.cached) === "0.5%", stv.pctOfTotal(stv.summary.queries.cached));
                waitFor(function() { return stv.clientHistory.slots.length === 24; }, 3000, function(okC) {
                    var ch = stv.clientHistory;
                    check("client chart: 24 slots, top 5 clients + Other", okC && ch.series.length === 6 && ch.series[5].name === "Other" && ch.series[5].key === "", ch.series.length);
                    check("client chart: named by hostname, else IP", ch.series[0].name === "laptop" && ch.series[1].name === "192.168.1.11" && ch.series[2].name === "phone", ch.series.map(function(x) { return x.name; }));
                    check("client chart: busiest first", ch.series[0].total >= ch.series[1].total && ch.series[4].total >= ch.series[5].total / 2, ch.series.map(function(x) { return x.total; }));
                    var sum = ch.series.reduce(function(a, b) { return a + b.total; }, 0);
                    var slotSum = ch.slots.reduce(function(a, b) { return a + b.total; }, 0);
                    check("client chart: series totals match slot totals", sum === slotSum, [sum, slotSum]);
                    check("client chart: each slot has one value per series", ch.slots.every(function(sl) { return sl.values.length === 6; }));
                    var lone = Fmt.clientSeries({ history: [{ timestamp: 1, data: { "10.0.0.1": 3, "10.0.0.2": 1 } }], clients: {} }, 5, "Other");
                    check("client chart: works without the clients summary", lone.series.length === 2 && lone.series[0].key === "10.0.0.1" && lone.slots[0].total === 4, lone);
                    check("client chart: empty response is harmless", Fmt.clientSeries(null, 5, "Other").slots.length === 0);
                });
                waitFor(function() { return stv.serverSections.length === 3; }, 3000, function(okS) {
                    var secs = stv.serverSections;
                    function rowOf(title, label) {
                        for (var i = 0; i < secs.length; i++) if (secs[i].title === title)
                            for (var j = 0; j < secs[i].rows.length; j++) if (secs[i].rows[j].label === label) return secs[i].rows[j].value;
                        return undefined;
                    }
                    check("server info: host, system and FTL sections", okS && secs.map(function(x) { return x.title; }).join("|") === "Host|System load|Pi-hole FTL", secs.map(function(x) { return x.title; }));
                    check("server info: model and OS", rowOf("Host", "Model") === "Raspberry Pi 4 Model B Rev 1.5" && rowOf("Host", "System") === "Linux 6.6.31+rpt-rpi-v8", [rowOf("Host", "Model"), rowOf("Host", "System")]);
                    check("server info: null DMI fields are left out", rowOf("Host", "Hostname") === "pihole" && secs[0].rows.length === 4, secs[0].rows.length);
                    check("server info: uptime / load / temperature", rowOf("System load", "Uptime") === "3d 3h" && rowOf("System load", "Load average") === "0.12  0.20  0.31" && rowOf("System load", "CPU temperature") === "48.3°C", [rowOf("System load", "Uptime"), rowOf("System load", "Load average"), rowOf("System load", "CPU temperature")]);
                    check("server info: memory in GB, no swap row when swap is off", rowOf("System load", "Memory") === "1.4 GB / 3.8 GB  (37.6%)" && rowOf("System load", "Swap") === undefined, rowOf("System load", "Memory"));
                    check("server info: FTL numbers", rowOf("Pi-hole FTL", "FTL uptime") === "1d 1h" && rowOf("Pi-hole FTL", "Domains on blocklists") === "123,456" && rowOf("Pi-hole FTL", "Clients") === "5 active · 11 known", [rowOf("Pi-hole FTL", "FTL uptime"), rowOf("Pi-hole FTL", "Domains on blocklists"), rowOf("Pi-hole FTL", "Clients")]);
                    var partial = Fmt.serverInfo(null, null, null, null, function(x) { return x; });
                    check("server info: nothing reported -> no sections", partial.length === 0);
                    var fahr = Fmt.serverInfo(null, { system: {} }, null, { sensors: { cpu_temp: 100, unit: "F" } }, function(x) { return x; });
                    check("server info: Fahrenheit unit respected", fahr.length === 1 && fahr[0].rows[0].value === "100.0°F", fahr);
                    T.setSensorsFail(true);
                    stv.refresh();
                    waitFor(function() { return rowOf2(stv.serverSections, "System load", "CPU temperature") === undefined && stv.serverSections.length === 3; }, 3000, function(okF) {
                        check("server info: a failing /info/sensors only drops the temperature row", okF && rowOf2(stv.serverSections, "System load", "Uptime") === "3d 3h");
                        T.setSensorsFail(false);
                    });
                });
                h.snapshot("stats");
                next();
            });
        },
        // 6. actions with spinner
        function(next) {
            sec.selectedIndex = 4;
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
            check("views reset", dash.summary === null && qv.queries.length === 0 && dv.domains.length === 0 && find(app, "adlistsView").lists.length === 0 && stv.summary === null && stv.upstreams.length === 0);
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
