# QOBLib Reformulation Benchmarks

This directory contains ToQUBO-generated benchmark workflows for QOBLIB source
models. These outputs are reformulation experiments, not canonical QOBLIB
artifacts. Canonical QOBLIB data remains owned by QOBLIB/QUBOLib provenance
workflows.

## Birkhoff Pilot

Run the pilot report generator from the repository root:

```bash
julia --project=. benchmarks/qoblib/birkhoff_pilot.jl
```

The script builds the QOBLIB Birkhoff integer-linear model for
`qbench_03_sparse`, instance `001`, through MathOptInterface and compiles it with
`ToQUBO.Optimizer`. It writes a Markdown comparison report to
`benchmarks/qoblib/reports/birkhoff_pilot.md`.

The embedded pilot data is the smallest sparse Birkhoff instance from QOBLIB:

- upstream repository: `https://github.com/ZIB-AOPT/QOBLIB`;
- upstream commit used for provenance: `a686aaa09fe14651294f744f34d453d5dce9cf57`;
- source data path: `03-birkhoff/instances/qbench_03_sparse.json`, key `1`;
- source LP metrics path:
  `03-birkhoff/models/integer_linear/lp_files/metrics.csv`, row
  `bhS-03-001.lp`;
- canonical QUBO metrics path:
  `03-birkhoff/models/integer_linear/metrics_qs_files.csv`, row
  `bhS-3-001.qs`;
- QOBLIB data license: Creative Commons Attribution 4.0 International.

## Modeling Assumptions

The pilot follows QOBLIB's integer-linear Birkhoff formulation:

- use all `n!` permutation matrices as decomposition columns;
- use integer weights `lambda_i` with `0 <= lambda_i <= scale`;
- use integer selectors `z_i` with `0 <= z_i <= 1`;
- enforce `sum(lambda_i) == scale`;
- enforce every matrix entry as `sum(lambda_i * P_i[row, col]) == A[row, col]`;
- enforce activation with `lambda_i <= scale * z_i`;
- minimize `sum(z_i)`.

The known incumbent is evaluated on the source model only. The native ToQUBO
upper-triangular coefficient range is reported alongside the QOBLIB-style
symmetrized convention used by QOBLIB's generated QS writer. The Birkhoff pilot
attributes the native maximum-coefficient delta to that off-diagonal reporting
convention, not to a penalty-scaling change.
