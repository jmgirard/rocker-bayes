#!/usr/bin/env bash
#
# Decide, for one attempt of a docker.yml run, whether the `retry-on-failure`
# job reruns the workflow and whether the `notify` job waits for that rerun
# instead of reporting. Both jobs call this script with the same inputs, so the
# rule and the attempt cap live in one place and
# .github/tests/test_retry_decision.sh can test it offline.
#
# Usage: .github/retry-decision.sh <attempt> <cap> <job>=<result>...
#   attempt   github.run_attempt, a whole number from 1.
#   cap       the total number of attempts a run may have, a whole number from
#             1. docker.yml passes its RETRY_CAP.
#   job=result  one entry per needed job, for example `build=failure`. The
#             jobs a rerun can heal are `build` and `publish`.
#
# Output, on stdout, in the form GITHUB_OUTPUT takes:
#   retry=true   when `build` or `publish` failed and attempt is below cap.
#   wait=true    when retry is true and no other job has a result that is
#                neither success nor cancelled. The rerun then decides what the
#                issue says. Otherwise a failure in another job, such as
#                `keepalive`, is reported now, because a rerun does not heal it.
# Each line is `false` otherwise. A malformed argument exits 2 with a message
# naming it, and prints nothing on stdout.
#
set -euo pipefail

die() {
    echo "$0: $1" >&2
    exit 2
}

[ $# -ge 2 ] || die "usage: $0 <attempt> <cap> <job>=<result>..."

attempt="$1"
cap="$2"
shift 2

[[ $attempt =~ ^[1-9][0-9]{0,5}$ ]] || die "the attempt (argument 1) is not a whole number from 1: '$attempt'"
[[ $cap =~ ^[1-9][0-9]{0,5}$ ]] || die "the cap (argument 2) is not a whole number from 1: '$cap'"

retryable_failed=0
other_problem=0
for entry in "$@"; do
    [[ $entry =~ ^[a-z][a-z0-9-]*=[a-z_]+$ ]] || die "not a <job>=<result> entry: '$entry'"
    job="${entry%%=*}"
    result="${entry#*=}"
    case "$job" in
        build|publish)
            [ "$result" = failure ] && retryable_failed=1
            ;;
        *)
            case "$result" in
                success|cancelled) ;;
                *) other_problem=1 ;;
            esac
            ;;
    esac
done

retry=false
wait=false
if [ "$retryable_failed" -eq 1 ] && (( attempt < cap )); then
    retry=true
    [ "$other_problem" -eq 0 ] && wait=true
fi

echo "retry=$retry"
echo "wait=$wait"
