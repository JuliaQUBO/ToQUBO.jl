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
- Penalty scaling issue: https://github.com/JuliaQUBO/ToQUBO.jl/issues/162
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

## QOBLIB Converter Evidence

- Manual verification: true against QOBLIB commit `a686aaa09fe14651294f744f34d453d5dce9cf57`.
- Converter path: `misc/convert_lp2qubo.py`.
- Converter refs: misc/convert_lp2qubo.py:55-65, misc/convert_lp2qubo.py:82-89.
- Converter convention: QOBLIB reads the LP with Gurobi, changes any continuous variables to integer, builds a Qiskit QuadraticProgram with from_gurobipy, converts it with QuadraticProgramToQubo() using the converter default penalty, writes linear coefficients on the diagonal, symmetrizes Q as (Q + Q') / 2, and writes the objective offset separately.
- Qiskit converter pipeline: QuadraticProgramToQubo first handles a narrow set of special binary inequalities, then converts remaining inequalities to equalities with integer slack variables, encodes integer variables to binary, and finally applies equality penalties.
- Qiskit optimization version checked: 0.7.0
- Qiskit penalty formula checked: LinearEqualityToPenalty._auto_define_penalty and LinearInequalityToPenalty._auto_define_penalty return 1 plus the objective linear/quadratic coefficient bound range for integer-coefficient constraints.
- Qiskit default penalty note: For integer-coefficient constraints, Qiskit's automatic equality penalty is 1 plus the objective coefficient bound range. The pinned QOBLIB converter uses that default path, and for this routing pilot the formula matches ToQUBO's objective-range penalty 16697.376350318606.

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
| minimum coefficient | -331.0 | -1.2874612e10 | -1.2433534e10 |
| maximum coefficient | 1.0 | 7.3976056e9 | 8.891019e9 |
| QOBLIB-style minimum coefficient | n/a | -1.2874612e10 | -1.2433534e10 |
| QOBLIB-style maximum coefficient | n/a | 7.3976056e9 | 8.0192823e9 |
| objective offset | n/a | n/a | 3.5731794e11 |
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
- Distinct constraint penalties: 16697.376
- Encoding types: `Binary`

## Converter Variable Accounting

- Source arc binary variables: 420
- Source load variables: 21
- Source load binary variables: 168
- Encoded source binary variables: 588
- ToQUBO redundant constraints dropped: 22
- QOBLIB retained redundant capacity upper-bound constraints: 21
- QOBLIB retained redundant depot lower-bound constraints: 1
- QOBLIB redundant slack bits vs ToQUBO: 176
- Target variable delta explained by redundant slack bits: true
- Target variable accounting note: Both converters use 8 binary variables for each 0..231 load variable. QOBLIB/Qiskit retains 21 redundant y[i] <= 231 constraints and the redundant depot lower-bound constraint y[1] >= 0; each retained 0..231 slack contributes 8 binary variables, explaining the 176-variable target delta exactly.

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
- Target variable delta note: ToQUBO generates 176 fewer binary variables than the pinned QOBLIB QS metrics row. This is explained by redundant-constraint handling: QOBLIB/Qiskit retains 22 redundant routing bounds as equality constraints with 0..231 integer slacks, while ToQUBO detects and drops those constraints.
- Redundant source constraints detected: 22
- QOBLIB redundant slack bits vs ToQUBO: 176
- Target variable delta explained by redundant slack bits: true
- Target density delta vs QOBLIB QS metrics: 0.0007345511
- Native min-coefficient delta vs QOBLIB QS metrics: 4.4107789e8
- Native max-coefficient delta vs QOBLIB QS metrics: 1.4934133e9
- QOBLIB-style min-coefficient delta vs QOBLIB QS metrics: 4.4107789e8
- QOBLIB-style max-coefficient delta vs QOBLIB QS metrics: 6.2167672e8
- QOBLIB-style minimum-coefficient absolute ratio: 0.96574049
- QOBLIB-style maximum-coefficient absolute ratio: 1.0840376
- QOBLIB-style largest absolute coefficient ratio: 0.96574049
- Same-order coefficient ratio bounds: 0.1 to 10.0
- Penalty-scaling divergence resolved: true
- Routing-specific penalty scaling needed: false
- Penalty scaling resolution note: The original issue-162 coefficient-range divergence no longer reproduces under the default objective-range penalty policy; ToQUBO's QOBLIB-style routing coefficient range is within the pinned QS row's 1e10 scale. ToQUBO's largest absolute coefficient is slightly smaller than QOBLIB's pinned largest absolute coefficient, although its positive-side maximum is larger. No routing-specific penalty scaling is needed for this pilot.

## Penalty Scaling Resolution

The issue-162 penalty-scaling divergence does not reproduce under the objective-range automatic penalty policy. ToQUBO's QOBLIB-style routing coefficient range is within the pinned QOBLIB QS metrics row's 1e10 scale under the symmetrized convention, and the source transcription and incumbent feasibility checks pass. No routing-specific penalty scaling is needed for this pilot. The exact target-size delta is explained by QOBLIB/Qiskit retaining 22 redundant routing bounds as 176 slack bits that ToQUBO drops. Remaining coefficient-extrema differences are conversion-convention effects, not evidence that the objective-range penalty is worse.
