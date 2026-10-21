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
  # CHECK_DIR runs the guard inside a git checkout, which `fresh` reads.
  out="$(cd "${CHECK_DIR:-.}" && bash "$GUARD" "$@" 2>&1)"
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

# A top-level array is valid JSON that jq cannot index, so it takes the
# unreadable path rather than the architecture check. Either way it is refused.
arr="$(manifest arr <<'JSON'
[{"platform": {"os": "linux", "architecture": "amd64"}}]
JSON
)"
check "manifest: a top-level JSON array is refused" 1 "not readable JSON" manifest "$arr" noble

# --- digests: the per-leg uploads the publish job requires -------------------

mkdir -p "${WORK}/d4" && touch "${WORK}/d4/"a "${WORK}/d4/"b "${WORK}/d4/"c "${WORK}/d4/"d
mkdir -p "${WORK}/d3" && touch "${WORK}/d3/"a "${WORK}/d3/"b "${WORK}/d3/"c
mkdir -p "${WORK}/d5" && touch "${WORK}/d5/"a "${WORK}/d5/"b "${WORK}/d5/"c "${WORK}/d5/"d "${WORK}/d5/"e
mkdir -p "${WORK}/d0"

# Silent case: all four legs uploaded.
check "digests: four of four is accepted" 0 "found all 4" digests "${WORK}/d4" 4
# A short count and an over-count must not share a message: only the short
# count is a leg that failed or was skipped.
check "digests: three of four names a failed leg" 1 "found 3 - a build leg failed or was skipped" digests "${WORK}/d3" 4
check "digests: five of four does not name a failed leg" 1 "found 5 - more digests than there are build legs" digests "${WORK}/d5" 4
check "digests: an empty directory is refused" 1 "found 0 - a build leg failed or was skipped" digests "${WORK}/d0" 4
check "digests: a missing directory is refused" 1 "found 0 - a build leg failed or was skipped" digests "${WORK}/absent" 4

# --- paths: the push filter `fresh` compares --------------------------------

DOCKER_YML="$(cd "${HERE}/../workflows" && pwd)/docker.yml"

# Stated here separately from docker.yml, so an edit to the filter that the
# parser misreads fails this case instead of silently narrowing `fresh`.
want_paths='Dockerfile
.dockerignore
scripts/**
.github/workflows/docker.yml
.github/smoke-test.sh
.github/smoke-fixtures/**
.github/publish-guard.sh'
got_paths="$(bash "$GUARD" paths "$DOCKER_YML" 2>&1)"
if [ "$got_paths" = "$want_paths" ]; then
  printf 'ok   %s\n' "paths: docker.yml's push filter is read exactly"
  pass=$((pass + 1))
else
  printf 'FAIL %s\n' "paths: docker.yml's push filter is read exactly"
  printf '     got:\n%s\n' "$got_paths"
  fail=$((fail + 1))
fi

printf 'on:\n  schedule:\n    - cron: "0 7 * * 1"\n' > "${WORK}/no-filter.yml"
check "paths: a workflow with no push filter is refused" 1 "no push paths filter" paths "${WORK}/no-filter.yml"

# --- fresh: has the default branch changed the recipe since this run? --------

# Every commit carries an identity and no signing, because CI runners have no
# git identity and a developer's config may require signing.
G() {
  git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false "$@"
}

# new_case <name>: a bare remote reached over file://, and a full "author"
# clone whose base commit holds every filtered path plus a README. Prints the
# case directory.
new_case() {
  local d="${WORK}/fresh-$1"
  mkdir -p "$d/author"
  git init -q --bare "$d/remote.git"
  (
    cd "$d/author" || exit 1
    git init -q
    G symbolic-ref HEAD refs/heads/main
    mkdir -p scripts/lib .github/workflows .github/smoke-fixtures
    printf 'FROM base\n' > Dockerfile
    printf '.git\n' > .dockerignore
    printf 'echo install\n' > scripts/install_bayes.sh
    printf 'echo helper\n' > scripts/lib/helper.sh
    cp "$DOCKER_YML" .github/workflows/docker.yml
    printf 'echo smoke\n' > .github/smoke-test.sh
    printf '{}\n' > .github/smoke-fixtures/data.json
    printf 'echo guard\n' > .github/publish-guard.sh
    printf 'readme\n' > README.md
    G add -A
    G commit -q -m base
    G remote add origin "file://$d/remote.git"
    G push -q origin main 2>/dev/null
  )
  printf '%s' "$d"
}

# run_clone <dir> [branch]: the run's checkout, a depth-1 clone as
# actions/checkout makes, taken before the author moves the branch on.
run_clone() {
  git clone -q --depth 1 --branch "${2:-main}" "file://$1/remote.git" "$1/run" 2>/dev/null
}

# author <dir> <command...>: run a command in the author clone.
author() {
  local d="$1"; shift
  (cd "$d/author" && "$@")
}
publish() {
  author "$1" G push -q "${2:-origin}" "${3:-main}" 2>/dev/null
}

# check_fresh <name> <status> <text> <dir>: run `fresh` in the run checkout
# against the remote's main.
check_fresh() {
  local name="$1" want="$2" text="$3" d="$4" sha
  sha="$(git -C "$d/run" rev-parse HEAD)"
  CHECK_DIR="$d/run" check "$name" "$want" "$text" fresh "$DOCKER_YML" "$sha" origin main
}
tip() {
  git -C "$1/author" rev-parse HEAD
}

# Pass: the tip is the run's commit.
d="$(new_case same)"; run_clone "$d"
check_fresh "fresh: the tip is the run's commit" 0 "fresh:" "$d"

# Pass: the tip moved only by an empty commit, as the keepalive job pushes.
d="$(new_case empty)"; run_clone "$d"
author "$d" G commit -q --allow-empty -m keepalive; publish "$d"
check_fresh "fresh: an empty commit on the tip" 0 "fresh:" "$d"

# Pass: names next to a filter entry that the filter does not match.
d="$(new_case near)"; run_clone "$d"
author "$d" mkdir -p sub scripts-old
author "$d" sh -c 'echo x > Dockerfile.dev; echo x > sub/Dockerfile; echo x > scripts-old/x; echo x > .github/smoke-test.sh.bak'
author "$d" G add -A; author "$d" G commit -q -m near; publish "$d"
check_fresh "fresh: near-miss names outside the filter" 0 "fresh:" "$d"

# Pass: a filtered file changed and then changed back.
d="$(new_case revert)"; run_clone "$d"
author "$d" sh -c 'echo changed > scripts/install_bayes.sh'
author "$d" G commit -q -am change
author "$d" sh -c 'echo "echo install" > scripts/install_bayes.sh'
author "$d" G commit -q -am revert; publish "$d"
check_fresh "fresh: a change and its revert" 0 "fresh:" "$d"

# Pass: the run's commit is ahead of the tip, with no filtered change, as a
# branch dispatch is.
d="$(new_case ahead)"
author "$d" G checkout -q -b feature
author "$d" sh -c 'echo more >> README.md'
author "$d" G commit -q -am readme; publish "$d" origin feature
run_clone "$d" feature
check_fresh "fresh: run commit ahead of the tip, no filtered change" 0 "fresh:" "$d"

# Refuse: each kind of filtered-path difference. The message must name the tip
# commit, which is what the workflow's warning reports.
d="$(new_case modify)"; run_clone "$d"
author "$d" sh -c 'echo "FROM other" > Dockerfile'
author "$d" G commit -q -am modify; publish "$d"
check_fresh "fresh: a modified Dockerfile is refused" 3 "$(tip "$d")" "$d"

d="$(new_case add)"; run_clone "$d"
author "$d" mkdir -p scripts/a/b
author "$d" sh -c 'echo new > scripts/a/b/new.sh'
author "$d" G add -A; author "$d" G commit -q -m add; publish "$d"
check_fresh "fresh: a file added deep under scripts/** is refused" 3 "$(tip "$d")" "$d"

d="$(new_case delete)"; run_clone "$d"
author "$d" G rm -q scripts/lib/helper.sh
author "$d" G commit -q -m delete; publish "$d"
check_fresh "fresh: a deleted filtered file is refused" 3 "$(tip "$d")" "$d"

d="$(new_case rename-within)"; run_clone "$d"
author "$d" G mv scripts/install_bayes.sh scripts/install.sh
author "$d" G commit -q -m rename; publish "$d"
check_fresh "fresh: a rename within the filter is refused" 3 "$(tip "$d")" "$d"

d="$(new_case rename-into)"; run_clone "$d"
author "$d" G mv README.md scripts/README.md
author "$d" G commit -q -m rename; publish "$d"
check_fresh "fresh: a rename into the filter is refused" 3 "$(tip "$d")" "$d"

d="$(new_case rename-out)"; run_clone "$d"
author "$d" mkdir -p docs
author "$d" G mv .github/smoke-test.sh docs/smoke-test.sh
author "$d" G commit -q -m rename; publish "$d"
check_fresh "fresh: a rename out of the filter is refused" 3 "$(tip "$d")" "$d"

d="$(new_case mode)"; run_clone "$d"
author "$d" G update-index --chmod=+x scripts/install_bayes.sh
author "$d" G commit -q -m mode; publish "$d"
check_fresh "fresh: a mode-only change is refused" 3 "$(tip "$d")" "$d"

# Refuse: the branch was rewritten, so the run's commit is not an ancestor of
# the tip, and the rewrite changed a filtered path.
d="$(new_case diverged)"; run_clone "$d"
author "$d" sh -c 'echo "FROM rewritten" > Dockerfile'
author "$d" G commit -q --amend -am rewritten
author "$d" G push -q -f origin main 2>/dev/null
check_fresh "fresh: a rewritten tip that is not a descendant is refused" 3 "$(tip "$d")" "$d"

# Fetch failure: its own status, distinct from a refusal, and no verdict.
d="$(new_case unreachable)"; run_clone "$d"
git -C "$d/run" remote set-url origin "file://$d/missing.git"
check_fresh "fresh: an unreachable remote is a fetch failure" 2 "could not fetch" "$d"

# Error: an empty branch name, as the workflow step would pass if its lookup of
# the default branch came back empty. It must not fetch an empty ref name.
d="$(new_case empty-branch)"; run_clone "$d"
sha="$(git -C "$d/run" rev-parse HEAD)"
CHECK_DIR="$d/run" check "fresh: an empty branch name is an error" 1 "::error::no branch name" \
  fresh "$DOCKER_YML" "$sha" origin ""

# --- os: is the leg's image the Ubuntu release its variant names? ------------

osr() {
  local f="${WORK}/os-release-$1"
  cat > "$f"
  printf '%s' "$f"
}

# Silent case: the file as Ubuntu 24.04 ships it, read from a noble build of
# this image. If this one is not accepted every leg fails and the refusals
# below prove nothing.
real_noble="$(osr real-noble <<'EOF'
PRETTY_NAME="Ubuntu 24.04.4 LTS"
NAME="Ubuntu"
VERSION_ID="24.04"
VERSION="24.04.4 LTS (Noble Numbat)"
VERSION_CODENAME=noble
ID=ubuntu
ID_LIKE=debian
HOME_URL="https://www.ubuntu.com/"
SUPPORT_URL="https://help.ubuntu.com/"
BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
UBUNTU_CODENAME=noble
LOGO=ubuntu-logo
EOF
)"
check "os: Ubuntu's own noble file is accepted as noble" 0 "codename is noble" os "$real_noble" noble

# os-release allows the value bare or in either kind of quotes.
dq="$(osr dq <<'EOF'
VERSION_CODENAME="resolute"
EOF
)"
check "os: a double-quoted value is accepted" 0 "codename is resolute" os "$dq" resolute
sq="$(osr sq <<'EOF'
VERSION_CODENAME='noble'
EOF
)"
check "os: a single-quoted value is accepted" 0 "codename is noble" os "$sq" noble

# The defect this check exists for, in both directions: the wrong base built
# under a variant's name.
check "os: a noble image under the resolute variant is refused" 1 \
  "codename is 'noble', but this leg's variant is 'resolute'" os "$real_noble" resolute
check "os: a resolute image under the noble variant is refused" 1 \
  "codename is 'resolute', but this leg's variant is 'noble'" os "$dq" noble

# The comparison is whole-value, not a prefix or substring match.
longer="$(osr longer <<'EOF'
VERSION_CODENAME=noble2
EOF
)"
check "os: a value the variant is a prefix of is refused" 1 \
  "codename is 'noble2', but this leg's variant is 'noble'" os "$longer" noble
shorter="$(osr shorter <<'EOF'
VERSION_CODENAME=nob
EOF
)"
check "os: a value that is part of the variant is refused" 1 \
  "codename is 'nob', but this leg's variant is 'noble'" os "$shorter" noble

# An unbalanced quote is not stripped, so the value keeps it and differs.
# printf, not a heredoc: bash 3.2 misparses an unbalanced quote in a heredoc
# inside $(...).
unbalanced="$(printf 'VERSION_CODENAME="noble\n' | osr unbalanced)"
check "os: an unbalanced quote is compared as it stands" 1 \
  "codename is '\"noble', but this leg's variant is 'noble'" os "$unbalanced" noble

# The first VERSION_CODENAME line decides, so a later matching line does not
# rescue a file whose first one differs.
two="$(osr two <<'EOF'
VERSION_CODENAME=jammy
VERSION_CODENAME=noble
EOF
)"
check "os: the first of two codename lines decides" 1 \
  "codename is 'jammy', but this leg's variant is 'noble'" os "$two" noble

# No VERSION_CODENAME value at all: the release is unknown, which is a refusal,
# not a pass. UBUNTU_CODENAME is not read in its place.
ubuntu_only="$(osr ubuntu-only <<'EOF'
NAME="Ubuntu"
UBUNTU_CODENAME=noble
EOF
)"
check "os: a file with only UBUNTU_CODENAME is refused" 1 "no VERSION_CODENAME value" os "$ubuntu_only" noble
empty_bare="$(osr empty-bare <<'EOF'
VERSION_CODENAME=
EOF
)"
check "os: an empty value is refused" 1 "no VERSION_CODENAME value" os "$empty_bare" noble
empty_q="$(osr empty-q <<'EOF'
VERSION_CODENAME=""
EOF
)"
check "os: an empty quoted value is refused" 1 "no VERSION_CODENAME value" os "$empty_q" noble

check "os: a missing file is refused" 1 "::error::the os-release file" os "${WORK}/absent-os-release" noble
check "os: a missing variant is a usage error" 1 "usage: publish-guard.sh os" os "$real_noble"
check "os: an empty variant is a usage error" 1 "usage: publish-guard.sh os" os "$real_noble" ""

# --- summary -----------------------------------------------------------------
printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
