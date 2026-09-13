#!/usr/bin/env bash
#
# Unit tests for .github/retry-decision.sh.
#
# Each case gives the script one attempt number, the cap of 3 that docker.yml
# uses, and the results of the jobs `notify` needs, and asserts the exact two
# lines it prints. Attempts 1 through 4 are driven for every named shape, so
# an off-by-one at the cap and a rule that ignores the attempt are both caught.
# Runs offline and calls nothing.
#
# Usage: bash .github/tests/test_retry_decision.sh
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../retry-decision.sh"
CAP=3
fails=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# expect <desc> <attempt> <want-retry> <want-wait> <job=result>...
expect() {
    local desc="$1" attempt="$2" want_retry="$3" want_wait="$4"; shift 4
    local out rc want
    out="$(bash "$SCRIPT" "$attempt" "$CAP" "$@" 2>"$WORK/err")"; rc=$?
    want="$(printf 'retry=%s\nwait=%s' "$want_retry" "$want_wait")"
    if [ "$rc" -eq 0 ] && [ "$out" = "$want" ]; then
        echo "ok: $desc, attempt $attempt: retry=$want_retry wait=$want_wait"
    else
        echo "FAIL: $desc, attempt $attempt: exit $rc, expected retry=$want_retry wait=$want_wait"
        printf '%s\n' "$out" | sed 's/^/    | /'; sed 's/^/    ! /' "$WORK/err"
        fails=$((fails + 1))
    fi
}

# reject <desc> <regex> <args...>: exit 2, nothing on stdout, message matches
reject() {
    local desc="$1" re="$2"; shift 2
    local out rc
    out="$(bash "$SCRIPT" "$@" 2>"$WORK/err")"; rc=$?
    if [ "$rc" -eq 2 ] && [ -z "$out" ] && grep -qE "$re" "$WORK/err"; then
        echo "ok: $desc"
    else
        echo "FAIL: $desc: exit $rc, stdout '$out'"; sed 's/^/    ! /' "$WORK/err"
        fails=$((fails + 1))
    fi
}

# The shapes docker.yml produces. A failed build leg fails `build`; `publish`
# then fails at its digest guard on main or in test mode, and is skipped on any
# other ref, the shape used here. Both give the same decision. A cancelled
# build leg cancels `build` and skips `publish`.
BUILD_FAIL="build=failure publish=skipped keepalive=success"
PUBLISH_FAIL="build=success publish=failure keepalive=success"
KEEPALIVE_FAIL="build=success publish=success keepalive=failure"
KEEPALIVE_AND_BUILD_FAIL="build=failure publish=skipped keepalive=failure"
BUILD_CANCELLED="build=cancelled publish=skipped keepalive=success"
ALL_GREEN="build=success publish=success keepalive=success"

for a in 1 2; do
    # shellcheck disable=SC2086
    expect "a build failure below the cap retries and waits" "$a" true true $BUILD_FAIL
    # shellcheck disable=SC2086
    expect "a publish failure below the cap retries and waits" "$a" true true $PUBLISH_FAIL
    # shellcheck disable=SC2086
    expect "keepalive and build failing below the cap retries and reports" "$a" true false $KEEPALIVE_AND_BUILD_FAIL
done
for a in 3 4; do
    # shellcheck disable=SC2086
    expect "a build failure at or past the cap reports" "$a" false false $BUILD_FAIL
    # shellcheck disable=SC2086
    expect "a publish failure at or past the cap reports" "$a" false false $PUBLISH_FAIL
    # shellcheck disable=SC2086
    expect "keepalive and build failing at or past the cap reports" "$a" false false $KEEPALIVE_AND_BUILD_FAIL
done
for a in 1 2 3 4; do
    # shellcheck disable=SC2086
    expect "a keepalive failure never retries and reports" "$a" false false $KEEPALIVE_FAIL
    # shellcheck disable=SC2086
    expect "a cancelled build never retries" "$a" false false $BUILD_CANCELLED
    # shellcheck disable=SC2086
    expect "an all-green attempt never retries" "$a" false false $ALL_GREEN
done

# A skipped job outside build and publish is a problem a rerun does not heal.
expect "a skipped keepalive beside a build failure reports" 1 true false \
    build=failure publish=skipped keepalive=skipped

# The cap is read, not assumed: with a cap of 5, attempt 4 still retries.
# shellcheck disable=SC2086
out="$(bash "$SCRIPT" 4 5 $BUILD_FAIL 2>/dev/null)"
if [ "$out" = "$(printf 'retry=true\nwait=true')" ]; then
    echo "ok: a cap of 5 retries on attempt 4"
else
    echo "FAIL: a cap of 5 did not retry on attempt 4: '$out'"; fails=$((fails + 1))
fi

# Rejections: each names what it rejected and prints nothing on stdout, so a
# workflow step reading the output never sees a half answer.
reject "no arguments exits 2"               'usage: '
reject "a missing cap exits 2"              'usage: ' 1
reject "attempt 0 exits 2"                  'attempt \(argument 1\)' 0 3 build=failure
reject "an empty attempt exits 2"           'attempt \(argument 1\)' "" 3 build=failure
reject "a word for the attempt exits 2"     'attempt \(argument 1\)' one 3 build=failure
reject "cap 0 exits 2"                      'cap \(argument 2\)' 1 0 build=failure
reject "a negative cap exits 2"             'cap \(argument 2\)' 1 -3 build=failure
reject "an entry with no = exits 2"         "not a <job>=<result> entry: 'failure'" 1 3 failure
reject "an entry with an empty result exits 2" "not a <job>=<result> entry: 'build='" 1 3 build=

if [ "$fails" -ne 0 ]; then
    echo "FAILED: $fails assertion(s)"; exit 1
fi
echo "PASS: all retry-decision assertions"
