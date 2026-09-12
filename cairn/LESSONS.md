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
- 2026-09-12 (M001): `gh run rerun` refuses a workflow that still has a job in flight ("This workflow is already running"). A retry job must depend on every job that can still be running, not just the one that failed.
- 2026-09-12 (M001): under `set -e`, a failing command substitution in an assignment kills the script before any error message prints. Guard every `docker inspect` read with `2>/dev/null || echo <fallback>`.
- 2026-09-12 (M001): `praise` and `oolong` are the smoke test's two bspm probes. `praise` has an r2u binary, `oolong` has none and installs from source, which is what makes the `dpkg -s` assertion discriminating.
- 2026-09-12 (M001): Docker treats any non-zero healthcheck exit as unhealthy, `wget`'s exit 4 included, so an exec-form HEALTHCHECK needs no `|| exit 1`.
- 2026-09-12 (M001): this repo's publish workflow has no `pull_request` trigger and filters pushes to main, so a pull request reports no checks. Branch evidence needs a `workflow_dispatch` run, and `test_mode=true` keeps it from attaching tags.
