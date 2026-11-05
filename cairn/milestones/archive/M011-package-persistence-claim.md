# M011: Fix the package persistence claim

**Status:** done (2026-11-05, PR #24 https://github.com/jmgirard/rocker-bayes/pull/24)

**Goal:** The README says truthfully where installed R packages live, when they are lost, and how to keep them.

**Outcome:** README text only, with no image change. A new "Keeping installed
packages" section says that by default `install.packages()` uses
`/usr/lib/R/site-library` and `/usr/local/lib/R/site-library`. Packages and
`sudo apt install` libraries stay across stop and start, and are lost when Compose
replaces the container: `down` then `up`, a newer image, or a changed `RS_PORT`. It
shows a saved `~/my_packages.R` list and a derivative image. Quick start, Option 1
and 2, the port and update FAQs, and the Baking example changed too. Hand runs on
`noble` checked each outcome, through launchers, bare commands, and an RStudio
session. No committed test: a smoke phase would hold back every tag if the base
starts keeping packages in the volume.

**Decisions:** D-005 keeps installed packages outside the home volume.

**Review:** two four-lens passes, 50 findings: 21 fixed, 1 changed AC2 (one
amendment return, approved at a stop after two re-audits), 6 follow-ups, 22
rejected (2 as rare cases). One review return, on AC2. New candidate rows: "Correct
the claim in rstudio2u too", "Stop calling the CmdStan tag immutable", "Check the
renv and bspm speed claim", "Run a derivative image with Compose", "Say what Option
2's rerun keeps", "Warn about moving the launcher folder". Graduated the candidate
row "Fix the package persistence claim".
