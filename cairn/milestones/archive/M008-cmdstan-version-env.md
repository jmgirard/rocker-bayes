# M008: Pass CMDSTAN_VERSION to R via Sys.getenv

**Status:** done (2026-10-20, PR #21 https://github.com/jmgirard/rocker-bayes/pull/21)

**Goal:** The CmdStan version reaches R as an environment variable, so no value can change the R code that installs CmdStan.

**Outcome:** `scripts/install_bayes.sh` resolves the version in
`resolve_cmdstan_version` (first argument, else the environment), exports it,
and stops with "CMDSTAN_VERSION is empty or unset" on an empty value. `main`
calls it before the R package install; `install_cmdstan_step` calls it before
R runs `install_cmdstan(version = Sys.getenv("CMDSTAN_VERSION"))`. The main
body runs only when the script is executed. `.github/tests/test_install_cmdstan.sh`
sources the script with R, mkdir, and chown stubbed on a stub-only PATH and
checks 10 metacharacter values byte for byte, argument precedence, and the
empty and unset stops. pr-ci's job, renamed "offline script suites", runs it.

**Decisions:** sourcing the script with stubs over a static grep or whole-script
PATH stubs; fail early on an empty value (plan gate). A smoke check that the
installed CmdStan matches its tag went to a candidate row.

**Review:** four lenses, 17 findings. Eight were fixed in 10bf6f8: the check
moved to the top of `main`, tests for precedence, mkdir and chown, and `main`'s
stop, the suite made executable, and wording. Nine were rejected. CI amd64 and
local arm64 smoke passed with CmdStan 2.40.0. Graduated the candidate row
"Pass CMDSTAN_VERSION to R via Sys.getenv".
