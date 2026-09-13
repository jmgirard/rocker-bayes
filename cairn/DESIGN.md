# Design

_Architecture as it **is**. Status lives in ROADMAP.md; tasks in milestone files; decisions in DECISIONS.md._

## Purpose & Scope

<!-- Elicited in the 2026-09-03 design interview (Phase 1). -->

- rocker-bayes is a Docker image for Bayesian data analysis in R, published to
  Docker Hub as `jmgirard/rocker-bayes`. The image is the sole deliverable.
- **Audience: the general Bayesian-R community.** Classrooms are one important
  user group, and the double-click launchers serve them, but `docker run` and
  derivative `FROM` images are first-class paths, not afterthoughts.
- **Contract boundary.** rocker-bayes inherits `jmgirard/rstudio2u` as given:
  R, RStudio Server, Pandoc, Quarto, bspm/r2u, and the runtime interface
  (port 8787, user `rstudio`, `/home/rstudio` volume, `PASSWORD` / `ROOT` /
  `DISABLE_AUTH` / `USERID`, s6 `/init`) are the base's to define, and
  base-level fixes go upstream first. This repo's own job is the Bayesian
  layer: CmdStan, the R package roster, and the launchers and compose file it
  ships. Launcher code is synced from rstudio2u; it may diverge here when the
  Bayesian layer needs it, with the divergence stated.
- **Roster bar.** A package earns a place by being mainstream in the
  Stan / Bayesian-R ecosystem and stating in one line what it adds that
  nothing already baked in does. Periodic pruning of packages that fell out of
  use is licensed work. No hard size number.
- **Build targets are commitments.** Two Ubuntu variants (`noble`, `resolute`)
  from one Dockerfile via `BASE_TAG`, each on amd64 and arm64; a broken leg is
  ship-blocking or hotfix-tier, with documented temporary asymmetry only when
  an upstream forces it.
- **Two version records.** Docker tags record *builds*: moving `latest` /
  `noble` / `resolute` plus immutable `<variant>-<date>` and
  `<variant>-cmdstan<v>` tags, published by CI on every build. Git tags and
  GitHub releases (`v1.0.0` …) record *recipe changes* under semver (D-002);
  release notes live in the GitHub release, not in a changelog file.
- Out of scope: R and RStudio versions (whatever rstudio2u ships), a
  locked-down or non-root mode, and any language package shipped to a
  registry.

## Function Families

- **Image build**: `Dockerfile` (build args `BASE_TAG`, `CMDSTAN_VERSION`) and
  `scripts/install_bayes.sh` (R package installs via bspm, CmdStan download and
  compile).
- **Local run**: `docker-compose.yml` (localhost-only port bind, named home
  volume, `RS_PORT` / `RS_PASS` from `.env`).
- **Launchers**: `start_*` / `stop_*` files plus `launcher_common.sh`; the
  Windows `.bat` files are stored with CRLF line endings (see `.gitattributes`).
- **CI / publish**: `.github/workflows/docker.yml` builds each architecture on
  a native runner and pushes it by digest. Each leg then pulls that digest
  back, asserts the architecture, and runs `.github/smoke-test.sh` against it.
  One publish job requires all four verified digests. It assembles both
  variants' manifest lists and checks each with `.github/publish-guard.sh`.
  Only then does it attach the mutable and immutable tags.
  `.github/smoke-fixtures/` holds the Stan program the smoke test compiles.
  `.github/tests/test_publish_guard.sh` drives the guard through its failing
  cases without a CI run.
- **Unattended-rebuild alerts**: `docker.yml`'s `keepalive` job
  (`.github/keepalive.sh`) and its `notify` job (`.github/ci-failure-issue.sh`).
  `.github/workflows/rebuild-gap.yml` runs `.github/rebuild-gap.sh`. Both date
  scripts source `.github/date-lib.sh`. `.github/workflows/rebuild-retry.yml`
  runs `.github/retry-decision.sh` each time a `docker.yml` run completes. Each
  script has a suite in `.github/tests/`.
- **Pre-merge checks**: `.github/workflows/pr-ci.yml` lints the Dockerfile,
  then builds and boots noble amd64 with the same `smoke-test.sh` the publish
  gate runs. It never logs in and never publishes. Its `script-tests` job runs
  four suites: `test_ci_failure_issue.sh`, `test_keepalive.sh`,
  `test_rebuild_gap.sh`, and `test_retry_decision.sh`.
  `.github/workflows/lint.yml` runs a pinned shellcheck over every tracked
  `*.sh` and `*.command` file. `.github/dependabot.yml` keeps the action pins
  current.

## Conventions

- Tags: mutable `latest`, `noble`, `resolute`; immutable `<variant>-<date>` and
  `<variant>-cmdstan<version>`. User-facing docs never mention milestone IDs.
- **CmdStan is pinned by hand** in the Dockerfile `ARG` and bumped after a
  CmdStan release is reviewed; the weekly rebuild never changes it. CI reads
  the pin for the immutable tag.
- R packages are the newest on CRAN at build time (cmdstanr from the Stan
  r-universe). **A version pin added to dodge an upstream bug is temporary**:
  recorded when added, tracked to removal, removed when upstream heals.
- **This repo's own user-facing surface is frozen** like the base interface:
  the `.env` variables `RS_PORT` / `RS_PASS`, the compose service name `bayes`,
  the launcher file names, and the immutable tag patterns change only through a
  deprecation period and a README notice.
- Launcher code (`start_*`, `stop_*`, `launcher_common.sh`) is synced from
  rstudio2u, whose test suite verifies it; tests are ported here only when a
  file diverges. `.bat` files are stored CRLF (`.gitattributes`).
- A weekly scheduled CI rebuild (no cache) picks up base-image updates; push
  builds use the GitHub Actions cache.
- **No tag moves until every leg is verified.** Each build leg smoke-tests the
  exact digest it pushed. A leg uploads its digest only after that smoke test
  passes. The publish job requires all four digests, and it checks both
  assembled manifest lists before it attaches any tag. A broken leg in either
  variant therefore holds both variants' tags back (GP4, GP8). The `test_mode`
  dispatch input runs the whole lane and attaches nothing.
- **A pull request that can change the image is built and booted before
  merge.** `pr-ci.yml` triggers on the Dockerfile, `.dockerignore`,
  `scripts/**`, the workflows, and the smoke test and its fixtures. It lints
  the Dockerfile, then builds noble amd64 and runs the publish gate's own
  smoke test against it. A pull request touching none of those paths runs no
  build, by design. The lane reads the publish lane's build cache and never
  writes it, so a pull request cannot poison what the publish lane builds
  from. Shell files are linted by a pinned shellcheck at `-S info`.
- **The weekly rebuild keeps itself scheduled.** GitHub disables a public
  repository's scheduled workflows after 60 days without repository activity.
  If the default branch's newest commit is 50 or more days old, `docker.yml`'s
  `keepalive` job pushes an empty commit to that branch. The rule is in
  `.github/keepalive.sh`. The push uses a write-enabled deploy key held in the
  `KEEPALIVE_DEPLOY_KEY` secret, so no job needs a token that can write.
- **A failed or missing rebuild opens an issue.** If a job in a scheduled run
  fails, the `notify` job in `docker.yml` opens or comments on a `ci-failure`
  issue. A fully green scheduled run closes it. Every attempt reports.
  `rebuild-gap.yml` runs each Tuesday. If the last successful
  scheduled rebuild is more than 8 days old, it raises the same issue. The suites in
  `.github/tests/` test these scripts offline, and `pr-ci.yml` runs them.
- **A weekly rebuild that failed on the r2u mirror is rerun once.**
  `rebuild-retry.yml` starts when a `docker.yml` run completes, because
  GitHub refuses a rerun requested from inside the same run. It reruns the
  run's failed jobs once, for scheduled runs only, and only for the mirror
  symptom: every failed build leg failed at its build step with
  `Command still failing after` in its log, and publish failed at most at its
  digest count. Attempt 1 still opens the issue, and a green attempt 2 closes
  it. A rerun works only while attempt 1's digest artifacts exist, which is 1
  day (`retention-days: 1`), because publish reads the green legs' digests
  from them.
- Container is intentionally root-capable (passwordless sudo); safety comes
  from the localhost-only bind, documented in README "Security".

## Design Principles

<!-- IP<n> = Inviolable (hard constraint; changing one takes a D-entry) first,
     then GP<n> = Guiding (tradeable with stated justification). Numbers are
     never reused or renumbered. Adopted in the 2026-09-03 design interview. -->

### Inviolable

- IP1: **The base contract is inherited, never overridden.** rstudio2u's
  runtime interface and shipped defaults (port 8787, user `rstudio`,
  `/home/rstudio`, `PASSWORD` / `ROOT` / `DISABLE_AUTH` / `USERID`, s6 `/init`,
  bspm) are the base's to define; base-level bugs go upstream first. The base's
  own scoping rules (what it chooses to ship) are not inherited: this repo adds
  a layer on top.
- IP2: **No default pairs disabled auth with a bind beyond `127.0.0.1`.** No
  compose file, launcher, or documented example ever publishes the port on a
  non-localhost interface while `DISABLE_AUTH` is set.
- IP3: **User work in the home volume is sacrosanct.** Stopping, restarting,
  and updating never destroy `/home/rstudio`; no launcher or documented flow
  wipes it implicitly. Only an explicit, warned command may.
- IP4: **This repo's user-facing surface is frozen.** `RS_PORT`, `RS_PASS`, the
  compose service name `bayes`, the launcher file names, and the immutable tag
  patterns change only through a deprecation period and a README notice.
  Adding is free; renaming or removing is not.

### Guiding

- GP1: **The README package list is the roster of record.** A package is baked
  in when it is mainstream in the Bayesian-R ecosystem and listed in the README
  under a category that says what it adds; a baked package with no README entry
  is drift. Pruning packages that fell out of use is licensed work.
- GP2: **Always fresh, always an escape hatch.** Moving tags track newest
  stable R packages and base image automatically; every build also publishes
  immutable date and CmdStan-version tags, and the README keeps teaching users
  to pin. CmdStan is the stated exception (GP3).
- GP3: **CmdStan moves only by a reviewed manual bump.** The Dockerfile `ARG`
  is the single pin; the weekly rebuild never changes it.
- GP4: **All four build legs are commitments.** noble and resolute, each on
  amd64 and arm64, are supported surfaces; a broken leg is ship-blocking or
  hotfix-tier, with documented temporary asymmetry only when an upstream
  forces it.
- GP5: **One Dockerfile.** Every variant builds from the single Dockerfile via
  build args, never a per-variant fork.
- GP6: **Pins are temporary.** A version pin added to dodge an upstream bug is
  recorded when added, tracked to removal, and removed when upstream heals.
- GP7: **Launchers are synced from rstudio2u.** Its test suite verifies them; a
  launcher file that diverges here states why and gets its tests ported.
- GP8: **Never knowingly ship a broken moving tag.** An unattended rebuild must
  not publish an image whose server fails to come up or whose CmdStan cannot
  compile a model. The CI smoke-test gate enforces this (corrected M001).

## Architecture

- Single-stage build: `FROM jmgirard/rstudio2u:${BASE_TAG}`, copy `scripts/`
  to `/rocker_scripts`, run `install_bayes.sh`, set a healthcheck on port 8787,
  `CMD ["/init"]` from the base.
- The build context is restricted by `.dockerignore` to `scripts/` and the
  Dockerfile.
- Home directory persists in the `rstudio_home` named volume, pre-populated
  from the image on first run.

## Known issues

- Launcher tests were not ported from rstudio2u: `.gitattributes` cites
  `scripts/tests/test_launcher_line_endings.sh`, which does not exist here.
  The launchers and the CRLF guard are unverified in this repo (interview
  2026-09-03).
- Newest-on-CRAN means a bad upstream release can break the weekly rebuild
  (rstanarm dev bug, 2025-01); a failed build leaves the old moving tag in
  place.
- Publishing is checked all-or-nothing but attached per variant. The publish
  job checks both manifest lists before it attaches any tag, then calls
  `imagetools create` once for noble and once for resolute. A registry error
  between the two calls leaves one variant tagged and the other not, with the
  run red. Two registry calls cannot be made atomic, so this is accepted rather
  than fixed (M001 review).
