# QOBLib Steiner Reformulation Pilot

This report is a ToQUBO-generated reformulation benchmark. It is not a canonical QOBLIB artifact.

## Provenance

- QOBLIB repository: https://github.com/ZIB-AOPT/QOBLIB
- QOBLIB commit: `a686aaa09fe14651294f744f34d453d5dce9cf57`
- QOBLIB class: `04-steiner`
- Source model: `04-steiner/models/integer_linear/stp_node_disjoint.zpl`
- Source instance: `04-steiner/instances/stp_s003_l1_t2_h0_rs97531`
- Source solution: `04-steiner/instances/stp_s003_l1_t2_h0_rs97531/sol.txt`
- Source metrics: `04-steiner/models/integer_linear/lp_files/metrics.csv`
- Source metrics CSV row: `stp_s003_l1_t2_h0_rs97531.lp,0,48,0,48,44,0,44,0.056818181818181816,-1.0,1.0`
- Canonical QUBO metrics: `04-steiner/models/integer_linear/metrics_qs_files.csv`
- Canonical QUBO metrics available for this instance: false
- Canonical QUBO metrics note: The pinned QOBLIB metrics_qs_files.csv has rows for larger Steiner instances, but no row or stored QS artifact for stp_s003_l1_t2_h0_rs97531; this pilot reports ToQUBO-generated QUBO metrics for the smallest source instance instead.
- Data license: Creative Commons Attribution 4.0 International
- Generated collection label: ToQUBO-generated reformulation benchmark

## Upstream Verification

- Manual verification: true against QOBLIB commit `a686aaa09fe14651294f744f34d453d5dce9cf57`.
- Model refs: 04-steiner/models/integer_linear/stp_node_disjoint.zpl:30-49, 04-steiner/models/integer_linear/stp_node_disjoint.zpl:51-104.
- Instance refs: 04-steiner/instances/stp_s003_l1_t2_h0_rs97531/param.dat:10-11, 04-steiner/instances/stp_s003_l1_t2_h0_rs97531/terms.dat:11-12, 04-steiner/instances/stp_s003_l1_t2_h0_rs97531/roots.dat:11, 04-steiner/instances/stp_s003_l1_t2_h0_rs97531/arcs.dat:11-34.
- Solution refs: 04-steiner/instances/stp_s003_l1_t2_h0_rs97531/sol.txt:1, 04-steiner/instances/stp_s003_l1_t2_h0_rs97531/sol.txt:4-7.
- Metrics ref: 04-steiner/models/integer_linear/lp_files/metrics.csv:2.
- param.dat lines 10-11 define 9 nodes and 1 net.
- terms.dat lines 11-12 identify terminal node 9 and root node 1 for net 1.
- roots.dat line 11 identifies root node 1.
- arcs.dat lines 11-34 are transcribed in order as the 24 directed unit-cost arcs.
- sol.txt line 1 gives cost 4 and lines 4-7 give the four active solution arcs.

## Instance

- QOBLIB id: `stp_s003_l1_t2_h0_rs97531`
- Source LP file: `stp_s003_l1_t2_h0_rs97531.lp`
- Size: 3
- Layers: 1
- Terminals: 2
- Holes: 0
- Random seed: 97531
- Nodes: 9
- Nets: 1
- Roots: `1`
- Terms: `9`

## Modeling Assumptions

- the source model follows QOBLIB's node-disjoint Steiner tree packing formulation
- x variables route one unit of flow from the root to each terminal
- y variables mark selected directed arcs for the only net
- all x and y variables are integer-bounded in [0, 1]
- node-disjointness limits every non-root node to at most one selected incoming arc and forbids incoming selected arcs to the root

## Bounds and Naming

- 0 <= x[index] <= 1, integer
- 0 <= y[index] <= 1, integer
- x[a,t] is represented as x[index] because the pilot has one terminal t = 9
- y[a,k] is represented as y[index] because the pilot has one net k = 1
- arc indices follow the upstream arcs.dat order

## Metrics

| Metric | QOBLIB source LP | QOBLIB canonical QUBO metrics | ToQUBO generated QUBO |
|:--|--:|--:|--:|
| variables | 48 | n/a | 80 |
| density | 0.056818182 | n/a | 0.089197531 |
| minimum coefficient | -1.0 | n/a | -100.0 |
| maximum coefficient | 1.0 | n/a | 75.0 |
| objective offset | n/a | n/a | 250.0 |
| QUBO terms | n/a | n/a | 289 |
| quadratic terms | n/a | n/a | 209 |

## Reformulation Metadata

- Metadata schema version: 1
- Source variables: 48
- Target variables: 80
- Auxiliary variables: 32
- Slack variables: 32
- Constraint penalties: 44
- Variable penalties: 0
- Slack penalties: 0
- Distinct constraint penalties: 25.0
- Encoding types: `Binary`

## Known Incumbent

- QOBLIB solution path: 1 -> 2 -> 3 -> 6 -> 9
- Active flow arcs: (1, 2), (2, 3), (3, 6), (6, 9)
- Active selected arcs: (1, 2), (2, 3), (3, 6), (6, 9)
- Source objective: 4
- QOBLIB solution artifact cost: 4
- Source feasible: true
- Flow feasible: true
- Node-disjointness feasible: true
- Binding feasible: true
- QOBLIB solution artifact consistency check: pass

## Comparison Notes

- Canonical QUBO metrics available for this instance: false
- Target variable delta vs QOBLIB source integer variables: 32
- Target density delta vs QOBLIB source LP density: 0.032379349

## Follow-Up

No major formulation gap was found in this pilot. The smallest Steiner source instance has no pinned canonical QUBO metrics row, so expansion to larger Steiner instances should be tracked separately if canonical QS parity is required.
