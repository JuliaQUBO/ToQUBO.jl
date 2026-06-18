# QOBLib Birkhoff Reformulation Pilot

This report is a ToQUBO-generated reformulation benchmark. It is not a canonical QOBLIB artifact.

## Provenance

- QOBLIB repository: https://github.com/ZIB-AOPT/QOBLIB
- QOBLIB commit: `a686aaa09fe14651294f744f34d453d5dce9cf57`
- QOBLIB class: `03-birkhoff`
- Source data: `03-birkhoff/instances/qbench_03_sparse.json`
- Source instance JSON key: `1`
- Source metrics: `03-birkhoff/models/integer_linear/lp_files/metrics.csv`
- Source metrics CSV row: `bhS-03-001.lp,0,12,0,12,16,0,16,0.1875,-1000.0,1.0`
- Canonical QUBO metrics: `03-birkhoff/models/integer_linear/metrics_qs_files.csv`
- Canonical QUBO metrics CSV row: `bhS-3-001.qs,126,0.3607049118860142,-13346277.0,7000001.0`
- Data license: Creative Commons Attribution 4.0 International
- Generated collection label: ToQUBO-generated reformulation benchmark

## Instance

- Dataset: `qbench_03_sparse`
- Instance: `001`
- QOBLIB id: `B3_3_1`
- Source LP file: `bhS-03-001.lp`
- Canonical QUBO metrics row: `bhS-3-001.qs`
- Matrix size: 3
- Scale: 1000

## Modeling Assumptions

- all n! permutation matrices are included as decomposition columns
- lambda variables are integer-bounded by the QOBLIB scale
- z selector variables are integer-bounded in [0, 1]
- activation constraints enforce lambda_i <= scale * z_i

## Metrics

| Metric | QOBLIB source LP | QOBLIB canonical QUBO metrics | ToQUBO generated QUBO |
|:--|--:|--:|--:|
| variables | 12 | 126 | 126 |
| density | 0.1875 | 0.36070491 | 0.36070491 |
| minimum coefficient | -1000.0 | -1.3346277e7 | -1.3346277e7 |
| maximum coefficient | 1.0 | 7.000001e6 | 8.76288e6 |
| objective offset | n/a | n/a | 1.9607392e7 |
| QUBO terms | n/a | n/a | 2886 |
| quadratic terms | n/a | n/a | 2760 |

## Coefficient Range Attribution

- Canonical artifact check: The pinned QOBLIB tree contains 03-birkhoff/models/integer_linear/metrics_qs_files.csv but no stored bhS-3-001.qs or bhS-3-001.qs.xz artifact, so this commit exposes the canonical coefficient range as a metrics-table row.
- QOBLIB converter convention: `misc/convert_lp2qubo.py` records this workflow: QOBLIB converts the LP with Qiskit QuadraticProgramToQubo, writes linear coefficients on the diagonal, symmetrizes Q as (Q + Q') / 2, and writes the objective offset separately.
- Upstream verification: manually checked QOBLIB commit `a686aaa09fe14651294f744f34d453d5dce9cf57`; converter refs misc/convert_lp2qubo.py:60-65, misc/convert_lp2qubo.py:82-89; metrics ref 03-birkhoff/models/integer_linear/metrics_qs_files.csv:42; LP refs decompressed LP lines 15-21, decompressed LP lines 22-39, decompressed LP lines 40-64.
- Source LP comparison: `03-birkhoff/models/integer_linear/lp_files/bhS-03/bhS-03-001.lp.xz` matches the pilot model after permutation-column renaming; lambda[1:4] match LP x#1:x#4; lambda[5] matches LP x#6; lambda[6] matches LP x#5; z selectors follow the same permutation-column renaming.
- Matched source structure: objective min sum(z); six integer lambda variables bounded in [0, scale]; six integer selector variables bounded in [0, 1]; one scale equality; nine matrix-entry equalities; six activation inequalities lambda_i <= scale * z_i.
- Distinct applied constraint penalties from ToQUBO metadata: 7.0; this matches Qiskit's automatic `sum(abs(objective)) + 1` scale for `min sum(z)`.
- ToQUBO native maximum coefficient terms:
  - Target term `(29, 30)`: native `8.76288e6`, QOBLIB-style `4.38144e6`; source bits: lambda[3] bit 256.0 x lambda[3] bit 489.0.
    - Contributing constraints: scale equality: sum(lambda) == scale; matrix equality: row 1, column 2; matrix equality: row 2, column 1; matrix equality: row 3, column 3; activation inequality: lambda[3] <= scale * z[3].
  - Target term `(59, 60)`: native `8.76288e6`, QOBLIB-style `4.38144e6`; source bits: lambda[6] bit 256.0 x lambda[6] bit 489.0.
    - Contributing constraints: scale equality: sum(lambda) == scale; matrix equality: row 1, column 3; matrix equality: row 2, column 2; matrix equality: row 3, column 1; activation inequality: lambda[6] <= scale * z[6].
- QOBLIB-style maximum coefficient terms:
  - Target term `(61, 61)`: native `7.000001e6`, QOBLIB-style `7.000001e6`; source bits: z[1] bit 1.0 x z[1] bit 1.0.
  - Target term `(62, 62)`: native `7.000001e6`, QOBLIB-style `7.000001e6`; source bits: z[2] bit 1.0 x z[2] bit 1.0.
  - Target term `(63, 63)`: native `7.000001e6`, QOBLIB-style `7.000001e6`; source bits: z[3] bit 1.0 x z[3] bit 1.0.
  - Target term `(64, 64)`: native `7.000001e6`, QOBLIB-style `7.000001e6`; source bits: z[4] bit 1.0 x z[4] bit 1.0.
  - Target term `(65, 65)`: native `7.000001e6`, QOBLIB-style `7.000001e6`; source bits: z[5] bit 1.0 x z[5] bit 1.0.
  - Target term `(66, 66)`: native `7.000001e6`, QOBLIB-style `7.000001e6`; source bits: z[6] bit 1.0 x z[6] bit 1.0.
- QOBLIB-style coefficient range: minimum `-1.3346277e7`, maximum `7.000001e6`.
- Ownership decision: documentation-only. The max-coefficient delta is a coefficient-reporting convention difference. ToQUBO's native upper-triangular terms keep full off-diagonal cross-term weights, while the QOBLIB writer symmetrizes Q and reports half of each off-diagonal cross term. Under the QOBLIB symmetrized convention, ToQUBO matches the canonical QUBO min/max coefficient row.

## Reformulation Metadata

- Metadata schema version: 1
- Source variables: 12
- Target variables: 126
- Auxiliary variables: 60
- Slack variables: 6
- Constraint penalties: 16
- Variable penalties: 0
- Slack penalties: 0
- Encoding types: `Binary`

## Known Incumbent

- Source objective: 2.0
- Source feasible: true
- Matches QOBLIB solution record: true

## Comparison Deltas

- Target variable delta vs QOBLIB canonical QUBO metrics: 0
- Density delta vs QOBLIB canonical QUBO metrics: 0.0
- Minimum coefficient delta vs QOBLIB canonical QUBO metrics: 0.0
- Maximum coefficient delta vs QOBLIB canonical QUBO metrics: 1.762879e6
- QOBLIB-style minimum coefficient delta vs QOBLIB canonical QUBO metrics: 0.0
- QOBLIB-style maximum coefficient delta vs QOBLIB canonical QUBO metrics: 0.0

## Follow-Up

The pilot's native max-coefficient delta is explained by the off-diagonal coefficient convention. Under QOBLIB's symmetrized QS writer convention, ToQUBO matches the canonical coefficient range for this instance; no ToQUBO penalty-scaling change is indicated.
