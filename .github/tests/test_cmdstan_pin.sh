#!/usr/bin/env bash
#
# Consistency test for the CmdStan pin.
#
# The Dockerfile ARG is the single pin (GP3). The README repeats the version
# in its tag table and in its pinning examples, so a bump that touches only
# the Dockerfile leaves the README teaching a stale version. This test reads
# the pin from the Dockerfile and fails when any CmdStan version string in
# the README differs from it. Runs offline.
#
# Usage: bash .github/tests/test_cmdstan_pin.sh
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE/../.."
fails=0

PIN="$(sed -n 's/^ARG CMDSTAN_VERSION="\([^"]*\)".*/\1/p' "$ROOT/Dockerfile")"
if ! [[ "$PIN" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "FAIL: could not read a x.y.z CMDSTAN_VERSION from the Dockerfile ARG line (got '$PIN')"
    exit 1
fi
echo "Dockerfile pins CmdStan $PIN"

# The Dockerfile comment shows the override syntax with a version; it must
# name the current pin so the example stays copy-pasteable.
if ! grep -q "CMDSTAN_VERSION=$PIN \." "$ROOT/Dockerfile"; then
    echo "FAIL: Dockerfile build-arg example does not name $PIN"; fails=$((fails + 1))
fi

# Every version-looking string next to the word cmdstan in the README, in
# either spelling: the `cmdstan2.39.0` tag form and the `| 2.39.0 |` column.
found=0
while IFS= read -r line; do
    n="${line%%:*}"; text="${line#*:}"
    while IFS= read -r v; do
        [ -n "$v" ] || continue
        found=$((found + 1))
        if [ "$v" != "$PIN" ]; then
            echo "FAIL: README.md:$n names CmdStan $v, Dockerfile pins $PIN"; fails=$((fails + 1))
        fi
    done < <(grep -oiE 'cmdstan[0-9]+\.[0-9]+\.[0-9]+|\|[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+[[:space:]]*\|' <<<"$text" \
             | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
done < <(grep -niE 'cmdstan[0-9]|\|[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+[[:space:]]*\|' "$ROOT/README.md")

if [ "$found" -eq 0 ]; then
    echo "FAIL: no CmdStan version strings found in README.md (pattern drift?)"; fails=$((fails + 1))
fi

if [ "$fails" -eq 0 ]; then
    echo "PASS: $found README references match the Dockerfile pin $PIN"
    exit 0
fi
echo "$fails failure(s)"
exit 1
