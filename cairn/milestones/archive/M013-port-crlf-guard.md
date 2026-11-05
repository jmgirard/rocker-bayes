# M013: Port the CRLF guard

**Status:** done (2026-11-05, PR #28 https://github.com/jmgirard/rocker-bayes/pull/28)

**Goal:** Make CI fail a pull request that stores a Windows launcher with LF line endings.

**Outcome:** `.github/tests/test_launcher_line_endings.sh`, ported from rstudio2u, reads each `*.bat` blob from the index and fails on any LF-only line or when no `.bat` is tracked. It lives in `.github/tests/` and not the cited `scripts/tests/`, because `scripts/**` is in the build context and `docker.yml`'s push paths. `.github/workflows/launchers.yml` runs it in a `line-endings` job on a pull request touching `**.bat`, `.gitattributes`, the guard, or the workflow, and `pr-ci.yml`'s `script-tests` job runs it too. The port fixes a miss in the original: a bare LF passed when the file ended in a CR with no LF after it. The `.gitattributes` comment names the new path and drops the `git archive` claim, which a local run showed false: `git archive` wrote CRLF for an LF blob under `text eol=crlf`. DESIGN.md's Known issues entry now covers only the launcher tests still not ported. The `*.cmd` line in `.gitattributes` has no guard, since no `.cmd` is tracked.

**Decisions:** port over a comment-only fix, by the user's answer at the question set, because rstudio2u's copy reads only its own blobs. A new workflow over adding `**.bat` to `pr-ci.yml`'s paths, which would build the image for a launcher-only edit.

**Review:** one pass, four lenses, 25 findings: 10 fixed, 4 to follow-up, 11 rejected. No return and no criterion amendment. Control PR #27, one LF-only line in `stop_windows.bat` into the milestone branch through a temporary `branches` pattern, failed `line-endings` and was closed unmerged. On PR #28 at head b16c053, `line-endings`, `offline script suites`, `build and smoke-test noble (amd64)`, and `Shell lint` passed, the last on a rerun after a 504 on the shellcheck download. AC3 and AC7 were verified on those checks; their ticks sat in local commits that the squash did not carry, as did the PR URL.

Graduated "Port the CRLF guard or drop its cite". New row "Resync the launchers from rstudio2u", which holds the launcher drift found at planning and rstudio2u's copies of the false claim and the guard's miss. New parked row "Widen the launcher guard's triggers". Updated "Fix required checks behind path filters" to say "No pull-request workflow". Lessons evicted by rank at the 25 limit: 2026-09-12 (M001) on the HEALTHCHECK exit, 2026-09-13 (M004) on `gh run rerun --failed`. Pruned the M010 row.
