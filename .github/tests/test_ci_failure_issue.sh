#!/usr/bin/env bash
#
# Unit tests for .github/ci-failure-issue.sh. Ported from jmgirard/rstudio2u.
#
# A stub `gh` on PATH logs every invocation (one line per call, the arguments
# space-joined) and answers `issue list` with canned JSON per scenario. The
# branches (failure with no open issue creates; failure with an open issue
# comments on the oldest; success with open issues comments on and closes each;
# success with none writes nothing; cancelled does nothing) are asserted by
# WHICH subcommand ran on WHICH issue number, never by call counts. Runs
# offline: no network, no token.
#
# The fixtures are job listings in the shape docker.yml's jobs produce: one
# build leg per (variant, arch) named "build (<variant>, <arch>)", and the plain
# jobs `publish` and `keepalive` beside them.
#
# Usage: bash .github/tests/test_ci_failure_issue.sh
#
set -uo pipefail

command -v jq >/dev/null || { echo "FAIL: jq is required (the gh stub applies the script's --jq filter)"; exit 1; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../ci-failure-issue.sh"
RUN_URL="https://github.com/o/r/actions/runs/123"
fails=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/bin"
LOG="$WORK/gh.log"
# The stub: append the argv to the log. `issue list` prints the JSON in
# GH_STUB_LIST through the script's own --jq filter, applied with the real jq.
cat > "$WORK/bin/gh" <<'EOF'
#!/usr/bin/env bash
args="$*"; printf '%s\n' "${args//$'\n'/ }" >> "$GH_STUB_LOG"
if [ "$1 $2" = "issue list" ]; then
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
elif [ "$1 $2" = "issue create" ]; then
    echo "https://github.com/o/r/issues/99"
fi
exit 0
EOF
chmod +x "$WORK/bin/gh"
export GH_STUB_LOG="$LOG"
export PATH="$WORK/bin:$PATH"

# run_script <result> <list-json> [jobs-json] [subject]: fresh log each run.
# The third argument is the content of a jobs document. It is written to a temp
# file and the file's path handed to the script, as the notify job does. With a
# subject and no jobs document, an empty jobs position goes ahead of the
# subject, the shape .github/rebuild-gap.sh uses.
run_script() {
    local result="$1" list="$2" jobs="${3-}" subject="${4-}"
    : > "$LOG"
    local args=("$result" "$RUN_URL")
    if [ -n "$jobs" ]; then
        printf '%s' "$jobs" > "$WORK/jobs.json"
        args+=("$WORK/jobs.json")
    elif [ -n "$subject" ]; then
        args+=("")
    fi
    [ -n "$subject" ] && args+=("$subject")
    GH_STUB_LIST="$list" bash "$SCRIPT" "${args[@]}" >"$WORK/out" 2>&1
    echo $?
}

# job <name> <conclusion>: one entry of a `gh run view --json jobs` document
job() { printf '{"name":"%s","conclusion":"%s"}' "$1" "$2"; }
jobs_doc() {
    local out="" j
    for j in "$@"; do out="${out:+$out,}$j"; done
    printf '{"jobs":[%s]}' "$out"
}

# noble's arm64 build leg failed, which also fails the publish job. Every
# resolute leg is green. "noble" must be named once and "resolute" not at all.
FIX_ARM64_FAIL=$(jobs_doc \
    "$(job 'build (noble, amd64)' success)" \
    "$(job 'build (noble, arm64)' failure)" \
    "$(job 'build (resolute, amd64)' success)" \
    "$(job 'build (resolute, arm64)' success)" \
    "$(job 'publish' failure)" \
    "$(job 'keepalive' success)")

# Every build leg green. Only the publish job failed, for example a registry
# hiccup in `imagetools create`. publish is a single job here, so it is named by
# its own name and no variant is named.
FIX_PUBLISH_ONLY_FAIL=$(jobs_doc \
    "$(job 'build (noble, amd64)' success)" \
    "$(job 'build (noble, arm64)' success)" \
    "$(job 'build (resolute, amd64)' success)" \
    "$(job 'build (resolute, arm64)' success)" \
    "$(job 'publish' failure)" \
    "$(job 'keepalive' success)")

# Every job green.
FIX_ALL_GREEN=$(jobs_doc \
    "$(job 'build (noble, amd64)' success)" \
    "$(job 'build (noble, arm64)' success)" \
    "$(job 'build (resolute, amd64)' success)" \
    "$(job 'build (resolute, arm64)' success)" \
    "$(job 'publish' success)" \
    "$(job 'keepalive' success)")

# Both variants down, with a green leg among them.
FIX_BOTH_FAIL=$(jobs_doc \
    "$(job 'build (noble, amd64)' failure)" \
    "$(job 'build (noble, arm64)' failure)" \
    "$(job 'build (resolute, amd64)' success)" \
    "$(job 'build (resolute, arm64)' failure)" \
    "$(job 'publish' failure)")

# Only the keepalive job failed. The images published, so no variant is at
# fault, and the alert has to name the job that was.
FIX_KEEPALIVE_FAIL=$(jobs_doc \
    "$(job 'build (noble, amd64)' success)" \
    "$(job 'build (noble, arm64)' success)" \
    "$(job 'build (resolute, amd64)' success)" \
    "$(job 'build (resolute, arm64)' success)" \
    "$(job 'publish' success)" \
    "$(job 'keepalive' failure)")

# noble's two build legs failed, and resolute's legs are green. The two noble
# legs collapse to one name, and the failed publish job keeps its own name.
# Expected: "noble publish", in listing order.
FIX_DEDUP_MIX=$(jobs_doc \
    "$(job 'build (noble, amd64)' failure)" \
    "$(job 'build (noble, arm64)' failure)" \
    "$(job 'build (resolute, amd64)' success)" \
    "$(job 'build (resolute, arm64)' success)" \
    "$(job 'publish' failure)" \
    "$(job 'keepalive' success)")

# The job name GitHub generates for a matrix `include` leg when the workflow
# sets no explicit `name:`: every include key, in order.
FIX_MULTIKEY=$(jobs_doc \
    "$(job 'build (noble, noble, amd64, ubuntu-latest)' success)" \
    "$(job 'build (noble, noble, arm64, ubuntu-24.04-arm)' failure)" \
    "$(job 'build (resolute, resolute, amd64, ubuntu-latest)' success)" \
    "$(job 'build (resolute, resolute, arm64, ubuntu-24.04-arm)' success)")

# assert_call <desc> <regex>: some logged gh call matches the regex
assert_call() {
    local desc="$1" re="$2"
    if grep -qE "$re" "$LOG"; then echo "ok: $desc"; else
        echo "FAIL: $desc: no gh call matching /$re/"; sed 's/^/    gh /' "$LOG"
        fails=$((fails + 1))
    fi
}

# assert_no_call <desc> <regex>: no logged gh call matches the regex
assert_no_call() {
    local desc="$1" re="$2"
    if grep -qE "$re" "$LOG"; then
        echo "FAIL: $desc: unexpected gh call matching /$re/"; sed 's/^/    gh /' "$LOG"
        fails=$((fails + 1))
    else echo "ok: $desc"; fi
}

# assert_no_gh <desc>: no gh call at all
assert_no_gh() {
    if [ -s "$LOG" ]; then
        echo "FAIL: $1: gh was called"; sed 's/^/    gh /' "$LOG"
        fails=$((fails + 1))
    else echo "ok: $1"; fi
}

# assert_out <desc> <regex>: the script's own output matches the regex
assert_out() {
    local desc="$1" re="$2"
    if grep -qE "$re" "$WORK/out"; then echo "ok: $desc"; else
        echo "FAIL: $desc: no output line matching /$re/"; sed 's/^/    | /' "$WORK/out"
        fails=$((fails + 1))
    fi
}

# assert_no_out <desc> <regex>: the script's output matches nothing
assert_no_out() {
    local desc="$1" re="$2"
    if grep -qE "$re" "$WORK/out"; then
        echo "FAIL: $desc: unexpected output matching /$re/"; sed 's/^/    | /' "$WORK/out"
        fails=$((fails + 1))
    else echo "ok: $desc"; fi
}

assert_rc() {
    local desc="$1" want="$2" got="$3"
    if [ "$got" -eq "$want" ]; then echo "ok: $desc"; else
        echo "FAIL: $desc: expected exit $want, got $got"; cat "$WORK/out"; fails=$((fails + 1))
    fi
}

NONE='[]'
TWO='[{"number":57},{"number":41}]'   # newest first, as gh lists them

# 1. failure, no open issue: create, labelled, naming the variant and run URL.
# The title regex is anchored on both sides ("...: noble publish --body"), so it
# fails if "noble" were repeated or "resolute" added.
rc=$(run_script failure "$NONE" "$FIX_ARM64_FAIL")
assert_rc      "failure/none exits 0" 0 "$rc"
assert_call    "failure/none creates an issue"                '^issue create '
assert_call    "  ... with the ci-failure label"              '^issue create .*--label ci-failure'
assert_call    "  ... whose title names the failed variant once, then publish" '^issue create .*--title Weekly run failed: noble publish --body '
assert_no_call "  ... and never names the all-green variant"  '^issue create .*resolute'
# The stub joins argv on spaces, so the body's blank line before "Run:" shows
# as two spaces.
assert_call    "  ... whose body opens with the failed-job wording" '^issue create .*--body The scheduled run failed in: noble publish  Run: '
assert_call    "  ... whose body links the run"               "^issue create .*$RUN_URL"
assert_call    "failure/none ensures the label exists"        '^label create ci-failure --force'
assert_no_call "failure/none comments on nothing"             '^issue comment '
assert_no_call "failure/none closes nothing"                  '^issue close '
assert_no_out  "  ... and warns about nothing"                '::warning::'

# 2. failure, open issues: comment on the oldest, create nothing.
rc=$(run_script failure "$TWO" "$FIX_ARM64_FAIL")
assert_rc      "failure/open exits 0" 0 "$rc"
assert_call    "failure/open comments on the oldest open issue (#41)" '^issue comment 41 '
assert_call    "  ... naming the failed variant"              '^issue comment 41 .*noble'
assert_no_call "failure/open does not comment on #57"        '^issue comment 57 '
assert_no_call "failure/open creates no second issue"        '^issue create '
assert_no_call "failure/open closes nothing"                  '^issue close '

# 3. success, open issues: comment on and close each.
rc=$(run_script "success success success" "$TWO" "$FIX_ALL_GREEN")
assert_rc      "success/open exits 0" 0 "$rc"
assert_call    "success/open comments on #41"                 '^issue comment 41 '
assert_call    "success/open closes #41"                      '^issue close 41$'
assert_call    "success/open comments on #57"                 '^issue comment 57 '
assert_call    "success/open closes #57"                      '^issue close 57$'
assert_no_call "success/open creates nothing"                 '^issue create '

# 4. success, no open issue: reads the list, writes nothing.
rc=$(run_script success "$NONE")
assert_rc      "success/none exits 0" 0 "$rc"
assert_call    "success/none lists open ci-failure issues"    '^issue list .*--label ci-failure .*--state open .*--limit 100'
assert_no_call "success/none creates nothing"                 '^issue create '
assert_no_call "success/none comments on nothing"             '^issue comment '
assert_no_call "success/none closes nothing"                  '^issue close '

# 5. failure, no jobs document: the title carries the fallback.
rc=$(run_script failure "$NONE")
assert_rc      "failure/no-listing exits 0" 0 "$rc"
assert_call    "failure/no-listing creates an issue with the fallback title" '^issue create .*--title Weekly run failed: \(see the run summary'

# 5b. Both variants down: both named, each once, in job order.
rc=$(run_script failure "$NONE" "$FIX_BOTH_FAIL")
assert_rc      "failure/both-variants exits 0" 0 "$rc"
assert_call    "both failed variants named, each once" '^issue create .*--title Weekly run failed: noble resolute publish --body '

# 5c. GitHub's auto-generated multi-key job name parses to the same variant.
rc=$(run_script failure "$NONE" "$FIX_MULTIKEY")
assert_rc      "failure/multikey-name exits 0" 0 "$rc"
assert_call    "multi-key job name yields just the variant" '^issue create .*--title Weekly run failed: noble --body '

# 5d. An unparseable jobs document must not abort the alert: fallback text, and
# jq's complaint is surfaced.
rc=$(run_script failure "$NONE" 'not json at all')
assert_rc      "failure/unparseable-jobs exits 0" 0 "$rc"
assert_call    "an unparseable jobs document yields the fallback title" '^issue create .*--title Weekly run failed: \(see the run summary'
assert_out     "  ... and reports why it could not be parsed"  '::warning::could not parse the job listing'
assert_no_out  "  ... without also claiming the listing was clean" '::warning::the run is reported failed'

# 5e. Only publish failed. It is named by its own name, not parsed for a
# variant, and no variant is named.
rc=$(run_script failure "$NONE" "$FIX_PUBLISH_ONLY_FAIL")
assert_rc      "failure/publish-only exits 0" 0 "$rc"
assert_call    "a publish-only failure names publish" '^issue create .*--title Weekly run failed: publish --body '
assert_no_call "  ... and names no variant"                   '^issue create .*(noble|resolute)'
assert_no_out  "  ... and warns about nothing"                '::warning::'

# 5f. A run reported failed whose job listing shows every job green. The alert
# still goes out, with the generic wording, and says the listing explained
# nothing.
rc=$(run_script failure "$NONE" "$FIX_ALL_GREEN")
assert_rc      "failure/all-green-listing exits 0" 0 "$rc"
assert_call    "a failed run with an all-green listing falls back" '^issue create .*--title Weekly run failed: \(see the run summary'
assert_out     "  ... and says the listing named no failed job"   '::warning::the run is reported failed but its job listing names no failed'
assert_no_out  "  ... without blaming the parser"             '::warning::could not parse'

# 5g. Only the keepalive job failed: named in the title and the body.
rc=$(run_script failure "$NONE" "$FIX_KEEPALIVE_FAIL")
assert_rc      "failure/keepalive-only exits 0" 0 "$rc"
assert_call    "a keepalive-only failure names keepalive in the title" '^issue create .*--title Weekly run failed: keepalive --body '
assert_call    "  ... and in the body"                        '^issue create .*--body The scheduled run failed in: keepalive'
assert_no_call "  ... and names no variant"                   '^issue create .*(noble|resolute)'
assert_no_out  "  ... and warns about nothing"                '::warning::'

# 5h. Two failed legs of one variant beside a failed publish job: the dedup
# holds, and neither the green variant nor the green keepalive is named.
rc=$(run_script failure "$NONE" "$FIX_DEDUP_MIX")
assert_rc      "failure/dedup-mix exits 0" 0 "$rc"
assert_call    "the variant named once, then publish, in listing order" '^issue create .*--title Weekly run failed: noble publish --body '
assert_no_call "  ... and the green keepalive job is not named" '^issue create .*keepalive'
assert_no_call "  ... and the green variant is not named"     '^issue create .*resolute'

# 5i. The keepalive result reaches the aggregation. Every image job succeeded,
# so the list is green but for keepalive, which must still take the comment
# path and never close the open issue.
rc=$(run_script "success success success failure" "$TWO" "$FIX_KEEPALIVE_FAIL")
assert_rc      "keepalive failure in the results list exits 0" 0 "$rc"
assert_no_call "a failed keepalive never closes the issue"    '^issue close '
assert_call    "  ... it comments on the open issue instead"  '^issue comment 41 '
assert_call    "  ... naming the failed job"                  '^issue comment 41 .*keepalive'

# 5j. A subject given: it is the whole title and the lead line of the body. The
# jobs position is empty, as the gap check leaves it, and that must not trip the
# "listing explained nothing" warning.
SUBJECT='No successful scheduled docker.yml rebuild in 16 days (since 2026-01-01)'
SUBJECT_RE='No successful scheduled docker\.yml rebuild in 16 days \(since 2026-01-01\)'
rc=$(run_script failure "$NONE" "" "$SUBJECT")
assert_rc      "failure with a subject exits 0" 0 "$rc"
assert_call    "a subject becomes the whole issue title" "^issue create .*--title $SUBJECT_RE --body "
assert_call    "  ... and the lead line of the body"     "^issue create .*--body $SUBJECT_RE  Run: "
assert_no_call "  ... replacing the failed-job wording"  'Weekly run failed|The scheduled run failed in'
assert_no_call "  ... and never the generic fallback"    'see the run summary'
assert_no_out  "  ... warning about nothing"             '::warning::'

# 5k. The same subject with the issue already open: the comment's lead line is
# the subject too.
rc=$(run_script failure "$TWO" "" "$SUBJECT")
assert_rc      "a subject with an open issue exits 0" 0 "$rc"
assert_call    "the comment's lead line is the subject" "^issue comment 41 --body $SUBJECT_RE  Run: "
assert_no_call "  ... not the failed-again wording"     'The scheduled run failed again in'
assert_no_call "  ... and opens no second issue"        '^issue create '

# 5l. A subject alongside a jobs document naming a failed job: the subject wins.
rc=$(run_script failure "$NONE" "$FIX_KEEPALIVE_FAIL" "$SUBJECT")
assert_rc      "a subject alongside a jobs document exits 0" 0 "$rc"
assert_call    "the subject still owns the title"        "^issue create .*--title $SUBJECT_RE --body "
assert_no_call "  ... and the job name is not appended"  '^issue create .*keepalive'

# 5m. A multi-line subject is trimmed to its first line.
rc=$(run_script failure "$NONE" "" "$(printf 'First line\nSecond line')")
assert_rc      "a multi-line subject exits 0" 0 "$rc"
assert_call    "only the first line becomes the title"   '^issue create .*--title First line --body '
assert_no_call "  ... and the second line is dropped"    'Second line'

# 6. Aggregating the needed jobs' results. Each case is asserted by which gh
# subcommand ran on which issue, so "did not close" is distinguishable from
# "did nothing".

# 6a. A single cancelled result: no gh call at all.
rc=$(run_script cancelled "$TWO" "$FIX_ARM64_FAIL")
assert_rc      "cancelled exits 0" 0 "$rc"
assert_no_gh   "cancelled makes no gh call"

# 6b. Cancelled members beside successes are ignored too.
rc=$(run_script "success cancelled cancelled success" "$TWO" "$FIX_ALL_GREEN")
assert_rc      "cancelled beside successes exits 0" 0 "$rc"
assert_no_gh   "cancelled beside successes makes no gh call"

# 6c. Green builds, publish skipped: no tag moved. Must not close #41/#57.
rc=$(run_script "success skipped success" "$TWO" "$FIX_ALL_GREEN")
assert_rc      "a skipped publish exits 0" 0 "$rc"
assert_no_call "a skipped publish never closes the issue"     '^issue close '
assert_call    "  ... it comments on the open issue instead"  '^issue comment 41 '

# 6d. The same shape with no open issue: the failure is reported.
rc=$(run_script "success skipped success" "$NONE" "$FIX_ALL_GREEN")
assert_rc      "a skipped publish, none open, exits 0" 0 "$rc"
assert_call    "a skipped publish opens an issue"             '^issue create '

# 6e. A skipped job beside a cancelled one is still reported. A build leg that
# timed out reads as cancelled and skips publish, and that run moved no tag.
rc=$(run_script "cancelled skipped success" "$NONE" "$FIX_ALL_GREEN")
assert_rc      "skipped beside cancelled exits 0" 0 "$rc"
assert_call    "skipped beside cancelled opens an issue"      '^issue create '
rc=$(run_script "cancelled skipped success" "$TWO" "$FIX_ALL_GREEN")
assert_call    "  ... or comments on the open one"            '^issue comment 41 '
assert_no_call "  ... and never closes it"                    '^issue close '

# 6f. A value none of the known results names is still not a success.
rc=$(run_script "success success neutral" "$TWO" "$FIX_ALL_GREEN")
assert_rc      "an unrecognised result exits 0" 0 "$rc"
assert_no_call "an unrecognised result never closes the issue" '^issue close '
assert_call    "  ... it comments on the open issue instead"  '^issue comment 41 '

# 6g. A real failure outranks a cancellation.
rc=$(run_script "success failure cancelled" "$NONE" "$FIX_ARM64_FAIL")
assert_rc      "failure alongside cancelled exits 0" 0 "$rc"
assert_call    "a failure outranks a cancellation and opens an issue" '^issue create .*--title Weekly run failed: noble publish --body '

# 6h. An empty results list reported nothing successful, so it is not a success.
rc=$(run_script "" "$TWO" "$FIX_ALL_GREEN")
assert_rc      "an empty results list exits 0" 0 "$rc"
assert_no_call "an empty results list never closes the issue" '^issue close '
assert_call    "  ... it reports the failure instead"         '^issue comment 41 '

# Usage error: fewer than two args exits 2 without calling gh.
: > "$LOG"
bash "$SCRIPT" failure >"$WORK/out" 2>&1; rc=$?
assert_rc      "missing run-url is a usage error (exit 2)" 2 "$rc"
assert_out     "  ... that prints the usage line" '^usage: '
assert_no_gh   "  ... and makes no gh call"

if [ "$fails" -ne 0 ]; then
    echo "FAILED: $fails assertion(s)"; exit 1
fi
echo "PASS: all ci-failure-issue assertions"
