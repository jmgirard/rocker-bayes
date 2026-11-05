<!-- Instantiated by /cairn-init as cairn/DECISIONS.md (file header; entries
     are appended from templates/decision.md). A migration replaces the body
     note with its pointer-only or re-recorded disposition (migration
     protocol step 5). -->
# Decisions

Append-only. Never renumber; supersede with a new entry. D-entries record
choices with rationale — never deferrals ("not now" is a ROADMAP fact).

### D-001 Docker tags are the only versioning; git tags retired; no changelog

**Superseded by D-002 (2026-09-03).**

**Date:** 2026-09-03 (design interview)

**Decision.** The immutable `<variant>-<date>` and `<variant>-cmdstan<v>`
Docker tags published by CI on every build are the release record. Git tags
(`v4.2` through `v8.0`) are retired: no new git tags or GitHub releases, and no
hand release walk. The toolchain profile's `changelog` slot is set to `none`.

**Rationale.** The existing git tags carried no consistent meaning (`v8.0`
points at a README edit), while CI already records every shipped image with a
date and a CmdStan version. A changelog would duplicate the immutable tag list
and the README's package roster (GP1). If a human-readable history is wanted
later, this entry is superseded rather than edited.

### D-002 Docker tags record builds; semver git releases record recipe changes

**Date:** 2026-09-03

**Decision.** Two version records with distinct meanings. The immutable
`<variant>-<date>` and `<variant>-cmdstan<v>` Docker tags published by CI on
every build are the *build* record. Annotated git tags `v<major>.<minor>.<patch>`
with a matching GitHub release are the *recipe* record: major when the
environment changes underneath users (base image family, Docker tag scheme);
minor when something is added or upgraded (R or CmdStan version, package,
variant, launch tool); patch for fixes. Refactors, docs, and rebuilds with no
recipe change get no release; unreleased changes fold into the next release.
Release notes live in the GitHub release body; there is no changelog file.

The original `v1.0`–`v8.0` tags and releases were deleted and the history
re-released under this rule as `v1.0.0` through `v4.1.0` (15 releases,
annotated tags backdated to their commits). Supersedes D-001.

**Rationale.** D-001 retired git releases because the old numbers meant
nothing consistent, but that discarded a human-readable history rather than
fixing it. Docker date tags answer "what did I run"; they do not answer "what
changed and when did it matter". Semver on the recipe answers the second
question without duplicating the tag list or the package roster (GP1).

### D-003 The docker.yml push paths filter leaves out `.github/tests/**`

**Date:** 2026-10-20

**Decision.** `.github/tests/**` stays out of the `docker.yml` push `paths`
filter. The candidate row "Add tests to the docker.yml paths filter" is
dropped.

**Rationale.** `docker.yml` runs none of the `.github/tests` suites, so a run
started by a test-only change would test nothing the change touched.
`pr-ci.yml` triggers on `.github/tests/**` and runs every suite before merge.
Adding the path would rebuild all four legs and re-point the tags for a
test-only merge. The `fresh` gate compares this same path list, so a
test-only commit on the default branch would also mark an older run as stale
and keep it from attaching tags.

### D-004 (2026-11-04): Triage drops five candidate rows as not worth keeping

**Context:** A `/cairn-triage` pass weighed each ROADMAP candidate and each
Known issues entry against the code and the CI run history.

**Decision:** These rows are dropped because the work is not worth doing.

- "Set setgid on site-library dirs only" would stop a user outside staff from
  gaining the staff group through an executable in an R site library. The
  container gives passwordless sudo, so there is no boundary to protect.
- "Use a subset check for manifest arches" would let an index with a third
  architecture pass the manifest guard. The refusal fails closed, and a third
  architecture needs matrix and digest-count edits anyway.
- The row that opens "The push paths filter includes `.github/smoke-test.sh`
  and the fixtures" would stop comment-only edits of those files from
  rebuilding four legs and re-pointing `latest`. It also absorbed the
  `pr-ci.yml` build on any `.github/workflows/**` edit. The cost is CI minutes
  only. The `fresh` gate reads the same push filter, and DESIGN.md lists the
  workflows among the `pr-ci.yml` trigger paths.
- "Test the os step's read failure" would test the step's `::error::` line for
  a failed `docker run`. Without that branch the step still fails under
  `set -e`, so only a log message is at stake.
- "Tell phase 2 exit 3 from package quit" would separate a package whose load
  calls `quit(status = 3)` from a package already in the image. CI uses
  `praise`, and the worst case is a wrong FAIL line.

**Consequences:** This entry supersedes no entry. A filed finding that matches
one of these rows cites this entry. Superseding this entry reopens the row.
