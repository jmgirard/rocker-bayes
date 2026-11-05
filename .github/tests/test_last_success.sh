#!/usr/bin/env bash
#
# Unit tests for .github/last-success.sh. Each case feeds the script a run list
# shaped like `gh run list --json createdAt,conclusion,event,databaseId` and
# asserts the one line it prints. A stub `gh` on PATH answers `gh run view` with
# a job listing per run: by default one whose "Attach the tags" step succeeded.
# Runs offline: no network, no token.
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

# The stub: `gh run view <id> --json jobs`. $WORK/jobs/<id> holds that run's
# listing; $WORK/jobs/<id>.fail makes the read fail. Anything else it is asked
# exits 64, so an unexpected call is a failure.
mkdir -p "$WORK/bin" "$WORK/jobs"
cat > "$WORK/bin/gh" <<'EOF'
#!/usr/bin/env bash
[ "$1 $2 $4 $5" = "run view --json jobs" ] || { echo "gh stub: unexpected call: $*" >&2; exit 64; }
if [ -e "$GH_STUB_DIR/$3.fail" ]; then echo "HTTP 502" >&2; exit 1; fi
if [ -e "$GH_STUB_DIR/$3" ]; then cat "$GH_STUB_DIR/$3"; exit 0; fi
printf '%s' '{"jobs":[{"name":"publish","steps":[{"name":"Attach the tags","conclusion":"success"}]}]}'
EOF
chmod +x "$WORK/bin/gh"
export GH_STUB_DIR="$WORK/jobs"
export PATH="$WORK/bin:$PATH"

# set_listing <run-createdAt> <listing>: the job listing that run's id answers with
run_id() { printf '%s' "${1//[^0-9]/}"; }
set_listing() { printf '%s' "$2" > "$WORK/jobs/$(run_id "$1")"; }
set_read_fails() { : > "$WORK/jobs/$(run_id "$1").fail"; }
clear_listings() { rm -f "$WORK/jobs/"*; }

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

run() { printf '{"createdAt":"%s","conclusion":"%s","event":"%s","databaseId":%s}' "$1" "$2" "$3" "$(run_id "$1")"; }

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

NEW=2026-10-05T15:48:59Z
OLD=2026-09-28T15:14:55Z
ATTACH_SKIPPED='{"jobs":[{"name":"build (noble, amd64)","steps":[{"name":"Checkout","conclusion":"success"}]},{"name":"publish","steps":[{"name":"Attach the tags","conclusion":"skipped"}]}]}'
NO_ATTACH_STEP='{"jobs":[{"name":"publish","steps":[{"name":"Checkout","conclusion":"success"}]}]}'

# 7. A stale run ended green and moved no tag, so the next older run answers.
clear_listings; set_listing "$NEW" "$ATTACH_SKIPPED"
expect "a newer stale run is passed over" 2026-09-28 "" \
    "[$(run $NEW success schedule),$(run $OLD success schedule)]"

# 8. Every successful run was stale.
clear_listings; set_listing "$NEW" "$ATTACH_SKIPPED"; set_listing "$OLD" "$ATTACH_SKIPPED"
expect "a list of stale runs alone is 'none'" none "" \
    "[$(run $NEW success schedule),$(run $OLD success schedule)]"

# 9. A readable listing with no such step does not count either, so renaming the
# step raises the alert rather than counting every run.
clear_listings; set_listing "$NEW" "$NO_ATTACH_STEP"
expect "a listing with no attach step is passed over" 2026-09-28 "" \
    "[$(run $NEW success schedule),$(run $OLD success schedule)]"

# 10. A listing the script reaches and cannot read.
clear_listings; set_read_fails "$NEW"
expect "a failed listing read is 'unknown'" unknown "could not read the job listing" \
    "[$(run $NEW success schedule),$(run $OLD success schedule)]"
clear_listings; set_listing "$NEW" '{"message":"Not Found"}'
expect "a JSON answer with no list of jobs is 'unknown'" unknown "unreadable job listing" \
    "[$(run $NEW success schedule),$(run $OLD success schedule)]"
clear_listings; set_listing "$NEW" '{"jobs":[{"steps":["oops"]}]}'
expect "a job listing jq cannot process is 'unknown'" unknown "unreadable job listing" \
    "[$(run $NEW success schedule),$(run $OLD success schedule)]"
clear_listings; set_listing "$NEW" ""
expect "an empty answer is 'unknown'" unknown "unreadable job listing" \
    "[$(run $NEW success schedule),$(run $OLD success schedule)]"
clear_listings
expect "a successful run with no id is 'unknown'" unknown "no run id" \
    '[{"createdAt":"2026-10-05T15:48:59Z","conclusion":"success","event":"schedule"}]'

# 11. The walk stops at the first run that counts: an older unreadable listing is
# never read, so it cannot turn a good answer into 'unknown'.
clear_listings; set_read_fails "$OLD"
expect "an unreadable listing past the answer does not matter" 2026-10-05 "" \
    "[$(run $NEW success schedule),$(run $OLD success schedule)]"

if [ "$fails" -ne 0 ]; then
    echo "FAILED: $fails assertion(s)"; exit 1
fi
echo "PASS: all last-success assertions"
