# QOBLib Topology Reformulation Pilot

This report is a ToQUBO-generated reformulation benchmark. It is not a canonical QOBLIB artifact.

## Provenance

- QOBLIB repository: https://github.com/ZIB-AOPT/QOBLIB
- QOBLIB commit: `a686aaa09fe14651294f744f34d453d5dce9cf57`
- QOBLIB class: `10-topology`
- Source model: `10-topology/models/seidel_linear/topology_seidel_linear.zpl`
- Source instance: `10-topology/instances/topology_15_4.dat`
- Source bounds: `10-topology/instances/bounds.csv`
- Source LP: `10-topology/models/seidel_linear/lp_files/topology_15_4.lp.xz`
- Source solution: `10-topology/solutions/topology_15_4.opt.gph`
- Source metrics: `10-topology/models/seidel_linear/lp_files/metrics.csv`
- Source metrics CSV row: `topology_15_4.lp,0,1576,0,1576,2955,0,2955,0.0016233347934757401,-1.0,1.0`
- Canonical QUBO metrics: `10-topology/models/seidel_linear/metrics_qs_files.csv`
- Canonical QUBO metrics CSV row: `topology_15_4.qs,4831,0.002770805545312352,-7.0,49.0`
- Canonical QUBO artifact available at pinned commit: false
- Canonical QUBO artifact note: The pinned QOBLIB tree contains the topology_15_4.qs metrics row but no stored topology_15_4.qs or topology_15_4.qs.xz artifact, so this pilot compares against the metrics table row.
- Model license: Apache License, Version 2.0
- Data license: Creative Commons Attribution 4.0 International
- Generated collection label: ToQUBO-generated reformulation benchmark

## Upstream Verification

- Manual verification: true against QOBLIB commit `a686aaa09fe14651294f744f34d453d5dce9cf57`.
- Class refs: 10-topology/README.md:17-30, 10-topology/README.md:32-40.
- Model refs: 10-topology/models/seidel_linear/topology_seidel_linear.zpl:19-24, 10-topology/models/seidel_linear/topology_seidel_linear.zpl:30-44.
- Instance refs: 10-topology/instances/README.md:3-6, 10-topology/instances/README.md:20-30, 10-topology/instances/bounds.csv:3, 10-topology/instances/topology_15_4.dat:1.
- Solution refs: 10-topology/solutions/topology_15_4.opt.gph:1-3, 10-topology/solutions/topology_15_4.opt.gph:4-33.
- Metrics refs: 10-topology/models/seidel_linear/lp_files/metrics.csv:3, 10-topology/models/seidel_linear/metrics_qs_files.csv:3.
- topology_15_4.dat gives nodes=15 and degree=4.
- bounds.csv fixes both minDiameter and maxDiameter to 2 for topology_15_4.
- the Seidel linear model declares distance indicators over D = 0:1 and linearization variables only for the active d=0 constraints in the generated LP.
- the .gph solution lists a 30-edge undirected graph with diameter 2.

## Instance

- QOBLIB id: `topology_15_4`
- Source LP file: `topology_15_4.lp`
- Canonical QUBO file: `topology_15_4.qs`
- Nodes: 15
- Degree: 4
- Diameter lower bound: 2
- Diameter upper bound: 2
- Undirected node pairs: 105

## Modeling Assumptions

- the source model follows QOBLIB's linearized Seidel all-pairs shortest-path formulation
- topology_15_4 fixes the diameter integer variable to 2 using QOBLIB's bounds.csv row
- dist[s,t,0] marks selected undirected graph edges and dist[s,t,1] marks node pairs connected within two hops
- y[s,t,k,0] linearizes the conjunction of a path from s to k within one hop and an edge from k to t
- degree constraints enforce degree 4 for every node because nodes * degree is even

## Bounds and Naming

- 2 <= diameter <= 2, integer
- 0 <= dist[s,t,d] <= 1, integer
- 0 <= y[s,t,k,0] <= 1, integer
- N uses QOBLIB's zero-based model indices 0:14
- F is stored as sorted undirected pairs (s,t) with s < t
- D is stored as distance levels 0 and 1 because maxDiameter is fixed to 2
- the upstream .gph solution uses one-based node labels and is shifted to zero-based labels for feasibility checks

## Metrics

| Metric | QOBLIB source LP | QOBLIB canonical QUBO metrics | ToQUBO generated QUBO |
|:--|--:|--:|--:|
| variables | 1576 | 4831 | 4830 |
| density | 0.0016233348 | 0.0027708055 | 0.0027719529 |
| minimum coefficient | -1.0 | -7.0 | -14.0 |
| maximum coefficient | 1.0 | 49.0 | 56.0 |
| QOBLIB-style minimum coefficient | n/a | -7.0 | -7.0 |
| QOBLIB-style maximum coefficient | n/a | 49.0 | 49.0 |
| objective offset | n/a | n/a | 347.0 |
| QUBO terms | n/a | n/a | 32340 |
| quadratic terms | n/a | n/a | 27615 |

## Source Model Counts

- Generated source variables: 1576
- Generated source constraints: 2955
- Diameter constraints: 105
- Distance-calculation constraints: 105
- Linearization constraints: 2730
- Degree constraints: 15

## Reformulation Metadata

- Metadata schema version: 1
- Source variables: 1576
- Target variables: 4830
- Auxiliary variables: 3255
- Slack variables: 2940
- Constraint penalties: 2955
- Variable penalties: 0
- Slack penalties: 0
- Distinct constraint penalties: 1.0
- Encoding types: `Binary`

## Known Incumbent

- Source objective: 2
- QOBLIB solution artifact objective: 2
- Source feasible: true
- Degree feasible: true
- Diameter constraints feasible: true
- Distance-calculation constraints feasible: true
- Linearization constraints feasible: true
- Max shortest-path distance: 2
- Selected undirected edges: 30
- Degree sequence: `4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4`
- Active dist[s,t,0] entries: 30
- Active dist[s,t,1] entries: 105
- Active y[s,t,k,0] entries: 90
- Selected edges: (1, 2), (1, 3), (1, 4), (1, 5), (2, 4), (2, 13), (2, 15), (3, 9), (3, 11), (3, 14), (4, 8), (4, 12), (5, 6), (5, 7), (5, 10), (6, 11), (6, 12), (6, 15), (7, 8), (7, 13), (7, 14), (8, 9), (8, 11), (9, 10), (9, 15), (10, 12), (10, 13), (11, 13), (12, 14), (14, 15)
- QOBLIB solution artifact consistency check: pass

## Comparison Notes

- Canonical QUBO metrics available for this instance: true
- Target variable delta vs QOBLIB QS metrics: -1
- Target variable delta note: QOBLIB's pinned QS metrics row was produced from the generated Seidel-linear LP. ToQUBO reformulates the same source constraints through its current integer encodings and reports the delta here for parity tracking.
- Target density delta vs QOBLIB QS metrics: 1.1473315e-6
- Native min-coefficient delta vs QOBLIB QS metrics: -7.0
- Native max-coefficient delta vs QOBLIB QS metrics: 7.0
- QOBLIB-style min-coefficient delta vs QOBLIB QS metrics: 0.0
- QOBLIB-style max-coefficient delta vs QOBLIB QS metrics: 0.0

## Follow-Up

No major formulation gap was found in this pilot. ToQUBO's QOBLIB-style symmetrized coefficient range matches the pinned Seidel-linear QS metrics row, while the target variable count differs by one; expansion to larger topology instances should track that parity delta separately if exact QS variable-count parity is required.
