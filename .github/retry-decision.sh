#!/usr/bin/env bash
#
# Decide whether a completed docker.yml run gets one rerun of its failed jobs,
# and make that rerun. Called by .github/workflows/rebuild-retry.yml, which
# `workflow_run` starts each time a docker.yml run completes. Tested offline by
# .github/tests/test_retry_decision.sh.
#
# The rule: rerun only a scheduled run's first attempt that concluded failure,
# and only when the failure is the r2u mirror symptom. That means at least one
# build leg failed, every failed build leg failed at its
# "Build <variant> (<arch>) and push by digest" step, and each such leg's log
# holds the line scripts/install_bayes.sh prints when its short in-build retry
# gives up. The only other job allowed to have failed is publish, and only at
# its "Require all four verified digests" step, which a short digest count
# fails whenever a leg failed. Anything else (a push or dispatch, a second
# attempt, a failed smoke test, a failed keepalive or notify) is left for a
# person.
#
# A rerun of the failed jobs reruns their dependents too (publish, notify),
# and publish reads the digests the green legs uploaded on attempt 1. Those
# artifacts are kept for one day, so a rerun started later than that cannot
# publish.
#
# Usage: .github/retry-decision.sh <run-id> <event> <attempt> <conclusion>
#   run-id      the docker.yml run (github.event.workflow_run.id)
#   event       the event that started it (github.event.workflow_run.event)
#   attempt     its attempt number (github.event.workflow_run.run_attempt)
#   conclusion  its conclusion (github.event.workflow_run.conclusion)
# Env: GH_TOKEN with actions:write, and GH_REPO naming the repository.
#
# Prints one decision line, "rerun: ..." or "no rerun: <the broken condition>".
# Exits 0 on either decision. Exits 1 when the jobs listing or a leg's log
# cannot be read, or the rerun call fails, and 2 on a usage error.
#
set -euo pipefail

MIRROR_LINE="Command still failing after"
PUBLISH_STEP="Require all four verified digests"

usage() {
    echo "usage: $0 <run-id> <event> <attempt> <conclusion>" >&2
    exit 2
}
[ "$#" -eq 4 ] || usage
run_id="$1" event="$2" attempt="$3" conclusion="$4"
[[ $run_id =~ ^[0-9]+$ ]] || usage

decline() {
    echo "no rerun: $*"
    exit 0
}
fail() {
    echo "::error::$*" >&2
    exit 1
}

# These three come from the event payload, so they cost no gh call.
[ "$event" = schedule ] || decline "the run's event is '$event', not schedule"
[ "$attempt" = 1 ] || decline "the run's attempt is '$attempt', not 1"
[ "$conclusion" = failure ] || decline "the run's conclusion is '$conclusion', not failure"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

gh run view "$run_id" --attempt "$attempt" --json jobs > "$work/jobs.json" \
    || fail "gh run view failed for run $run_id, so no rerun decision was made"
[ -s "$work/jobs.json" ] || fail "the jobs listing for run $run_id is empty"
jq -e '.jobs | type == "array"' "$work/jobs.json" > /dev/null 2>&1 \
    || fail "the jobs listing for run $run_id could not be parsed"

# One line per job: index, conclusion, name. The name goes last because it is
# the one field that holds spaces.
jq -r '.jobs | to_entries[] | "\(.key)\t\(.value.conclusion)\t\(.value.name)"' \
    "$work/jobs.json" > "$work/jobs.tsv"

failed_steps() {
    jq -r --argjson i "$1" '.jobs[$i].steps[]? | select(.conclusion == "failure") | .name' "$work/jobs.json"
}
job_id() {
    jq -r --argjson i "$1" '.jobs[$i].databaseId' "$work/jobs.json"
}

# Read every failed build leg's log first. gh refuses to write a response that
# holds terminal escape sequences, which build logs do, unless
# --allow-escape-sequences is passed (seen on gh 2.100.0, even with the output
# redirected to a file; gh's escape-sequence change came in 2.97.0). The log
# only goes to a file here.
while IFS=$'\t' read -r i c name; do
    [[ $name == "build ("* && $c == failure ]] || continue
    id="$(job_id "$i")"
    [[ $id =~ ^[0-9]+$ ]] || fail "job '$name' has no job id in the listing"
    gh api "repos/{owner}/{repo}/actions/jobs/$id/logs" --allow-escape-sequences > "$work/log-$i" \
        || fail "could not read the log of job '$name' ($id)"
done < "$work/jobs.tsv"

failed_jobs=0
mirror_legs=()
while IFS=$'\t' read -r i c name; do
    if [[ $name == "build ("* ]]; then
        case "$c" in
            success) continue ;;
            failure) ;;
            *) decline "build leg '$name' concluded $c" ;;
        esac
        failed_jobs=$((failed_jobs + 1))
        [[ $name =~ ^build\ \(([^,]+),\ ([^\)]+)\)$ ]] \
            || decline "failed job '$name' is not named like a build leg"
        want="Build ${BASH_REMATCH[1]} (${BASH_REMATCH[2]}) and push by digest"
        steps="$(failed_steps "$i")"
        [ -n "$steps" ] || decline "build leg '$name' failed with no failed step"
        while IFS= read -r s; do
            [ "$s" = "$want" ] || decline "build leg '$name' failed at step '$s'"
        done <<< "$steps"
        grep -qF "$MIRROR_LINE" "$work/log-$i" \
            || decline "build leg '$name' failed at its build step, but its log lacks '$MIRROR_LINE'"
        mirror_legs+=("$name")
    elif [ "$c" = failure ]; then
        failed_jobs=$((failed_jobs + 1))
        [ "$name" = publish ] || decline "job '$name' failed, and only build legs and publish may"
        steps="$(failed_steps "$i")"
        [ -n "$steps" ] || decline "publish failed with no failed step"
        while IFS= read -r s; do
            [ "$s" = "$PUBLISH_STEP" ] || decline "publish failed at step '$s'"
        done <<< "$steps"
    fi
done < "$work/jobs.tsv"

[ "$failed_jobs" -gt 0 ] || decline "the listing names no failed job"
[ "${#mirror_legs[@]}" -gt 0 ] || decline "no build leg failed"

echo "rerun: ${#mirror_legs[@]} build leg(s) failed on the r2u mirror: ${mirror_legs[*]}"
gh run rerun "$run_id" --failed || fail "gh run rerun $run_id --failed failed"
