# M014: Stop calling the CmdStan tag immutable

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP4, GP2
- **Resolves:** —
- **Surface tier:** user-facing — the README is what users read when they pin a tag
- **Branch/PR:** m014-cmdstan-tag-claim

## Goal

The README and design file say truthfully which Docker tags can move, so a user who pins a tag for reproducibility gets what the text promises.

## Scope

**In:** Prose in `README.md` and `cairn/DESIGN.md`. The README stops calling the tags immutable, says what each tag keeps and when it moves, recommends a date tag from an earlier day for a setting that must stay the same, and names the image digest as the one pin that never moves. The derivative image `FROM` example moves to a date tag. The table example, `noble-2026-07-05`, returns 404 on Docker Hub, so it changes to a tag that exists. DESIGN.md drops the word, with IP4 and GP2 reworded as D-006 records.

**Out:**
- Changing what the publish job pushes → candidate row "Freeze the tags at first publish".
- The same wording in rstudio2u's README → candidate row "Stop calling rstudio2u tags immutable".
- The text of D-001 and D-002, which is history. D-006 corrects the word.
- A GitHub release. D-002 gives docs changes no release.
- The README's renv speed claim → candidate row "Check the renv and bspm speed claim".

## Acceptance criteria

- [x] AC1: `git grep -n -i -E 'immutable|frozen|will not change' -- README.md` prints nothing.
- [x] AC2: README's Reproducibility section says that a `<variant>-cmdstan<v>` tag keeps only the CmdStan version, moves with each publish while `<v>` is the Dockerfile pin, and then stays on the last one. This matches Docker Hub's tags API at review: for `noble` and `resolute`, the tag naming the pin has the digest of that variant's newest `<variant>-<date>` tag, and `noble-cmdstan2.39.0` has the digest of `noble-2026-09-14`.
- [x] AC3: README's Reproducibility section says that a `<variant>-<date>` tag keeps the whole image, is named for the UTC day of the publish job, and moves if a second publish runs that day. It tells the reader to choose a date from an earlier day. This matches the workflows: `git grep -n -E 'imagetools create|build-push-action|docker push|push=true' -- .github/workflows` shows that only `docker.yml`'s publish job attaches registry tags, and that job reads the date with `date -u +%Y-%m-%d`.
- [x] AC4: README names the digest form `jmgirard/rocker-bayes@sha256:<digest>` as the one pin that never moves and gives one command that prints a tag's digest. A run of that command on the date tag in the `FROM` example prints the `digest` that the tags API gives for that tag, and `docker buildx imagetools inspect jmgirard/rocker-bayes@<digest>` lists both `linux/amd64` and `linux/arm64`.
- [x] AC5: The `FROM` example in README's derivative image section names a `<variant>-<date>` tag. `grep -oE '(noble|resolute)-[0-9]{4}-[0-9]{2}-[0-9]{2}' README.md` finds at least one match. Each match is dated before the UTC date of the branch's last commit and returns HTTP 200 from the tags API. `bash .github/tests/test_cmdstan_pin.sh` passes.
- [x] AC6: `git grep -n -i immutable -- cairn/DESIGN.md` prints nothing. DESIGN.md's Tags convention says what the README says about when each tag moves. IP4 still names `RS_PORT`, `RS_PASS`, the compose service name `bayes`, the launcher file names, both tag patterns, its deprecation clause, and "Adding is free; renaming or removing is not."
- [x] AC7: `git diff --name-only <default-branch>...HEAD` lists only `README.md` and paths under `cairn/`.

## Coverage

- AC1 → T1, T2
- AC2 → T2, T4
- AC3 → T2, T4
- AC4 → T2, T4
- AC5 → T1, T2, T4
- AC6 → T3
- AC7 → T4

## Tasks

- [x] T1: Rewrite `README.md:30-32` and `README.md:181-185`. The `FROM` line names a date tag from an earlier day that exists on Docker Hub, such as `noble-2026-11-02`.
- [x] T2: Rewrite `README.md:243-254`. Replace the "Frozen at" column with what each tag keeps and when it moves. Replace `noble-2026-07-05`. "As of that build" becomes the publish day, because a rerun after midnight UTC can name legs built the day before. Add the digest form and its command. Do not write an old CmdStan version in the README, because `test_cmdstan_pin.sh` fails on it.
- [x] T3: Reword `cairn/DESIGN.md` lines 32, 68, 96, 100, 106, 132, 197, and 209. Use the IP4 and GP2 wording in D-006, and state in the Tags convention when each tag moves.
- [x] T4: Run the commands that AC2 to AC5 and AC7 name, on the branch. A README-only pull request starts no `pr-ci.yml` run, so `test_cmdstan_pin.sh` runs by hand.

## Work log

- 2026-11-05: created by /milestone-plan.
- 2026-11-05: tier check: not run — work named at the question set.
- 2026-11-05: idea vet: gap, the date tag also moves within its day, reading taken: the README says so. Gap, the `FROM` example teaches the CmdStan tag as the reproducible pin, reading taken: it moves to a date tag. Gap, the table example returns 404, reading taken: replace it. No flaw: Docker Hub shows `noble-cmdstan2.40.0` with the digest of `noble-2026-11-05`.
- 2026-11-05: lessons used: 2026-09-12 (M002), a `pull_request` paths filter reads the whole diff, so a README-only pull request runs no `pr-ci.yml` and T4 runs the pin test by hand.
- 2026-11-05: question set: what to plan — "Stop calling the CmdStan tag immutable", chosen from the normal rung.
- 2026-11-05: question set: reword IP4 and GP2 without changing what they require — reword both. Asked as a second question because no cairn rule covers a permission that appears after the work is chosen at the set. The answer settles the IP-touching question, so no task carries a tripwire tag.
- 2026-11-05: criteria audit (full mode, fresh Opus reader): AC1 grep was a spelling proxy, added `frozen` and kept the promise to the words swept. AC2 was false for old tags, added "while `<v>` is the pin" and a 2.39.0 digest check. AC3 "only on that UTC date" was false across midnight, narrowed to the publish day and an earlier-day instruction, and the grep now covers untagged build pushes. AC4 accepted single-architecture digests, now requires the API digest and both platforms. AC5 now requires a date before the commit's date, T2 names the table example. AC6 lacked a D-entry and passed on deletion alone, D-006 lands in this plan commit and AC6 requires the Tags convention to state the behavior. AC7 returned nothing.
- 2026-11-05: plan gate chose changing the words over freezing the tags at first publish because the row asks for the words and a frozen CmdStan tag would stop taking package and base updates; falsified by a user report that the moving CmdStan tag broke a pinned setup despite the new text.
- 2026-11-05: plan gate chose naming the digest in the README over leaving date tags as the strongest pin because only a digest cannot move on its build day; falsified by Docker Hub deleting untagged manifests that digest pins name.
- 2026-11-05: test scope: no committed test, because the claims read Docker Hub and the offline suites cannot; a Hub read in `pr-ci.yml` would fail on a Hub outage. M011 took the same route. The named commands run at review.
- 2026-11-05: T1 done: the README's top note and `FROM` example now point at a date tag, `noble-2026-11-02`, which Docker Hub lists.
- 2026-11-05: T2 done: the Reproducibility table says what each tag keeps and when it moves, and the section adds the digest pin. Chose `imagetools inspect` with no `--format` flag because a `{{...}}` argument in single quotes does not work in Windows `cmd`; a run on `noble-2026-11-02` printed the index digest and both platforms.
- 2026-11-05: T3 done: DESIGN.md drops the word, IP4 and GP2 use D-006's wording, and the Tags convention states when each tag moves.
- 2026-11-05: T4 done: the commands of AC2 to AC5 and AC7 passed on the branch, and `test_cmdstan_pin.sh` found 3 references. The lint hook's hits on lines this branch wrote are fixed. Its other README hits are older text, left alone as out of scope, and now candidate row "Clear the README's plain-English hits".
- 2026-11-05: claim audit: 15 claims read, 2 corrected — README.md. Corrected "change with each publish" to "can change", because push builds use the cache, and the digest wording, because the `Digest:` line already holds `sha256:` and pasting it whole gave `@sha256:sha256:`. The reader also found that `up --build` ignores a pin, so T2 adds a Compose paragraph, a minor amendment; its re-read and a dry run confirmed all three on a tag pin, with `start_linux.sh` read and the other start files checked by grep.
- 2026-11-05: collision sweep: candidate row absorbed. D-002 and D-001 use the word, corrected by D-006. Row "Prune untagged manifests from dispatches" gains a note, because pruning can break a digest pin. Inbox sweep: 0 open issues, 0 open pull requests, so no assignment option. No release-shaped or checker-regress hit.

## Decisions

## Review

- AC1 evidence (2026-11-05): `git grep -n -i -E 'immutable|frozen|will not change' -- README.md` printed nothing, exit 1.
- AC2 evidence (2026-11-05): the Reproducibility section states the three facts in its table and CmdStan paragraph. Tags API: `noble-cmdstan2.40.0` equals `noble-2026-11-05` (`sha256:eeb15415a7d0`), `resolute-cmdstan2.40.0` equals `resolute-2026-11-05` (`sha256:e520e445e9b9`), and `noble-cmdstan2.39.0` equals `noble-2026-09-14`.
- AC3 evidence (2026-11-05): the section states the whole image, the UTC day of the publish job, the second-publish move, and "choose a date from an earlier day". The grep lists `docker.yml:104` and `:120` (push by digest, no tag), `docker.yml:298` (dry run), `docker.yml:371` (the attach), and `pr-ci.yml:99` (`load: true`, a local tag). `docker.yml:271` reads `date -u +%Y-%m-%d`.
- AC4 evidence (2026-11-05): the README gives the digest form and `docker buildx imagetools inspect`. On `noble-2026-11-02` the command printed `sha256:2511d73a0dad…`, equal to the tags API `digest`, and inspecting that digest listed `linux/amd64` and `linux/arm64`, exit 0.
- AC5 evidence (2026-11-05): `README.md:186` is `FROM jmgirard/rocker-bayes:noble-2026-11-02`. The grep found 3 matches, all `noble-2026-11-02`, dated before the branch's last commit date of 2026-11-05 UTC, each HTTP 200. `test_cmdstan_pin.sh` passed with 3 references.
- AC6 evidence (2026-11-05): `git grep -n -i immutable -- cairn/DESIGN.md` printed nothing, exit 1. The Tags convention states the README's behavior for each tag. IP4 still names `RS_PORT`, `RS_PASS`, `bayes`, the launcher file names, both tag patterns, the deprecation clause, and "Adding is free; renaming or removing is not."
