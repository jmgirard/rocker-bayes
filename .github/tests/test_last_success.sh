#!/usr/bin/env bash
#
# Unit tests for .github/last-success.sh. Each case feeds the script a run list
# shaped like `gh run list --json createdAt,conclusion,event` and asserts the
# one line it prints. Runs offline: the script reads stdin and calls only jq.
#
# Case 1 is the run order GitHub returned on 2026-10-06, when rebuild-gap.yml
# took the first run of the list and reported a 64-day gap the day after a
# green scheduled rebuild: the list is not newest first, so the script must
# pick the newest run itself.
#
# Usage: bash .github/tests/test_last_success.sh
#
set -uo pipefail

command -v jq >/dev/null || { echo "FAIL: jq is required (the script under test uses it)"; exit 1; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../last-success.sh"
fails=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# expect <desc> <want-stdout> <want-warning-regex-or-empty> <input>
expect() {
    local desc="$1" want="$2" warn="$3" input="$4" got rc
    got="$(printf '%s' "$input" | bash "$SCRIPT" 2>"$WORK/err")"; rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "FAIL: $desc: expected exit 0, got $rc"; sed 's/^/    | /' "$WORK/err"
        fails=$((fails + 1)); return
    fi
    if [ "$got" != "$want" ]; then
        echo "FAIL: $desc: expected '$want', got '$got'"; sed 's/^/    | /' "$WORK/err"
        fails=$((fails + 1)); return
    fi
    if [ -n "$warn" ]; then
        if ! grep -qE -- "^::warning::.*$warn" "$WORK/err"; then
            echo "FAIL: $desc: no ::warning:: line matching /$warn/"; sed 's/^/    | /' "$WORK/err"
            fails=$((fails + 1)); return
        fi
    elif [ -s "$WORK/err" ]; then
        echo "FAIL: $desc: unexpected stderr"; sed 's/^/    | /' "$WORK/err"
        fails=$((fails + 1)); return
    fi
    echo "ok: $desc"
}

run() { printf '{"createdAt":"%s","conclusion":"%s","event":"%s"}' "$1" "$2" "$3"; }

# 1. Out of order: the newest success is not first.
expect "the newest success is picked when the list is not newest first" 2026-10-05 "" \
    "[$(run 2026-08-03T10:49:38Z success schedule),$(run 2026-10-05T15:48:59Z success schedule),$(run 2026-09-28T15:14:55Z success schedule)]"

# 2. Newest first, the ordinary case.
expect "a newest-first list gives its first run" 2026-10-05 "" \
    "[$(run 2026-10-05T15:48:59Z success schedule),$(run 2026-09-28T15:14:55Z success schedule)]"

# 3. A newer run that failed, or has not finished, is not a success.
expect "a newer failed run is passed over" 2026-09-28 "" \
    "[$(run 2026-10-05T15:48:59Z failure schedule),$(run 2026-09-28T15:14:55Z success schedule)]"
expect "a newer unfinished run is passed over" 2026-09-28 "" \
    "[$(run 2026-10-05T15:48:59Z "" schedule),$(run 2026-09-28T15:14:55Z success schedule)]"

# 4. A newer green push or dispatch build is not a scheduled rebuild.
expect "a newer green push build is passed over" 2026-09-28 "" \
    "[$(run 2026-10-05T15:48:59Z success push),$(run 2026-09-28T15:14:55Z success schedule)]"
expect "a newer green dispatch build is passed over" 2026-09-28 "" \
    "[$(run 2026-10-05T15:48:59Z success workflow_dispatch),$(run 2026-09-28T15:14:55Z success schedule)]"

# 5. No successful scheduled run in the list.
expect "an empty list is 'none'" none "" "[]"
expect "a list of failures and non-scheduled successes is 'none'" none "" \
    "[$(run 2026-10-05T15:48:59Z failure schedule),$(run 2026-09-28T15:14:55Z success push)]"

# 6. Input the script cannot read.
expect "input that is not JSON is 'unknown'" unknown "not a JSON list" "HTTP 502"
expect "a list holding a non-object is read past it" 2026-09-28 "" \
    "[1,null,$(run 2026-09-28T15:14:55Z success schedule)]"
expect "a JSON object is 'unknown'" unknown "not a JSON list" '{"message":"Bad credentials"}'
expect "empty input is 'unknown'" unknown "not a JSON list" ""
expect "a newest createdAt that is not RFC 3339 is 'unknown'" unknown "unparseable createdAt" \
    "[$(run 2026-09-28T15:14:55Z success schedule),$(run "Oct 5 2026" success schedule)]"

if [ "$fails" -ne 0 ]; then
    echo "FAILED: $fails assertion(s)"; exit 1
fi
echo "PASS: all last-success assertions"
