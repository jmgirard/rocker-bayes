#!/usr/bin/env bash
#
# Boot a rocker-bayes image and confirm it works before CI attaches any tag.
# Three phases, each printing one PASS line:
#
#   1. server up   - RStudio Server answers on 8787 (healthcheck, or a direct
#                    port probe when the image declares none).
#   2. bspm binary - a CRAN package the image does not already carry installs,
#                    loads, and lands as an apt r-cran-* binary rather than a
#                    silent source compile.
#   3. cmdstan     - cmdstanr reports a CmdStan path and version, and a model
#                    whose posterior mean is known in closed form compiles,
#                    samples, and returns that mean.
#
# Exit 0 only when all three phases pass. Each failure prints one line starting
# with "FAIL:" that names the phase, so CI triage can read the reason off that
# line. A failure is also followed by a tail of the container log.
#
# Usage: .github/smoke-test.sh <image-ref>
#
# Env:
#   SMOKE_TIMEOUT    seconds to wait for server health          (default 300)
#   SMOKE_PORT       host port to publish container 8787 on     (default 8787)
#   SMOKE_PKG        CRAN package for the bspm binary check,    (default praise)
#                    one the image must not already carry
#   SMOKE_STAN_FILE  Stan program for phase 3                   (default the
#                    bundled .github/smoke-fixtures/bernoulli.stan)
#   SMOKE_THETA_REF  analytic posterior mean to compare against (default
#                    0.4019608, the mean for the bundled fixture data)
#
set -euo pipefail

IMAGE="${1:?usage: smoke-test.sh <image-ref>}"
TIMEOUT="${SMOKE_TIMEOUT:-300}"
PORT="${SMOKE_PORT:-8787}"
PKG="${SMOKE_PKG:-praise}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAN_FILE="${SMOKE_STAN_FILE:-${SCRIPT_DIR}/smoke-fixtures/bernoulli.stan}"
# The tolerance is fixed, not configurable: it is part of what this test
# asserts. SMOKE_THETA_REF is the knob, and the control run moves it to a value
# the sampler cannot reach to prove the assertion can go red.
THETA_REF="${SMOKE_THETA_REF:-0.4019608}"
THETA_TOL="0.05"

NAME="rocker-bayes-smoke-$$"
SMOKE_OK=0

if [ ! -f "$STAN_FILE" ]; then
  echo "FAIL: phase 3 (cmdstan) - Stan program not found: $STAN_FILE"
  exit 1
fi
STAN_DIR="$(cd "$(dirname "$STAN_FILE")" && pwd)"
STAN_BASE="$(basename "$STAN_FILE")"
DATA_BASE="${STAN_BASE%.stan}.data.json"

# shellcheck disable=SC2329  # invoked via the EXIT trap below, not by name
cleanup() {
  if [ "$SMOKE_OK" != "1" ]; then
    echo "--- container logs (tail) ---"
    docker logs --tail 50 "$NAME" 2>&1 || true
  fi
  docker rm -f "$NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# The bind stays on 127.0.0.1: no smoke run ever exposes an auth-disabled
# RStudio to another host (IP2). The fixture directory is mounted read-only,
# so phase 3 copies the program somewhere writable before compiling it.
echo "==> booting $IMAGE as $NAME (timeout ${TIMEOUT}s)"
if ! docker run -d --name "$NAME" \
  -p "127.0.0.1:${PORT}:8787" \
  -v "${STAN_DIR}:/smoke-fixtures:ro" \
  "$IMAGE" >/dev/null; then
  echo "FAIL: phase 1 (server up) - could not start a container from $IMAGE"
  exit 1
fi

# .State.Health is null when the image declares no HEALTHCHECK; probe the
# published port directly in that case.
has_healthcheck() {
  [ "$(docker inspect --format '{{if .State.Health}}yes{{end}}' "$NAME" 2>/dev/null)" = "yes" ]
}

# --- Phase 1: server up -----------------------------------------------------
echo "==> [1/3] server up"
status="n/a"
deadline=$(( $(date +%s) + TIMEOUT ))
while :; do
  running="$(docker inspect --format '{{.State.Running}}' "$NAME" 2>/dev/null || echo false)"
  if [ "$running" != "true" ]; then
    echo "FAIL: phase 1 (server up) - container exited before becoming healthy"
    exit 1
  fi

  if has_healthcheck; then
    # Guarded like the .State.Running read above. An unguarded read aborts the
    # script under set -e when the container disappears mid-poll, and the run
    # then ends with no FAIL: line at all. "unknown" falls through to the next
    # iteration, where the .State.Running check reports the exit properly.
    status="$(docker inspect --format '{{.State.Health.Status}}' "$NAME" 2>/dev/null || echo unknown)"
    case "$status" in
      healthy)
        echo "PASS: phase 1 (server up) - container reported healthy"
        break
        ;;
      unhealthy)
        echo "FAIL: phase 1 (server up) - healthcheck reported unhealthy"
        exit 1
        ;;
    esac
  elif curl -fsS -o /dev/null "http://127.0.0.1:${PORT}/"; then
    echo "PASS: phase 1 (server up) - 8787 answered (no HEALTHCHECK; probed directly)"
    break
  fi

  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "FAIL: phase 1 (server up) - not healthy within ${TIMEOUT}s (last status: ${status})"
    exit 1
  fi
  sleep 3
done

# --- Phase 2: bspm binary install -------------------------------------------
# Request a CRAN package and confirm it loads AND arrived as an apt binary.
# The package must be absent before the install, because a package the image
# already carries passes the load and the dpkg check with nothing fetched. Two
# checks look for it first: dpkg, for an apt binary, and find.package() in the
# R session that runs the install, for a copy that R can load but apt does not
# know about. With both clear, the dpkg check after the install is what proves
# the r2u binary path worked: a silent source compile also ends with a
# loadable package, but with no apt entry.
apt_pkg="r-cran-$(printf '%s' "$PKG" | tr '[:upper:]' '[:lower:]')"
echo "==> [2/3] bspm binary install ($PKG -> $apt_pkg)"

# Print the package's dpkg state, the last word of the Status line (installed,
# unpacked, config-files, ...), or nothing when dpkg has no record of it.
# Print "?" when the read itself failed. docker exec exits 1 for a container
# that is gone, the same status dpkg -s gives for an unknown package, so only
# dpkg's own "is not installed" message counts as no record. dpkg -s also
# succeeds for a removed package that left its config files behind, which is
# why callers read the state rather than the exit status.
dpkg_state() {
  local out rc=0
  out="$(docker exec "$NAME" dpkg -s "$1" 2>&1)" || rc=$?
  if [ "$rc" -eq 0 ]; then
    printf '%s\n' "$out" | sed -n 's/^Status: .* //p'
  else
    case "$out" in
      *"is not installed"*) ;;
      *) echo "?" ;;
    esac
  fi
}

pre_state="$(dpkg_state "$apt_pkg")"
case "$pre_state" in
  ""|not-installed|config-files) ;;
  "?")
    echo "FAIL: phase 2 (bspm binary) - could not read the dpkg status of $apt_pkg before the install"
    exit 1
    ;;
  *)
    echo "FAIL: phase 2 (bspm binary) - $PKG was already in the image before the install (dpkg check: $apt_pkg is $pre_state); set SMOKE_PKG to a package the image lacks"
    exit 1
    ;;
esac
# PKG reaches R through the environment, never by string interpolation into the
# -e source: a value carrying a quote would otherwise run arbitrary R here.
# Exit status 3 means find.package() found the package before the install.
# Every other non-zero status, from R or from docker exec, takes the install
# failure line.
set +e
docker exec -e SMOKE_PKG_NAME="$PKG" "$NAME" Rscript -e '
  pkg <- Sys.getenv("SMOKE_PKG_NAME")
  found <- find.package(pkg, quiet = TRUE)
  if (length(found) > 0) {
    message("found before the install: ", paste(found, collapse = ", "))
    quit(save = "no", status = 3)
  }
  install.packages(pkg)
  library(pkg, character.only = TRUE)
'
install_status=$?
set -e
case "$install_status" in
  0) ;;
  3)
    echo "FAIL: phase 2 (bspm binary) - $PKG was already in the image before the install (R library check: find.package() found it); set SMOKE_PKG to a package the image lacks"
    exit 1
    ;;
  *)
    echo "FAIL: phase 2 (bspm binary) - install or load of $PKG failed"
    exit 1
    ;;
esac
post_state="$(dpkg_state "$apt_pkg")"
case "$post_state" in
  installed) ;;
  "?")
    echo "FAIL: phase 2 (bspm binary) - could not read the dpkg status of $apt_pkg after the install"
    exit 1
    ;;
  "")
    echo "FAIL: phase 2 (bspm binary) - $PKG did not install as an apt binary ($apt_pkg absent)"
    exit 1
    ;;
  *)
    echo "FAIL: phase 2 (bspm binary) - $PKG did not install as an apt binary ($apt_pkg is $post_state)"
    exit 1
    ;;
esac
echo "PASS: phase 2 (bspm binary) - $PKG was absent from the image before the install, installed as $apt_pkg, and loads"

# --- Phase 3: CmdStan --------------------------------------------------------
# Runs as the rstudio user with an explicit HOME, because CmdStan is installed
# under /home/rstudio/.cmdstan and cmdstanr finds it by looking there. Root
# would look in /root and report no CmdStan at all.
echo "==> [3/3] cmdstan compile and sample ($STAN_BASE)"
if ! docker exec -u rstudio -e HOME=/home/rstudio "$NAME" Rscript -e '
  suppressMessages(library(cmdstanr))
  path <- tryCatch(cmdstanr::cmdstan_path(), error = function(e) "")
  if (!nzchar(path) || !dir.exists(path)) {
    stop("cmdstanr reports no usable CmdStan path", call. = FALSE)
  }
  cat("cmdstan path:", path, "\n")
  cat("cmdstan version:", cmdstanr::cmdstan_version(), "\n")
'; then
  echo "FAIL: phase 3 (cmdstan) - cmdstanr is missing, or reports no CmdStan path or version"
  exit 1
fi

# The R block below prints a `stage:` marker before it gives up, so a compile
# failure and a wrong posterior mean produce different FAIL lines rather than
# one message covering both. A check that cannot say which thing broke cannot
# be trusted to have caught the thing it names.
set +e
stan_out="$(docker exec -u rstudio -e HOME=/home/rstudio \
     -e STAN_BASE="$STAN_BASE" -e DATA_BASE="$DATA_BASE" \
     -e THETA_REF="$THETA_REF" -e THETA_TOL="$THETA_TOL" \
     "$NAME" Rscript -e '
  suppressMessages(library(cmdstanr))
  work <- file.path(tempdir(), "smoke")
  dir.create(work, showWarnings = FALSE, recursive = TRUE)
  # The fixture mount is read only and CmdStan writes the compiled binary
  # beside the program, so compile from a copy.
  stan <- file.path(work, Sys.getenv("STAN_BASE"))
  invisible(file.copy(file.path("/smoke-fixtures", Sys.getenv("STAN_BASE")), stan, overwrite = TRUE))
  # Compile before looking for the data file. Compiling needs no data, and a
  # missing data file must never stand in for a program that does not compile.
  mod <- tryCatch(
    cmdstanr::cmdstan_model(stan),
    error = function(e) {
      cat("stage:compile\n")
      stop(conditionMessage(e), call. = FALSE)
    }
  )
  data_src <- file.path("/smoke-fixtures", Sys.getenv("DATA_BASE"))
  if (!file.exists(data_src)) {
    cat("stage:data\n")
    stop("no data file beside the Stan program: ", Sys.getenv("DATA_BASE"), call. = FALSE)
  }
  fit <- tryCatch(
    mod$sample(
      data = data_src,
      seed = 20260911,
      chains = 2,
      parallel_chains = 2,
      iter_warmup = 500,
      iter_sampling = 1000,
      refresh = 0,
      show_messages = FALSE
    ),
    error = function(e) {
      cat("stage:sample\n")
      stop(conditionMessage(e), call. = FALSE)
    }
  )
  got <- fit$summary("theta")$mean
  ref <- as.numeric(Sys.getenv("THETA_REF"))
  tol <- as.numeric(Sys.getenv("THETA_TOL"))
  cat(sprintf("theta posterior mean %.4f, reference %.4f, tolerance %.2f\n", got, ref, tol))
  if (!is.finite(got) || abs(got - ref) > tol) {
    cat("stage:mean\n")
    stop(sprintf("posterior mean %.4f is not within %.2f of %.4f", got, tol, ref), call. = FALSE)
  }
' 2>&1)"
stan_status=$?
set -e
printf '%s\n' "$stan_out"
if [ "$stan_status" -ne 0 ]; then
  case "$stan_out" in
    *"stage:data"*)    echo "FAIL: phase 3 (cmdstan) - no data file beside $STAN_BASE" ;;
    *"stage:compile"*) echo "FAIL: phase 3 (cmdstan) - $STAN_BASE did not compile" ;;
    *"stage:sample"*)  echo "FAIL: phase 3 (cmdstan) - the model compiled but sampling failed" ;;
    *"stage:mean"*)    echo "FAIL: phase 3 (cmdstan) - the posterior mean is not within $THETA_TOL of $THETA_REF" ;;
    *)                 echo "FAIL: phase 3 (cmdstan) - the CmdStan run failed before it reached a stage marker" ;;
  esac
  exit 1
fi
echo "PASS: phase 3 (cmdstan) - model compiled, sampled, and matched the reference posterior mean"

echo "PASS: smoke test (server up + bspm binary + cmdstan) succeeded"
SMOKE_OK=1
exit 0
