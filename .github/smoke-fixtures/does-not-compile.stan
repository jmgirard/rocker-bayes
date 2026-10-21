// Deliberately invalid Stan program. The smoke test's control run points
// SMOKE_STAN_FILE at this file to prove the CmdStan phase reports a stanc
// failure rather than passing. `no_such_type` is not a Stan type, so stanc
// rejects the program before the C++ build or any sampling happens.
parameters {
  no_such_type theta;
}
model {
  theta ~ beta(1, 1)
}
