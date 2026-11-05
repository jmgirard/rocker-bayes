# M014: Stop calling the CmdStan tag immutable

**Status:** done (2026-11-05, PR #29 https://github.com/jmgirard/rocker-bayes/pull/29)

**Goal:** The README and design file say truthfully which Docker tags can move, so a user who pins a tag for reproducibility gets what the text promises.

**Outcome:** README and `cairn/DESIGN.md` text only, with no image change. The README
stops calling tags immutable. A date tag keeps the whole image, is named for the UTC day
of the publish job, and moves if a second publish runs that day. A CmdStan tag keeps only
the CmdStan version and moves with each publish while that version is the Dockerfile pin.
The `FROM` and table examples name `noble-2026-11-02`, because `noble-2026-07-05` returned
404. The README adds the image digest as the one pin that never moves, with
`docker buildx imagetools inspect`, and Compose pin steps that warn about the replaced
container, a tag that does not exist, and `up --build`. No committed test: the claims read
Docker Hub, so the criteria's commands ran by hand.

**Decisions:** D-006 rewords IP4 and GP2 and corrects the word in D-001 and D-002.

**Review:** four-lens pass, 29 findings: 6 fixed, 12 follow-ups, 11 rejected (1 as an
edge case: a Docker install with no buildx plugin). No returns and no amendments. New
candidate rows: "Stop calling rstudio2u tags immutable", "Freeze the tags at first
publish", "Tighten the README's pinning text", "Name a bad pin in launcher errors", and
"Clear the README's plain-English hits". Graduated the candidate row "Stop calling the
CmdStan tag immutable". Evicted lesson 2026-09-13 (M005) at the 25-lesson limit.
