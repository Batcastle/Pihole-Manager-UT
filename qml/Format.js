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
