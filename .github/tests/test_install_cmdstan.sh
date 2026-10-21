#!/usr/bin/env bash
#
# Offline suite for the CmdStan step of scripts/install_bayes.sh.
#
# The step must hand the CmdStan version to R through the environment, so no
# value can change the R code that calls install_cmdstan(). Each case sources
# the script in a subshell whose PATH holds only stubs for R, mkdir, and
# chown, then calls the step. Any other command fails as "not found", so
# nothing here touches the host. The R stub is a child process, so it sees
# CMDSTAN_VERSION only when the variable is exported. The first-argument cases
# unset it first, so they show that the script exports it. The stub records
# its argument list and that variable to files, which this suite compares
# byte for byte.
#
# Usage: bash .github/tests/test_install_cmdstan.sh
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../../scripts/install_bayes.sh"
fails=0

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
STUBS="$WORK/stubs"
mkdir -p "$STUBS"

# R stub: call n writes argv.n (NUL-separated arguments) and env.n (the
# variable's bytes), or env.n.unset when the variable is not in its
# environment. Only bash builtins, because PATH holds nothing else.
cat >"$STUBS/R" <<'EOF'
#!/bin/bash
n=0
[ -f "$STUB_LOG/n" ] && n=$(<"$STUB_LOG/n")
n=$((n + 1))
printf '%s' "$n" >"$STUB_LOG/n"
printf '%s\0' "$@" >"$STUB_LOG/argv.$n"
if [ "${CMDSTAN_VERSION+set}" = set ]; then
  printf '%s' "$CMDSTAN_VERSION" >"$STUB_LOG/env.$n"
else
  : >"$STUB_LOG/env.$n.unset"
fi
EOF
# mkdir and chown stubs log their arguments and do nothing else.
cat >"$STUBS/mkdir" <<'EOF'
#!/bin/bash
printf '%s\n' "${0##*/} $*" >>"$STUB_LOG/calls"
EOF
cp "$STUBS/mkdir" "$STUBS/chown"
chmod +x "$STUBS"/*

# run_case <dir> <env|arg|both|empty|unset> [value] [function]
#   env    CMDSTAN_VERSION exported with the value, as the Dockerfile ENV does
#   arg    the value passed as the first argument, variable unset
#   both   the value passed as the first argument, variable exported as 9.9.9
#   empty  CMDSTAN_VERSION exported as "", no argument
#   unset  CMDSTAN_VERSION unset, no argument
# The function called is install_cmdstan_step unless a fourth argument names
# another, such as main.
run_case() {
  local dir="$1" mode="$2" v="${3-}" fn="${4:-install_cmdstan_step}"
  mkdir -p "$dir"
  (
    export STUB_LOG="$dir"
    case "$mode" in
      env)   export CMDSTAN_VERSION="$v" ;;
      both)  export CMDSTAN_VERSION="9.9.9" ;;
      empty) export CMDSTAN_VERSION="" ;;
      *)     unset CMDSTAN_VERSION ;;
    esac
    # No positional parameters may leak into the sourced script.
    set --
    PATH="$STUBS"
    # shellcheck source=scripts/install_bayes.sh
    source "$SCRIPT"
    case "$mode" in
      arg|both) "$fn" "$v" ;;
      *)        "$fn" ;;
    esac
  ) >"$dir/stdout" 2>"$dir/stderr"
  echo "$?" >"$dir/status"
}

fail() { echo "FAIL: $*"; fails=$((fails + 1)); }

# The baseline. Its R program is the text every other value must reproduce.
BASE="$WORK/base"
run_case "$BASE" env "2.40.0"
if [ "$(cat "$BASE/status")" != 0 ] || [ ! -f "$BASE/n" ]; then
  fail "baseline 2.40.0 did not run R (status $(cat "$BASE/status")): $(head -c 300 "$BASE/stderr")"
  echo "$fails failure(s)"
  exit 1
fi
base_n="$(cat "$BASE/n")"
if ! grep -qF 'Sys.getenv("CMDSTAN_VERSION")' "$BASE/argv.1"; then
  fail "the R program does not read Sys.getenv(\"CMDSTAN_VERSION\")"
fi
printf '%s\n' "mkdir -p /home/rstudio/.cmdstan" "chown -R rstudio /home/rstudio/.cmdstan" >"$BASE/calls.expected"
if ! cmp -s "$BASE/calls.expected" "$BASE/calls"; then
  fail "the step's mkdir and chown calls are not the two expected: $(cat "$BASE/calls" 2>/dev/null)"
fi

# Each value after the first carries at least one character that would break
# or rewrite R source if it were spliced in: a double quote, a single quote, a backslash, a backtick,
# a command substitution, a space, a glob, a newline, a trailing space.
# shellcheck disable=SC1003,SC2016  # the unexpanded metacharacters are the test
VALUES=(
  '2.40.0'
  '2.40.0", dir = "/tmp'
  "2.40.0'"
  '2.40.0\'
  '2.40.0`id`'
  '2.40.0$(id)'
  '2.40 .0'
  '2.40.*'
  $'2.40.0\n'
  '2.40.0 '
)

check_case() {
  local dir="$1" label="$2" v="$3" i
  if [ "$(cat "$dir/status")" != 0 ]; then
    fail "$label: step exited $(cat "$dir/status"): $(head -c 300 "$dir/stderr")"
    return
  fi
  if [ ! -f "$dir/n" ] || [ "$(cat "$dir/n")" != "$base_n" ]; then
    fail "$label: R called $(cat "$dir/n" 2>/dev/null || echo 0) time(s), baseline $base_n"
    return
  fi
  printf '%s' "$v" >"$dir/expected"
  for ((i = 1; i <= base_n; i++)); do
    if ! cmp -s "$BASE/argv.$i" "$dir/argv.$i"; then
      fail "$label: R call $i got arguments that differ from the 2.40.0 call"
    fi
    if [ -f "$dir/env.$i.unset" ]; then
      fail "$label: CMDSTAN_VERSION is not in R's environment on call $i"
    elif ! cmp -s "$dir/expected" "$dir/env.$i"; then
      fail "$label: R's CMDSTAN_VERSION on call $i is not the value given byte for byte"
    fi
  done
}

for idx in "${!VALUES[@]}"; do
  v="${VALUES[$idx]}"
  run_case "$WORK/env.$idx" env "$v"
  check_case "$WORK/env.$idx" "value $idx from the environment" "$v"
  run_case "$WORK/arg.$idx" arg "$v"
  check_case "$WORK/arg.$idx" "value $idx as the first argument" "$v"
done

# The first argument wins over the environment.
run_case "$WORK/both" both "2.40.0"
check_case "$WORK/both" "argument over an environment of 9.9.9" "2.40.0"

# An empty or missing version stops with the script's own message before R
# starts, both in the step and at the top of main, which would otherwise run
# R for the package install first. bash's own "unbound variable" error does
# not count.
for fn in install_cmdstan_step main; do
  for mode in empty unset; do
    dir="$WORK/$fn.$mode"
    run_case "$dir" "$mode" "" "$fn"
    if [ "$(cat "$dir/status")" = 0 ]; then
      fail "$fn $mode: exited 0"
    fi
    if [ -f "$dir/n" ]; then
      fail "$fn $mode: R was called"
    fi
    if ! grep -qF 'CMDSTAN_VERSION is empty' "$dir/stderr"; then
      fail "$fn $mode: stderr lacks 'CMDSTAN_VERSION is empty': $(head -c 300 "$dir/stderr")"
    fi
  done
done

if [ "$fails" -eq 0 ]; then
  echo "PASS: ${#VALUES[@]} values from the environment and as an argument reach R unchanged, the argument wins, and empty and unset stop the step and main before R"
  exit 0
fi
echo "$fails failure(s)"
exit 1
