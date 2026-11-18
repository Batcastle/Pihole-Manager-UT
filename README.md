# Pi-hole Manager for Ubuntu Touch

A native (pure QML) app to monitor and control a **Pi-hole v6** from Ubuntu Touch.

## Features

- **Home** – blocking on/off with timed disable (30 s, 5 min, 30 min, 1 h, custom, indefinite) and a live
  countdown, headline stats, 24 h activity chart (tap/drag the bars for numbers), top blocked / permitted
  domains, top clients. Pull to refresh, plus configurable auto-refresh.
- **Queries** – live query log with All / Blocked / Allowed buttons and search (domain or client). A
  **Filters** button narrows the whole log on the Pi-hole itself by status, query type, client, upstream,
  reply type or DNSSEC result. Tap a row for the **query details** (reply time, upstream, DNSSEC, which
  blocklist or rule caught it) with one-tap block / allow. "Load more" fetches older entries.
- **Lists** – *Blocked* and *Allowed* show your deny/allow entries (exact + regex): add, tap to edit
  (enabled, comment, groups), swipe a row right to remove. *Adlists* manages the blocklists / allowlists that
  feed gravity: add, enable/disable with a switch, edit, delete, spot lists that failed to download, and
  update gravity.
- **Stats** – queries per second, share answered from cache / forwarded, query types, upstream servers (with
  average reply time) and reply types.
- **More** – multiple Pi-holes (switch between them), auto-refresh interval, update gravity, restart DNS,
  flush the query log, Pi-hole version info.

## Build & install

Needs [Clickable](https://clickable-ut.dev) **8.4.0 or newer**.

```sh
clickable build          # builds the .click (architecture "all": pure QML)
clickable install        # installs to a connected device
clickable desktop        # try it on your computer (Lomiri components needed)
```

`clickable.yaml` targets `ubuntu-touch-24.04-1.x`. For a 20.04 device build with
`CLICKABLE_FRAMEWORK=ubuntu-sdk-20.04 clickable build` (the QML only uses Lomiri.Components 1.3 and
Qt 5.12-era APIs).

The click is named `piholemanager.batcastle`. Rename it in `manifest.json.in` and
`clickable.yaml`-related files if you want a different OpenStore ID.

## Connecting

Add a Pi-hole under **More → Add a Pi-hole**:

- **Address**: `pi.hole`, `192.168.1.2`, `192.168.1.2:8080`, or a full URL. A pasted `/admin` suffix is stripped.
  `http://` is assumed when no scheme is given.
- **Password**: your web interface password, or an **app password** (Pi-hole → Settings → Web interface / API).
  Use an app password if two-factor authentication is on.
- **Test connection** checks the address + login and shows the Pi-hole version.

Notes:

- Pi-hole **v6 only** (the REST API under `/api`). Pi-hole v5 is detected and reported as unsupported.
- The app uses plain HTTP by default. Pi-hole v6 serves HTTP on port 80 and HTTPS on 443; Qt's
  `XMLHttpRequest` can't accept a self-signed certificate, so `https://` only works with a certificate your
  phone trusts.
- Passwords are stored in the app's private config directory (confined by AppArmor), not encrypted.
- The app logs in once, reuses the session, re-logs-in automatically if it expires, and logs out on exit.

## Layout

```
qml/Main.qml            window, header tabs, server management, shared dialogs/actions
qml/Api.qml             Pi-hole v6 REST client (login, SID header, retry on 401, timeouts)
qml/DashboardView.qml   "Home" tab             qml/QueriesView.qml   query log + filters
qml/DomainsView.qml     "Lists" tab            qml/AdlistsView.qml   adlists (inside Lists)
qml/StatsView.qml       "Stats" tab            qml/SettingsView.qml  "More" tab
qml/*Dialog.qml, GroupPicker, StatTile, TopList, ActivityChart, Toast, Format.js   building blocks
tests/                  headless tests: mock Pi-hole server + QML harness (see below)
```

## Tests

`tests/` holds a mock Pi-hole v6 server and a QML harness that drives the real app code against it
(login, concurrent calls sharing one login, session expiry, blocking toggle, query filters incl. the
server-side ones, query details, domain and adlist add/edit/remove incl. URL-encoding, the stats tab, error
cases, timeouts, password-less Pi-hole, v5 detection).
It uses PySide6 with small stand-ins for the Lomiri components, so it checks logic and bindings, not the
Lomiri look.

```sh
pip install PySide6-Essentials
python3 tests/run_tests.py
```

Both this and the real-toolkit check below run on every push and pull request via GitHub Actions
(`.github/workflows/tests.yml`).

### Checking against the real Lomiri toolkit

The PySide6 harness uses stand-ins for the Lomiri components, so it can't catch things the real toolkit
rejects (unsupported properties, Qt 5 JS engine differences). `tests/smoke_lomiri.sh` launches the app on the
real `qml-module-lomiri-components` + Qt 5 `qmlscene` (available from the Ubuntu 24.04 archive) under a
virtual display and fails on any QML error:

```sh
sudo apt install qmlscene qml-module-lomiri-components qml-module-qt-labs-settings qml-module-qtquick2 xvfb suru-icon-theme
./tests/smoke_lomiri.sh
```

## Acknowledgements

Pi-hole Manager was inspired and influenced by [pi-hole-client](https://github.com/tsutsu3/pi-hole-client)
by tsutsu3, the Android app that was the daily driver on the phone this one replaces. Its feature set was the
yardstick for deciding what a good Pi-hole client should do (adlist management, editing list entries, the
query detail screen, richer query filters, a statistics screen). pi-hole-client is itself based on
[DroidHole](https://github.com/JGeek00/droid-hole) by JGeek00, so credit goes there too.

This is an independent implementation for Ubuntu Touch: pure QML against the Pi-hole v6 REST API. No source
code, assets or translations were copied from either project. pi-hole-client is licensed under Apache 2.0.

Pi-hole is a trademark of Pi-hole LLC; this app is not affiliated with or endorsed by the Pi-hole project.
