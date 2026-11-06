#!/usr/bin/env bash
#
# Guard: each stop launcher's closing message says that the files in the home
# folder are kept, and does not say that the user can resume where they left
# off. Installed R packages are lost when a start pulls a newer image (README
# "Keeping installed packages"), so "resume where you left off" is false.
# The text is synced from jmgirard/rstudio2u.
#
# Reads the tracked blobs from the index. Runs offline, no dependencies.
#
# Usage: bash .github/tests/test_stop_launcher_text.sh
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
cd "$REPO" || { echo "FAIL: cannot cd to repo root"; exit 1; }
fails=0

for f in stop_linux.sh stop_mac.command stop_windows.bat; do
    if ! git ls-files --error-unmatch -- "$f" >/dev/null 2>&1; then
        echo "FAIL: $f is not tracked"; fails=$((fails + 1)); continue
    fi
    blob="$(git cat-file -p ":$f")"
    if ! grep -qF "Server stopped. The files in your home folder are kept." <<<"$blob"; then
        echo "FAIL: $f does not say that the home folder's files are kept"
        fails=$((fails + 1)); continue
    fi
    if ! grep -qF "to start the server again." <<<"$blob"; then
        echo "FAIL: $f does not say how to start the server again"
        fails=$((fails + 1)); continue
    fi
    if grep -qiF "resume where you left off" <<<"$blob"; then
        echo "FAIL: $f still says the user can resume where they left off"
        fails=$((fails + 1)); continue
    fi
    echo "ok: $f"
done

if [ "$fails" -ne 0 ]; then
    echo "FAILED: $fails stop launcher(s) with the wrong closing message"; exit 1
fi
echo "PASS: all stop launchers say the home folder's files are kept"
