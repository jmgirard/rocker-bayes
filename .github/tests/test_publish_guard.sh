#!/usr/bin/env bash
#
# Drive .github/publish-guard.sh through the cases it exists to catch, plus the
# cases where it must stay silent. Runs anywhere bash and jq are installed and
# needs no Docker, no registry, and no CI run.
#
# Usage: bash .github/tests/test_publish_guard.sh
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUARD="${HERE}/../publish-guard.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0
fail=0

# Run the guard and check both its exit status and, when it fails, that the
# message names the reason. Asserting the message is what keeps a guard that
# dies for an unrelated reason from counting as a caught case.
check() {
  local name="$1" want_status="$2" want_text="$3"; shift 3
  local out status
  out="$(bash "$GUARD" "$@" 2>&1)"
  status=$?

  if [ "$status" -ne "$want_status" ]; then
    printf 'FAIL %s: exit %d, expected %d\n' "$name" "$status" "$want_status"
    printf '     output: %s\n' "$out"
    fail=$((fail + 1))
    return
  fi
  if [ -n "$want_text" ] && ! printf '%s' "$out" | grep -qF -- "$want_text"; then
    printf 'FAIL %s: output did not mention %s\n' "$name" "$want_text"
    printf '     output: %s\n' "$out"
    fail=$((fail + 1))
    return
  fi
  printf 'ok   %s\n' "$name"
  pass=$((pass + 1))
}

manifest() {
  local name="$1"; shift
  local f="${WORK}/${name}.json"
  cat > "$f"
  printf '%s' "$f"
}

# --- manifest: the index the publish job is about to tag ---------------------

# Silent case: a real two-architecture index. If this one is not accepted the
# guard blocks every publish and the failing cases below prove nothing.
good="$(manifest good <<'JSON'
{"manifests": [
  {"platform": {"os": "linux", "architecture": "amd64"}},
  {"platform": {"os": "linux", "architecture": "arm64"}}
]}
JSON
)"
check "manifest: amd64 + arm64 is accepted" 0 "both architectures" manifest "$good" noble

# Silent case: buildx adds attestation entries whose platform reads "unknown".
# They are not architectures and must not make a valid index look wrong.
good_att="$(manifest good_att <<'JSON'
{"manifests": [
  {"platform": {"os": "linux", "architecture": "amd64"}},
  {"platform": {"os": "linux", "architecture": "arm64"}},
  {"platform": {"os": "unknown", "architecture": "unknown"}}
]}
JSON
)"
check "manifest: attestation entry is ignored" 0 "both architectures" manifest "$good_att" noble

# The four bad indexes the milestone names.
one_arch="$(manifest one_arch <<'JSON'
{"manifests": [
  {"platform": {"os": "linux", "architecture": "amd64"}}
]}
JSON
)"
check "manifest: amd64 alone is refused" 1 "'amd64', expected 'amd64 arm64'" manifest "$one_arch" noble

dup_arch="$(manifest dup_arch <<'JSON'
{"manifests": [
  {"platform": {"os": "linux", "architecture": "amd64"}},
  {"platform": {"os": "linux", "architecture": "amd64"}}
]}
JSON
)"
check "manifest: two amd64 entries are refused" 1 "'amd64', expected 'amd64 arm64'" manifest "$dup_arch" noble

att_only="$(manifest att_only <<'JSON'
{"manifests": [
  {"platform": {"os": "linux", "architecture": "amd64"}},
  {"platform": {"os": "unknown", "architecture": "unknown"}}
]}
JSON
)"
check "manifest: amd64 plus an attestation entry is refused" 1 "'amd64', expected 'amd64 arm64'" manifest "$att_only" noble

empty="$(manifest empty <<'JSON'
{"manifests": []}
JSON
)"
check "manifest: an empty manifests array is refused" 1 "'', expected 'amd64 arm64'" manifest "$empty" noble

# Two ways the input itself can be wrong.
check "manifest: a missing file is refused" 1 "was not written" manifest "${WORK}/absent.json" noble

notjson="$(manifest notjson <<'JSON'
this is not json
JSON
)"
check "manifest: unreadable JSON is refused" 1 "not readable JSON" manifest "$notjson" noble

# --- digests: the per-leg uploads the publish job requires -------------------

mkdir -p "${WORK}/d4" && touch "${WORK}/d4/"a "${WORK}/d4/"b "${WORK}/d4/"c "${WORK}/d4/"d
mkdir -p "${WORK}/d3" && touch "${WORK}/d3/"a "${WORK}/d3/"b "${WORK}/d3/"c
mkdir -p "${WORK}/d5" && touch "${WORK}/d5/"a "${WORK}/d5/"b "${WORK}/d5/"c "${WORK}/d5/"d "${WORK}/d5/"e
mkdir -p "${WORK}/d0"

# Silent case: all four legs uploaded.
check "digests: four of four is accepted" 0 "found all 4" digests "${WORK}/d4" 4
check "digests: three of four is refused" 1 "found 3" digests "${WORK}/d3" 4
check "digests: five of four is refused" 1 "found 5" digests "${WORK}/d5" 4
check "digests: an empty directory is refused" 1 "found 0" digests "${WORK}/d0" 4
check "digests: a missing directory is refused" 1 "found 0" digests "${WORK}/absent" 4

# --- summary -----------------------------------------------------------------
printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
