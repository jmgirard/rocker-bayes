#!/usr/bin/env bash
#
# The checks that stand between a finished build and a moving Docker tag.
# They live here, not inline in the workflow, so .github/tests/test_publish_guard.sh
# can drive them through their failing cases on a laptop instead of costing a
# four-leg CI build per case.
#
# Usage:
#   publish-guard.sh digests  <dir> <expected-count>
#       Count the digest files a build leg uploaded. Every leg uploads its
#       digest only after its own smoke test passes, so a short count means a
#       leg failed or was skipped and nothing may be tagged.
#
#   publish-guard.sh manifest <json-file> <label>
#       Read an assembled manifest list and require that it names both
#       linux/amd64 and linux/arm64. Counting digest files proves only that
#       two legs uploaded something, never that the assembled index covers two
#       architectures. Attestation entries carry the platform "unknown" and are
#       not architectures, so they are ignored.
#
#   publish-guard.sh paths <workflow-file>
#       Print the workflow's push `paths` filter, one entry per line.
#
#   publish-guard.sh fresh <workflow-file> <run-sha> <remote> <branch>
#       Run inside the run's checkout. Fetch the tip of <branch> and compare
#       it with <run-sha> over the paths `paths` prints. On a run of a
#       default-branch commit, a difference means a later commit changed the
#       recipe. Such a commit normally starts its own push build, so this run
#       must not move the tags back to its older recipe. On a branch run the
#       difference can be the branch's own change. Exits 0 ("fresh:") when
#       nothing differs, 3 ("stale:", naming the tip commit) when something
#       does, and 2 when the fetch fails.
#
# digests and manifest print a GitHub Actions ::error:: line and exit 1 on
# failure. paths and fresh do the same on a read error, and fresh does the
# same on an empty or missing branch name. Any other missing argument prints
# bash's own usage message and exits 1.
#
set -euo pipefail

die() {
  echo "::error::$*"
  exit 1
}

cmd_digests() {
  local dir="${1:?usage: publish-guard.sh digests <dir> <expected-count>}"
  local want="${2:?usage: publish-guard.sh digests <dir> <expected-count>}"

  # download-artifact creates no directory when its pattern matches nothing,
  # which is exactly the every-leg-failed case. Report it as a count of zero
  # rather than letting the find below fail.
  local got=0
  if [ -d "$dir" ]; then
    got="$(find "$dir" -type f | wc -l | tr -d ' ')"
  fi

  # Report the two directions separately. A short count is a leg that failed or
  # was skipped; an over-count is not, so one message covering both would name
  # a cause the check cannot tell apart.
  if [ "$got" -lt "$want" ]; then
    die "expected $want verified digests, found $got - a build leg failed or was skipped, so no tag was attached"
  fi
  if [ "$got" -gt "$want" ]; then
    die "expected $want verified digests, found $got - more digests than there are build legs, so no tag was attached"
  fi
  echo "found all $got verified digests"
}

cmd_manifest() {
  local file="${1:?usage: publish-guard.sh manifest <json-file> <label>}"
  local label="${2:?usage: publish-guard.sh manifest <json-file> <label>}"

  [ -f "$file" ] || die "the $label manifest list was not written to $file"

  # `.manifests[]?` yields an empty list rather than an error when the document
  # is a JSON object that is not an index, so a single-image result reaches the
  # architecture check below instead of aborting jq under set -e. Input jq
  # cannot index at all, such as a top-level array, exits non-zero and is
  # refused by the message below it. Either way nothing is tagged.
  local got
  got="$(jq -r '
    [.manifests[]?.platform | select(.os == "linux") | .architecture]
    | unique | join(" ")
  ' "$file")" || die "the $label manifest list at $file is not readable JSON"

  if [ "$got" != "amd64 arm64" ]; then
    die "the $label manifest list names linux architectures '${got}', expected 'amd64 arm64' - nothing was tagged"
  fi
  echo "the $label manifest list names both architectures: $got"
}

cmd_paths() {
  local file="${1:?usage: publish-guard.sh paths <workflow-file>}"

  [ -f "$file" ] || die "the workflow file $file does not exist"

  # Reads the list under on: > push: > paths: at the 2-, 4-, and 6-space
  # indents docker.yml uses. Comment and blank lines inside the list are
  # skipped, and the first other line ends it. A layout this does not read
  # yields no entries, which is refused below rather than comparing nothing.
  local list
  list="$(awk '
    /^on:/                   { in_on = 1; next }
    in_on && /^[^ #]/        { in_on = 0; in_push = 0; in_paths = 0 }
    in_on && /^  push:/      { in_push = 1; next }
    in_push && /^  [^ #]/    { in_push = 0 }
    in_push && /^    paths:/ { in_paths = 1; next }
    in_paths {
      if ($0 ~ /^[ ]*(#.*)?$/) next
      if ($0 ~ /^      - /) {
        v = $0
        sub(/^      - /, "", v)
        sub(/[ ]+#.*$/, "", v)
        gsub(/^["'\'']|["'\'']$/, "", v)
        print v
        next
      }
      in_paths = 0
    }
  ' "$file")"

  [ -n "$list" ] || die "no push paths filter found in $file"
  printf '%s\n' "$list"
}

cmd_fresh() {
  local usage="usage: publish-guard.sh fresh <workflow-file> <run-sha> <remote> <branch>"
  local file="${1:?$usage}" run_sha="${2:?$usage}" remote="${3:?$usage}" branch="${4-}"

  # The workflow looks the branch name up at run time, so an empty name is a
  # failed lookup, not a typo. Report it as the job's error line.
  [ -n "$branch" ] || die "no branch name was given, so there is no default-branch tip to compare with and no tag was attached"

  # The assignment would end the script under set -e with the ::error:: line
  # captured and never printed, so print it before exiting.
  local list
  list="$(cmd_paths "$file")" || { echo "$list"; exit 1; }

  # GitHub's `paths` patterns and git's glob pathspecs agree on the literal
  # paths and trailing /** entries docker.yml uses. `top` anchors each one at
  # the repository root whatever the working directory.
  local specs=() p
  while IFS= read -r p; do
    specs+=(":(top,glob)$p")
  done <<< "$list"

  git rev-parse --verify --quiet "${run_sha}^{commit}" > /dev/null \
    || die "the run's commit $run_sha is not in this checkout"

  # A depth-1 fetch is enough: the comparison reads two trees, not history.
  if ! git fetch --quiet --no-tags --depth=1 "$remote" "refs/heads/$branch"; then
    echo "::error::could not fetch $branch from $remote, so the recipe on the default branch is unknown and no tag was attached"
    exit 2
  fi
  local tip
  tip="$(git rev-parse FETCH_HEAD)"

  local status=0
  git diff --quiet "$run_sha" "$tip" -- "${specs[@]}" || status=$?
  case "$status" in
    0)
      echo "fresh: the tip of $branch ($tip) has the same recipe paths as the run's commit ($run_sha)"
      ;;
    1)
      local changed
      changed="$(git diff --name-only --no-renames "$run_sha" "$tip" -- "${specs[@]}" | tr '\n' ' ')"
      echo "stale: the tip of $branch ($tip) changed ${changed}since the run's commit ($run_sha)"
      exit 3
      ;;
    *)
      die "git diff could not compare $run_sha with $tip"
      ;;
  esac
}

case "${1:-}" in
  digests)  shift; cmd_digests "$@" ;;
  manifest) shift; cmd_manifest "$@" ;;
  paths)    shift; cmd_paths "$@" ;;
  fresh)    shift; cmd_fresh "$@" ;;
  *)        die "usage: publish-guard.sh {digests <dir> <count>|manifest <json> <label>|paths <workflow>|fresh <workflow> <sha> <remote> <branch>}" ;;
esac
