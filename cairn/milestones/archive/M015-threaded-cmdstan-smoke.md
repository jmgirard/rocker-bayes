# M015: Smoke a threaded CmdStan build in CI

**Status:** done (2026-11-05, PR #30 https://github.com/jmgirard/rocker-bayes/pull/30)

**Goal:** Smoke phase 3 fails when the `rstudio` user cannot run a threaded CmdStan build.

**Outcome:** `.github/smoke-test.sh` phase 3, after the unthreaded run,
compiles a copy of the fixture with `stan_threads` under `stage:thread-build`
(model created with `compile = FALSE` outside it) and fails when no
`main_threads.o` is left in the CmdStan tree. It samples 1 chain with
`threads_per_chain = 2` under `stage:thread-sample`, failing unless the run
recorded 2. The build FAIL line names write permission only when the output
holds "Permission denied". A local `chmod -R g-w /opt/cmdstan` image failed
on that line. Two four-leg test-mode runs passed; each smoke step grew from
41-59 s to about 2-2.5 min. The header and DESIGN.md describe the step.

**Decisions:** a one-time local control over a CI plant step; a second build
inside phase 3 over a new phase 5 (plan gate).

**Review:** four lenses, 31 findings: 9 fixed in 7ebff97 (thread count
asserted, cause-specific FAIL line, model outside the stage, docs narrowed),
5 follow-ups, 15 rejected, 2 noted. New parked rows "Show sampler output when
smoke fails" and "Bound the docker.yml smoke step time". Graduated "Smoke a
threaded CmdStan build in CI". Evicted lesson 2026-10-20 (M006) at the limit.
