#!/usr/bin/env bash
#
# Open, update, or close the repo's `ci-failure` issue from a scheduled run's
# job results. Ported from jmgirard/rstudio2u. Two callers use it:
#
#   - the `notify` job in .github/workflows/docker.yml, on scheduled runs (and
#     on a dispatch with its `notify` input set), so a failure anywhere in the
#     run reaches the maintainer as an issue, and the next fully green run
#     closes it;
#   - .github/rebuild-gap.sh, which reports what no single run can see: that no
#     scheduled run has succeeded in too long. It uses this same issue, because
#     the next fully green scheduled run is the right close condition for both.
#
# Usage: .github/ci-failure-issue.sh <results> <run-url> [jobs-json] [subject]
#   results   the needed jobs' results, space-separated (`needs.<job>.result`
#             for each). This script aggregates them, so the suite covers the
#             rule. Every result "success" closes the issue. Any result that is
#             neither "success" nor "cancelled" (a failure, a skipped job, a
#             value GitHub has yet to invent) opens or updates the issue, even
#             beside a cancelled job, because a skipped job did not do its work.
#             A list whose only non-success results are "cancelled" is reported
#             and ignored.
#   run-url   link to the workflow run, put in the issue or comment body.
#   jobs-json path to `gh run view --json jobs` output (or "-" for stdin). The
#             failed job names are extracted from it here. A build leg is named
#             by its variant rather than its own leg name, since a variant with
#             two failed legs is one thing wrong. Every other failed job is
#             named by its own job name. Omitted, empty, or unparseable means
#             the issue falls back to generic text. A document that parses but
#             names no failed job is warned about when the result is a failure
#             and no subject is given.
#   subject   what the issue is about, as one sentence. Given, it replaces the
#             "Weekly run failed: <jobs>" wording in the title and in the lead
#             line of the body or comment. A caller reporting something other
#             than a failed job passes one, and usually passes "" as jobs-json.
#             It is trimmed to its first line and to 256 characters.
# Env: GH_TOKEN (or a logged-in `gh`) with issues:write on the repo.
#
# One issue is reused: with an open ci-failure issue, a failure comments on the
# oldest one instead of opening another.
#
set -euo pipefail

LABEL="ci-failure"

# jq's own diagnostics land here rather than in /dev/null, so an absent jq or a
# changed `gh run view --json jobs` schema is reported instead of silently
# degrading the alert to its generic text.
JQ_ERR="$(mktemp)"
trap 'rm -f "$JQ_ERR"' EXIT

usage() {
    echo "usage: $0 <results> <run-url> [jobs-json] [subject]" >&2
    exit 2
}

# Collapse the needed jobs' results to one of failure / success / cancelled.
# Success must be unanimous. Anything that is neither success nor cancelled
# counts as a failure, and a failure outranks a cancellation. An empty list is a
# failure too, because nothing reported success.
aggregate_result() {
    local all_success=1 any_failure=0 r
    [ $# -gt 0 ] || { all_success=0; any_failure=1; }
    for r in "$@"; do
        case "$r" in
            success)   ;;
            cancelled) all_success=0 ;;
            *)         all_success=0; any_failure=1 ;;
        esac
    done
    if [ "$all_success" -eq 1 ]; then
        echo success
    elif [ "$any_failure" -eq 1 ]; then
        echo failure
    else
        echo cancelled
    fi
}

[ $# -ge 2 ] || usage
# Deliberately unquoted: the first argument is a space-separated list.
# shellcheck disable=SC2086
result="$(aggregate_result $1)"
run_url="$2"
jobs_json="${3:-}"
subject="${4:-}"
subject="${subject%%$'\n'*}"
subject="${subject:0:256}"

# Recover the failed job names from the run's job list. The build legs in
# docker.yml are named "build (<variant>, <arch>)", so for those the variant is
# the first field inside the parentheses, and the dedup names a variant once
# however many of its legs failed. A job name GitHub generates from a matrix
# `include` with several keys carries the extra keys after the first comma,
# which the same parse discards. Every other failed job (`publish`,
# `keepalive`, whatever a later lane adds) is named by itself.
extract_failed_names() {
    jq -r '
        .jobs[]
        | select(.conclusion == "failure")
        | .name
        | if test("^build \\(") then
              sub("^build \\("; "") | sub("[,)].*$"; "")
          else
              .
          end
        | select(length > 0)
    ' 2>"$JQ_ERR" | awk '!seen[$0]++' || true
}

jobs_doc=""
if [ -n "$jobs_json" ]; then
    if [ "$jobs_json" = "-" ]; then
        jobs_doc="$(cat)"
    else
        jobs_doc="$(cat "$jobs_json" 2>/dev/null || true)"
    fi
fi

failed_names=()
if [ -n "$jobs_doc" ]; then
    while IFS= read -r v; do
        [ -n "$v" ] && failed_names+=("$v")
    done < <(printf '%s' "$jobs_doc" | extract_failed_names)
fi

# Emitted outside the extraction pipeline, so it reaches stdout as a workflow
# annotation instead of being read back as a job name.
if [ -s "$JQ_ERR" ]; then
    echo "::warning::could not parse the job listing ($(head -1 "$JQ_ERR")); the issue will not name the failed jobs"
fi

if [ ${#failed_names[@]} -gt 0 ]; then
    failed_text="${failed_names[*]}"
else
    failed_text="(see the run summary for the failed job)"
fi

if [ -n "$subject" ]; then
    title="$subject"
    lead_open="$subject"
    lead_again="$subject"
    reason="$subject"
else
    title="Weekly run failed: $failed_text"
    lead_open="The scheduled run failed in: $failed_text"
    lead_again="The scheduled run failed again in: $failed_text"
    reason="$failed_text"
fi

# Fill the `open` array with the numbers of the open ci-failure issues, oldest
# first (gh lists newest first). A read loop, not mapfile, so the suite runs
# under macOS bash 3.2.
list_open() {
    open=()
    while IFS= read -r n; do
        [ -n "$n" ] && open+=("$n")
    done < <(gh issue list --label "$LABEL" --state open --limit 100 \
        --json number --jq 'sort_by(.number) | .[].number')
}

case "$result" in
    failure)
        # A failed run whose own job listing names no failed job is a
        # contradiction: the extraction, the job names, or the aggregation is
        # wrong. Say so rather than quietly shipping the generic text.
        if [ ${#failed_names[@]} -eq 0 ] && [ -z "$subject" ] && [ -n "$jobs_doc" ] && [ ! -s "$JQ_ERR" ]; then
            echo "::warning::the run is reported failed but its job listing names no failed job; the issue falls back to generic text"
        fi
        gh label create "$LABEL" --force \
            --description "Opened when a scheduled run fails or no scheduled rebuild has succeeded lately" \
            --color B60205 >/dev/null
        list_open
        if [ ${#open[@]} -eq 0 ]; then
            gh issue create --label "$LABEL" \
                --title "$title" \
                --body "$(printf '%s\n\nRun: %s\n\nThis issue is closed automatically by the next fully green scheduled run.' "$lead_open" "$run_url")"
            echo "opened a $LABEL issue for: $reason"
        else
            gh issue comment "${open[0]}" \
                --body "$(printf '%s\n\nRun: %s' "$lead_again" "$run_url")"
            echo "commented on open $LABEL issue #${open[0]}"
        fi
        ;;
    success)
        list_open
        if [ ${#open[@]} -eq 0 ]; then
            echo "the scheduled run was fully green; no open $LABEL issue"
            exit 0
        fi
        for n in "${open[@]}"; do
            gh issue comment "$n" \
                --body "$(printf 'The scheduled run was fully green; closing.\n\nRun: %s' "$run_url")"
            gh issue close "$n"
            echo "closed $LABEL issue #$n"
        done
        ;;
    *)
        echo "the run was $result; neither opening nor closing a $LABEL issue"
        ;;
esac
