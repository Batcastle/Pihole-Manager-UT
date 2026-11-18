.pragma library

function pad(n) {
    return n < 10 ? "0" + n : "" + n;
}

// 1234567 -> "1,234,567"
function num(n) {
    if (n === null || n === undefined || isNaN(n)) return "–";
    // (a lookahead regex gives doubled commas in Qt 5's JS engine, so do it by hand)
    var s = String(Math.round(Math.abs(Number(n))));
    var out = "";
    while (s.length > 3) {
        out = "," + s.slice(-3) + out;
        s = s.slice(0, -3);
    }
    return (Number(n) < 0 ? "-" : "") + s + out;
}

function pct(p) {
    if (p === null || p === undefined || isNaN(p)) return "–";
    return Number(p).toFixed(1) + "%";
}

// seconds -> "m:ss" or "h:mm:ss"
function countdown(totalSeconds) {
    var s = Math.max(0, Math.round(totalSeconds));
    var h = Math.floor(s / 3600);
    var m = Math.floor((s % 3600) / 60);
    var sec = s % 60;
    if (h > 0) return h + ":" + pad(m) + ":" + pad(sec);
    return m + ":" + pad(sec);
}

// epoch seconds -> "HH:MM"
function clock(ts) {
    var d = new Date(ts * 1000);
    return pad(d.getHours()) + ":" + pad(d.getMinutes());
}

// epoch seconds -> "HH:MM:SS" (today) or "Mon DD HH:MM:SS"
function dateTime(ts) {
    var d = new Date(ts * 1000);
    var t = pad(d.getHours()) + ":" + pad(d.getMinutes()) + ":" + pad(d.getSeconds());
    var now = new Date();
    if (d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth() && d.getDate() === now.getDate())
        return t;
    return (d.getMonth() + 1) + "/" + d.getDate() + " " + t;
}

// epoch seconds -> "2026-11-15 18:29:44"
function fullDateTime(ts) {
    var d = new Date(ts * 1000);
    return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) + " "
         + pad(d.getHours()) + ":" + pad(d.getMinutes()) + ":" + pad(d.getSeconds());
}

// epoch seconds -> "5 min ago" / "3 h ago" / "2 d ago"
function ago(ts) {
    var s = Math.max(0, Math.round(Date.now() / 1000 - ts));
    if (s < 60) return "just now";
    if (s < 3600) return Math.floor(s / 60) + " min ago";
    if (s < 86400) return Math.floor(s / 3600) + " h ago";
    return Math.floor(s / 86400) + " d ago";
}

var BLOCKED = {
    GRAVITY: 1, REGEX: 1, DENYLIST: 1,
    EXTERNAL_BLOCKED_IP: 1, EXTERNAL_BLOCKED_NULL: 1, EXTERNAL_BLOCKED_NXRA: 1,
    GRAVITY_CNAME: 1, REGEX_CNAME: 1, DENYLIST_CNAME: 1,
    SPECIAL_DOMAIN: 1
};

var LABELS = {
    GRAVITY: "Blocked (blocklist)",
    REGEX: "Blocked (regex)",
    DENYLIST: "Blocked (denylist)",
    EXTERNAL_BLOCKED_IP: "Blocked (upstream, IP)",
    EXTERNAL_BLOCKED_NULL: "Blocked (upstream, NULL)",
    EXTERNAL_BLOCKED_NXRA: "Blocked (upstream, NXDOMAIN)",
    GRAVITY_CNAME: "Blocked (CNAME, blocklist)",
    REGEX_CNAME: "Blocked (CNAME, regex)",
    DENYLIST_CNAME: "Blocked (CNAME, denylist)",
    SPECIAL_DOMAIN: "Blocked (special domain)",
    FORWARDED: "Allowed (forwarded)",
    CACHE: "Allowed (cache)",
    CACHE_STALE: "Allowed (stale cache)",
    RETRIED: "Allowed (retried)",
    RETRIED_DNSSEC: "Allowed (retried, DNSSEC)",
    IN_PROGRESS: "In progress",
    DBBUSY: "Database busy",
    UNKNOWN: "Unknown"
};

function isBlocked(status) {
    return BLOCKED[status] === 1;
}

function statusLabel(status) {
    if (!status) return "Unknown";
    if (LABELS[status]) return LABELS[status];
    var s = String(status).toLowerCase().replace(/_/g, " ");
    return s.charAt(0).toUpperCase() + s.slice(1);
}

// "pi.hole:8080" -> "pi.hole:8080", "http://x/" -> "x"
function hostOf(url) {
    return String(url || "").replace(/^https?:\/\//i, "").replace(/\/.*$/, "");
}

// reply time in ms (negative when unknown) -> "3.2 ms" / "48 ms" / "1.3 s"
function replyTime(ms) {
    if (ms === null || ms === undefined || isNaN(ms) || ms < 0) return "";
    if (ms < 0.05) return "<0.1 ms";
    if (ms < 10) return Number(ms).toFixed(1) + " ms";
    if (ms < 1000) return Math.round(ms) + " ms";
    return (ms / 1000).toFixed(1) + " s";
}

var REPLIES = {
    NODATA: "No data", NXDOMAIN: "Domain doesn't exist", CNAME: "CNAME", IP: "IP address",
    DOMAIN: "Domain", RRNAME: "RR name", SERVFAIL: "Server failure", REFUSED: "Refused",
    NOTIMP: "Not implemented", DNSSEC: "DNSSEC", NONE: "No reply", BLOB: "Blob", OTHER: "Other", UNKNOWN: "Unknown"
};

function replyLabel(type) {
    if (!type) return "";
    return REPLIES[type] || String(type);
}

var DNSSEC = {
    SECURE: "Secure", INSECURE: "Insecure", BOGUS: "Bogus", ABANDONED: "Abandoned", UNKNOWN: "Not checked"
};

function dnssecLabel(s) {
    if (!s) return "";
    return DNSSEC[s] || String(s);
}

// Which kind of list a blocked query matched, from its status: "adlist" | "domain" | "".
function matchedList(status) {
    switch (status) {
    case "GRAVITY": case "GRAVITY_CNAME": return "adlist";
    case "REGEX": case "REGEX_CNAME":
    case "DENYLIST": case "DENYLIST_CNAME": return "domain";
    }
    return "";
}

// Flatten a /queries item into [{ key, value }] rows for the detail dialog (empty values are dropped).
function queryDetails(q) {
    var rows = [];
    function add(key, value) {
        if (value !== null && value !== undefined && value !== "") rows.push({ key: key, value: String(value) });
    }
    var client = q.client || {};
    add("domain", q.domain);
    add("time", q.time ? fullDateTime(q.time) : "");
    add("type", q.type);
    add("status", statusLabel(q.status));
    add("client", client.name ? client.name + " (" + client.ip + ")" : client.ip);
    var reply = q.reply || {};
    add("reply", replyLabel(reply.type));
    add("replyTime", replyTime(reply.time));
    add("upstream", q.upstream);
    add("cname", q.cname);
    add("dnssec", dnssecLabel(q.dnssec));
    if (q.ede && q.ede.code !== undefined && q.ede.code >= 0)
        add("ede", q.ede.text ? q.ede.text + " (" + q.ede.code + ")" : q.ede.code);
    return rows;
}

// Colours for the per-client chart (+ grey for "Other"); chosen to stay apart for common colour-vision types.
var CLIENT_COLORS = ["#3b82f6", "#f59e0b", "#14b8a6", "#a855f7", "#ec4899"];
var OTHER_COLOR = "#94a3b8";

// /history/clients response -> { series: [{ key, name, total, color }], slots: [{ timestamp, total, values: [n per series] }] }
// The busiest `topN` clients get their own series; everything else is folded into a final "Other" series.
function clientSeries(resp, topN, otherLabel) {
    var clients = (resp && resp.clients) || {};
    var history = (resp && resp.history) || [];
    var totals = {};
    var key;
    for (key in clients) totals[key] = clients[key].total || 0;
    // clients that only appear in the history (no summary entry) still count
    for (var h = 0; h < history.length; h++)
        for (key in (history[h].data || {}))
            if (totals[key] === undefined) totals[key] = 0;

    var keys = Object.keys(totals);
    // fall back to summing the history when the summary totals are missing
    var haveTotals = keys.some(function(k) { return totals[k] > 0; });
    if (!haveTotals) {
        for (var i = 0; i < history.length; i++)
            for (key in (history[i].data || {})) totals[key] += history[i].data[key];
    }
    keys.sort(function(a, b) { return totals[b] - totals[a]; });

    var top = keys.slice(0, topN), rest = keys.slice(topN);
    var series = top.map(function(k, idx) {
        var c = clients[k] || {};
        return { key: k, name: c.name || k || "?", total: totals[k], color: CLIENT_COLORS[idx % CLIENT_COLORS.length] };
    });
    if (rest.length > 0) {
        var restTotal = 0;
        for (var r = 0; r < rest.length; r++) restTotal += totals[rest[r]];
        series.push({ key: "", name: otherLabel || "Other", total: restTotal, color: OTHER_COLOR });
    }

    var slots = history.map(function(slot) {
        var data = slot.data || {};
        var values = top.map(function(k) { return data[k] || 0; });
        var sum = 0, n;
        for (n = 0; n < values.length; n++) sum += values[n];
        if (rest.length > 0) {
            var other = 0;
            for (var m = 0; m < rest.length; m++) other += data[rest[m]] || 0;
            values.push(other);
            sum += other;
        }
        return { timestamp: slot.timestamp, total: sum, values: values };
    });
    return { series: series, slots: slots };
}
