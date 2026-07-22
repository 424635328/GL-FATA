---
name: gl-fata-core
description: Maintain, review, debug, or modify the GL-FATA and local FATA MATLAB optimizers. Use when changing GL_FATA.m, CEC2022/GL_FATA.m, FATA.m, initialization.m, objective-budget handling, boundaries, or optimizer tests.
---

# GL-FATA Core

Read `.claude/knowledge/ALGORITHM.md` and `.claude/knowledge/PROJECT_MAP.md` before editing.

## Workflow

1. Reproduce the reported behavior with a small deterministic objective before changing code.
2. Preserve minimization semantics, input/output order, boundary clipping, and FE-budget behavior.
3. Apply the smallest change that addresses the request.
4. Keep `GL_FATA.m` and `CEC2022/GL_FATA.m` behavior aligned. Use a diff to inspect the two implementations after editing.
5. Run `tests/smoke_test.m`; for CEC-local changes, also execute a small objective through `CEC2022/GL_FATA.m`.
6. Report changed behavior, test command, and any remaining reproducibility limitation.

## Guardrails

- Do not edit `third_party/FATA/`.
- Do not alter algorithm coefficients, random behavior, or FE accounting merely for formatting.
- Do not claim a performance effect without a controlled comparison using the same experimental configuration.
