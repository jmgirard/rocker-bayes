#!/usr/bin/env bash
#
# Unit tests for .github/retry-decision.sh.
#
# A stub `gh` on PATH logs every invocation (one line per call, the arguments
# space-joined). It answers `run view` with the jobs listing in $WORK/jobs.json,
# answers the job-log `api` call with $WORK/logs/<job-id>, and answers
# `run rerun` with nothing. Per scenario, a marker file makes one of those
# calls exit non-zero. Each decision is asserted by the script's output line,
# its exit status, and which gh calls ran. Runs offline: no network, no token.
#
# The fixtures are job listings in the shape `gh run view --json jobs` returns
# for docker.yml: each job carries databaseId, name, conclusion, and steps. The
# step names are read from docker.yml when this suite runs, with the matrix
# values filled in per leg, so a renamed step changes the fixtures and the
# script together. GitHub adds "Set up job" first, a "Post <step>" entry for
# each action step, and "Complete job" last.
#
# Usage: bash .github/tests/test_retry_decision.sh
#
set -uo pipefail

command -v jq >/dev/null || { echo "FAIL: jq is required (the fixtures are built with it)"; exit 1; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../retry-decision.sh"
WORKFLOW="$HERE/../workflows/docker.yml"
RUN_ID=555
LINE='Command still failing after 2 attempts: Rscript -e install.packages()'
fails=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/bin" "$WORK/logs"
LOG="$WORK/gh.log"
cat > "$WORK/bin/gh" <<'EOF'
#!/usr/bin/env bash
args="$*"; printf '%s\n' "${args//$'\n'/ }" >> "$GH_STUB_LOG"
case "$1 $2" in
    "run view")
        [ -e "$GH_STUB_DIR/view.fail" ] && exit 1
        cat "$GH_STUB_DIR/jobs.json" ;;
    "run rerun")
        [ -e "$GH_STUB_DIR/rerun.fail" ] && exit 1 ;;
    api\ *)
        id=$(printf '%s' "$2" | sed -n 's#^repos/{owner}/{repo}/actions/jobs/\([0-9]*\)/logs$#\1#p')
        [ -n "$id" ] || exit 1
        [ -e "$GH_STUB_DIR/logs/$id.fail" ] && exit 1
        cat "$GH_STUB_DIR/logs/$id" 2>/dev/null ;;
    *) exit 1 ;;
esac
exit 0
EOF
chmod +x "$WORK/bin/gh"
export GH_STUB_LOG="$LOG" GH_STUB_DIR="$WORK"
export PATH="$WORK/bin:$PATH"

# steps_of <job>: the `- name:` values of one job in docker.yml, in order.
steps_of() {
    awk -v job="$1" '
        /^  [a-z-]+:$/ { injob = ($1 == job ":") ; next }
        injob && /^      - name: / { sub(/^      - name: /, ""); print }
    ' "$WORKFLOW"
}
BUILD_TEMPLATE=$(steps_of build)
PUBLISH_STEPS=$(steps_of publish)

# A parse that stopped matching would build empty fixtures and let every case
# pass for the wrong reason, so the anchors the script relies on must be found.
guard_parse() {
    if ! printf '%s\n' "$2" | grep -qxF "$3"; then
        echo "FAIL: could not read the $1 step '$3' from docker.yml"; exit 1
    fi
}
# The ${{ }} expressions are the literal workflow text, not shell expansions.
# shellcheck disable=SC2016
guard_parse build   "$BUILD_TEMPLATE" 'Build ${{ matrix.variant }} (${{ matrix.arch }}) and push by digest'
guard_parse publish "$PUBLISH_STEPS"  'Require all four verified digests'
echo "ok: read $(printf '%s\n' "$BUILD_TEMPLATE" | wc -l | tr -d ' ') build steps and $(printf '%s\n' "$PUBLISH_STEPS" | wc -l | tr -d ' ') publish steps from docker.yml"

# build_steps <variant> <arch>: the build job's step names for one leg.
build_steps() {
    printf '%s\n' "$BUILD_TEMPLATE" \
        | sed -e "s/\${{ matrix.variant }}/$1/g" -e "s/\${{ matrix.arch }}/$2/g"
}
build_step_name() { printf 'Build %s (%s) and push by digest' "$1" "$2"; }

# job_json <id> <name> <conclusion> <failing-step> <step-names>: one job whose
# steps succeed up to <failing-step>, which fails, and are skipped after it.
# The failing step may be "Set up job" or a "Post ..." name. An empty
# <failing-step> gives an all-green job.
job_json() {
    local id="$1" name="$2" conclusion="$3" failing="$4" names="$5"
    { echo "Set up job"; printf '%s\n' "$names"
      printf '%s\n' "$names" | grep -E '^(Checkout|Set up Docker Buildx|Log in to Docker Hub|Build .* and push by digest|Upload the digest)$' | sed 's/^/Post /' | awk '{ l[NR] = $0 } END { for (i = NR; i > 0; i--) print l[i] }'
      echo "Complete job"; } \
    | jq -R . | jq -s --argjson id "$id" --arg name "$name" --arg c "$conclusion" --arg f "$failing" '
        (if $f == "" then -1 else (index($f) // -2) end) as $at
        | {databaseId: $id, name: $name, conclusion: $c, status: "completed",
           steps: [to_entries[] | {number: (.key + 1), name: .value,
             conclusion: (if $at == -1 then "success"
                          elif .key < $at then "success"
                          elif .key == $at then "failure"
                          elif (.value | startswith("Post ")) or .value == "Complete job" then "success"
                          else "skipped" end)}]}'
}

# Leg ids: noble amd64 101, noble arm64 102, resolute amd64 103, resolute arm64 104.
leg_id() {
    case "$1 $2" in
        "noble amd64") echo 101 ;; "noble arm64") echo 102 ;;
        "resolute amd64") echo 103 ;; "resolute arm64") echo 104 ;;
    esac
}
ALL_LEGS="noble amd64
noble arm64
resolute amd64
resolute arm64"

# leg <variant> <arch> <conclusion> [failing-step] [log-has-line]: a build leg
# job, and its log file. A failed leg defaults to failing at its build step
# with the mirror line in its log.
leg() {
    local v="$1" a="$2" c="$3" f="${4-}" has="${5-yes}" id
    id=$(leg_id "$v" "$a")
    if [ "$c" = failure ] && [ -z "$f" ]; then f=$(build_step_name "$v" "$a"); fi
    if [ "$has" = yes ]; then
        printf 'step output\n%s\nERROR: failed to solve\n' "$LINE" > "$WORK/logs/$id"
    else
        printf 'step output\nERROR: failed to solve: exit code 1\n' > "$WORK/logs/$id"
    fi
    job_json "$id" "build ($v, $a)" "$c" "$f" "$(build_steps "$v" "$a")"
}
publish_job() { job_json 201 publish "$1" "${2-}" "$PUBLISH_STEPS"; }
plain_job() { job_json "$1" "$2" "$3" "${4-}" "Checkout
Run the job"; }
GREEN_KEEPALIVE=$(plain_job 301 keepalive success)
GREEN_NOTIFY=$(plain_job 302 notify success)

# listing <job-json>...: write a jobs document from the given jobs.
listing() {
    jq -s '{jobs: .}' <<< "$(printf '%s\n' "$@")" > "$WORK/jobs.json"
}

# std_listing <failed-legs> [publish-conclusion] [publish-failing-step]: all
# four legs, the legs in <failed-legs> ("variant arch" lines) failing at their
# build step with the line, publish failing at the digest guard, and green
# keepalive and notify jobs.
std_listing() {
    local failed="$1" pc="${2-failure}" pf="${3-Require all four verified digests}" jobs=() v a
    while read -r v a; do
        if printf '%s\n' "$failed" | grep -qxF "$v $a"; then jobs+=("$(leg "$v" "$a" failure)")
        else jobs+=("$(leg "$v" "$a" success)"); fi
    done <<< "$ALL_LEGS"
    jobs+=("$(publish_job "$pc" "$pf")" "$GREEN_KEEPALIVE" "$GREEN_NOTIFY")
    listing "${jobs[@]}"
}

# run_script <event> <attempt> <conclusion>: fresh log and markers each run.
run_script() {
    : > "$LOG"
    bash "$SCRIPT" "$RUN_ID" "$1" "$2" "$3" >"$WORK/out" 2>&1
    echo $?
}
reset_markers() { rm -f "$WORK"/*.fail "$WORK"/logs/*.fail "$WORK"/logs/* "$WORK/jobs.json"; }

assert_rc() {
    local desc="$1" want="$2" got="$3"
    if [ "$got" -eq "$want" ]; then echo "ok: $desc"; else
        echo "FAIL: $desc: expected exit $want, got $got"; sed 's/^/    | /' "$WORK/out"; fails=$((fails + 1))
    fi
}
assert_rc_nonzero() {
    if [ "$2" -ne 0 ]; then echo "ok: $1"; else
        echo "FAIL: $1: expected a non-zero exit, got 0"; sed 's/^/    | /' "$WORK/out"; fails=$((fails + 1))
    fi
}
assert_out() {
    if grep -qE "$2" "$WORK/out"; then echo "ok: $1"; else
        echo "FAIL: $1: no output line matching /$2/"; sed 's/^/    | /' "$WORK/out"; fails=$((fails + 1))
    fi
}
assert_no_out() {
    if grep -qE "$2" "$WORK/out"; then
        echo "FAIL: $1: unexpected output matching /$2/"; sed 's/^/    | /' "$WORK/out"; fails=$((fails + 1))
    else echo "ok: $1"; fi
}
assert_call() {
    if grep -qE "$2" "$LOG"; then echo "ok: $1"; else
        echo "FAIL: $1: no gh call matching /$2/"; sed 's/^/    gh /' "$LOG"; fails=$((fails + 1))
    fi
}
assert_no_gh() {
    if [ -s "$LOG" ]; then
        echo "FAIL: $1: gh was called"; sed 's/^/    gh /' "$LOG"; fails=$((fails + 1))
    else echo "ok: $1"; fi
}
# assert_rerun_calls <desc> <n>: exactly n `run rerun` calls, each for RUN_ID.
assert_rerun_calls() {
    local n
    n=$(grep -c '^run rerun' "$LOG")
    if [ "$n" -ne "$2" ]; then
        echo "FAIL: $1: expected $2 rerun call(s), got $n"; sed 's/^/    gh /' "$LOG"; fails=$((fails + 1))
    elif [ "$2" -eq 1 ] && ! grep -qx "run rerun $RUN_ID --failed" "$LOG"; then
        echo "FAIL: $1: the rerun call is not 'run rerun $RUN_ID --failed'"; sed 's/^/    gh /' "$LOG"; fails=$((fails + 1))
    else echo "ok: $1"; fi
}

# no_rerun <desc> <condition-regex>: exit 0, a no-rerun line naming the
# condition, and no rerun call.
no_rerun() {
    local rc="$1" desc="$2" re="$3"
    assert_rc          "$desc: exits 0" 0 "$rc"
    assert_out         "  ... decides no rerun, naming the broken condition" "^no rerun: .*$re"
    assert_rerun_calls "  ... and makes no rerun call" 0
}
# rerun <desc>: exit 0, a rerun line, and exactly one rerun call for the run.
rerun() {
    local rc="$1" desc="$2"
    assert_rc          "$desc: exits 0" 0 "$rc"
    assert_out         "  ... decides to rerun" '^rerun: '
    assert_no_out      "  ... and never also decides against it" '^no rerun: '
    assert_rerun_calls "  ... with exactly one 'gh run rerun $RUN_ID --failed'" 1
    assert_call        "  ... after reading the jobs listing for attempt 1" "^run view $RUN_ID --attempt 1 --json jobs$"
}

# ere_quote <text>: <text> with its extended-regex metacharacters escaped.
ere_quote() {
    # shellcheck disable=SC2016
    printf '%s' "$1" | sed 's/[][\.*^$()+?{}|]/\\&/g'
}

# --- Rerun decisions -------------------------------------------------------

# One qualifying leg of each of the four legs.
while read -r v a; do
    reset_markers; std_listing "$v $a"
    rc=$(run_script schedule 1 failure)
    rerun "$rc" "one qualifying leg, $v $a"
    assert_call "  ... reading that leg's log" "^api repos/\{owner\}/\{repo\}/actions/jobs/$(leg_id "$v" "$a")/logs --allow-escape-sequences$"
done <<< "$ALL_LEGS"

# Two qualifying legs.
reset_markers; std_listing "noble arm64
resolute amd64"
rc=$(run_script schedule 1 failure)
rerun "$rc" "two qualifying legs"
assert_call "  ... reading the first leg's log"  '^api repos/\{owner\}/\{repo\}/actions/jobs/102/logs --allow-escape-sequences$'
assert_call "  ... and the second leg's log"     '^api repos/\{owner\}/\{repo\}/actions/jobs/103/logs --allow-escape-sequences$'

# --- No-rerun decisions before any gh call ---------------------------------

reset_markers; std_listing "noble amd64"
rc=$(run_script push 1 failure)
no_rerun "$rc" "a push event" 'event'
assert_no_gh "  ... without calling gh"

rc=$(run_script schedule 2 failure)
no_rerun "$rc" "attempt 2" 'attempt'
assert_no_gh "  ... without calling gh"

for c in success cancelled timed_out; do
    rc=$(run_script schedule 1 "$c")
    no_rerun "$rc" "run conclusion $c" 'conclusion'
    assert_no_gh "  ... without calling gh"
done

# --- No-rerun decisions read from the listing ------------------------------

# A failed run whose listing names no failed job.
reset_markers; std_listing "" success ""
rc=$(run_script schedule 1 failure)
no_rerun "$rc" "a listing with no failed job" 'no failed job'

# A qualifying leg beside a leg whose own conclusion is cancelled.
reset_markers
listing "$(leg noble amd64 failure)" "$(leg noble arm64 cancelled "$(build_step_name noble arm64)")" \
    "$(leg resolute amd64 success)" "$(leg resolute arm64 success)" \
    "$(publish_job failure 'Require all four verified digests')" "$GREEN_KEEPALIVE" "$GREEN_NOTIFY"
rc=$(run_script schedule 1 failure)
no_rerun "$rc" "a build leg concluded cancelled" 'build \(noble, arm64\).*cancelled'

# One input per other step of the build job: noble amd64 fails at that step,
# with the mirror line still in its log, so only the step breaks the rule.
while IFS= read -r step; do
    [ "$step" = "$(build_step_name noble amd64)" ] && continue
    reset_markers
    listing "$(leg noble amd64 failure "$step")" "$(leg noble arm64 success)" \
        "$(leg resolute amd64 success)" "$(leg resolute arm64 success)" \
        "$(publish_job failure 'Require all four verified digests')" "$GREEN_KEEPALIVE" "$GREEN_NOTIFY"
    rc=$(run_script schedule 1 failure)
    step_re=$(ere_quote "$step")
    no_rerun "$rc" "a build leg failed at '$step'" "build \(noble, amd64\).*'$step_re'"
done <<< "$(build_steps noble amd64)"

# One input per other step of the publish job, beside a qualifying leg.
while IFS= read -r step; do
    [ "$step" = 'Require all four verified digests' ] && continue
    reset_markers; std_listing "resolute arm64" failure "$step"
    rc=$(run_script schedule 1 failure)
    step_re=$(ere_quote "$step")
    no_rerun "$rc" "publish failed at '$step'" "publish.*'$step_re'"
done <<< "$PUBLISH_STEPS"

# A failed "Set up job" step on a leg.
reset_markers
listing "$(leg noble amd64 failure 'Set up job')" "$(leg noble arm64 success)" \
    "$(leg resolute amd64 success)" "$(leg resolute arm64 success)" \
    "$(publish_job failure 'Require all four verified digests')" "$GREEN_KEEPALIVE" "$GREEN_NOTIFY"
rc=$(run_script schedule 1 failure)
no_rerun "$rc" "a build leg failed at 'Set up job'" "'Set up job'"

# A failed "Post" step on a leg.
reset_markers
post="Post $(build_step_name noble amd64)"
listing "$(leg noble amd64 failure "$post")" "$(leg noble arm64 success)" \
    "$(leg resolute amd64 success)" "$(leg resolute arm64 success)" \
    "$(publish_job failure 'Require all four verified digests')" "$GREEN_KEEPALIVE" "$GREEN_NOTIFY"
rc=$(run_script schedule 1 failure)
no_rerun "$rc" "a build leg failed at its Post step" "'Post Build noble \(amd64\) and push by digest'"

# A qualifying leg beside a leg whose log lacks the line.
reset_markers
listing "$(leg noble amd64 failure)" "$(leg noble arm64 failure '' no)" \
    "$(leg resolute amd64 success)" "$(leg resolute arm64 success)" \
    "$(publish_job failure 'Require all four verified digests')" "$GREEN_KEEPALIVE" "$GREEN_NOTIFY"
rc=$(run_script schedule 1 failure)
no_rerun "$rc" "a leg whose log lacks the mirror line" 'build \(noble, arm64\).*log'

# A failed keepalive, and a failed notify, each beside a qualifying leg.
for jname in keepalive notify; do
    reset_markers
    jobs=("$(leg noble amd64 failure)" "$(leg noble arm64 success)"
          "$(leg resolute amd64 success)" "$(leg resolute arm64 success)"
          "$(publish_job failure 'Require all four verified digests')")
    if [ "$jname" = keepalive ]; then jobs+=("$(plain_job 301 keepalive failure 'Run the job')" "$GREEN_NOTIFY")
    else jobs+=("$GREEN_KEEPALIVE" "$(plain_job 302 notify failure 'Run the job')"); fi
    listing "${jobs[@]}"
    rc=$(run_script schedule 1 failure)
    no_rerun "$rc" "a failed $jname beside a qualifying leg" "$jname"
done

# --- gh failures: non-zero exit, and never a rerun -------------------------

reset_markers; std_listing "noble amd64"; : > "$WORK/view.fail"
rc=$(run_script schedule 1 failure)
assert_rc_nonzero  "gh failing on the listing exits non-zero" "$rc"
assert_out         "  ... reporting the failed listing call" '^::error::gh run view failed for run 555'
assert_rerun_calls "  ... and makes no rerun call" 0

reset_markers; std_listing "noble amd64"; : > "$WORK/logs/101.fail"
rc=$(run_script schedule 1 failure)
assert_rc_nonzero  "gh failing on a leg's log exits non-zero" "$rc"
assert_out         "  ... reporting which log" "^::error::could not read the log of job 'build \\(noble, amd64\\)' \\(101\\)"
assert_rerun_calls "  ... and makes no rerun call" 0

reset_markers; : > "$WORK/jobs.json"
rc=$(run_script schedule 1 failure)
assert_rc_nonzero  "a zero-byte listing exits non-zero" "$rc"
assert_out         "  ... reporting the empty listing" '^::error::the jobs listing for run 555 is empty'
assert_rerun_calls "  ... and makes no rerun call" 0

reset_markers; printf 'not json at all' > "$WORK/jobs.json"
rc=$(run_script schedule 1 failure)
assert_rc_nonzero  "an unparseable listing exits non-zero" "$rc"
assert_out         "  ... reporting the parse failure" '^::error::the jobs listing for run 555 could not be parsed'
assert_rerun_calls "  ... and makes no rerun call" 0

reset_markers; std_listing "noble amd64"; : > "$WORK/rerun.fail"
rc=$(run_script schedule 1 failure)
assert_rc_nonzero  "gh run rerun failing exits non-zero" "$rc"
assert_out         "  ... reporting the failed rerun call" '^::error::gh run rerun 555 --failed failed'
assert_rerun_calls "  ... after exactly one rerun call" 1

# --- Usage ----------------------------------------------------------------

: > "$LOG"
bash "$SCRIPT" "$RUN_ID" schedule 1 >"$WORK/out" 2>&1; rc=$?
assert_rc    "three arguments is a usage error (exit 2)" 2 "$rc"
assert_out   "  ... that prints the usage line" '^usage: '
assert_no_gh "  ... and makes no gh call"

if [ "$fails" -ne 0 ]; then
    echo "FAILED: $fails assertion(s)"; exit 1
fi
echo "PASS: all retry-decision assertions"
