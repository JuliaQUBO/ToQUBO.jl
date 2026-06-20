# QOBLib Routing Reformulation Pilot

This report is a ToQUBO-generated reformulation benchmark. It is not a canonical QOBLIB artifact.

## Provenance

- QOBLIB repository: https://github.com/ZIB-AOPT/QOBLIB
- QOBLIB commit: `a686aaa09fe14651294f744f34d453d5dce9cf57`
- QOBLIB class: `09-routing`
- Source model: `09-routing/models/integer_linear/cvrp_ilp.zpl`
- Source instance: `09-routing/instances/XSH-n20-k4-01.vrp`
- Source LP: `09-routing/models/integer_linear/lp_files/XSH-n20-k4-01.lp.xz`
- Source solution: `09-routing/solutions/XSH-n20-k4-01.opt.sol`
- Source metrics: `09-routing/models/integer_linear/lp_files/metrics.csv`
- Source metrics CSV row: `XSH-n20-k4-01.lp,0,441,0,441,483,0,483,0.011558522649915729,-331.0,1.0`
- Canonical QUBO metrics: `09-routing/models/integer_linear/metrics_qs_files.csv`
- Canonical QUBO metrics CSV row: `XSH-n20-k4-01.qs,4527,0.011716313817136443,-12874612219.171257,7397605618.245156`
- Canonical QUBO artifact available at pinned commit: false
- Canonical QUBO artifact note: The pinned QOBLIB tree contains the XSH-n20-k4-01.qs metrics row but no stored QS artifact, so this pilot compares against the metrics table row.
- Model license: Apache License, Version 2.0
- Data license: Creative Commons Attribution 4.0 International
- Penalty scaling follow-up: https://github.com/JuliaQUBO/ToQUBO.jl/issues/162
- Generated collection label: ToQUBO-generated reformulation benchmark

## Upstream Verification

- Manual verification: true against QOBLIB commit `a686aaa09fe14651294f744f34d453d5dce9cf57`.
- Class refs: 09-routing/README.md:18-35.
- Model refs: 09-routing/models/integer_linear/cvrp_ilp.zpl:16-23, 09-routing/models/integer_linear/cvrp_ilp.zpl:39-44, 09-routing/models/integer_linear/cvrp_ilp.zpl:49-84.
- Instance refs: 09-routing/instances/XSH-n20-k4-01.vrp:10-15, 09-routing/instances/XSH-n20-k4-01.vrp:16-37, 09-routing/instances/XSH-n20-k4-01.vrp:38-63.
- Solution refs: 09-routing/solutions/XSH-n20-k4-01.opt.sol:1-5, 09-routing/solutions/README.md:10.
- Metrics refs: 09-routing/models/integer_linear/lp_files/metrics.csv:2, 09-routing/models/integer_linear/metrics_qs_files.csv:2.
- XSH-n20-k4-01 is the first 21-node, 4-vehicle CVRP instance in the routing class.
- node 1 is the depot and nodes 2 through 21 are the customers.
- the QOBLIB solution file uses CVRPLIB customer numbering, so each listed customer id is mapped to QOBLIB node id customer + 1.
- the ZIMPL model uses Euclidean sqrt distances in the LP objective, while the solution artifact reports the rounded CVRPLIB route cost.

## Instance

- QOBLIB id: `XSH-n20-k4-01`
- Source LP file: `XSH-n20-k4-01.lp`
- Canonical QUBO file: `XSH-n20-k4-01.qs`
- Nodes: 21
- Customers: 20
- Vehicles: 4
- Capacity: 231
- Depot: 1
- Edge weight type: EUC_2D
- QOBLIB solution cost: 646

## Modeling Assumptions

- the source model follows QOBLIB's integer-linear CVRP formulation
- node 1 is the depot and each non-depot node is visited exactly once
- flow-conservation constraints balance incoming and outgoing selected arcs at each customer
- the depot has at most four outgoing selected arcs, matching the vehicle limit
- MTZ-style load variables y[i] are integer-bounded in [0, 231]
- the explicit capacity upper and lower constraints are kept to match the pinned LP row

## Bounds and Naming

- 0 <= x[i,j] <= 1, integer, for i != j
- 0 <= y[i] <= 231, integer
- explicit source constraints also enforce demand[i] <= y[i] <= 231
- x[i,j] follows the QOBLIB selected directed arc variable
- y[i] follows the QOBLIB cumulative demand/load variable
- QOBLIB LP variable names use x#i#j and y#i

## Metrics

| Metric | QOBLIB source LP | QOBLIB canonical QUBO metrics | ToQUBO generated QUBO |
|:--|--:|--:|--:|
| variables | 441 | 4527 | 4351 |
| density | 0.011558523 | 0.011716314 | 0.012450865 |
| minimum coefficient | -331.0 | -1.2874612e10 | -1.4036904e13 |
| maximum coefficient | 1.0 | 7.3976056e9 | 2.7938839e13 |
| QOBLIB-style minimum coefficient | n/a | -1.2874612e10 | -1.4036904e13 |
| QOBLIB-style maximum coefficient | n/a | 7.3976056e9 | 1.5646507e13 |
| objective offset | n/a | n/a | 1.5412343e13 |
| QUBO terms | n/a | n/a | 117882 |
| quadratic terms | n/a | n/a | 113531 |

## Source Model Counts

- Generated source variables: 441
- Generated source constraints: 483
- Customer-visited-once constraints: 20
- Flow-conservation constraints: 20
- Vehicle-limit constraints: 1
- Capacity-linking constraints: 400
- Capacity upper-bound constraints: 21
- Capacity lower-bound constraints: 21

## Reformulation Metadata

- Metadata schema version: 1
- Source variables: 441
- Target variables: 4351
- Auxiliary variables: 3763
- Slack variables: 421
- Constraint penalties: 461
- Variable penalties: 0
- Slack penalties: 0
- Distinct constraint penalties: 16697.376, 1.6479324e7, 2.6568944e8
- Encoding types: `Binary`

## Known Incumbent

- Source objective using sqrt distances: 646.67036
- Rounded CVRPLIB route cost: 646.0
- QOBLIB solution artifact cost: 646
- Source feasible: true
- Customer-visited-once feasible: true
- Flow-conservation feasible: true
- Vehicle-limit feasible: true
- Capacity-linking feasible: true
- Capacity upper bounds feasible: true
- Capacity lower bounds feasible: true
- Route demands: 231, 231, 231, 231
- All routes capacity-tight: true
- Active selected arcs: 24
- Selected arcs: (1, 16), (16, 3), (3, 19), (19, 2), (2, 9), (9, 1), (1, 11), (11, 12), (12, 8), (8, 10), (10, 7), (7, 1), (1, 18), (18, 5), (5, 6), (6, 20), (20, 4), (4, 1), (1, 21), (21, 13), (13, 14), (14, 15), (15, 17), (17, 1)
- QOBLIB solution artifact consistency check: pass

## Comparison Notes

- Canonical QUBO metrics available for this instance: true
- Target variable delta vs QOBLIB QS metrics: -176
- Target variable delta note: ToQUBO generates fewer binary variables than the pinned QOBLIB QS metrics row. The current compiler also detects 22 explicit source constraints as always feasible, so the target-size delta should be interpreted alongside the redundant-constraint count and encoding metadata.
- Redundant source constraints detected: 22
- Target density delta vs QOBLIB QS metrics: 0.0007345511
- Native min-coefficient delta vs QOBLIB QS metrics: -1.402403e13
- Native max-coefficient delta vs QOBLIB QS metrics: 2.7931441e13
- QOBLIB-style min-coefficient delta vs QOBLIB QS metrics: -1.402403e13
- QOBLIB-style max-coefficient delta vs QOBLIB QS metrics: 1.5639109e13

## Follow-Up

The pilot found a major coefficient-scaling gap: ToQUBO's generated routing QUBO coefficient range is about three orders of magnitude larger than the pinned QOBLIB QS metrics row even under the QOBLIB-style symmetrized convention. The source transcription and incumbent feasibility checks pass, so this PR keeps the reproducible routing pilot and tracks penalty-scaling investigation in https://github.com/JuliaQUBO/ToQUBO.jl/issues/162 before expanding the routing benchmark class.
