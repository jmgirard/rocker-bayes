<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M005: Superseded CI runs stop acting

- **Status:** review   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** high   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** M004   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate; RR<NN> whose Binding criteria bind this milestone's ACs (binding-criteria check), or — -->
- **Principles touched:** GP2, GP8   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Resolves:** —   <!-- owner: plan · create/amend-via-gate; comma-separated GitHub issues the scope absorbs, each `#N closes` (the PR closes it at merge) or `#N partial` (the remainder gets a candidate row), or — ; skill conduct only — no validate check parses it -->
- **Surface tier:** user-facing — the publish job decides which image `latest`, `noble`, and `resolute` point at   <!-- owner: plan · create/amend-via-gate; user-facing | internal — <one-clause reason>; skill conduct only — no validate check parses it -->
- **Branch/PR:** m005-superseded-runs   <!-- owner: implement (branch) / review (PR URL) · create -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

A CI run that a newer commit made obsolete stops acting: an older `docker.yml`
run attaches no tag over a newer recipe, and an older pull request run is
cancelled.

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:** A `fresh` check in `.github/publish-guard.sh`. It compares the run's
commit with the default branch's tip over the paths in `docker.yml`'s push
`paths` filter. Each commit that changes one of those paths normally starts
its own push build, so a refusal normally means a newer build exists. The
check runs in the publish job before tags are attached. A refused run attaches
no tag, warns, and ends green. `.dockerignore` joins the push `paths` filter,
because it changes the build context. `pr-ci.yml` and `lint.yml` get
per-pull-request concurrency groups that cancel older runs. The
`script-tests` job in `pr-ci.yml` runs `test_publish_guard.sh`. DESIGN.md
records the rule and its exception to GP2.

**Out:**
- A concurrency group on `docker.yml`. The plan gate rejected it (work log).
  No row.
- A decline in `retry-decision.sh` when the default branch moved. The publish
  check also covers reruns started by hand (work log). No row.
- Cancelling superseded push builds in `docker.yml` to save minutes. It is not
  needed for correctness (work log). No row.
- `.github/tests/**` missing from the `docker.yml` push paths. This half stays
  in the `test_publish_guard.sh` candidate row.
- A failed push build alerts no one, so tags can stay on an older image
  unnoticed. New candidate row.

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets. -->

- [x] AC1: `.github/publish-guard.sh paths <workflow-file>` prints one line
      per entry of that file's push `paths` filter, and `fresh` compares
      exactly the paths that `paths` prints. `test_publish_guard.sh` states
      the expected list for the repository's `docker.yml` separately and
      asserts that `paths` prints exactly that list.
- [x] AC2: `.github/tests/test_publish_guard.sh` runs `fresh` against a
      bare repository reached over `file://`. The run's commit is cloned and
      the tip is fetched at depth 1. The test asserts three distinct exit
      statuses: pass, refuse, and fetch failure. It passes when the tip is the
      run's commit, when the tip moved only by an empty commit, when it moved
      only by the near-miss files `Dockerfile.dev`, `sub/Dockerfile`,
      `scripts-old/x`, and `.github/smoke-test.sh.bak`, when a filtered file
      changed and changed back, and when the run's commit is ahead of the tip
      with no filtered change. It refuses a modified file, an added file in a
      nested directory under a `**` entry, a deleted file, a rename within,
      into, and out of the filter, a mode-only change, and a run commit that
      is not an ancestor of the tip. An unreachable remote gets the fetch
      failure status.
- [x] AC3: In `docker.yml`, the publish job runs `fresh` after both manifest
      lists pass and before "Attach the tags". The code sets this behavior:
      on a refusal the job attaches no tag for either variant, prints a
      `::warning::` naming the tip commit, and succeeds. On a fetch failure it
      attaches no tag and fails. The push `paths` filter lists
      `.dockerignore`. A `test_mode` dispatch of the milestone branch, which
      changes `docker.yml`, prints the refusal warning naming the tip commit
      in its publish log.
- [x] AC4: `pr-ci.yml` and `lint.yml` each declare a workflow-level
      concurrency group keyed on the workflow name and the pull request
      number, with `cancel-in-progress: true`. A drill pull request is opened
      first. Then one script pushes two commits seconds apart. For each
      workflow, the first push's run concludes `cancelled`, or it concluded
      before the second push's run was created, per `gh run view`
      timestamps. Each second-push run concludes `success`.
- [x] AC5: The `script-tests` job in `pr-ci.yml` runs
      `.github/tests/test_publish_guard.sh` beside its four suites. The job
      in the second push's run on the drill pull request concludes `success`.
- [x] AC6: All five suites in `.github/tests/` pass locally, and shellcheck
      0.11.0 at `-S info` reports nothing on `.github/publish-guard.sh` and
      `.github/tests/test_publish_guard.sh`.
- [x] AC7: `cairn/DESIGN.md` states the freshness rule and names it as an
      exception to the GP2 statement that every build publishes immutable
      tags. It lists the pull request concurrency groups and names five
      suites in `script-tests`.

## Coverage
<!-- owner: plan · create/amend-via-gate -->

- AC1 → T1, T2
- AC2 → T1, T2
- AC3 → T3, T5, T7
- AC4 → T4, T5
- AC5 → T4, T5
- AC6 → T1, T2, T3
- AC7 → T6

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits) -->

- [x] T1: Write the tests first in `.github/tests/test_publish_guard.sh`. Add
      a helper that builds a bare remote and reaches it over `file://` with
      depth-1 clones and fetches. Pass `-c user.name` and `-c user.email` to
      every commit, because CI runners have no git identity. Add the AC1 list
      case and the AC2 cases, each asserting its exit status. See each new
      case fail before T2.
- [x] T2: Add `.dockerignore` to the push `paths` filter in
      `.github/workflows/docker.yml`, so the AC1 list matches. Add
      `paths <workflow-file>` and
      `fresh <workflow-file> <run-sha> <remote> <branch>` to
      `.github/publish-guard.sh`. `fresh` fetches the branch tip at depth 1
      and compares with `git diff --quiet <run-sha> FETCH_HEAD --` and one
      `:(glob)` pathspec per entry. Update the header usage. Run the suite
      under bash 3.2 and bash 5 (M004 lesson).
- [x] T3: In the `docker.yml` publish job, add a step after the assembly step
      that runs `fresh` with the default branch name and records the verdict.
      The "Attach the tags" step reads the verdict before its `test_mode`
      exit. The warning says that a newer build normally, but not always,
      follows. Update the comments.
- [x] T4: Add the concurrency groups to `.github/workflows/pr-ci.yml` and
      `.github/workflows/lint.yml`. Add `test_publish_guard.sh` to
      `script-tests` and update its comment.
- [x] T5: Collect branch evidence. Dispatch `docker.yml` on the milestone
      branch with `test_mode=true`, and record the publish log's refusal
      line. Push a copy of the branch, open a drill pull request, then push
      two commits seconds apart from one script. Record each run's conclusion
      and timestamps. Close the drill pull request unmerged and delete its
      branch.
- [x] T6: Update the Conventions and Architecture sections of
      `cairn/DESIGN.md`: the freshness rule and its GP2 exception, the pull
      request concurrency groups, and the fifth suite.
- [x] T7: (review O1) Make the `fresh` step find the default branch without
      `github.event.repository`, which scheduled runs may lack, for example
      with `git ls-remote --symref origin HEAD`. Refuse an empty branch
      argument in `fresh` with an `::error::`, and add a suite case for it.
      Re-run the suites, shellcheck, actionlint, and a `test_mode` dispatch.

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates. -->

- 2026-09-13: created by /milestone-plan. Absorbs the `[high]` `docker.yml` concurrency row (M004 review O1) and the `[low]` PR-lane concurrency row (M002 review, M003 review P2). Also absorbs the "no workflow runs" half of the `test_publish_guard.sh` row (M001 F8, M003 N5).
- 2026-09-13: criteria audit (full mode, fresh [O] reader) returned 7 findings. Fixed: the compared paths became the `docker.yml` push filter, not `Dockerfile` and `scripts/`. The probes gained add, delete, rename, mode, revert, and ancestry cases asserted by exit status. A fetch failure fails the job. The branch dispatch shows a live refusal. The GP2 exception is recorded. CI evidence comes from the drill PR. Put to the gate: the `docker.yml` group, the refusal outcome, the suite wiring, and the drill.
- 2026-09-13: plan gate chose a freshness check without a `docker.yml` concurrency group over a publish-job group. A group guards only the seconds before tagging, and its pending-job cancellation can drop a newer run's publish with no alert. Falsified by a run that passed `fresh` and then tagged after a newer recipe's publish.
- 2026-09-13: plan gate chose a green refusal with a warning over a red failure. The newer commit's own push build publishes, and a red run would open the alert issue for a non-failure. Falsified by a refused run whose newer push build never started.
- 2026-09-13: plan chose the publish-time check over a decline in `retry-decision.sh`. The publish job is the one place every run passes, including a rerun started by hand. Falsified by a stale publish that did not pass through the publish job.
- 2026-09-13: plan chose not to cancel superseded push builds in `docker.yml`. The freshness check already stops them from tagging, and a cancel group on push runs adds a second cancellation path. Falsified by build minutes becoming a constraint.
- 2026-09-13: criteria re-audit after the gate (full mode, second fresh [O] reader) returned 7 findings, all fixed in place. AC4 accepts a first-push run that finished before the second push. AC2 adds depth-1 `file://` fetches, near-miss names, and renames into and out of the filter. AC1 names a `paths` subcommand. AC3 verifies the green and red publish outcomes by reading the code. `.dockerignore` moved to T2. AC5 names the second push's run. Scope says "normally".
- 2026-09-13: implement started on branch `m005-superseded-runs`; no question gate, since the plan left nothing open.
- 2026-09-13: T1 done. `test_publish_guard.sh` gained the `paths` case, a no-filter case, and 15 `fresh` cases over depth-1 `file://` clones. All 16 new cases fail on the missing subcommand before T2; the 14 old cases pass.
- 2026-09-13: T2 done. `publish-guard.sh` gained `paths` and `fresh` (exit 0 fresh, 3 stale, 2 fetch failure, 1 other error), and `.dockerignore` joined the push filter. Suite 30/30 on bash 3.2 and on bash 5.2 in a container with no git identity; shellcheck 0.11.0 `-S info` clean. The test's own revert case first wrote the wrong content and was fixed. Plants in scratch copies: dropping the exit 3 turned 8 refuse cases red, a modify-only diff filter turned 5 red, and reading comments as list ends turned the `paths` case and 6 refuse cases red. Dropping the `:(top,glob)` magic turned nothing red, because git's default pathspec matches the current filter's entries the same way.
- 2026-09-13: T3 done. The publish job's new step runs `fresh` against the default branch and records the verdict. A stale verdict prints a warning naming the tip, and "Attach the tags" exits 0 before its test-mode branch; any other failure fails the step. actionlint reports nothing on the three workflows. The live dispatch is T5.
- 2026-09-13: T4 done. `pr-ci.yml` and `lint.yml` declare `group: ${{ github.workflow }}-${{ github.event.pull_request.number }}` with `cancel-in-progress: true`, and `script-tests` runs `test_publish_guard.sh` fifth. All five suites pass locally; actionlint reports nothing.
- 2026-09-13: T5 started. Dispatched `docker.yml` run 34779453138 on the branch with `test_mode=true`. Opened drill PR #13 from `m005-drill`, then one script pushed `207ce12` at 20:02:46 and `da7cbd7` at 20:02:51 UTC. The first push's lint run concluded `cancelled`; the build runs are still going.
- 2026-09-13: T6 done. DESIGN.md Architecture names the `fresh` check and five `script-tests` suites and describes the PR concurrency groups. A new Conventions bullet states the freshness rule, its GP2 exception, and why `docker.yml` has no group.
- claim audit: 41 claims read, 4 corrected — .github/publish-guard.sh, .github/tests/test_publish_guard.sh, .github/workflows/docker.yml, .github/workflows/lint.yml, .github/workflows/pr-ci.yml
- 2026-09-13: the 4 corrections were the `fresh` header and the publish step's comment, warning, and attach message, which claimed a difference always means a newer build. On a branch run the difference can be the branch's own change. The header also claimed `::error::` output for missing arguments, which bash prints as its own usage message. Suite 30/30, shellcheck and actionlint clean afterwards. The running dispatch (head `8dfdcde`) prints the pre-correction warning text.
- 2026-09-13: T5 done. Dispatch 34779453138 concluded `success`: all four legs, keepalive, and publish passed, and notify was skipped. The publish log printed `stale: the tip of main (492dbfc…) changed .github/publish-guard.sh .github/workflows/docker.yml` and a warning naming `492dbfc`. "Attach the tags" printed its no-tag line and exited before the test-mode line. Drill PR #13 runs: at the opening commit `8dfdcde`, lint was `success` (it finished before the first push) and PR CI was `cancelled`. At push 1 `207ce12`, lint and PR CI were both `cancelled`. At push 2 `da7cbd7`, lint was `success` and PR CI was `success`, with `script-tests` and the build job both `success`. PR #13 was closed unmerged and `m005-drill` was deleted.
- 2026-09-13: implement complete, status `review`. The branch changes no Dockerfile or build context, so the profile's hadolint and build gate was not rerun locally; drill run 34779532789 ran hadolint and the noble build green on `da7cbd7`. The only commit after that is the claim-correction commit, which changes comments and messages alone.
- 2026-09-13: review started. All seven criteria have fresh evidence and the consistency gate passed. The three-lens review is running.
- 2026-09-13: three-lens review returned 8 [O] findings and no [S] conflicts. O1 (empty default branch on scheduled runs) is unconfirmed and put to the gate.
- 2026-09-13: review returned to in-progress (defect return 1). The user judged review O1 a load-bearing defect: if scheduled runs carry no `github.event.repository`, `fresh` exits 1 on every weekly publish. Logged as T7.
- 2026-09-13: T7 code in. The `fresh` step reads the default branch from `git ls-remote --symref origin HEAD`, and `fresh` prints `::error::` and exits 1 on an empty branch name. The new suite case failed first on bash's usage message. Suite 31/31 on bash 3.2 and on bash 5.2 in a container with no git identity. Shellcheck 0.11.0 `-S info` and actionlint 1.7.12 report nothing. The dispatch is next.
- claim audit: 75 claims read, 1 corrected — .github/workflows/docker.yml
- 2026-09-13: the correction was the new `fresh` step comment. It said a failed lookup leaves the name empty. The step runs under bash `-e` with `pipefail`, so a failed `ls-remote` ends the step with git's error, and only a missing symref line reaches `fresh` with an empty name. The reader re-read the new wording and found it accurate.
- 2026-09-13: T7 done. Dispatch 34781490836 (`test_mode`, head `17c784b`) concluded `success`: four legs, keepalive, and publish passed, and notify was skipped. The lookup resolved `main`: the publish log printed `stale: the tip of main (492dbfc…)` and a warning naming it, and "Attach the tags" printed its no-tag line. The only later change is the corrected comment.
- 2026-09-13: implement complete, status `review`.

## Decisions
<!-- owner: implement / review · append-only; milestone-local -->

## Review
<!-- owner: review · exclusive -->

Evidence gathered 2026-09-13 on `m005-superseded-runs` at `9862923`. The branch contains `origin/main` (`492dbfc`), so no merge was needed.

- AC1: `publish-guard.sh paths .github/workflows/docker.yml` prints the seven entries, `.dockerignore` second. `cmd_fresh` builds its pathspecs from `cmd_paths` output alone (read in the diff). The suite's `want_paths` literal is stated apart from `docker.yml`, and the case "paths: docker.yml's push filter is read exactly" passes. Pass.
- AC2: `test_publish_guard.sh` passed 30/30 under bash 3.2.57 (macOS). It also passed 30/30 under bash 5.2.15 in a `debian:bookworm-slim` container with git 2.39.5 and no git identity. Each case builds a bare remote over `file://`, a depth-1 run clone, and a depth-1 fetch in `fresh`. Status 0 cases: same commit, empty commit, the four near-miss names, change and revert, run commit ahead. Status 3 cases: modify, add under `scripts/a/b/`, delete, rename within, into, and out of the filter, mode-only, and a rewritten non-descendant tip. Status 2 case: unreachable remote. Pass.
- AC3: Code read at `9862923`. The `fresh` step (`docker.yml:298`) follows "Assemble and check both manifest lists", which runs the `manifest` guard for both variants, and precedes "Attach the tags". That assembly uses `imagetools create --dry-run`, so no tag exists before the attach step. Status 3 writes `verdict=stale` and a `::warning::` that carries the `stale:` line with the tip SHA. The attach step exits 0 on any verdict other than `fresh`, before the test-mode branch and both variant loops. Any other status exits 1, which fails the job and skips the attach step. The push filter lists `.dockerignore` (line 9). Dispatch run 34779453138 (`test_mode`, head `8dfdcde`, which changes `docker.yml`) concluded `success`. Its publish log, read again today, prints `stale: the tip of main (492dbfc…)` and a warning naming `492dbfc`. "Attach the tags" printed its no-tag line. After `8dfdcde`, only `33f5703` touches `.github`, and it changes comments and two message strings. Pass.
- AC4: `pr-ci.yml` and `lint.yml` each declare a workflow-level `concurrency` with `group: ${{ github.workflow }}-${{ github.event.pull_request.number }}` and `cancel-in-progress: true`. actionlint 1.7.12 reports nothing on the workflows. Drill PR #13 (branch `m005-drill`, now closed unmerged) opened at `8dfdcde` at 20:01:47 UTC. `gh run list`, read today, shows the push-1 runs at `207ce12` (created 20:02:50): Shell lint 34779526988 `cancelled`, PR CI 34779527102 `cancelled`. The push-2 runs at `da7cbd7` (created 20:02:56): Shell lint 34779532787 `success`, PR CI 34779532789 `success`. Pass.
- AC5: `pr-ci.yml` `script-tests` runs `test_publish_guard.sh` as its fifth line. In run 34779532789 (the push-2 run), the job "alert and keepalive script suites" concluded `success`, and its log shows `bash ./.github/tests/test_publish_guard.sh` and `30 passed, 0 failed`. Pass.
- AC6: All five suites in `.github/tests/` exit 0 locally: `test_ci_failure_issue.sh`, `test_keepalive.sh`, `test_publish_guard.sh`, `test_rebuild_gap.sh`, `test_retry_decision.sh`. shellcheck 0.11.0 (`koalaman/shellcheck:v0.11.0` image) at `-S info` on `.github/publish-guard.sh` and `.github/tests/test_publish_guard.sh` prints nothing and exits 0. Pass.
- AC7: `cairn/DESIGN.md` Conventions opens with "No tag moves back to an older recipe", which states the freshness rule. Line 106 calls it an exception to GP2's "every build also publishes immutable tags". Architecture "Pre-merge checks" names the concurrency groups of `pr-ci.yml` and `lint.yml` and names the five `script-tests` suites. The GP2 text itself is unchanged. Pass.

Consistency gate:

- `cairn_validate.py` exits 0 with every check PASS or OK, `coverage complete` included.
- `cairn_impact.py --changed` lists 8 GP2 references. No principle text changed, so no reconciliation is needed.
- `hadolint Dockerfile` (`hadolint/hadolint` image) reports nothing. The branch does not change `Dockerfile` or any file in the build context, because `.dockerignore` excludes `.github` and `cairn`. So no local `docker build` ran. PR CI 34779532789 built and smoke-tested noble amd64 green at `da7cbd7`, and `docker.yml` dispatch 34779453138 built all four legs green at `8dfdcde`.
- Base image: `FROM jmgirard/rstudio2u:${BASE_TAG}` uses a named variant tag, not `latest`. It moves by design (GP2), and this branch does not change it.
- No secrets in `Dockerfile` layers, and `.dockerignore` is present and excludes `.git`.
- Changelog: none as a file (D-002). The release walk writes release notes.

Independent review (user-facing tier, three lenses, 2026-09-13). Dispositions are set at the step-7 gate.

- [O] O1 (high): `docker.yml:301` reads `github.event.repository.default_branch`, which reports say is empty on `schedule` events (docker/metadata-action#184, community discussion #54817). With an empty branch, `fresh` stops at `${4:?}` with exit 1, so every scheduled publish fails and attaches no tag. Not confirmed: no scheduled run of the current `docker.yml` exists yet (latest scheduled run 34127399018 predates M001's workflow). The T5 dispatch could not show it, because dispatch events carry `repository`.
- [O] O2 (medium): a stale run ends green, so `notify` closes an open ci-failure issue and `rebuild-gap` counts a rebuild, even when the newer push build failed and the tags never moved.
- [O] O3 (low): the `paths` parser keeps trailing whitespace, a CRLF carriage return, and a leading `!`, which print as pathspecs that match nothing. The exact-list test case catches this for `docker.yml` itself.
- [O] O4 (low): GitHub globs and git pathspecs differ for `!x/**` and `**.sh`. The current entries do not use either form.
- [O] O5 (low): pass cases in `test_publish_guard.sh` discard push errors and never assert that the tip moved, so a failed push still reads `ok`.
- [O] O6 (low): no test covers "run's commit not in this checkout", a `paths` read failure inside `fresh`, an empty branch argument, or the workflow step's status-to-verdict mapping.
- [O] O7 (low): the attach message on a stale `test_mode` dispatch says "paths differ", and an empty `VERDICT` prints the same text though no comparison ran.
- [O] O8 (low): `${out}` goes into `::warning::` without escaping `%`, CR, or LF.
- [S] blame lens: no conflict with past intent. Noted: a fetch failure in the new step fails publish at a step `retry-decision.sh` does not retry, which matches M004's "anything else is left for a person".
- [S] prior-review lens: no reintroduced or contradicted finding. The `gh` probe returned no PR review comments.

Gate dispositions (2026-09-13):

- O1: fix now, as a return to in-progress (T7).
- O2: follow-up, absorbed into the ROADMAP row "A failed push build of `docker.yml` alerts no one".
- O3, O4, O5, O6, O7: follow-up, one new ROADMAP candidate row for publish guard hardening.
- O8: rejected, because file names that contain `%`, CR, or LF are unlikely in this repository.
- Blame lens note on retry and fetch failure: noted, no action.
- Prior-review lens: no findings.
