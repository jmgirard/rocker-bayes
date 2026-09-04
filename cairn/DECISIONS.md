<!-- Instantiated by /cairn-init as cairn/DECISIONS.md (file header; entries
     are appended from templates/decision.md). A migration replaces the body
     note with its pointer-only or re-recorded disposition (migration
     protocol step 5). -->
# Decisions

Append-only. Never renumber; supersede with a new entry. D-entries record
choices with rationale — never deferrals ("not now" is a ROADMAP fact).

### D-001 Docker tags are the only versioning; git tags retired; no changelog

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
