# M006: Assert smoke packages arrive this run

**Status:** done (2026-10-20, PR #19 https://github.com/jmgirard/rocker-bayes/pull/19)

**Goal:** Smoke phase 2 passes only when the probe package was absent from the image before bspm installed it.

**Outcome:** `.github/smoke-test.sh` phase 2 gained `dpkg_state()`, which reads
the last word of the `dpkg -s` Status line, or `?` when the read fails. Before
the install, any state but none, `not-installed`, or `config-files` fails the
phase on the dpkg check. `find.package()` in the root Rscript that runs the
install exits 3 on a hit, which fails the phase on the R library check. After
the install the dpkg state must be `installed`. A failed dpkg read has its own
FAIL line. A present probe fails the run, with no fallback list. DESIGN.md's
CI / publish bullet states the rule.

**Decisions:** fail on a present probe rather than try a fallback list. Local
noble arm64 control runs rather than CI control branches. Exit status 3 rather
than a stdout marker, so install output streams live.

**Review:** four lenses, 15 findings. Ten were fixed in a6bbeae: a post-install
check that took any dpkg record, unpacked and similar states read as absent, a
failed exec read as absent, and five wording items. Exit 3 from a package's own
`quit()` went to a candidate row. Four were rejected. No lesson was retired.
