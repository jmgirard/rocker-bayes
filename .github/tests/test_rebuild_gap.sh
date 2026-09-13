#!/usr/bin/env bash
#
# Unit tests for .github/rebuild-gap.sh. Ported from jmgirard/rstudio2u.
#
# Three stubs sit on PATH (`gh`, `curl` and `wget`), each logging every
# invocation to its own file and exiting 0, so "the script decided without
# reaching the network" is asserted by empty logs. The gh stub is the one from
# test_ci_failure_issue.sh: a gap runs the real .github/ci-failure-issue.sh,
# and what that script does is visible only in the gh calls it makes. Runs
# offline: no network, no token.
#
# The bound is "more than <threshold> days", so three neighbours are driven:
# one day below, exactly at it, and one day above. Only the last is a gap. Each
# rejection is asserted on the argument position it names.
#
# The stubs are proved able to record before anything is asserted about their
# silence, because a log that can never fill would make every "no call"
# assertion pass for the wrong reason.
#
# Usage: bash .github/tests/test_rebuild_gap.sh
#
set -uo pipefail

command -v jq >/dev/null || { echo "FAIL: jq is required (the gh stub applies ci-failure-issue.sh's --jq filter)"; exit 1; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../rebuild-gap.sh"
RUN_URL="https://github.com/o/r/actions/runs/456"
fails=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/bin"
GH_LOG="$WORK/gh.log"
CURL_LOG="$WORK/curl.log"
WGET_LOG="$WORK/wget.log"

cat > "$WORK/bin/gh" <<'EOF'
#!/usr/bin/env bash
args="$*"; printf '%s\n' "${args//$'\n'/ }" >> "$GH_STUB_LOG"
if [ "${1:-} ${2:-}" = "issue list" ]; then
    jqf=""
    while [ $# -gt 0 ]; do
        if [ "$1" = "--jq" ]; then jqf="$2"; shift; fi
        shift
    done
    if [ -n "$jqf" ]; then
        printf '%s' "$GH_STUB_LIST" | jq -r "$jqf"
    else
        printf '%s' "$GH_STUB_LIST"
    fi
elif [ "${1:-} ${2:-}" = "issue create" ]; then
    echo "https://github.com/o/r/issues/99"
fi
exit 0
EOF
# curl and wget exist only to be logged. Written out one at a time because each
# needs its own log variable.
cat > "$WORK/bin/curl" <<'EOF'
#!/usr/bin/env bash
args="$*"; printf '%s\n' "${args//$'\n'/ }" >> "$CURL_STUB_LOG"
exit 0
EOF
cat > "$WORK/bin/wget" <<'EOF'
#!/usr/bin/env bash
args="$*"; printf '%s\n' "${args//$'\n'/ }" >> "$WGET_STUB_LOG"
exit 0
EOF
chmod +x "$WORK/bin/gh" "$WORK/bin/curl" "$WORK/bin/wget"
export GH_STUB_LOG="$GH_LOG" CURL_STUB_LOG="$CURL_LOG" WGET_STUB_LOG="$WGET_LOG"
export GH_STUB_LIST='[]'
export PATH="$WORK/bin:$PATH"

# --- The stubs are the commands the script finds, and they record ----------
for c in gh curl wget; do
    if [ "$(command -v "$c")" != "$WORK/bin/$c" ]; then
        echo "FAIL: the $c stub is not first on PATH ($(command -v "$c"))"; exit 1
    fi
done
gh probe-call >/dev/null 2>&1
curl probe-call >/dev/null 2>&1
wget probe-call >/dev/null 2>&1
for pair in "gh:$GH_LOG" "curl:$CURL_LOG" "wget:$WGET_LOG"; do
    c="${pair%%:*}"; f="${pair#*:}"
    if ! grep -q '^probe-call$' "$f" 2>/dev/null; then
        echo "FAIL: the $c stub did not record a call it was given"; exit 1
    fi
done
echo "ok: the gh, curl and wget stubs are on PATH and record what they are given"

# run_script <args...>: fresh logs each run; echoes the exit status.
run_script() {
    : > "$GH_LOG"; : > "$CURL_LOG"; : > "$WGET_LOG"
    RUN_URL="$RUN_URL" bash "$SCRIPT" "$@" >"$WORK/out" 2>&1
    echo $?
}

assert_rc() {
    local desc="$1" want="$2" got="$3"
    if [ "$got" -eq "$want" ]; then echo "ok: $desc"; else
        echo "FAIL: $desc: expected exit $want, got $got"; sed 's/^/    | /' "$WORK/out"
        fails=$((fails + 1))
    fi
}

# assert_call <desc> <regex>: some logged gh call matches the regex
assert_call() {
    local desc="$1" re="$2"
    if grep -qE -- "$re" "$GH_LOG"; then echo "ok: $desc"; else
        echo "FAIL: $desc: no gh call matching /$re/"; sed 's/^/    gh /' "$GH_LOG"
        fails=$((fails + 1))
    fi
}

assert_no_call() {
    local desc="$1" re="$2"
    if grep -qE -- "$re" "$GH_LOG"; then
        echo "FAIL: $desc: unexpected gh call matching /$re/"; sed 's/^/    gh /' "$GH_LOG"
        fails=$((fails + 1))
    else echo "ok: $desc"; fi
}

# assert_no_gh <desc>: the script ran no gh command whatsoever
assert_no_gh() {
    local desc="$1"
    if [ -s "$GH_LOG" ]; then
        echo "FAIL: $desc: gh was called"; sed 's/^/    gh /' "$GH_LOG"
        fails=$((fails + 1))
    else echo "ok: $desc"; fi
}

# assert_offline <desc>: neither curl nor wget was called
assert_offline() {
    local desc="$1" bad=0
    [ -s "$CURL_LOG" ] && { echo "FAIL: $desc: curl was called"; sed 's/^/    curl /' "$CURL_LOG"; bad=1; }
    [ -s "$WGET_LOG" ] && { echo "FAIL: $desc: wget was called"; sed 's/^/    wget /' "$WGET_LOG"; bad=1; }
    if [ "$bad" -eq 1 ]; then fails=$((fails + 1)); else echo "ok: $desc"; fi
}

assert_out() {
    local desc="$1" re="$2"
    if grep -qE -- "$re" "$WORK/out"; then echo "ok: $desc"; else
        echo "FAIL: $desc: no output line matching /$re/"; sed 's/^/    | /' "$WORK/out"
        fails=$((fails + 1))
    fi
}

assert_no_out() {
    local desc="$1" re="$2"
    if grep -qE -- "$re" "$WORK/out"; then
        echo "FAIL: $desc: unexpected output matching /$re/"; sed 's/^/    | /' "$WORK/out"
        fails=$((fails + 1))
    else echo "ok: $desc"; fi
}

# The measured-age branch's own marks: its output line and its issue title.
MEASURED_OUT='succeeded [0-9]+ day\(s\) ago'
MEASURED_TITLE='--title No successful scheduled docker\.yml rebuild in [0-9]+ days'

# --- The bound, and its two neighbours -------------------------------------
# The workflow's threshold is 8. 2026-01-01 plus 8 days is 2026-01-09.

# 1. One day under the bound: no gap, saying so, touching nothing.
rc=$(run_script 2026-01-01 2026-01-08 8)
assert_rc      "7 days against an 8-day bound exits 0" 0 "$rc"
assert_no_gh   "  ... and calls no gh command"
assert_offline "  ... and neither curl nor wget"
assert_out     "  ... reporting the gap it measured" 'succeeded 7 day\(s\) ago, within the 8-day'

# 2. Exactly at the bound: still not a gap.
rc=$(run_script 2026-01-01 2026-01-09 8)
assert_rc      "8 days against an 8-day bound exits 0" 0 "$rc"
assert_no_gh   "  ... and calls no gh command"
assert_offline "  ... and neither curl nor wget"
assert_out     "  ... reporting it as within the bound" 'succeeded 8 day\(s\) ago, within the 8-day'

# 3. One day over the bound: a gap, raised through ci-failure-issue.sh with a
#    subject that gives the gap and the date. The title is anchored on both
#    sides.
rc=$(run_script 2026-01-01 2026-01-10 8)
assert_rc      "9 days against an 8-day bound exits 0" 0 "$rc"
assert_offline "  ... having called neither curl nor wget"
assert_call    "  ... creates a ci-failure issue"  '^issue create .*--label ci-failure'
assert_call    "  ... whose title gives the gap and the date" \
    '^issue create .*--title No successful scheduled docker\.yml rebuild in 9 days \(since 2026-01-01\) --body '
assert_no_call "  ... and never uses the build-failure wording" '--title Weekly run failed'
assert_call    "  ... whose body links this run"   "^issue create .*$RUN_URL"
assert_out     "  ... and says it raised the alert" 'succeeded 9 day\(s\) ago, past the 8-day'

# 4. A gap with the issue already open: a comment on it, no second issue.
GH_STUB_LIST='[{"number":57},{"number":41}]'
rc=$(run_script 2026-01-01 2026-01-10 8)
export GH_STUB_LIST='[]'
assert_rc      "a gap with an open issue exits 0" 0 "$rc"
assert_call    "  ... comments on the oldest open issue (#41)" '^issue comment 41 '
assert_call    "  ... giving the gap"              '^issue comment 41 .*No successful scheduled docker\.yml rebuild in 9 days'
assert_no_call "  ... and opens no second issue"   '^issue create '

# 5. The `none` sentinel: no successful scheduled run on record. It takes its
#    own branch, never the measured-age one, even with a threshold of 0.
for t in 8 0; do
    rc=$(run_script none 2026-01-10 "$t")
    assert_rc      "the 'none' sentinel at threshold $t exits 0" 0 "$rc"
    assert_offline "  ... having called neither curl nor wget"
    assert_call    "  ... raising the alert with its own title" \
        '^issue create .*--label ci-failure .*--title No successful scheduled docker\.yml rebuild on record --body '
    assert_out     "  ... and its own output line" 'no successful scheduled rebuild is on record'
    assert_no_call "  ... and no measured-age title" "$MEASURED_TITLE"
    assert_no_out  "  ... and no measured-age output" "$MEASURED_OUT"
done

# 6. The `unknown` sentinel: the history could not be read. Its own branch too.
for t in 8 0; do
    rc=$(run_script unknown 2026-01-10 "$t")
    assert_rc      "the 'unknown' sentinel at threshold $t exits 0" 0 "$rc"
    assert_offline "  ... having called neither curl nor wget"
    assert_call    "  ... raising the alert with its own title" \
        '^issue create .*--label ci-failure .*--title Could not read the scheduled docker\.yml rebuild history --body '
    assert_out     "  ... and its own output line" 'history could not be read'
    assert_no_call "  ... and no measured-age title" "$MEASURED_TITLE"
    assert_no_call "  ... and not the 'none' title" 'rebuild on record'
    assert_no_out  "  ... and no measured-age output" "$MEASURED_OUT"
done

# 7. A real leap day is a real date: 2024-02-29 plus 9 days is a gap.
rc=$(run_script 2024-02-29 2024-03-09 8)
assert_rc      "a leap day is accepted as a date" 0 "$rc"
assert_call    "  ... and 9 days later it alerts" '^issue create .*--title No successful scheduled docker\.yml rebuild in 9 days'

# --- Rejections: each names its own argument, and makes no gh call ---------

# 8. A value that is not a date, in each of the first two positions.
for bad in yesterday 2026-1-1 2026-02-30 2026-13-01; do
    rc=$(run_script "$bad" 2026-01-17 8)
    assert_rc      "last-success date '$bad' exits 2" 2 "$rc"
    assert_no_gh   "  ... and calls no gh command"
    assert_offline "  ... and neither curl nor wget"
    assert_out     "  ... naming argument 1" 'last success date \(argument 1\)'
    rc=$(run_script 2026-01-01 "$bad" 8)
    assert_rc      "current date '$bad' exits 2" 2 "$rc"
    assert_no_gh   "  ... and calls no gh command"
    assert_out     "  ... naming argument 2" 'current date \(argument 2\)'
done

# 9. The sentinels are argument 1's alone.
for bad in none unknown; do
    rc=$(run_script 2026-01-01 "$bad" 8)
    assert_rc      "current date '$bad' exits 2" 2 "$rc"
    assert_no_gh   "  ... and calls no gh command"
    assert_out     "  ... naming argument 2" 'current date \(argument 2\) is not a YYYY-MM-DD date'
done

# 10. A last-success date after today is refused.
rc=$(run_script 2026-01-18 2026-01-17 8)
assert_rc      "a last-success date one day in the future exits 2" 2 "$rc"
assert_no_gh   "  ... and calls no gh command"
assert_out     "  ... saying which date is later" 'last success date \(argument 1\) is later than the current date'

# 11. A missing threshold, and one that is not a non-negative integer, refused
#     on a measured date and on a sentinel alike.
rc=$(run_script 2026-01-01 2026-01-17 "")
assert_rc      "an empty threshold exits 2" 2 "$rc"
assert_no_gh   "  ... and calls no gh command"
assert_out     "  ... naming argument 3 as missing" 'threshold in days \(argument 3\) is missing'

rc=$(run_script 2026-01-01 2026-01-17)
assert_rc      "an omitted threshold exits 2" 2 "$rc"
assert_no_gh   "  ... and calls no gh command"
assert_out     "  ... naming argument 3 as missing" 'threshold in days \(argument 3\) is missing'

for bad in -1 5.5 eight " " 8days; do
    rc=$(run_script 2026-01-01 2026-01-17 "$bad")
    assert_rc      "threshold '$bad' exits 2" 2 "$rc"
    assert_no_gh   "  ... and calls no gh command"
    assert_out     "  ... naming argument 3" 'threshold in days \(argument 3\) is not a non-negative integer'
done
rc=$(run_script none 2026-01-17 eight)
assert_rc      "a bad threshold beside the 'none' sentinel exits 2" 2 "$rc"
assert_no_gh   "  ... and raises nothing"

# 12. An empty first argument is missing, not a sentinel.
rc=$(run_script "" 2026-01-17 8)
assert_rc      "an empty last-success date exits 2" 2 "$rc"
assert_no_gh   "  ... and calls no gh command"
assert_out     "  ... naming argument 1 as missing" 'last success date \(argument 1\) is missing'

# 13. An over-wide threshold is refused. `10#` on a value of 19 or more digits
#     can wrap negative, which would read as a gap and raise a false alert every
#     week.
for huge in 10000000 9999999999999999999 99999999999999999999999999999999; do
    rc=$(run_script 2026-01-01 2026-01-17 "$huge")
    assert_rc      "a ${#huge}-digit threshold exits 2" 2 "$rc"
    assert_no_gh   "  ... and calls no gh command"
    assert_out     "  ... naming argument 3 as too wide" 'threshold in days \(argument 3\) is wider than seven digits'
done

# 14. A seven-digit threshold is accepted and compared.
rc=$(run_script 2026-01-01 2026-01-17 9999999)
assert_rc      "a 7-digit threshold exits 0" 0 "$rc"
assert_no_gh   "  ... and calls no gh command"
assert_out     "  ... having compared it"      'succeeded 16 day\(s\) ago, within the 9999999-day'

# 15. The width check reads the value: a zero-padded 8 is an 8-day bound.
rc=$(run_script 2026-01-01 2026-01-10 0000000000000000008)
assert_rc      "a zero-padded 8 is still an 8-day bound" 0 "$rc"
assert_call    "  ... so a 9-day gap alerts"  '^issue create .*--title No successful scheduled docker\.yml rebuild in 9 days'

# 16. A fourth argument is refused.
rc=$(run_script 2026-01-01 2026-01-17 8 extra)
assert_rc      "a fourth argument exits 2" 2 "$rc"
assert_no_gh   "  ... and calls no gh command"
assert_out     "  ... saying how many it got" 'expected 3 arguments, got 4'

# 17. No RUN_URL in the environment: the alert still goes out.
: > "$GH_LOG"; : > "$CURL_LOG"; : > "$WGET_LOG"
env -u RUN_URL bash "$SCRIPT" 2026-01-01 2026-01-10 8 >"$WORK/out" 2>&1; rc=$?
assert_rc      "a gap with no RUN_URL still exits 0" 0 "$rc"
assert_call    "  ... and still raises the alert" '^issue create .*--title No successful scheduled docker\.yml rebuild in 9 days'
assert_call    "  ... with a stand-in line for the link" '^issue create .*see the Actions tab'

if [ "$fails" -ne 0 ]; then
    echo "FAILED: $fails assertion(s)"; exit 1
fi
echo "PASS: all rebuild-gap assertions"
