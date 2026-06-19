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

## Steiner Pilot

Run the Steiner pilot report generator from the repository root:

```bash
julia --project=. benchmarks/qoblib/steiner_pilot.jl
```

The script builds the QOBLIB node-disjoint Steiner tree packing model for
`stp_s003_l1_t2_h0_rs97531` through MathOptInterface and compiles it with
`ToQUBO.Optimizer`. It writes a Markdown comparison report to
`benchmarks/qoblib/reports/steiner_pilot.md`.

The embedded pilot data is the smallest Steiner instance from QOBLIB:

- upstream repository: `https://github.com/ZIB-AOPT/QOBLIB`;
- upstream commit used for provenance: `a686aaa09fe14651294f744f34d453d5dce9cf57`;
- source instance path:
  `04-steiner/instances/stp_s003_l1_t2_h0_rs97531`;
- source model path:
  `04-steiner/models/integer_linear/stp_node_disjoint.zpl`;
- source LP metrics path:
  `04-steiner/models/integer_linear/lp_files/metrics.csv`, row
  `stp_s003_l1_t2_h0_rs97531.lp`;
- QOBLIB data license: Creative Commons Attribution 4.0 International.

The pinned QOBLIB tree does not include a canonical QS metrics row or stored QS
artifact for this smallest Steiner instance. The pilot therefore reports
ToQUBO-generated QUBO metrics for the small source instance and documents the
absence of canonical QUBO metrics in the generated report.

## Sports Pilot

Run the Sports pilot report generator from the repository root:

```bash
julia --project=. benchmarks/qoblib/sports_pilot.jl
```

The script builds the QOBLIB mixed-integer sports scheduling model for
`Addition_000_Small` through MathOptInterface and compiles it with
`ToQUBO.Optimizer`. It writes a Markdown comparison report to
`benchmarks/qoblib/reports/sports_pilot.md`.

The embedded pilot data is a small 8-team phased double round-robin instance
from QOBLIB:

- upstream repository: `https://github.com/ZIB-AOPT/QOBLIB`;
- upstream commit used for provenance: `a686aaa09fe14651294f744f34d453d5dce9cf57`;
- source instance path:
  `05-sports/instances/Small/Addition_000_Small.xml.gz`;
- source LP path:
  `05-sports/models/mixed_integer_linear/lp_files/Small/Addition_000_Small.lp.xz`;
- source solution path:
  `05-sports/solutions/Small/Addition_000_Small.opt.sol`;
- source LP metrics path:
  `05-sports/models/mixed_integer_linear/lp_files/metrics.csv`, row
  `Addition_000_Small.lp`;
- canonical QUBO metrics path:
  `05-sports/models/mixed_integer_linear/metrics_qs_files.csv`, row
  `Addition_000_Small.qs`;
- QOBLIB data license: Creative Commons Attribution 4.0 International.

The pilot transcribes the hard CA4, GA1, BR1, and BR2 constraints from the XML
instance. The generated report documents the known feasible schedule from the
QOBLIB solution artifact, four redundant hard constraints that ToQUBO detects as
always feasible, and the QOBLIB-style symmetrized coefficient range used for QS
metric comparison.

## Network Pilot

Run the Network pilot report generator from the repository root:

```bash
julia --project=. benchmarks/qoblib/network_pilot.jl
```

The script builds the QOBLIB integer network design model for `network05`
through MathOptInterface and compiles it with `ToQUBO.Optimizer`. It writes a
Markdown comparison report to `benchmarks/qoblib/reports/network_pilot.md`.

The embedded pilot data is the smallest network instance from QOBLIB:

- upstream repository: `https://github.com/ZIB-AOPT/QOBLIB`;
- upstream commit used for provenance: `a686aaa09fe14651294f744f34d453d5dce9cf57`;
- source model path: `08-network/models/integer_lp/d3ver0int.zpl`;
- source demand path: `08-network/instances/demand.txt`;
- source LP path: `08-network/models/integer_lp/lp_files/network05.lp.xz`;
- source solution path: `08-network/solutions/network05.opt.sol`;
- source LP metrics path:
  `08-network/models/integer_lp/lp_files/metrics.csv`, row `network05.lp`;
- canonical QUBO metrics path:
  `08-network/models/integer_lp/metrics_qs_files.csv`, row `network05.qs`;
- QOBLIB data license: Creative Commons Attribution 4.0 International.

The pilot transcribes the `num_nodes=5` network design model with fixed in- and
out-degree constraints, source-indexed integer flow balance, arc-linking
constraints, and the max-load objective. The generated report documents the
known QOBLIB feasible solution, ToQUBO target metrics, penalty and encoding
metadata, and the absence of a stored `network05.qs` artifact at the pinned
commit.
