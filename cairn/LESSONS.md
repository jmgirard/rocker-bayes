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

- 2026-09-12 (M001): a GitHub Actions job gated on `always()` also runs when the run is cancelled. Use `!cancelled()` where the job must not act against a cancel.
- 2026-09-12 (M001): `gh run rerun` refuses a workflow that still has a job in flight ("This workflow is already running"). A job inside the run is itself in flight, so no job can rerun its own run, whatever it depends on. A retry has to start from another workflow, such as a `workflow_run` trigger (corrected M003).
- 2026-09-12 (M001): under `set -e`, a failing command substitution in an assignment kills the script before any error message prints. Guard every `docker inspect` read with `2>/dev/null || echo <fallback>`.
- 2026-09-12 (M001): `praise` and `oolong` are the smoke test's two bspm probes. `praise` has an r2u binary, `oolong` has none and installs from source, which is what makes the `dpkg -s` assertion discriminating.
- 2026-09-12 (M001): Docker treats any non-zero healthcheck exit as unhealthy, `wget`'s exit 4 included, so an exec-form HEALTHCHECK needs no `|| exit 1`.
- 2026-09-12 (M001): this repo's publish workflow has no `pull_request` trigger and filters pushes to main. Branch evidence for it needs a `workflow_dispatch` run, and `test_mode=true` keeps that run from attaching tags. The pre-merge lanes from M002 do run on pull requests (corrected M002).
- 2026-09-12 (M002): a `pull_request` paths filter matches against the whole pull request diff, not the last commit. A branch that adds a workflow file triggers that workflow through `.github/workflows/**`, whatever else it touches. Account for it when reasoning about why a control run fired.
- 2026-09-12 (M002): Docker Desktop on this Mac shares the home directory but not `/tmp` or the session scratchpad. A container mounting those paths sees an empty directory and reports `openBinaryFile: does not exist`. Run containerized linters against files inside the repo checkout.
- 2026-09-13 (M003): GitHub refuses `gh workflow run` for a workflow file that is not yet on the default branch. To run a new workflow from a milestone branch, add a temporary `push` trigger scoped to that branch and remove it before review.
- 2026-09-13 (M004): gh 2.97.0 and later refuse to print a job log that holds terminal escape sequences, even into a file. Build logs hold them, so pass `--allow-escape-sequences` to `gh api .../actions/jobs/<id>/logs`.
- 2026-09-13 (M004): `gh run rerun <id> --failed` also reruns the jobs that depend on a failed job (publish, notify). Jobs that passed keep their attempt-1 start time, and the rerun reads attempt 1's artifacts, which `docker.yml` keeps for 1 day.
- 2026-09-13 (M004): macOS ships bash 3.2, where `"${arr[*]}"` of an empty array under `set -u` stops the script. The runner's bash 5 does not stop. A local suite run and a CI run of the same shell script can fail in different places.
- 2026-09-12 (M002): a trigger path list copied from one workflow drifts from the others. When a workflow reads a file, check that every workflow reading it also triggers on it.
