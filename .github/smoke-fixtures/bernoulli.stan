// Fixture for the CI smoke test. Not shipped in the image.
//
// A Bernoulli likelihood with a Beta(1, 1) prior is conjugate, so the
// posterior is Beta(1 + sum(y), 1 + N - sum(y)) and its mean is known in
// closed form. bernoulli.data.json holds N = 100 with sum(y) = 40, giving a
// posterior mean of 41 / 102 = 0.4019608. The smoke test compares the sampled
// mean against that number, so a CmdStan that compiles and samples but returns
// nonsense is caught, not just one that fails to build.
data {
  int<lower=0> N;
  array[N] int<lower=0, upper=1> y;
}
parameters {
  real<lower=0, upper=1> theta;
}
model {
  theta ~ beta(1, 1);
  y ~ bernoulli(theta);
}
