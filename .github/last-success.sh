#!/usr/bin/env bash
#
# Reduce a list of docker.yml runs to the date of the newest successful
# scheduled one that moved the tags. Called by
# .github/workflows/rebuild-gap.yml, which hands the answer to
# .github/rebuild-gap.sh as its first argument. The rule lives here so
# .github/tests/test_last_success.sh can test it offline.
#
# The script picks the run itself and trusts neither the order nor the filters
# of the list it is given. On 2026-10-06 GitHub answered the query
# `--event schedule --status success --limit 1` with a run from 2026-08-03, the
# day after a green scheduled rebuild, and the check raised a false 64-day gap.
# So a run counts only when its own `conclusion` is `success` and its own
# `event` is `schedule`. Only those runs are candidates, wherever they sit.
#
# A stale run also ends green: its publish job found a newer recipe on the
# default branch and attached no tag, so it is not a rebuild. Its "Attach the
# tags" step shows as skipped. The script therefore reads the job listing of each
# successful scheduled run, newest first, and stops at the first whose step
# succeeded. A readable listing with no such step does not count, so after a
# rename of the step in docker.yml, runs under the new name stop counting and the
# alert fires once the runs under the old name pass the threshold. A stale run
# from before the step's `if` was added shows the step as a success, because the
# step exited 0 then, and it counts.
#
# Usage: gh run list ... --json createdAt,conclusion,event,databaseId | .github/last-success.sh
# Env: GH_TOKEN (or a logged-in `gh`) with actions:read, for `gh run view`.
#
# Prints one line and exits 0:
#   YYYY-MM-DD  the createdAt of that run, in UTC.
#   none        the list holds no such run.
#   unknown     the input is not a JSON list of runs, a successful scheduled
#               run's createdAt is not an RFC 3339 UTC timestamp, or a job
#               listing the walk reached has no run id or cannot be read. A
#               `::warning::` line on stderr says which.
#
set -euo pipefail

input="$(cat)"

warn_unknown() {
    echo "::warning::$1; reporting an unreadable rebuild history" >&2
    echo unknown
    exit 0
}

if ! printf '%s' "$input" | jq -e 'type == "array"' >/dev/null 2>&1; then
    warn_unknown "the run list is not a JSON list of runs"
fi

# Every successful scheduled run, one per line: createdAt, a tab, databaseId.
candidates="$(printf '%s' "$input" | jq -r '
    .[] | objects | select(.conclusion == "success" and .event == "schedule")
    | "\(.createdAt // "" | tostring)\t\(.databaseId // "" | tostring)"')"

if [ -z "$candidates" ]; then
    echo none
    exit 0
fi

while IFS=$'\t' read -r c _; do
    # RFC 3339 in UTC, so timestamps of this one shape sort as strings and the
    # date is the part before the T.
    [[ $c =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] \
        || warn_unknown "the run list holds an unparseable createdAt ('$c')"
done <<< "$candidates"

while IFS=$'\t' read -r c id; do
    [ -n "$id" ] || warn_unknown "the run from $c has no run id"
    if ! listing="$(gh run view "$id" --json jobs </dev/null)"; then
        warn_unknown "could not read the job listing of run $id"
    fi
    # jq stops with an error on anything that is not a job listing.
    if ! attached="$(printf '%s' "$listing" | jq '
        [.jobs[] | .steps[]? | select(.name == "Attach the tags") | .conclusion]
        | any(. == "success")' 2>/dev/null)"; then
        warn_unknown "run $id has an unreadable job listing"
    fi
    if [ "$attached" = "true" ]; then
        echo "${c%%T*}"
        exit 0
    fi
done <<< "$(printf '%s\n' "$candidates" | LC_ALL=C sort -r)"

echo none
