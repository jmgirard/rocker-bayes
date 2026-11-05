# M013: Port the CRLF guard

- **Status:** review
- **Priority:** high
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP7
- **Resolves:** —
- **Surface tier:** internal — a check over in-repo files that runs only in this repo's CI
- **Branch/PR:** m013-port-crlf-guard

## Goal

Make CI fail a pull request that stores a Windows launcher with LF line endings.

## Scope

**In:** Port rstudio2u's guard to `.github/tests/test_launcher_line_endings.sh`. Run it from a new `launchers.yml` workflow and from `pr-ci.yml`'s `script-tests` job. Correct the `.gitattributes` comment, which cites a missing path and makes a false claim about `git archive`. Update `cairn/DESIGN.md`.

**Out:** The other launcher tests and the launcher resync → candidate "Resync the launchers from rstudio2u". The false `git archive` claim in rstudio2u's own files → the same row. `*.cmd` files: none are tracked, so the guard stays on `*.bat` as in rstudio2u.

## Acceptance criteria

- [x] AC1: `bash .github/tests/test_launcher_line_endings.sh`, run in this repo, exits 0 and prints an `ok:` line for each path that `git ls-files '*.bat'` lists.
- [x] AC2: In a throwaway git repo holding a copy of the guard at the same relative path, the guard exits 1 and prints a `FAIL:` line naming the file when a tracked `.bat` blob has all LF lines, when it has one LF-only line among CRLF lines, and when the blob is LF while the working-tree file is CRLF. It exits 1 with a `FAIL:` line when no `.bat` is tracked. It exits 0 when the blob is CRLF while the working-tree file is LF.
- [ ] AC3: `.github/workflows/launchers.yml` triggers on pull requests to `main` with `paths` naming `**.bat`, `.gitattributes`, the guard, and the workflow file. Its `line-endings` job runs the guard in a step that does not mask the guard's exit status (no `|| true`, no `continue-on-error`). The milestone's own pull request gets a passing `line-endings` check.
- [x] AC4: The `script-tests` job of `.github/workflows/pr-ci.yml` runs the guard, so that workflow still runs every suite in `.github/tests/`: the `test_*.sh` names from `ls .github/tests/` each appear in that job.
- [x] AC5: `.gitattributes` names the guard at `.github/tests/test_launcher_line_endings.sh`, `grep -n 'scripts/tests' .gitattributes` finds nothing, and its comment no longer says that `git archive` applies no line-ending conversion.
- [x] AC6: `cairn/DESIGN.md`'s Known issues entry no longer says that the CRLF guard is unverified or that the cited file does not exist, and still says that the other launcher tests were not ported. Its pre-merge checks bullet names `launchers.yml`.
- [ ] AC7: The `Shell lint` check passes on the milestone's pull request, and `.github/tests/test_launcher_line_endings.sh` is in the list that check enumerates (`git ls-files '*.sh' '*.command'`).

## Coverage

- AC1 → T1
- AC2 → T1, T2
- AC3 → T4, T6
- AC4 → T3
- AC5 → T5
- AC6 → T7
- AC7 → T1

## Tasks

- [x] T1: Copy `~/github/rstudio2u/scripts/tests/test_launcher_line_endings.sh` to `.github/tests/`. Keep its logic. In its header, remove the rstudio2u milestone reference and the false `git archive` reason, and add a usage line like the other suites have. shellcheck is not installed locally, so run the pinned version in a container against the repo checkout, or rely on CI.
- [x] T2: Run AC2's five cases in scratch repos and record the results in the work log.
- [x] T3: Add the guard to the `script-tests` run list in `.github/workflows/pr-ci.yml:58`.
- [x] T4: Add `.github/workflows/launchers.yml`, with `permissions` and `concurrency` as in `lint.yml` and the same `actions/checkout` pin. State in its header why it is separate from `pr-ci.yml`: a launcher-only change does not need an image build.
- [x] T5: Rewrite the `.gitattributes` comment at lines 3 to 7 with the new path and a reason that a run showed: under `-text`, git converts no bytes on checkout or in `git archive`, so only CRLF in the blob ships as CRLF.
- [x] T6: Control run. Push the milestone branch with `m013-*` temporarily added to `launchers.yml`'s `branches`. Cut a control branch with one LF-only line in `stop_windows.bat`, and open a pull request into the milestone branch. Record the failed `line-endings` check, close the pull request unmerged, and delete the control branch. Remove the temporary filter in its own commit before review.
- [x] T7: In `cairn/DESIGN.md`, narrow the Known issues entry at line 246 to the launcher tests still not ported, and name `launchers.yml` and the guard in the pre-merge checks bullet at line 78.

## Work log

- 2026-11-05: created by /milestone-plan.
- 2026-11-05: tier check: milestone — the row offers a comment fix (trivial) or a port that adds a test and a workflow (milestone), and a request with a milestone part is a milestone.
- 2026-11-05: idea vet: gap — the request leaves port or comment-only open, and the user chose port at the set. Gap — the comment's reason is false: in a local run (git 2.54), `git archive` wrote CRLF for an LF blob under `text eol=crlf`; reading taken: keep the blob check, which holds under `-text`, and correct the reason. No flaw.
- 2026-11-05: lessons used: 2026-09-12 (M002) a `pull_request` paths filter reads the whole diff; 2026-09-12 (M002) trigger path lists drift; 2026-09-13 (M003) temporary trigger removed before review; 2026-09-12 (M002) run containerized linters inside the checkout.
- 2026-11-05: collision check: candidate row "Port the CRLF guard or drop its cite" absorbed in full. D-003 says `pr-ci.yml` runs every suite in `.github/tests/`, which is why AC4 exists. No standing rejection applies.
- 2026-11-05: inbox sweep: 0 open issues and 0 open PRs.
- 2026-11-05: criteria audit (reduced mode, fresh Opus reader): one finding. AC3's planted-failure clause was a live demonstration past the internal-tier standard; narrowed to the workflow's trigger, an unmasked guard step, and a passing check, with the control run moved to T6. The other six passed.
- 2026-11-05: question set: open one throwaway pull request to see the check fail on GitHub — yes, closed unmerged and its branch deleted.
- 2026-11-05: plan gate chose porting the guard over fixing only the comment because rstudio2u's copy reads only its own blobs; falsified by evidence that cmd.exe runs every launcher branch correctly from an LF `.bat`.
- 2026-11-05: plan chose a new `launchers.yml` over adding `**.bat` to `pr-ci.yml`'s paths because that would build the image for a launcher-only edit; falsified by a line-ending defect that only an image build catches.
- 2026-11-05: plan chose `.github/tests/` over the cited `scripts/tests/` because `scripts/**` is in the build context and in `docker.yml`'s push paths, so a guard edit would rebuild four legs and move tags; falsified by a `docker.yml` paths change that frees `scripts/tests/`.
- 2026-11-05: new candidate "Resync the launchers from rstudio2u" holds the launcher drift found here; it is outside this request.
- 2026-11-05: T1: ported the guard to `.github/tests/`, logic unchanged. It passes on `start_windows.bat` and `stop_windows.bat`, and shellcheck 0.11.0 at `-S info` in a container is clean.
- 2026-11-05: T2: AC2's five cases in scratch repos each gave the wanted exit: all-LF blob, one LF-only line, and LF blob with CRLF working tree exit 1 and name `x.bat`; no tracked `.bat` exits 1 with the "no tracked" line; CRLF blob with LF working tree exits 0.
- 2026-11-05: T3, T4, T5, T7: added the guard to `script-tests`, added `launchers.yml`, rewrote the `.gitattributes` comment from the local `git archive` run, and narrowed the DESIGN.md Known issues entry. Their tasks ran out of plan order, before T6, so T6 tests the final workflow.
- 2026-11-05: T6: control PR #27 held one LF-only line in `stop_windows.bat`. Its only check, `line-endings` (run 42044410120), failed in 3s with "FAIL: stop_windows.bat — blob has 1 LF-only line(s) of 12" while `start_windows.bat` printed `ok:`. Closed unmerged, control branch deleted, temporary `m013-*` filter removed.
- 2026-11-05: implementation choice: the control's edit was made in a scratch clone with `sed`, so this checkout's launcher never changed.
- 2026-11-05: claim audit: not owed — internal tier.
- 2026-11-05: step-7 approval: m013-port-crlf-guard approved for merge

## Decisions

## Review

Evidence below was run at branch head 15d7ec0 on 2026-11-05, with `origin/main` not ahead of the branch.

- AC1: the guard exits 0 and prints `ok:` for `start_windows.bat` (218 lines) and `stop_windows.bat` (12 lines), the two paths `git ls-files '*.bat'` lists.
- AC2: in scratch repos with a copy of the guard, all-LF blob, one LF-only line, and LF blob under a CRLF working tree each exit 1 with `FAIL: x.bat`; no tracked `.bat` exits 1 with `FAIL: no tracked *.bat files found`; CRLF blob under an LF working tree exits 0.
- AC3 (file part): `launchers.yml` triggers on `pull_request` to `main` with the four named paths, `line-endings` runs the guard, and a search finds no `|| true` or `continue-on-error`. Control PR #27 (T6) failed this job on one LF-only line. The own-PR check is pending until the PR opens at step 8, and its box stays unticked until then.
- AC4: all 9 `test_*.sh` names from `ls .github/tests/` appear in the `script-tests` job.
- AC5: rerun after the review fix at 4632713. `.gitattributes` names `.github/tests/test_launcher_line_endings.sh`, `grep -n 'scripts/tests\|git archive'` finds nothing, and the comment says only that `-text` keeps a `.bat` file's bytes as committed.
- AC6: the Known issues entry reads "Launcher tests other than the CRLF guard were not ported from rstudio2u", and neither "unverified" claim about the guard nor the missing-file claim remains. The pre-merge checks bullet names `launchers.yml`.
- AC7 (list part): the guard is in `git ls-files '*.sh' '*.command'`, and shellcheck 0.11.0 at `-S info` in a container is clean. The `Shell lint` check is pending until the PR opens, and its box stays unticked until then.
- Gate, cairn: `cairn_validate` passes. No principle text changed, so `cairn_impact` is skipped.
- Gate, toolchain: `hadolint Dockerfile` is clean. `git diff origin/main` shows no change to `Dockerfile`, `scripts/`, or `.dockerignore`, so the image inputs match main, whose last `docker.yml` push run (3917506) succeeded. No local `docker build` ran, because `pr-ci.yml` builds and boots the image on this PR and the merge waits on it. The base tag is explicit, `.dockerignore` is present, the Dockerfile holds no secrets, and the changelog slot is none.
- spawned: diff-bug, blame-history, prior-review, ripple
- diff-bug #1: the guard passes a bare LF when the file ends in a CR with no LF after it (`a\r\nb\nc\r`, lf=2, crlf=2, exit 0) — fix now, fixed 4632713; that input now exits 1 and a clean CRLF file exits 0.
- diff-bug #2: the `.gitattributes` trigger runs a check that never reads attributes, so a PR setting `*.bat text eol=lf` or `export-ignore` exits 0 — reject, false for the line-ending case: the guard's promise is the blob, and a run with `*.bat text eol=lf` and the blob untouched still archived 2 of 2 lines as CRLF, and `export-ignore` removes the file instead of changing its endings, which is outside what the guard promises.
- diff-bug #3: no `push` trigger and no branch protection, so a direct commit of an LF `.bat` is unchecked and a red check does not block a merge — reject, planned change: the Goal names pull requests, and direct commits of runtime files are outside the repo's work tiers.
- diff-bug #4: guard and trigger are case-sensitive, so a new `EXTRA.BAT` with LF is missed — follow-up, parked row "Widen the launcher guard's triggers", no documented or common use reaches it.
- diff-bug #5: a PR retargeted to `main` with no new push runs nothing, GitHub docs say a diff over 300 files can skip a run (not tested), and a nested `.gitattributes` does not match — follow-up, same parked row.
- diff-bug #6: a bare CR mid-line and `\r\r\n` pass, and an unterminated last line prints "all 1 lines" — reject: false for the first two, since each line still ends in CRLF, which is what the guard promises; style for the message.
- diff-bug #7: DESIGN.md's "tests are ported here only when a file diverges" was not updated — fix now, fixed 4632713.
- diff-bug #8: the `script-tests` comment omits the guard — fix now, fixed 4632713.
- diff-bug #9: the DESIGN.md trigger list omits two paths, and "no image build" is false for them — fix now, fixed 4632713.
- diff-bug #10: the `.gitattributes` comment still names `git archive`, in tension with AC5's wording — fix now, fixed 4632713; the comment no longer names it.
- diff-bug #11: the commit that removed the temporary filter also edits tracking files, while T6 said "its own commit" — reject, style: tracking travels with code, and the squash erases it.
- diff-bug #12: AC3 and AC7 are unproven because no M013 PR exists, and `origin` still has the temporary filter — reject, planned change: step 8 pushes the branch and opens the PR, and those boxes stay unticked until its checks are read.
- diff-bug #13: "no dependencies" in the guard header is loose, since it needs git, wc, grep, and tr — reject, style.
- blame-history #1: the `.gitattributes` comment reads as the retired `git archive` claim — fix now, fixed 4632713 (same as diff-bug #10).
- blame-history #2: the comment drops the Download ZIP reason that commit d0b1c32 recorded for `-text` — fix now, fixed 4632713.
- blame-history #3: the DESIGN.md trigger list is incomplete — fix now, fixed 4632713 (same as diff-bug #9).
- blame-history #4: the `script-tests` comment no longer fits — fix now, fixed 4632713 (same as diff-bug #8).
- blame-history #5: the guard covers `*.bat` while `.gitattributes` also sets `*.cmd -text` — reject, planned change: Scope Out states it, and no `.cmd` is tracked.
- prior-review #1: `launchers.yml` adds a paths-filtered `pull_request` workflow with no `merge_group` trigger, the pattern of the parked row "Fix required checks behind path filters" — follow-up, that row now says "No pull-request workflow" and still waits on `main` getting a required check.
- prior-review #2: GitHub globs and git pathspecs can differ for `**.bat` and `*.bat` — reject, false: the lens expects no divergence, and control PR #27 fired on a root `.bat`.
- ripple #1: the candidate row at ROADMAP line 18 is stale — reject, planned change: step 9 graduates that row.
- ripple #2: DESIGN.md Conventions on when tests are ported — fix now, fixed 4632713 (same as diff-bug #7).
- ripple #3: GP7 says a diverging launcher gets its tests ported, while Known issues says they were not — follow-up, row "Resync the launchers from rstudio2u"; a principle change is not this milestone's.
- ripple #4: the ROADMAP row repeats rstudio2u's `git archive` claim — reject, false: the row names it as rstudio2u's and says it is false.
- ripple #5: README line 84 recommends Download ZIP with no caveat — reject, false: the README makes no line-ending claim, and the blobs hold CRLF.
- conversation: no read; no PR for this branch is open yet.
- snapshot: no changed snapshot files.
- Rerun after 4632713: AC1 passes, AC2's five cases give the same exits, shellcheck is clean, and `Goal` and criteria wording are unchanged. The fix's two scratch cases are recorded at diff-bug #1.
