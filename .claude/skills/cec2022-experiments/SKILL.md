---
name: cec2022-experiments
description: Prepare, configure, run, repair, or interpret GL-FATA CEC2022 comparison and ablation workflows. Use when working with RUNCEC2022_0529.m, Analyze_0529.m, Run_Ablation_Study.m, CEC MEX setup, experiment budgets, raw result files, or statistical outputs.
---

# CEC2022 Experiments

Read `.claude/knowledge/EXPERIMENTS.md` and `.claude/knowledge/PROJECT_MAP.md` before acting.

## Workflow

1. Identify the requested entry point and algorithm set. Prefer `RUNCEC2022_0529.m` for the current eight-algorithm workflow.
2. Confirm `cec22_func`, input data, required statistical functions, and the intended dimension before a long run.
3. Preserve the comparison contract: objective wrapper, dimension, population, FE budget, run count, algorithm list, and random-stream policy.
4. Protect tracked historical output. Use a separate worktree or output location for new runs unless the user explicitly authorizes replacement.
5. Run the matching analysis script only on the result file produced by the same entry point.
6. Report configuration, generated artifacts, missing runs, and environment details with the result.

## Guardrails

- Do not merge data from legacy and current entry points.
- Treat runtime acceleration as an execution setting, never as an algorithmic difference.
- Do not silently delete MAT or Excel artifacts to force a rerun.
- Do not make ranking claims from incomplete, mixed, or unrecorded data.
