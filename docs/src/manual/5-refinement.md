# Iterative Penalty Refinement

The attributes on this page act on the penalty coefficients described in
[Compiler Settings](@ref).

When a solve returns a best sample that violates source constraints — the
practical symptom of under-tuned penalties — ToQUBO can re-tune and re-solve
automatically inside one `optimize!` call. Enable the loop with
[`ToQUBO.Attributes.MaxPenaltyUpdates`](@ref); each iteration checks the best
sample with the same measurement as [`ToQUBO.violations`](@ref), updates the
penalties of violated constraints according to
[`ToQUBO.Attributes.PenaltyUpdateStrategy`](@ref), recompiles, and samples
again, stopping on feasibility, budget exhaustion, or an empty result set.

```@example penalty-refinement
using JuMP
using QUBODrivers
using ToQUBO
using ToQUBO: Attributes

model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

@variable(model, x[1:2], Bin)
@objective(model, Max, 3x[1] + 3x[2])
c = @constraint(model, x[1] + x[2] <= 1)

# Deliberately under-penalize, then let refinement recover feasibility.
set_attribute(c, Attributes.ConstraintEncodingPenaltyHint(), -0.1)
set_attribute(model, Attributes.MaxPenaltyUpdates(), 5)

optimize!(model)

(primal_status(model), objective_value(model))
```

The default [`ToQUBO.Attributes.MultiplicativeUpdate`](@ref) strategy matches
MQT QAO's sequential penalty escalation (arXiv:2406.12840): violated
constraints' coefficients are multiplied by a factor (default 10) — hinted
constraints through their hint (sign preserved), inferred constraints through
[`ToQUBO.Attributes.ConstraintPenaltyScale`](@ref). The number of iterations
performed is queryable afterwards:

```@example penalty-refinement
get_attribute(model, Attributes.PenaltyUpdateCount())
```

Each iteration fully recompiles the model;
[`ToQUBO.Attributes.CompilationTime`](@ref) reports the **last** recompile
only, so total refinement overhead scales with the iteration count.

Escalation grows the QUBO's coefficient range, which physical samplers resolve
with limited precision. For bounded coefficients, configure constraints with
[`ToQUBO.Attributes.AugmentedLagrangianPenalty`](@ref) and select
[`ToQUBO.Attributes.SubgradientUpdate`](@ref): the multiplier ``\lambda`` is
then updated from each iteration's **signed** residual (method of
multipliers), converging with ``\rho`` held fixed (Bertsekas 1982;
Yonaga–Miyama–Ohzeki, [arXiv:2012.06119](https://arxiv.org/abs/2012.06119)
run this iteration on a D-Wave annealer), and ``\rho`` escalates only after
`patience` consecutive non-improving iterations. Violations driven by
variable encodings rather than constraint penalties have no per-constraint
coefficient and are not updated by either strategy.

```@docs
ToQUBO.Attributes.MaxPenaltyUpdates
ToQUBO.Attributes.PenaltyUpdateStrategy
ToQUBO.Attributes.PenaltyUpdate
ToQUBO.Attributes.MultiplicativeUpdate
ToQUBO.Attributes.SubgradientUpdate
ToQUBO.Attributes.PenaltyUpdateCount
```

