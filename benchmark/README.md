# Exact penalty verification

Run `exact_penalty.jl` in a pinned project, with one Julia/native thread and an
external CPU, memory and wall-time limit. The optional argument names a new TOML
output file. The script refuses to overwrite existing output.

The reference functions retain the former materializing polynomial comparison
and generic float-to-rational conversion. Both conditions use the same loaded
PBO dependency. Each operation has two warmups and five measured repetitions in
alternating order; GC runs outside each measurement. Raw timing, allocation,
allocated-byte and in-window GC observations are retained. The first fixture and
imports are outside the reported windows.

These microbenchmarks measure integral coefficient conversion and equality of
5,050-term polynomials. They do not measure full conversion, export, audit or
solver performance. A missing-term miss or non-integral float can exercise a
different path. Repository tests cover numerical rejection and explicit zeros.

The accompanying real-instance experiment uses the pinned QOBLIB source
`bhD-05-001.lp` at `16a166ee67c24c112551c803aab5394743b815b5`, with identical
converter defaults and merged PBO `55cc80582ee3e6765f686718e490b3e41dd77311` in
both conditions. D5-specific warmup, ordinary warmed compilation, sampled
compilation and later canonical export/metadata validation are distinct phases.
Raw aggregate observations and exact source/artifact identities are retained in
[birkhoff_d5_receipt.json](birkhoff_d5_receipt.json).

| Warmed compilation | Baseline, same-core recheck | Candidate |
| --- | ---: | ---: |
| Ordinary wall seconds | 44.968953359 | 29.085882952 |
| Allocations | 488,354,176 | 312,340,877 |
| Total allocated bytes | 14,465,523,296 | 9,828,491,776 |
| In-window GC seconds | 12.747101527 | 8.254068086 |

The observed ratio is 1.546, with 36.0% fewer allocations and 32.1% fewer
allocated bytes. The original baseline ordinary observation was 44.823024314 s
on another physical core; the candidate and later baseline recheck used the same
physical core. Separate sampled observations were 49.669891081 s baseline and
31.451584272 s candidate. Profiling overhead and shared-host variation prevent
interpreting these individual observations as a universal runtime guarantee.
Each process first completed an identical full D5 warmup; the ordinary samples
exclude first-case JIT. There is one ordinary warmed sample per original condition
and one baseline recheck, rather than a distribution of independent repetitions.

Both complete canonical QUBOs have 3,480 variables, 1,448,160 interactions and
SHA256 `0a08a200a958dec64831995d421b85f1bf4225d97f6b027c1e70f5a9bae08bd9`.
Their variable order, normalization, all 146 constraint penalty factors and the
complete recorded penalty-policy metadata match. Full candidate reformulation
metadata matches the retained baseline byte for byte, SHA256
`c121869fb14b018cbbf9c8c9d2ab75df61b8570cc7a71c67e0cff268ad89cce5`.
These checks establish generated-model identity, without a new source optimum
or official-QOBLIB-QUBO identity claim.

The later explicit metadata expansion alone took 116.164319792 s in the candidate
and is outside these compilation windows. Only the candidate repeats that full
expansion in the new experiment; whole-process durations are therefore not paired
comparisons. Both conditions remain capped at 16 GiB, with no OOM events. Total
allocated bytes describe allocation traffic over GC cycles, not peak live memory.
The benchmark uses a merged PBO source pin, without changing package compatibility
or implying that this dependency source is a registered release.

The D5 receipt also binds the executable frozen study harness and its supporting
files by SHA256, records all three Julia invocation templates and the producing
Project/Manifest hashes, and describes reconstruction from the retained study
artifact. The timed call is `@timed MOI.optimize!(model)` on a fresh identically
constructed optimizer after a full D5 warmup. The separate helper script above
does not reproduce the D5 experiment. Relocating source paths changes manifest
bytes; retain every package revision and adapt both environments consistently.
