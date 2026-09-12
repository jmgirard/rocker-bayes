#!/usr/bin/env bash
#
# The two checks that stand between a finished build and a moving Docker tag.
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
# Both print a GitHub Actions ::error:: line and exit 1 on failure.
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

case "${1:-}" in
  digests)  shift; cmd_digests "$@" ;;
  manifest) shift; cmd_manifest "$@" ;;
  *)        die "usage: publish-guard.sh {digests <dir> <count>|manifest <json> <label>}" ;;
esac
