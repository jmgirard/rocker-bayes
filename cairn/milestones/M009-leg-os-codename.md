<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M009: Assert each leg's OS matches its variant

- **Status:** review   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** high   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate; RR<NN> whose Binding criteria bind this milestone's ACs (binding-criteria check), or — -->
- **Principles touched:** GP4, GP8   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Resolves:** —   <!-- owner: plan · create/amend-via-gate; comma-separated GitHub issues the scope absorbs, each `#N closes` (the PR closes it at merge) or `#N partial` (the remainder gets a candidate row), or — ; skill conduct only — no validate check parses it -->
- **Surface tier:** user-facing — the check decides which bytes ship under the `noble` and `resolute` tags users pull   <!-- owner: plan · create/amend-via-gate; user-facing | internal — <one-clause reason>; skill conduct only — no validate check parses it -->
- **Branch/PR:** m009-leg-os-codename   <!-- owner: implement (branch) / review (PR URL) · create; a companion checkout the milestone also works in is one further entry per checkout, `companion: <abs-path> <branch>` (implement), its PR URL appended by review — /milestone-review merges companions first, in listed order -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

A publish build leg whose image runs a different Ubuntu release than its variant names fails before it uploads its digest.

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:** a new `os` subcommand in `.github/publish-guard.sh` that compares an
os-release file's `VERSION_CODENAME` with a variant name, with offline cases in
`.github/tests/test_publish_guard.sh`. A new build-job step in
`.github/workflows/docker.yml`, between the architecture assertion and the
smoke test, that reads `/etc/os-release` from the pulled-back digest and runs
the check against `matrix.variant`. The build-job comment and
`cairn/DESIGN.md` (CI / publish family, the "No tag moves until every leg is
verified" convention) describe the check. Two `test_mode` dispatches as
evidence.

**Out:** the same check in `pr-ci.yml` → not planned, at the user's choice at
the plan gate: that image is never pushed. A codename map for a future variant
whose name is not an Ubuntu codename → not planned; adding such a variant must
change this check. Pruning the untagged images the two dispatches push → the
existing `[low] Prune untagged manifests from dispatches` candidate row.
Checking the CmdStan version against its tag → the existing "Check CmdStan
matches the version tag" candidate row.

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets. -->

- [x] AC1: `.github/publish-guard.sh os <os-release-file> <variant>` reads the
      first line of the file that starts with `VERSION_CODENAME=`, strips one
      pair of surrounding double or single quotes from its value, and exits 0,
      printing the codename, when the result equals `<variant>`. It exits 1
      with an `::error::` line in each of these cases: the value differs from
      `<variant>` (the line names both), the file has no such line or the
      value is empty, and the file does not exist. Any other value shape is
      compared as it stands and counts as a mismatch. A missing or empty
      argument exits 1 with bash's usage message, as the script's other
      subcommands do. Evidence: `bash .github/tests/test_publish_guard.sh`
      passes.
- [x] AC2: In `.github/workflows/docker.yml`, a separate build-job step with
      no `if:` and no `continue-on-error`, placed between the `pulled` step
      and the smoke test, reads `/etc/os-release` from
      `${{ steps.pulled.outputs.ref }}` and passes it to `publish-guard.sh os`
      with `${{ matrix.variant }}` as the variant; a non-zero guard exit fails
      the step. Evidence: the branch diff of `docker.yml`.
- [x] AC3: A `test_mode=true` dispatch of `docker.yml` on the milestone branch
      ends green, and each of its four build legs passes the `os` check with
      a codename equal to that leg's variant. Evidence: the run URL and each
      leg's accept line.
- [x] AC4: A `test_mode=true` dispatch of `docker.yml` from a throwaway branch
      whose only change from the milestone branch swaps `base_tag` on all four
      matrix rows (noble rows get `resolute`, resolute rows get `noble`) fails
      all four legs at the `os` check with the mismatch line, and its publish
      job fails at the digest count with `found 0`. The milestone branch's
      final `docker.yml` sets `base_tag` equal to `variant` on all four matrix
      rows. Evidence: the run URL, the four mismatch lines, and the publish
      job's digest-count error.
- [x] AC5: shellcheck 0.11.0 run as `shellcheck -x -S info` reports nothing on
      `.github/publish-guard.sh` and `.github/tests/test_publish_guard.sh`.

## Coverage
<!-- owner: plan · create/amend-via-gate -->

- AC1 → T1, T2
- AC2 → T3
- AC3 → T4
- AC4 → T5
- AC5 → T2

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits) -->

- [x] T1: Tests first. Add `os` cases to `.github/tests/test_publish_guard.sh`,
      each asserting exit status and message: bare `noble` match; double-quoted
      `resolute` match; single-quoted match; a noble file checked as resolute;
      values holding the variant as a prefix or part (`noble2`, `nob`); two
      `VERSION_CODENAME=` lines where only the second matches (refused); only a
      `UBUNTU_CODENAME=` line (refused); an empty value, bare and `""`; a
      missing file. See the new cases fail before T2.
- [x] T2: Add `cmd_os` to `.github/publish-guard.sh`, with its usage block in
      the header and its case in the dispatcher (publish-guard.sh:177-183).
      Run the suite green, then shellcheck 0.11.0 `-x -S info` on both files,
      run in its container against the files in the repo checkout.
- [x] T3: Add the step to `docker.yml` after the `pulled` step
      (docker.yml:125-147), reading the file with
      `docker run --rm --entrypoint cat "$ref" /etc/os-release` and guarding
      the read as the M001 `set -e` lesson says. Update the build-job comment
      (docker.yml:37-43) and the two `cairn/DESIGN.md` passages named in
      Scope.
- [x] T4: Push the milestone branch and run
      `gh workflow run docker.yml --ref <branch> -f test_mode=true`, leaving
      `notify` false. Record the run URL and each leg's accept line.
- [x] T5: Cut a throwaway branch from the milestone branch, swap `base_tag` on
      all four rows, push it, and dispatch it the same way. Record the run URL,
      the four mismatch lines, and the digest-count error. Delete the branch
      locally and on the remote. This run writes the noble and resolute gha
      cache scopes with layers from the other release, which costs the next
      push build time and changes no published bytes.

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates. -->

- 2026-10-20: created by /milestone-plan.
- 2026-10-20: tier check: milestone — it adds a step to the publish workflow's build legs, which is running CI code, and restores no documented behavior.
- 2026-10-20: absorbed the candidate row "Assert each leg's OS matches its variant" (M001 review F14).
- 2026-10-20: inbox sweep: 0 open issues and 0 open PRs on jmgirard/rocker-bayes; Resolves stays —.
- 2026-10-20: collision check: no planned or in-progress milestone; the rows "Check CmdStan matches the version tag" and "Name digest files by variant and arch" are separate work and stay rows; D-001 to D-003 do not conflict (test edits stay outside the docker.yml paths filter, per D-003).
- 2026-10-20: lessons applied: branch evidence for docker.yml needs a workflow_dispatch with test_mode (M001); containerized shellcheck must read files inside the checkout (M002); guard the `docker run` read under `set -e` (M001).
- 2026-10-20: criteria audit (full mode, fresh Opus reader) returned 8 findings, all fixed: AC1's case list read as complete (now "each of these cases", single quotes, other shapes, and missing arguments stated); AC1's suite evidence (case list moved to T1); AC2 allowed a non-failing or conditional step (now a separate step with no `if:` or `continue-on-error`); AC3 bound the log (now the leg passing the check); AC4 probed one direction (now all four rows swapped, `found 0`); AC4 left the noble legs unstated (moot after the swap); the throwaway run's cache writes (accepted, noted in T5); notify (left false, T4). No principle or D-entry conflict.
- 2026-10-20: question set: proof runs — two test_mode dispatches of docker.yml, one on the milestone branch and one on a throwaway branch with base_tag swapped on all four rows; each pushes four untagged images and writes the gha cache scopes.
- 2026-10-20: question set: the same check in pr-ci.yml — not wanted; publish workflow only.
- 2026-10-20: plan gate chose `VERSION_CODENAME` from the pulled image's `/etc/os-release` over the base's `org.opencontainers.image.version` label because the label holds a version number (24.04, 26.04) that needs a codename map and is metadata the base author sets; falsified by an rstudio2u image whose os-release codename differs from the Ubuntu release its apt sources name.
- 2026-10-20: plan gate chose comparing with `matrix.variant` over `matrix.base_tag` because the variant names the digest artifact and the tags while base_tag is the build input under test; falsified by a variant whose name is not an Ubuntu codename.
- 2026-10-20: plan gate chose a `publish-guard.sh` subcommand over an inline YAML check like the architecture assertion because the offline suite can drive the refusal cases without a build; falsified by a CI failure of the new step that the offline suite cannot reproduce.
- 2026-10-20: started /milestone-implement on branch m009-leg-os-codename, cut from main at db5712f.
- 2026-10-20: T1: 15 `os` cases added to test_publish_guard.sh (also an unbalanced-quote case and an empty-variant case); all 15 fail before T2 with the dispatcher's usage error, 31 existing cases pass. The unbalanced-quote fixture uses printf because bash 3.2 misparses it in a heredoc inside `$(...)`.
- 2026-10-20: T2: `cmd_os` added to publish-guard.sh with its header usage block and dispatcher case; the suite passes 46/46 on macOS bash 3.2, and shellcheck 0.11.0 `-x -S info` (container, repo checkout) reports nothing on both files. Messages: accept "the image's Ubuntu codename is <v>, as its variant names"; mismatch "the image's Ubuntu codename is '<got>', but this leg's variant is '<want>'".
- 2026-10-20: T3: step "Assert the image's Ubuntu release is <variant>" added after `pulled` in docker.yml, reading `steps.pulled.outputs.ref` and failing with its own `::error::` line if the `docker run` read fails; build-job comment and the two DESIGN.md passages updated. actionlint 1.7.7 (container, with its shellcheck pass) reports nothing on docker.yml; `publish-guard.sh paths` still reads the push filter. Decided: a separate step rather than more lines in `pulled`, so the step name says which check failed.
- 2026-10-20: T4: test_mode dispatch https://github.com/jmgirard/rocker-bayes/actions/runs/39540604852 on f1638b8 ended success; each of the four legs printed "the image's Ubuntu codename is <variant>, as its variant names"; publish found all 4 digests and attached nothing (fresh verdict stale on a branch run, as expected).
- 2026-10-20: T5: throwaway branch m009-planted-os (one commit swapping base_tag on all four rows) dispatched as https://github.com/jmgirard/rocker-bayes/actions/runs/39540616541, ended failure; all four legs failed at the new step with the mismatch line (noble legs: 'resolute' vs 'noble'; resolute legs: 'noble' vs 'resolute'), smoke, export and upload skipped; publish failed with "expected 4 verified digests, found 0". Branch deleted locally and on origin; the milestone branch's four rows read base_tag = variant.
- 2026-10-20: claim audit: 42 claims read, 2 corrected — .github/tests/test_publish_guard.sh (real_noble fixture restored to the image's full 13-line file, so its comment holds), .github/publish-guard.sh (missing-file message now says "does not exist or is not a regular file"); the same reader re-read both as true. These edits postdate the T4/T5 runs on f1638b8 and change neither the accept nor the mismatch message; suite 46/46 and shellcheck clean after them.

## Decisions
<!-- owner: implement / review · append-only; milestone-local. -->

## Review
<!-- owner: review · exclusive. -->

Review pass 1, 2026-10-20, on aa55732 (main db5712f unmoved since the cut; no PR yet; Copilot round off).

- AC1: `bash .github/tests/test_publish_guard.sh` → 46 passed, 0 failed, including the 15 `os` cases (bare, double- and single-quoted accepts; both mismatch directions; `noble2`, `nob`; unbalanced quote; first of two lines; UBUNTU_CODENAME only; empty bare and `""`; missing file; missing and empty variant). Direct runs: a noble file as `noble` exits 0 printing "the image's Ubuntu codename is noble, as its variant names"; as `resolute` exits 1 with "::error::the image's Ubuntu codename is 'noble', but this leg's variant is 'resolute'"; with no variant exits 1 with bash's "usage: publish-guard.sh os <os-release-file> <variant>".
- AC2: `git diff main...HEAD -- .github/workflows/docker.yml` adds one step, "Assert the image's Ubuntu release is ${{ matrix.variant }}", seventh of the build job's ten steps, after "Pull back the pushed image and assert its architecture" (`id: pulled`) and before "Smoke-test …". It carries no `if:` and no `continue-on-error`, reads `ref="${{ steps.pulled.outputs.ref }}"`, and ends with `bash ./.github/publish-guard.sh os /tmp/os-release "${{ matrix.variant }}"` under `set -euo pipefail`, so the guard's exit 1 is the step's exit status; a failed `docker run` read exits 1 with its own `::error::` line.
- AC3: https://github.com/jmgirard/rocker-bayes/actions/runs/39540604852 (workflow_dispatch, test_mode=true, branch m009-leg-os-codename at f1638b8) concluded success. The new step concluded success on all four build legs, and their logs read "the image's Ubuntu codename is noble, as its variant names" (noble amd64, noble arm64) and "… is resolute, as its variant names" (resolute amd64, resolute arm64). The commits after f1638b8 change the guard only in its missing-file message and add four lines to a test fixture (`git diff f1638b8 HEAD -- .github/`), so the accept path this run executed is the one on the branch head.
- AC4: https://github.com/jmgirard/rocker-bayes/actions/runs/39540616541 (workflow_dispatch, test_mode=true, branch m009-planted-os at df8b607, whose parent is f1638b8 and whose diff from it is 4 changed lines in docker.yml swapping base_tag on all four rows) concluded failure. All four build legs failed at the new step, with smoke, export and upload skipped: noble amd64 and arm64 "the image's Ubuntu codename is 'resolute', but this leg's variant is 'noble'", resolute amd64 and arm64 "… is 'noble', but this leg's variant is 'resolute'". Publish failed with "expected 4 verified digests, found 0 - a build leg failed or was skipped, so no tag was attached". `git ls-remote --heads origin m009-planted-os` prints nothing, and the branch head's docker.yml rows read noble/noble, noble/noble, resolute/resolute, resolute/resolute (variant/base_tag).
- AC5: `docker run --rm -v "$PWD:/mnt" -w /mnt koalaman/shellcheck:v0.11.0 -x -S info .github/publish-guard.sh .github/tests/test_publish_guard.sh` printed nothing and exited 0.
- Gate: `cairn_validate.py` all checks passed (exit 0). No DESIGN.md principle text changed, so `cairn_impact` was skipped. Profile consistency-gate: `hadolint/hadolint:v2.12.0` on the Dockerfile exited 0 with no output; the branch changes nothing in the build context (`git diff main...HEAD -- Dockerfile .dockerignore scripts/` is empty), and both dispatches built all four legs from a clean context with `no-cache`; base pin, secrets, and `.dockerignore` are unchanged; changelog slot is "none" and the image's contents do not change, so no release-note entry is owed.
