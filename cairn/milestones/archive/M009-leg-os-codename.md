# M009: Assert each leg's OS matches its variant

**Status:** done (2026-10-21, PR #22 https://github.com/jmgirard/rocker-bayes/pull/22)

**Goal:** A publish build leg whose image runs a different Ubuntu release than its variant names fails before it uploads its digest.

**Outcome:** `.github/publish-guard.sh os <os-release-file> <variant>` reads the
first `VERSION_CODENAME=` line, strips one pair of quotes, and refuses a
mismatch, an empty or missing value, a missing file, or a failed read.
`docker.yml`'s build job runs it in a new step, "Assert the image's Ubuntu
release is <variant>", between the architecture assertion and the smoke test,
on `/etc/os-release` read from the pulled-back digest, against
`matrix.variant`. `test_publish_guard.sh` has 16 `os` cases. A test_mode run
passed all four legs; a throwaway branch swapping `base_tag` on all four rows
failed every leg at the new step and publish at `found 0`.

**Decisions:** os-release over the base's version label, `matrix.variant` over
`base_tag`, and a guard subcommand over inline YAML (plan gate). The same check
in `pr-ci.yml` was declined at the plan gate.

**Review:** four lenses, 20 findings. Eight were fixed in 10e237e: a read-error
message and test, the CR note in the header, and four step lists that now name
the check. Eleven were rejected. One became the candidate row "Test the os
step's read failure". Graduated the candidate row "Assert each leg's OS matches
its variant".
