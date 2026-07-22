---
name: results-curation
description: Validate, select, visualize, and document GL-FATA experiment results. Use when updating README figures, result captions, spreadsheets, historical Run0529 artifacts, ranking summaries, or claims derived from CEC2022 output.
---

# Results Curation

Read `.claude/knowledge/RESULTS.md` and `.claude/knowledge/EXPERIMENTS.md` before selecting or describing output.

## Workflow

1. Identify the exact run directory, source MAT file, analysis script, and algorithm list behind each artifact.
2. Verify rankings and reported values against the matching spreadsheet or raw data before changing documentation.
3. Select a compact figure set: full-width distribution first, paired compact summaries next, then secondary detail.
4. Use relative image paths, descriptive alt text, and captions that identify historical snapshots accurately.
5. State ranking direction and experimental limits; avoid claims beyond what the data supports.
6. Keep README figures, captions, and result-source tables synchronized.

## Guardrails

- Do not mix figures from runs with different algorithm lists.
- Do not use stale image names without checking their contents.
- Do not overwrite historical charts while preparing a new presentation.
