# GL-FATA Agent Guide

Start with `.claude/knowledge/INDEX.md`. Load only the knowledge file relevant to the request.

## Repository rules

- Treat `GL_FATA.m` and `CEC2022/GL_FATA.m` as synchronized implementations. Keep their behavior aligned whenever the algorithm changes.
- Treat `third_party/FATA` as an external upstream submodule. Do not edit files inside it from this repository.
- Preserve historical files in `CEC2022/RunCEC2022/`. Do not overwrite, delete, or mix them with new output without explicit approval.
- Keep comparisons fair: record objective function, dimension, population size, evaluation budget, independent runs, random-stream setup, and algorithm list.
- Do not describe runtime acceleration settings as part of the GL-FATA method or as a source of comparative advantage.
- Run `tests/smoke_test.m` after changing root-level optimizer code. Run the smallest relevant CEC check before long experiments.

## Knowledge base

| File | Read when |
| --- | --- |
| `.claude/knowledge/PROJECT_MAP.md` | locating code, scripts, data, or historical output |
| `.claude/knowledge/ALGORITHM.md` | changing or reviewing FATA / GL-FATA behavior |
| `.claude/knowledge/EXPERIMENTS.md` | preparing, running, or interpreting CEC2022 tasks |
| `.claude/knowledge/RESULTS.md` | updating result tables, figures, or README presentation |

## Local skills

- `$gl-fata-core` — maintain or review the core optimizer safely.
- `$cec2022-experiments` — prepare and manage CEC2022 experiment runs.
- `$results-curation` — verify and present result artifacts in documentation.
