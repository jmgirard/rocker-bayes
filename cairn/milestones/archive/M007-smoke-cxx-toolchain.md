# M007: Cover a broken C++ toolchain in smoke

**Status:** done (2026-10-20, PR #20 https://github.com/jmgirard/rocker-bayes/pull/20)

**Goal:** Smoke phase 3 fails on its own C++ build line when the image's C++ compiler is broken.

**Outcome:** `.github/smoke-test.sh` phase 3 creates the model with
`cmdstan_model(compile = FALSE)` outside any stage, runs `$check_syntax()`
under `stage:stanc`, then `$compile()` under `stage:cxx`. The shell prints
"stanc failed on <file>" or "<file> passed stanc but the C++ build failed" in
place of the old "did not compile" line. The `stage:cxx` handler prints the
error's `stderr` field, which cmdstanr fills and does not print when make
fails while it reads CmdStan flags. Local arm64 controls: `does-not-compile.stan`
gives the stanc line, and an image whose `g++` file is a failing stub gives
the C++ build line. DESIGN.md's CI / publish bullet states the split.

**Decisions:** a one-time local control over a CI step (parked as "Run the
broken compiler control in CI"). Two FAIL lines over one. Replacing the
resolved `g++` file over shadowing it on `PATH`.

**Review:** four lenses, 11 findings. Seven were fixed in fe308fc: the model
constructor moved out of the stanc stage, the stanc line reworded, safer
stderr printing, a comment overclaim, and the fixture header. Marker matching
anywhere in the output went to a candidate row. Three were rejected.
Graduated the candidate row "Cover a broken C++ toolchain in smoke".
