# Algorithm Notes

## Contract

Both optimizers solve continuous single-objective minimization problems:

```matlab
[bestPos, bestScore, curve] = Algorithm(fobj, lb, ub, dim, N, MaxFEs)
```

- `fobj` accepts a `1 × dim` candidate and returns one scalar.
- `lb` and `ub` may be scalars or row vectors of length `dim`.
- `bestScore` is minimized; no maximization adapter is provided.
- `curve` records the best value observed at each completed generation.

## GL-FATA modifications

1. `initialization_PWLCM` produces an independent `N × dim` chaotic population, discarding ten transient iterations before mapping to bounds.
2. The refraction branch preserves local refinement for the current best individual and uses a `lambda = 2.0` differential guide for other individuals.
3. A Lévy candidate is generated with probability `0.2`, clipped to bounds, and accepted only if it improves the global best.
4. GL-FATA checks `FEs < MaxFEs` before every objective call, including the Lévy candidate.

## Invariants to preserve

- Keep all candidate positions within `lb` and `ub` before objective evaluation.
- Do not consume more than `MaxFEs` in GL-FATA.
- Preserve input/output order and minimization semantics.
- Change root and CEC-local GL-FATA together, then compare the behavioral diff and run the smoke check.
- Do not replace the local FATA baseline with the submodule implicitly; update the submodule pointer only through Git submodule operations.

## Baseline note

The local FATA implementation evaluates whole populations by generation. For a strict budget match, choose a `MaxFEs` divisible by `N`, or account for the final partial-generation difference when comparing it with GL-FATA.
