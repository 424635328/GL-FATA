# Result Artifact Notes

## README image sources

Use only matching `Run0529` artifacts for the current eight-algorithm presentation:

| File | Meaning | README placement |
| --- | --- | --- |
| `xxt1.jpg` | Fitness-distribution boxplots for F1–F12 | Full-width overview. |
| `Friedman.jpg` | Mean Friedman ranking; lower is better | Pair with runtime chart. |
| `runtime.jpg` | Mean elapsed time by function and algorithm | Pair with ranking chart. |
| `leida.jpg` | Function-level ranking profile | Centered secondary figure. |

Do not substitute `boxplots.jpg` or `xxt.jpg` without checking the algorithm list; they retain an older comparison set.

## Presentation rules

- Place a dense multi-function figure before compact summaries.
- Pair landscape charts of similar visual density; keep the radar chart centered and narrower.
- Every figure must use a relative repository path and descriptive alt text.
- Describe all images as historical snapshots unless they were regenerated from the current data under a recorded environment.
- State whether lower or higher values are preferable when the chart does not make it obvious.

## Validation before publication

1. Confirm the image filename, data file, analysis script, and algorithm list refer to the same run.
2. Check that any reported ranking matches the corresponding spreadsheet or MAT data.
3. Avoid qualitative superiority claims that the artifact alone does not support.
4. Update README captions and the artifact table together when a new run becomes the displayed snapshot.
