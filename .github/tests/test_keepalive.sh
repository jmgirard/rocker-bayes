#!/usr/bin/env bash
#
# Unit tests for .github/keepalive.sh. Ported from jmgirard/rstudio2u.
#
# A stub `git` on PATH logs every invocation (one line per call, the arguments
# space-joined) and exits 0. The commit path must run `commit --allow-empty`
# and then `push` and nothing else, and every other path must run no git
# command at all. Runs offline: no network, no repository, no credential.
#
# Around the threshold, three neighbours are driven: one day below (no commit),
# exactly at it (commit), and one day above (commit), so an inverted comparison
# and an off-by-one are distinguishable. Each rejection is asserted on the
# argument position it names, so a validator wired to the wrong position fails
# here even though it still rejects.
#
# Usage: bash .github/tests/test_keepalive.sh
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../keepalive.sh"
fails=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/bin"
LOG="$WORK/git.log"
cat > "$WORK/bin/git" <<'EOF'
#!/usr/bin/env bash
args="$*"; printf '%s\n' "${args//$'\n'/ }" >> "$GIT_STUB_LOG"
exit 0
EOF
chmod +x "$WORK/bin/git"
export GIT_STUB_LOG="$LOG"
export PATH="$WORK/bin:$PATH"

# The stub must be the git the script finds. Otherwise every "no git call"
# assertion below would pass by running nothing at all.
if [ "$(command -v git)" != "$WORK/bin/git" ]; then
    echo "FAIL: the git stub is not first on PATH ($(command -v git))"; exit 1
fi

# run_script <args...>: fresh log each run; echoes the exit status.
run_script() {
    : > "$LOG"
    bash "$SCRIPT" "$@" >"$WORK/out" 2>&1
    echo $?
}

assert_rc() {
    local desc="$1" want="$2" got="$3"
    if [ "$got" -eq "$want" ]; then echo "ok: $desc"; else
        echo "FAIL: $desc: expected exit $want, got $got"; sed 's/^/    | /' "$WORK/out"
        fails=$((fails + 1))
    fi
}

# assert_call <desc> <regex>: some logged git call matches the regex
assert_call() {
    local desc="$1" re="$2"
    if grep -qE "$re" "$LOG"; then echo "ok: $desc"; else
        echo "FAIL: $desc: no git call matching /$re/"; sed 's/^/    git /' "$LOG"
        fails=$((fails + 1))
    fi
}

# assert_call_log <desc> <regex...>: the log holds exactly these calls, in this
# order, and no others. assert_call alone would pass an extra or reordered call.
assert_call_log() {
    local desc="$1"; shift
    local want got i=0
    got="$(wc -l < "$LOG" | tr -d ' ')"
    if [ "$got" -ne "$#" ]; then
        echo "FAIL: $desc: expected $# git call(s), got $got"
        sed 's/^/    git /' "$LOG"; fails=$((fails + 1)); return
    fi
    for want in "$@"; do
        i=$((i + 1))
        if ! sed -n "${i}p" "$LOG" | grep -qE "$want"; then
            echo "FAIL: $desc: git call $i does not match /$want/"
            sed 's/^/    git /' "$LOG"; fails=$((fails + 1)); return
        fi
    done
    echo "ok: $desc"
}

# The two calls of the commit path, as assert_call_log patterns.
COMMIT_RE='^-c user\.name=github-actions\[bot\] -c user\.email=[^ ]+ commit --allow-empty -m keepalive: '
PUSH_RE='^push$'

# assert_no_git <desc>: the script ran no git command whatsoever
assert_no_git() {
    local desc="$1"
    if [ -s "$LOG" ]; then
        echo "FAIL: $desc: git was called"; sed 's/^/    git /' "$LOG"
        fails=$((fails + 1))
    else echo "ok: $desc"; fi
}

# assert_out <desc> <regex>: the script's own output matches the regex
assert_out() {
    local desc="$1" re="$2"
    if grep -qE "$re" "$WORK/out"; then echo "ok: $desc"; else
        echo "FAIL: $desc: no output line matching /$re/"; sed 's/^/    | /' "$WORK/out"
        fails=$((fails + 1))
    fi
}

# --- The threshold, and its two neighbours ---------------------------------
# 2026-01-01 plus 50 days is 2026-02-20.

# 1. One day below the threshold: no commit, saying so, no git call.
rc=$(run_script 2026-01-01 2026-02-19 50)
assert_rc     "49 days against a 50-day threshold exits 0" 0 "$rc"
assert_no_git "  ... and calls no git command"
assert_out    "  ... and reports the age it measured" 'is 49 day\(s\) old, below the 50-day threshold'

# 2. Exactly at the threshold: an empty commit by the bot identity, with a
#    message naming itself, then a push, and nothing else.
rc=$(run_script 2026-01-01 2026-02-20 50)
assert_rc  "50 days against a 50-day threshold exits 0" 0 "$rc"
assert_call "  ... commits as the github-actions bot" '^-c user\.name=github-actions\[bot\] -c user\.email=[^ ]+ commit '
assert_call_log "  ... making exactly two calls, commit then push" "$COMMIT_RE" "$PUSH_RE"
assert_out  "  ... reporting the age it measured"     'is 50 day\(s\) old, at or past the 50-day threshold'

# 3. One day above the threshold: the same two calls.
rc=$(run_script 2026-01-01 2026-02-21 50)
assert_rc   "51 days against a 50-day threshold exits 0" 0 "$rc"
assert_call_log "  ... making exactly two calls, commit then push" "$COMMIT_RE" "$PUSH_RE"

# 4. A zero threshold makes any age stale, the shape AC6's dispatch uses.
rc=$(run_script 2026-02-20 2026-02-20 0)
assert_rc   "a same-day commit against a 0-day threshold exits 0" 0 "$rc"
assert_call_log "  ... making exactly two calls, commit then push" "$COMMIT_RE" "$PUSH_RE"

# 5. A real leap day is a real date. 2024 is a leap year, so this is 50 days of
#    age and not a rejection.
rc=$(run_script 2024-02-29 2024-04-19 50)
assert_rc   "a leap day is accepted as a date" 0 "$rc"
assert_call_log "  ... and 50 days later it commits and pushes" "$COMMIT_RE" "$PUSH_RE"

# --- Rejections: each names its own argument, and makes no git call --------

# 6. An absent argument in each position. Positions 1 and 2 are given as an
#    empty string, the shape a workflow expression producing nothing yields.
#    Position 3 is also driven by omitting it.
rc=$(run_script "" 2026-02-20 50)
assert_rc     "an empty commit date exits 2" 2 "$rc"
assert_no_git "  ... and calls no git command"
assert_out    "  ... naming argument 1 as missing" 'commit date \(argument 1\) is missing'

rc=$(run_script 2026-01-01 "" 50)
assert_rc     "an empty current date exits 2" 2 "$rc"
assert_no_git "  ... and calls no git command"
assert_out    "  ... naming argument 2 as missing" 'current date \(argument 2\) is missing'

rc=$(run_script 2026-01-01 2026-02-20 "")
assert_rc     "an empty threshold exits 2" 2 "$rc"
assert_no_git "  ... and calls no git command"
assert_out    "  ... naming argument 3 as missing" 'threshold in days \(argument 3\) is missing'

rc=$(run_script 2026-01-01 2026-02-20)
assert_rc     "an omitted threshold exits 2" 2 "$rc"
assert_no_git "  ... and calls no git command"
assert_out    "  ... naming argument 3 as missing" 'threshold in days \(argument 3\) is missing'

rc=$(run_script)
assert_rc     "no arguments at all exits 2" 2 "$rc"
assert_no_git "  ... and calls no git command"
assert_out    "  ... naming argument 1 first" 'commit date \(argument 1\) is missing'

# 7. Malformed dates in each of the first two positions: a word, and a wrong
#    digit layout. Each is refused by the shape check.
for bad in yesterday 2026-1-1; do
    rc=$(run_script "$bad" 2026-02-20 50)
    assert_rc     "commit date '$bad' exits 2" 2 "$rc"
    assert_no_git "  ... and calls no git command"
    assert_out    "  ... naming argument 1 as not a date" 'commit date \(argument 1\) is not a YYYY-MM-DD date'
    rc=$(run_script 2026-01-01 "$bad" 50)
    assert_rc     "current date '$bad' exits 2" 2 "$rc"
    assert_no_git "  ... and calls no git command"
    assert_out    "  ... naming argument 2 as not a date" 'current date \(argument 2\) is not a YYYY-MM-DD date'
done

# 8. Impossible calendar dates, correctly shaped: a day the month does not have
#    (including 29 February in a common year), and a month that does not
#    exist. A shape-only check would let these into the arithmetic.
for bad in 2026-02-30 2026-02-29 2026-04-31; do
    rc=$(run_script "$bad" 2026-05-20 50)
    assert_rc     "commit date '$bad' exits 2" 2 "$rc"
    assert_no_git "  ... and calls no git command"
    assert_out    "  ... naming a day the month does not have" 'commit date \(argument 1\) names day .* which that month does not have'
    rc=$(run_script 2026-01-01 "$bad" 50)
    assert_rc     "current date '$bad' exits 2" 2 "$rc"
    assert_no_git "  ... and calls no git command"
    assert_out    "  ... naming a day the month does not have" 'current date \(argument 2\) names day .* which that month does not have'
done
for bad in 2026-13-01 2026-00-10; do
    rc=$(run_script "$bad" 2026-02-20 50)
    assert_rc     "commit date '$bad' exits 2" 2 "$rc"
    assert_no_git "  ... and calls no git command"
    assert_out    "  ... naming a month that is not a month" 'commit date \(argument 1\) names month .* which is not a month'
done

# 9. A commit dated one day after the current date. Refused, so a negative age
#    cannot read as fresh.
rc=$(run_script 2026-02-21 2026-02-20 50)
assert_rc     "a commit date one day in the future exits 2" 2 "$rc"
assert_no_git "  ... and calls no git command"
assert_out    "  ... saying which date is later" 'commit date \(argument 1\) is later than the current date'

# 10. A threshold that is not a non-negative integer.
for bad in -1 5.5 fifty " " 50days x; do
    rc=$(run_script 2026-01-01 2026-02-20 "$bad")
    assert_rc     "threshold '$bad' exits 2" 2 "$rc"
    assert_no_git "  ... and calls no git command"
    assert_out    "  ... naming argument 3 as not an integer" 'threshold in days \(argument 3\) is not a non-negative integer'
done

# 11. An over-wide threshold. `10#` on a 19- or 20-digit value wraps to a
#     negative number, which would read as "the age is past it" and commit.
#     Each of these is refused at eight digits and more. The age is past 50
#     days, so a wrap or a skipped check would commit.
for huge in 10000000 9999999999999999999 99999999999999999999999999999999; do
    rc=$(run_script 2026-01-01 2026-02-21 "$huge")
    assert_rc     "a ${#huge}-digit threshold exits 2" 2 "$rc"
    assert_no_git "  ... and calls no git command"
    assert_out    "  ... naming argument 3 as too wide" 'threshold in days \(argument 3\) is wider than seven digits'
done

# 12. The width check reads the value, not the string: a 19-character threshold
#     whose leading zeros strip to 50 is a 50-day threshold.
rc=$(run_script 2026-01-01 2026-02-21 0000000000000000050)
assert_rc   "a zero-padded 50 is still a 50-day threshold" 0 "$rc"
assert_call_log "  ... so a 51-day age commits and pushes" "$COMMIT_RE" "$PUSH_RE"

# 13. A seven-digit threshold is accepted and compared.
rc=$(run_script 2026-01-01 2026-02-19 9999999)
assert_rc     "a 7-digit threshold exits 0" 0 "$rc"
assert_no_git "  ... and calls no git command"
assert_out    "  ... having compared it"              'is 49 day\(s\) old, below the 9999999-day threshold'

# 14. A fourth argument is refused, saying how many it got.
rc=$(run_script 2026-01-01 2026-02-20 50 extra)
assert_rc     "a fourth argument exits 2" 2 "$rc"
assert_no_git "  ... and calls no git command"
assert_out    "  ... saying how many it got"          'expected 3 arguments, got 4'

if [ "$fails" -ne 0 ]; then
    echo "FAILED: $fails assertion(s)"; exit 1
fi
echo "PASS: all keepalive assertions"
