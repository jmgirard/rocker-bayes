#!/usr/bin/env bash
#
# Decide whether too long has passed since a scheduled docker.yml rebuild last
# succeeded, and raise the `ci-failure` issue if it has. Ported from
# jmgirard/rstudio2u. Called by .github/workflows/rebuild-gap.yml, which reduces
# the newest successful scheduled docker.yml run to a date and hands this script
# that date, today, and a threshold. The rule lives here so
# .github/tests/test_rebuild_gap.sh can test it offline.
#
# docker.yml's `notify` job reports on a run that happened. A run that never
# happens reports nothing. A disabled schedule, a deleted workflow, and weeks of
# red builds all show the same symptom, which this script measures: no rebuild
# has succeeded lately.
#
# Usage: .github/rebuild-gap.sh <last-success-date> <current-date> <threshold-days>
#   last-success-date  YYYY-MM-DD; when a scheduled rebuild last succeeded. Two
#                      words stand in for a date that does not exist: `none`
#                      (the history holds no successful scheduled run) and
#                      `unknown` (the history could not be read). Each raises
#                      the alert with its own wording, so the issue never
#                      claims a measured gap it does not have.
#   current-date       YYYY-MM-DD; today, in UTC.
#   threshold-days     a non-negative integer of at most seven digits once
#                      leading zeros are dropped; the largest gap that is not
#                      yet an alert.
# Env: RUN_URL   link to this check's run, put in the issue body. When it is
#                missing, a stand-in line is used and the alert still goes out.
#      GH_TOKEN  (or a logged-in `gh`) with issues:write, for the issue.
#
# There is a gap when current-date minus last-success-date is MORE than
# threshold-days. A gap exactly that wide is still within the bound. A gap
# raises the issue through .github/ci-failure-issue.sh, the same issue a failed
# run opens, because the next fully green scheduled run closes both. No gap
# means no call to anything, a line saying so, and exit 0. Every argument is
# validated before the dates are compared. A rejection names the argument it
# rejected (a fourth argument is refused by count), exits 2, and raises
# nothing. The validation lives in .github/date-lib.sh, shared with
# .github/keepalive.sh.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=.github/date-lib.sh
. "$HERE/date-lib.sh"

[ $# -le 3 ] || die "expected 3 arguments, got $#"

last_success="${1-}"
current_date="${2-}"
threshold="${3-}"

run_url="${RUN_URL:-see the Actions tab of this repository for the run that raised this}"

# Arguments 2 and 3 are validated the same way whichever argument 1 is, so a
# bad threshold is refused on a run with no history too.
current_days="$(parse_date "the current date (argument 2)" "$current_date")"
threshold_days="$(parse_threshold "the threshold in days (argument 3)" "$threshold")"

case "$last_success" in
    none)
        subject="No successful scheduled docker.yml rebuild on record"
        echo "no successful scheduled rebuild is on record; raising the alert"
        ;;
    unknown)
        subject="Could not read the scheduled docker.yml rebuild history"
        echo "the scheduled rebuild history could not be read; raising the alert"
        ;;
    *)
        last_days="$(parse_date "the last success date (argument 1)" "$last_success")"
        gap=$(( current_days - last_days ))

        # A success dated after today is a clock or an input that cannot be
        # trusted. Refuse rather than compute a negative gap that would always
        # read as within the bound.
        if (( gap < 0 )); then
            die "the last success date (argument 1) is later than the current date: '$last_success' > '$current_date'"
        fi

        if (( gap <= 10#$threshold_days )); then
            echo "the scheduled rebuild last succeeded $gap day(s) ago, within the ${threshold}-day bound; no alert"
            exit 0
        fi

        subject="No successful scheduled docker.yml rebuild in $gap days (since $last_success)"
        echo "the scheduled rebuild last succeeded $gap day(s) ago, past the ${threshold}-day bound; raising the alert"
        ;;
esac

# "failure" is this check's verdict on the schedule, not a job result: one value
# that is not "success" opens or updates the issue. The empty third argument is
# the jobs document there is none of, and the subject is what the issue says.
bash "$HERE/ci-failure-issue.sh" failure "$run_url" "" "$subject"
