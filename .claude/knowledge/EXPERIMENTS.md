# CEC2022 Experiment Notes

## Current comparison entry

Use `CEC2022/RUNCEC2022_0529.m` for the retained eight-algorithm workflow:

- Functions: F1–F12
- Dimension: 20
- Population: 30
- Independent runs: 30
- Budget: 300,000 FEs per run
- Algorithms: GL-FATA, MFATA-Levy, IMFATA, ASFSSA, PSO, FATA, GWO, SSA

Run `Analyze_0529.m` only against the data produced by the matching entry point.

## Output contract

`RUNCEC2022_0529.m` writes the following files in `CEC2022/`:

| Artifact | Purpose |
| --- | --- |
| `CEC2022_Data.mat` | Per-function, per-algorithm raw fitness and elapsed-time records. |
| `Result_Stats.xlsx` | Min, standard deviation, mean, median, and worst fitness. |
| `Result_RankSum.xlsx` | Pairwise rank-sum summaries against GL-FATA. |
| `Result_Time.xlsx` | Mean elapsed times. |
| `Result_Friedman.xlsx` | Per-function and mean rankings. |

These paths are tracked historical output. Prefer a separate worktree or a copied experiment directory for a new run. Never delete or reset them automatically.

## Comparability rules

- Hold the objective wrapper, dimension, population size, FE budget, independent-run count, and algorithm list fixed across a comparison.
- Record MATLAB version, installed toolboxes, operating system, MEX build, CPU, and random-stream setup with each new result set.
- Treat execution acceleration only as a wall-clock setting. It is not an algorithm operator, and it must not be presented as a method difference or performance advantage.
- Current scripts do not establish one repository-wide deterministic random-stream policy. Do not claim bitwise reproducibility unless the random stream is explicitly controlled.

## Environment checks

- Confirm that `cec22_func` is callable before a long run. The repository includes a Windows x64 MEX binary and its C++ source.
- Confirm that `ranksum` and `tiedrank` are available before requesting statistical output.
- Start with reduced `run_times` and `MaxFEs` to validate the environment, then restore the intended comparison configuration.

## Ablation workflow

`Run_Ablation_Study.m` compares the baseline, three component-removal variants, and the complete GL-FATA variant. Its random initialization uses a time-derived state; record the run context before treating two ablation runs as directly comparable.
