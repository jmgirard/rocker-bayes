#!/usr/bin/env bash
#
# Reduce a list of docker.yml runs to the date of the newest successful
# scheduled one. Called by .github/workflows/rebuild-gap.yml, which hands the
# answer to .github/rebuild-gap.sh as its first argument. The rule lives here so
# .github/tests/test_last_success.sh can test it offline.
#
# The script picks the run itself and trusts neither the order nor the filters
# of the list it is given. On 2026-10-06 GitHub answered the query
# `--event schedule --status success --limit 1` with a run from 2026-08-03, the
# day after a green scheduled rebuild, and the check raised a false 64-day gap.
# So a run counts only when its own `conclusion` is `success` and its own
# `event` is `schedule`, and the newest of those wins, wherever it sits.
#
# Usage: gh run list ... --json createdAt,conclusion,event | .github/last-success.sh
#
# Prints one line and exits 0:
#   YYYY-MM-DD  the newest createdAt among the successful scheduled runs, in
#               UTC.
#   none        the list holds no successful scheduled run.
#   unknown     the input is not a JSON list of runs, or a successful scheduled
#               run's createdAt is not an RFC 3339 UTC timestamp. A
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

# The createdAt of every successful scheduled run, one per line.
created="$(printf '%s' "$input" | jq -r '
    .[] | objects | select(.conclusion == "success" and .event == "schedule") | (.createdAt // "" | tostring)')"

if [ -z "$created" ]; then
    echo none
    exit 0
fi

newest=""
while IFS= read -r c; do
    # RFC 3339 in UTC, so timestamps of this one shape sort as strings and the
    # date is the part before the T.
    [[ $c =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] \
        || warn_unknown "the run list holds an unparseable createdAt ('$c')"
    if [[ $c > $newest ]]; then newest="$c"; fi
done <<< "$created"

echo "${newest%%T*}"
