#!/usr/bin/env bash
#
# Decide whether the checked-out branch is quiet enough to need a keepalive
# commit, and make one if it is. Ported from jmgirard/rstudio2u. Called by the
# `keepalive` job in .github/workflows/docker.yml, which checks out the default
# branch with a push credential and hands this script two dates and a
# threshold. The rule lives here so .github/tests/test_keepalive.sh can test it
# offline.
#
# GitHub disables a public repository's scheduled workflows after 60 days
# without repository activity. The empty commit this script pushes is that
# activity, so the weekly rebuild stays scheduled.
#
# Usage: .github/keepalive.sh <commit-date> <current-date> <threshold-days>
#   commit-date     YYYY-MM-DD; the date of the branch's newest commit.
#   current-date    YYYY-MM-DD; today, in UTC.
#   threshold-days  a non-negative integer of at most seven digits once leading
#                   zeros are dropped; the age at which a commit is made.
#
# The branch needs a commit when current-date minus commit-date is
# threshold-days or more. Then the script makes exactly two git calls: an empty
# commit, then a push. Otherwise it makes no git call, prints a line saying so,
# and exits 0. Every argument is validated before the dates are compared. A
# rejection names the argument it rejected (a fourth argument is refused by
# count), exits 2, and makes no git call.
# The validation lives in .github/date-lib.sh, shared with
# .github/rebuild-gap.sh.
#
set -euo pipefail

# shellcheck source=.github/date-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/date-lib.sh"

# The commit's author and committer, set with `git -c` on the commit call
# rather than by a `git config` call, so the commit path is two git calls.
COMMIT_NAME="github-actions[bot]"
COMMIT_EMAIL="41898282+github-actions[bot]@users.noreply.github.com"

[ $# -le 3 ] || die "expected 3 arguments, got $#"

commit_date="${1-}"
current_date="${2-}"
threshold="${3-}"

commit_days="$(parse_date "the commit date (argument 1)" "$commit_date")"
current_days="$(parse_date "the current date (argument 2)" "$current_date")"
threshold_days="$(parse_threshold "the threshold in days (argument 3)" "$threshold")"

age=$(( current_days - commit_days ))

# A commit dated after today is a clock or an input that cannot be trusted, not
# a fresh branch. Refuse rather than compute a negative age that would always
# read as fresh.
if (( age < 0 )); then
    die "the commit date (argument 1) is later than the current date: '$commit_date' > '$current_date'"
fi

if (( age < 10#$threshold_days )); then
    echo "the newest commit is $age day(s) old, below the ${threshold}-day threshold; no keepalive commit"
    exit 0
fi

message="keepalive: empty commit to keep scheduled workflows enabled

The newest commit on this branch was $age day(s) old, at or past the
${threshold}-day threshold. GitHub disables a public repository's scheduled
workflows after 60 days without repository activity. This commit is that
activity and changes nothing else."

echo "the newest commit is $age day(s) old, at or past the ${threshold}-day threshold; committing"
git -c "user.name=$COMMIT_NAME" -c "user.email=$COMMIT_EMAIL" \
    commit --allow-empty -m "$message"
git push
echo "pushed a keepalive commit"
