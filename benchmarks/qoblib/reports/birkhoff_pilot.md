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

## Follow-Up

The pilot records a coefficient-range delta: ToQUBO's maximum coefficient is above the canonical QOBLIB metrics row for this instance. Track the penalty-scaling investigation in JuliaQUBO/ToQUBO.jl#148 before expanding class coverage.
