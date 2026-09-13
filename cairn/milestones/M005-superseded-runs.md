<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M005: Superseded CI runs stop acting

- **Status:** in-progress   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
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

- [ ] AC1: `.github/publish-guard.sh paths <workflow-file>` prints one line
      per entry of that file's push `paths` filter, and `fresh` compares
      exactly the paths that `paths` prints. `test_publish_guard.sh` states
      the expected list for the repository's `docker.yml` separately and
      asserts that `paths` prints exactly that list.
- [ ] AC2: `.github/tests/test_publish_guard.sh` runs `fresh` against a
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
- [ ] AC3: In `docker.yml`, the publish job runs `fresh` after both manifest
      lists pass and before "Attach the tags". The code sets this behavior:
      on a refusal the job attaches no tag for either variant, prints a
      `::warning::` naming the tip commit, and succeeds. On a fetch failure it
      attaches no tag and fails. The push `paths` filter lists
      `.dockerignore`. A `test_mode` dispatch of the milestone branch, which
      changes `docker.yml`, prints the refusal warning naming the tip commit
      in its publish log.
- [ ] AC4: `pr-ci.yml` and `lint.yml` each declare a workflow-level
      concurrency group keyed on the workflow name and the pull request
      number, with `cancel-in-progress: true`. A drill pull request is opened
      first. Then one script pushes two commits seconds apart. For each
      workflow, the first push's run concludes `cancelled`, or it concluded
      before the second push's run was created, per `gh run view`
      timestamps. Each second-push run concludes `success`.
- [ ] AC5: The `script-tests` job in `pr-ci.yml` runs
      `.github/tests/test_publish_guard.sh` beside its four suites. The job
      in the second push's run on the drill pull request concludes `success`.
- [ ] AC6: All five suites in `.github/tests/` pass locally, and shellcheck
      0.11.0 at `-S info` reports nothing on `.github/publish-guard.sh` and
      `.github/tests/test_publish_guard.sh`.
- [ ] AC7: `cairn/DESIGN.md` states the freshness rule and names it as an
      exception to the GP2 statement that every build publishes immutable
      tags. It lists the pull request concurrency groups and names five
      suites in `script-tests`.

## Coverage
<!-- owner: plan · create/amend-via-gate -->

- AC1 → T1, T2
- AC2 → T1, T2
- AC3 → T3, T5
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
- [ ] T3: In the `docker.yml` publish job, add a step after the assembly step
      that runs `fresh` with the default branch name and records the verdict.
      The "Attach the tags" step reads the verdict before its `test_mode`
      exit. The warning says that a newer build normally, but not always,
      follows. Update the comments.
- [ ] T4: Add the concurrency groups to `.github/workflows/pr-ci.yml` and
      `.github/workflows/lint.yml`. Add `test_publish_guard.sh` to
      `script-tests` and update its comment.
- [ ] T5: Collect branch evidence. Dispatch `docker.yml` on the milestone
      branch with `test_mode=true`, and record the publish log's refusal
      line. Push a copy of the branch, open a drill pull request, then push
      two commits seconds apart from one script. Record each run's conclusion
      and timestamps. Close the drill pull request unmerged and delete its
      branch.
- [ ] T6: Update the Conventions and Architecture sections of
      `cairn/DESIGN.md`: the freshness rule and its GP2 exception, the pull
      request concurrency groups, and the fifth suite.

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

## Decisions
<!-- owner: implement / review · append-only; milestone-local -->

## Review
<!-- owner: review · exclusive -->
