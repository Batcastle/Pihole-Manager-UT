#!/bin/bash
# Launch the app on the REAL Lomiri toolkit + Qt 5 qmlscene (as on Ubuntu Touch 24.04), headless,
# and fail on any QML load error or runtime warning from the app's own files.
#
# One-time setup (Ubuntu 24.04 / Debian-based):
#   sudo apt install qmlscene qml-module-lomiri-components qml-module-qt-labs-settings \
#                    qml-module-qtquick2 xvfb suru-icon-theme
#
# With a Pi-hole (or tests/mock_pihole.py) listening, the app just shows its first-run screen;
# this only checks that everything loads and renders without errors.
set -u
cd "$(dirname "$0")/.."
export HOME=$(mktemp -d) UITK_ICON_THEME=suru XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/tmp/runtime-$(id -u)}
mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"

echo "== Format.js under Qt 5's JS engine"
out=$(timeout 20 xvfb-run -a qmlscene tests/qt5_format_test.qml 2>&1)
echo "$out" | grep "FORMAT TEST"
echo "$out" | grep -q "FORMAT TEST PASS" || exit 1

echo "== Launching app"
log=$(mktemp)
timeout 8 xvfb-run -a qmlscene qml/Main.qml > "$log" 2>&1
code=$?
# 124 = still running when the timeout hit = it started and stayed up
if [ "$code" -ne 124 ]; then echo "App exited early (code $code):"; cat "$log"; exit 1; fi
bad=$(grep -v "Connections: Implicitly defined\|'caller' is DEPRECATED\|XDG_RUNTIME_DIR" "$log")
if [ -n "$bad" ]; then echo "Warnings/errors:"; echo "$bad"; exit 1; fi
echo "OK: app starts and stays up with no QML errors"
