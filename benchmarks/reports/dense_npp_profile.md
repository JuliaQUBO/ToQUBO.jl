# Dense NPP-Like Profile

This report records a local diagnostic run for issue #196. It is a
reproducible benchmark note, not a canonical cross-machine performance claim.

## Environment

- Date: 2026-06-25
- Branch point: `8b80879cd6ca8dcb7c68a89dd8eba8167c3049ba`
- Julia: 1.10.11
- ToQUBO.jl: 0.6.0 from this checkout
- JuMP: 1.30.1 from `test/Manifest.toml`
- QUBOTools.jl: 0.16.0
- Command:

```sh
JULIA_LOAD_PATH="@:test:@stdlib" \
TOQUBO_DENSE_PROFILE_N=1000 \
TOQUBO_DENSE_PROFILE_NON_NPP_N=250 \
TOQUBO_DENSE_PROFILE_REPEATS=5 \
julia --project=. benchmarks/dense_npp_profile.jl
```

## Results

The cached mode uses a normal JuMP `Model` backed by `ToQUBO.Optimizer`.
The direct mode uses `JuMP.direct_model(ToQUBO.Optimizer{Float64}())` as a
diagnostic comparison. The compile-time column is
`ToQUBO.Attributes.CompilationTime()` recorded by ToQUBO inside `optimize!`.

| Fixture | n | Mode | Phase | Median time (s) | Min time (s) | Median alloc (MiB) | Median GC (s) | Median compile time (s) |
| --- | ---: | --- | --- | ---: | ---: | ---: | ---: | ---: |
| NPP-like squared affine | 1000 | cached | model construction | 0.16786 | 0.163039 | 84.034 | 0.002987 |  |
| NPP-like squared affine | 1000 | cached | optimize! | 0.062655 | 0.033776 | 106.223 | 0.028829 | 0.025646 |
| NPP-like squared affine | 1000 | cached | QUBOTools.backend | 0.001072 | 0.00106 | 7.69 | 0.0 |  |
| NPP-like squared affine | 1000 | direct | model construction | 0.168005 | 0.159682 | 83.887 | 0.003161 |  |
| NPP-like squared affine | 1000 | direct | optimize! | 0.025643 | 0.024825 | 59.182 | 0.0 | 0.025531 |
| NPP-like squared affine | 1000 | direct | QUBOTools.backend | 0.001085 | 0.001046 | 7.69 | 0.0 |  |
| generic dense quadratic | 250 | cached | model construction | 0.010218 | 0.008726 | 22.765 | 0.0 |  |
| generic dense quadratic | 250 | cached | optimize! | 0.003212 | 0.003143 | 6.968 | 0.0 | 0.001511 |
| generic dense quadratic | 250 | cached | QUBOTools.backend | 0.000137 | 0.00013 | 0.467 | 0.0 |  |
| generic dense quadratic | 250 | direct | model construction | 0.010225 | 0.010101 | 22.685 | 0.0 |  |
| generic dense quadratic | 250 | direct | optimize! | 0.001617 | 0.001605 | 3.891 | 0.0 | 0.001525 |
| generic dense quadratic | 250 | direct | QUBOTools.backend | 0.000132 | 0.000124 | 0.467 | 0.0 |  |

## Conclusions

- For the NPP-like `n = 1000` case, JuMP model construction is the largest
  measured phase at about 168 ms median.
- ToQUBO's recorded compile time is about 25.6 ms. In direct optimizer mode,
  measured `optimize!` is effectively the same size as the recorded compile
  time, which indicates the residual cached-mode `optimize!` gap is mostly
  JuMP/MOI cached-copy overhead and GC rather than compiler work.
- `QUBOTools.backend(model)` is about 1.1 ms locally for the NPP-like case, so
  backend extraction is not the material bottleneck in this run.
- The smaller generic dense quadratic fixture shows the same shape:
  cached-mode `optimize!` is above recorded compile time, direct-mode
  `optimize!` tracks recorded compile time, and backend extraction is small.
- No generic low-risk compiler change is indicated by this diagnostic run. The
  remaining benchmark gap should be interpreted mainly as JuMP/MOI frontend
  construction plus cached optimizer overhead and benchmark methodology, not as
  QUBOTools backend extraction.

## Follow-Up

If absolute NPP benchmark competitiveness remains a goal, compare benchmark
methodology and JuMP frontend construction separately from ToQUBO compilation.
Direct optimizer mode is useful as a diagnostic, but it should not replace the
normal public JuMP usage path without a separate compatibility review.
