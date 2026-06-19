# QOBLib Sports Reformulation Pilot

This report is a ToQUBO-generated reformulation benchmark. It is not a canonical QOBLIB artifact.

## Provenance

- QOBLIB repository: https://github.com/ZIB-AOPT/QOBLIB
- QOBLIB commit: `a686aaa09fe14651294f744f34d453d5dce9cf57`
- QOBLIB class: `05-sports`
- Source instance: `05-sports/instances/Small/Addition_000_Small.xml.gz`
- Source converter: `05-sports/misc/itc2mip.py`
- Source LP: `05-sports/models/mixed_integer_linear/lp_files/Small/Addition_000_Small.lp.xz`
- Source solution: `05-sports/solutions/Small/Addition_000_Small.opt.sol`
- Source metrics: `05-sports/models/mixed_integer_linear/lp_files/metrics.csv`
- Source metrics CSV row: `Addition_000_Small.lp,0,992,0,992,587,0,587,0.027009946694510085,-1.0,1.0`
- Canonical QUBO metrics: `05-sports/models/mixed_integer_linear/metrics_qs_files.csv`
- Canonical QUBO metrics CSV row: `Addition_000_Small.qs,1737,0.12329035750036603,-497.0,88.0`
- Data license: Creative Commons Attribution 4.0 International
- Generated collection label: ToQUBO-generated reformulation benchmark

## Upstream Verification

- Manual verification: true against QOBLIB commit `a686aaa09fe14651294f744f34d453d5dce9cf57`.
- Converter refs: 05-sports/misc/itc2mip.py:60-88, 05-sports/misc/itc2mip.py:90-107, 05-sports/misc/itc2mip.py:145-178, 05-sports/misc/itc2mip.py:334-399, 05-sports/misc/itc2mip.py:402-450, 05-sports/misc/itc2mip.py:455-549.
- Instance refs: 05-sports/instances/Small/Addition_000_Small.xml.gz:14, 05-sports/instances/Small/Addition_000_Small.xml.gz:22-30, 05-sports/instances/Small/Addition_000_Small.xml.gz:43-69, 05-sports/instances/Small/Addition_000_Small.xml.gz:73-159, 05-sports/instances/Small/Addition_000_Small.xml.gz:160-192, 05-sports/instances/Small/Addition_000_Small.xml.gz:193-238.
- LP refs: decompressed LP lines 1-18, decompressed LP lines 221-1990, decompressed LP lines 1991-3767, decompressed LP lines 3801-5787.
- Solution refs: 05-sports/solutions/Small/Addition_000_Small.opt.sol:2, 05-sports/solutions/Small/Addition_000_Small.opt.sol:3-994.
- Metrics refs: 05-sports/models/mixed_integer_linear/lp_files/metrics.csv:Addition_000_Small.lp, 05-sports/models/mixed_integer_linear/metrics_qs_files.csv:Addition_000_Small.qs.
- Additional_0_Small8.xml defines 8 teams, 14 slots, phased double round robin play, and no soft objective.
- x[h,a,s] follows the QOBLIB home-away-slot variable names with zero-based team and slot ids.
- bh[t,s] and ba[t,s] are home-break and away-break indicators for slots 1 through 13.
- the hard XML constraints in this instance use CA4, GA1, BR1, and BR2 families.

## Instance

- QOBLIB id: `Addition_000_Small`
- XML instance name: `Additional_0_Small8.xml`
- Source LP file: `Addition_000_Small.lp`
- Canonical QUBO metrics row: `Addition_000_Small.qs`
- Size class: Small
- Teams: 8
- Slots: 14
- Number round robin: 2
- Game mode: P
- Matches per slot: 4

## Modeling Assumptions

- the source model follows QOBLIB's mixed-integer sports scheduling formulation
- x[h,a,s] assigns ordered home-away games to slots
- each ordered match is assigned once and each team plays once per slot
- phased play requires every unordered pairing to occur once in the first half
- hard CA4, GA1, BR1, and BR2 constraints are transcribed from the XML instance

## Bounds and Naming

- 0 <= x[h,a,s] <= 1, integer
- 0 <= bh[t,s] <= 1, integer
- 0 <= ba[t,s] <= 1, integer
- team and slot ids follow the zero-based QOBLIB XML and LP names
- x#h#a#s is represented as x[h,a,s]
- bh#t#s and ba#t#s are represented as bh[t,s] and ba[t,s]

## Metrics

| Metric | QOBLIB source LP | QOBLIB canonical QUBO metrics | ToQUBO generated QUBO |
|:--|--:|--:|--:|
| variables | 992 | 1737 | 1733 |
| density | 0.027009947 | 0.12329036 | 0.12385467 |
| minimum coefficient | -1.0 | -497.0 | -497.0 |
| maximum coefficient | 1.0 | 88.0 | 176.0 |
| objective offset | n/a | n/a | 6084.0 |
| QUBO terms | n/a | n/a | 186093 |
| quadratic terms | n/a | n/a | 184360 |

## Reformulation Metadata

- Metadata schema version: 1
- Source variables: 992
- Target variables: 1733
- Auxiliary variables: 741
- Slack variables: 344
- Constraint penalties: 583
- Variable penalties: 0
- Slack penalties: 0
- Distinct constraint penalties: 1.0
- Encoding types: `Binary`

## Source Constraint Counts

- Assignment constraints: 56
- Slot capacity constraints: 14
- Team-slot constraints: 112
- Break-count constraints: 208
- Phased constraints: 28
- CA4 capacity constraints: 85
- GA1 game constraints: 41
- BR1/BR2 break-limit constraints: 43

## Known Incumbent

- QOBLIB solution artifact objective: 0
- Source objective: 0
- Active games: 56
- Home breaks: 13
- Away breaks: 13
- Source feasible: true
- Assignment feasible: true
- Slot capacity feasible: true
- Team-slot feasible: true
- Phased feasible: true
- Break-count feasible: true
- CA4 capacity feasible: true
- GA1 game feasible: true
- BR1/BR2 break-limit feasible: true
- QOBLIB solution artifact consistency check: pass

## Comparison Notes

- Canonical QUBO metrics available for this instance: true
- Target variable delta vs QOBLIB canonical QUBO metrics: -4
- Density delta vs QOBLIB canonical QUBO metrics: 0.00056430979
- Minimum coefficient delta vs QOBLIB canonical QUBO metrics: 0.0
- Maximum coefficient delta vs QOBLIB canonical QUBO metrics: 88.0
- QOBLIB-style minimum coefficient delta vs QOBLIB canonical QUBO metrics: 0.0
- QOBLIB-style maximum coefficient delta vs QOBLIB canonical QUBO metrics: 0.0
- Redundant source constraints detected as always feasible by ToQUBO: 4
- QOBLIB-style coefficient range: minimum `-497.0`, maximum `88.0`.
- The native maximum coefficient keeps full off-diagonal weights, while QOBLIB's QS metrics use the symmetrized convention.

## Follow-Up

No source formulation gap was found. The target-variable delta is explained by four redundant hard constraints that ToQUBO detects as always feasible and leaves unpenalized; the native max-coefficient delta is an off-diagonal coefficient convention difference, while QOBLIB-style symmetrized min/max coefficients match the canonical QS row.
