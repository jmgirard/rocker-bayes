<!-- Instantiated by /cairn-init as cairn/LESSONS.md (file header; the
     scaffold ships it empty of lessons). One line per lesson; corrected in
     place when proven false; retirement per tracking-rules "Retiring a
     lesson". -->
# Lessons

Durable repo lessons — build quirks, testing tricks, gotchas worth
remembering next time — captured at milestone end and surfaced at plan time.
Not status, not decisions: a lesson is a reusable "how this repo actually
behaves" note. Cross-cutting *choices* still go to `DECISIONS.md`.

One line per lesson: `- YYYY-MM-DD (M<NNN>): <lesson>`. Two caps: 50 lines
and 20,000 bytes; over either, retire or prune before adding. Corrected in
place when proven false (never append a correction).

- 2026-09-12 (M001, used M012): a GitHub Actions job gated on `always()` also runs when the run is cancelled. Use `!cancelled()` where the job must not act against a cancel.
- 2026-09-12 (M001, used M011): `praise` and `oolong` are the smoke test's two bspm probes. `praise` has an r2u binary, `oolong` has none and installs from source, which is what makes the `dpkg -s` assertion discriminating.
- 2026-09-12 (M001, used M012): this repo's publish workflow has no `pull_request` trigger and filters pushes to main. Branch evidence for it needs a `workflow_dispatch` run, and `test_mode=true` keeps that run from attaching tags. The pre-merge lanes from M002 do run on pull requests (corrected M002).
- 2026-09-12 (M002, used M014): a `pull_request` paths filter matches against the whole pull request diff, not the last commit. A branch that adds a workflow file triggers that workflow through `.github/workflows/**`, whatever else it touches. Account for it when reasoning about why a control run fired.
- 2026-09-12 (M002, used M013): Docker Desktop on this Mac shares the home directory but not `/tmp` or the session scratchpad. A container mounting those paths sees an empty directory and reports `openBinaryFile: does not exist`. Run containerized linters against files inside the repo checkout.
- 2026-09-13 (M003, used M013): GitHub refuses `gh workflow run` for a workflow file that is not yet on the default branch. To run a new workflow from a milestone branch, add a temporary `push` trigger scoped to that branch and remove it before review.
- 2026-09-13 (M004, used M013): gh 2.97.0 and later refuse to print a job log that holds terminal escape sequences, even into a file. Build logs hold them, so pass `--allow-escape-sequences` to `gh api .../actions/jobs/<id>/logs`.
- 2026-09-13 (M004, used M012): macOS ships bash 3.2, where `"${arr[*]}"` of an empty array under `set -u` stops the script. The runner's bash 5 does not stop. A local suite run and a CI run of the same shell script can fail in different places.
- 2026-10-20 (M006, used M011): `dpkg -s` exits 0 for a removed package left in `config-files` state, and `docker exec` exits 1 for a container that is gone, the status `dpkg -s` gives an unknown package. Read the Status line and dpkg's "is not installed" message, never the exit status alone.
- 2026-10-20 (M006): `brms` (an r2u binary in the image) and `cmdstanr` (in `/usr/local/lib/R/site-library`, no dpkg entry) are the smoke test's already-present controls for phase 2's dpkg and R library absence checks.
- 2026-10-20 (M007): the smoke test passes R code to `Rscript -e` inside shell single quotes, so an apostrophe in an R comment there ends the quote and breaks the script. Shellcheck flags it as SC1011. Write those R comments without apostrophes.
- 2026-10-20 (M007): with cmdstanr 0.9.0, a broken compiler can fail `$compile()` before the build, in `get_cmdstan_flags()`, because Stan Math reads `$(CXX) -dumpversion` while make parses its files. That error keeps make's stderr in `e[["stderr"]]` and prints nothing. A failure in the build itself streams its stderr through `message()`.
- 2026-10-20 (M008): to test a build script offline, give it a source guard, then source it in a subshell whose `PATH` holds only stub executables. Any command left unstubbed fails as "not found" instead of touching the host, and a stub run as a child process sees only exported variables.
- 2026-10-21 (M009): macOS bash 3.2 misparses a heredoc that holds an unbalanced quote when the heredoc sits inside `$(...)`, and the whole test file then fails with "unexpected EOF". Write such a fixture with `printf` piped into the helper.
- 2026-10-21 (M010): Docker copies the image's files into a named volume only while the volume is empty. To seed a volume as an older image left it, mount it at a path the image does not have (such as `/seed`), write there, then mount it as the home.
- 2026-10-21 (M010): `docker exec` hands the image's ENV straight to the process, but an RStudio session reads it only from `Renviron.site`, which the base's `01_set_env` writes at start. To test what a session sees, remove the variable with `env -u`. Without that, a check passes even with `01_set_env` deleted.
- 2026-10-21 (M010): `printenv VAR` exits 1 for an unset variable, the status a failed `docker exec` also gives; read it as `sh -c "printenv VAR || true"`. macOS has no `timeout` command (exit 127), so a local wait wrapped in it ends at once.
- 2026-11-05 (M011): `docker exec` passes no host variable without `-e NAME`. An R loop over a list read from the environment then runs zero times, prints nothing, and exits 0. Fail the check when the list is empty.
- 2026-11-05 (M011): to run the launchers without touching a real home volume, set `COMPOSE_PROJECT_NAME`, `RS_PORT`, and `RS_LAUNCHER_NONINTERACTIVE=1`. The launchers call bare `docker compose`, so they stay on that project and its own volume.
- 2026-09-12 (M002, used M013): a trigger path list copied from one workflow drifts from the others. When a workflow reads a file, check that every workflow reading it also triggers on it.
- 2026-11-05 (M012): a job that hits `timeout-minutes` shows as `cancelled` in `needs`, but the `cancelled()` function stays false, so a `!cancelled()` job after it still runs. Cancelling the whole run does stop that job. To test this cheaply, set `timeout-minutes: 1` on a throwaway branch.
- 2026-11-05 (M012): a push run has no inputs, so `test_mode` is empty. A temporary push trigger on a drill branch can attach real tags once `publish` admits the branch and the verdict reads fresh. Block the attach step in that commit, and remove the trigger in the commit that restores the step.
- 2026-11-05 (M013): `git archive` applies `.gitattributes` line-ending rules: an LF blob under `text eol=crlf` comes out CRLF (git 2.54). Under `-text` it ships the stored bytes, so an LF blob ships as LF.
- 2026-11-05 (M013): to test a new `pull_request` paths filter before merge, add the milestone branch's pattern to the workflow's `branches` and open a control PR into that branch, so the diff holds only the trigger file. A PR into `main` also carries the workflow file and proves nothing about the other paths. Remove the pattern before review.
- 2026-11-05 (M014): `docker-compose.yml` has both `image:` and `build:`. After a failed pull of a tag, `docker compose up -d` builds from the Dockerfile and gives the result that tag's name, and `up --build` does so for any tag. With a digest on `image:`, `docker compose build` fails with "build tag cannot contain a digest". `docker compose --dry-run` shows the steps with no build or pull.
