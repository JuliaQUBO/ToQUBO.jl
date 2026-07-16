# Compiler Settings

```@docs
ToQUBO.Attributes.StableCompilation
```

## Compiler Messages

```@docs
ToQUBO.Attributes.Warnings
```

## Constraint Feasibility Actions

```@docs
ToQUBO.Attributes.IgnoreFeasibleConstraints
ToQUBO.Attributes.ErrorInfeasibleConstraints
```

## Compiler Optimization

```@docs
ToQUBO.Attributes.Optimization
```

## Working with target architectures

```@docs
ToQUBO.Attributes.Architecture
```

## Quadratization

```@docs
ToQUBO.Attributes.Quadratize
ToQUBO.Attributes.QuadratizationMethod
ToQUBO.Attributes.StableQuadratization
```

## Variable & Constraint Encoding

### Automatic Penalty Inference

When a constraint, variable encoding, or slack-variable encoding needs a penalty
coefficient and no explicit hint is set, ToQUBO infers one automatically. The
default [`ToQUBO.Attributes.ObjectiveRangePenalty`](@ref) policy uses an
objective-range exact-penalty bound:

```math
\rho = s \cdot \sigma \cdot \left(\frac{U - L + \beta}{\epsilon}\right)
```

where `s` is [`ToQUBO.Attributes.PenaltyScale`](@ref), `β` is
[`ToQUBO.Attributes.PenaltyOffset`](@ref), `σ` is `1` for minimization models
and `-1` for maximization models, `U - L` is the compiled pseudo-boolean
objective range, and `ϵ` is the smallest positive value of the generated
nonnegative penalty function. With the default scale `s = 1` and `β > 0`, any
infeasible assignment is penalized by more than the largest possible objective
improvement available within the compiled objective range. With custom scales,
the same sufficient exactness condition is `s * (U - L + β) > U - L`; smaller
scales can make the penalty a tuning heuristic rather than a certified exact
penalty.

The objective range is computed from interval bounds on the compiled PBF over
encoded target binary variables. For normal finite JuMP/MOI models this bound
is finite after encoding, but it may overestimate the exact source-objective
span when an encoding has redundant target states or feasibility relations such
as one-hot sums. That overestimate keeps the penalty sufficient, but it is not
always the tightest possible objective range.

When the objective range or positive penalty gap cannot be certified, ToQUBO
falls back for that coefficient to [`ToQUBO.Attributes.LegacyPenalty`](@ref):

```math
\rho = s \cdot \sigma \cdot \left(\frac{\delta}{\epsilon} + \beta\right)
```

where `δ` is the historical objective gap estimate from `PBO.maxgap`.
The selected policy, objective bounds, inferred penalties with their `ϵ`
sources, and any fallback reasons are exposed through
[`ToQUBO.Attributes.PenaltyPolicyMetadata`](@ref) and the `"penalty_policy"`
field in reformulation metadata.

The precedence is:

1. Explicit hints such as
   [`ToQUBO.Attributes.ConstraintEncodingPenaltyHint`](@ref) are used as-is.
2. Constraint overrides
   [`ToQUBO.Attributes.ConstraintPenaltyScale`](@ref) and
   [`ToQUBO.Attributes.ConstraintPenaltyOffset`](@ref) apply to the source
   constraint and to the slack-variable encoding penalty generated for that
   constraint.
3. Global [`ToQUBO.Attributes.PenaltyPolicy`](@ref),
   [`ToQUBO.Attributes.PenaltyScale`](@ref), and
   [`ToQUBO.Attributes.PenaltyOffset`](@ref) apply everywhere else.

The defaults are `PenaltyPolicy() == ObjectiveRangePenalty()`,
`PenaltyScale() == 1.0`, and `PenaltyOffset() == 1.0`. The coefficient is
positive for minimization models and negative for maximization models, so
explicit hints should use the same sign as the coefficient you want the
compiler to apply.

Use the controls according to how much of the model you want to change:

- Use [`ToQUBO.Attributes.PenaltyPolicy`](@ref) to select the automatic
  inference policy. Set it to [`ToQUBO.Attributes.LegacyPenalty`](@ref) only
  when you need to reproduce the historical maxgap-based coefficients.
- Use [`ToQUBO.Attributes.PenaltyScale`](@ref) and
  [`ToQUBO.Attributes.PenaltyOffset`](@ref) to change all automatically
  inferred penalties while preserving their policy-dependent objective and
  penalty-gap dependence.
- Use [`ToQUBO.Attributes.ConstraintPenaltyScale`](@ref) and
  [`ToQUBO.Attributes.ConstraintPenaltyOffset`](@ref) when one source
  constraint needs a different automatic penalty. These overrides also apply to
  the slack-variable encoding penalty generated for that constraint.
- Use explicit hints such as
  [`ToQUBO.Attributes.ConstraintEncodingPenaltyHint`](@ref),
  [`ToQUBO.Attributes.SlackVariableEncodingPenaltyHint`](@ref), or
  [`ToQUBO.Attributes.VariableEncodingPenaltyHint`](@ref) when you need a fixed
  coefficient. Hints bypass the automatic scale and offset settings.

!!! note "ToQUBO-specific settings"
    These attributes control the ToQUBO compiler, so the reference for setting,
    overriding, and retrieving penalty coefficients belongs in this manual.
    End-to-end ecosystem examples can live in the `QUBO.jl` documentation and
    link back here when they tune ToQUBO penalties.

### Changing Penalty Values

For feasibility tuning, start by inspecting
[`ToQUBO.Attributes.PenaltyPolicyMetadata`](@ref) and sweeping `PenaltyScale()`
while keeping explicit hints unset. If only one constraint needs adjustment,
override that constraint's automatic scale or offset. Pin exact penalty values
only when you have a known coefficient to apply.

Finite-run stochastic samplers such as `DWave.Neal` may need stronger penalties
than the default exact-penalty bound to return feasible samples at a useful
rate. In that case, prefer targeted
[`ToQUBO.Attributes.ConstraintPenaltyScale`](@ref) overrides for the source
constraints that are violated most often, instead of increasing the global
[`ToQUBO.Attributes.PenaltyScale`](@ref) or replacing automatic inference with
fixed hints everywhere. For example, if equality constraints `c2`, `c3`, and
`c4` need about a 400x larger automatic penalty under a sampler:

```julia
set_attribute.(c2, Ref(Attributes.ConstraintPenaltyScale()), 400.0)
set_attribute.(c3, Ref(Attributes.ConstraintPenaltyScale()), 400.0)
set_attribute.(c4, Ref(Attributes.ConstraintPenaltyScale()), 400.0)
```

This keeps the selected automatic policy and its metadata, while reshaping the
penalty landscape only around the constraints that need more sampler pressure.

```@example penalty-settings
using JuMP
using QUBODrivers
using ToQUBO
using ToQUBO: Attributes, Encoding

# Use an exact sampler for a small example. Replace it with your QUBO solver.
model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))
@variable(model, x[1:2], Bin)
@variable(model, 0 <= z <= 3, Int)
@objective(model, Min, 3x[1] + x[2] + z)

capacity = @constraint(model, x[1] + x[2] <= 1)
assignment = @constraint(model, x[1] + x[2] == 1)

# Model-wide automatic penalty tuning.
set_attribute(model, Attributes.PenaltyScale(), 2.0)
set_attribute(model, Attributes.PenaltyOffset(), 1.0)

# Automatic tuning for one source constraint and its slack encoding.
set_attribute(capacity, Attributes.ConstraintPenaltyScale(), 4.0)
set_attribute(capacity, Attributes.ConstraintPenaltyOffset(), 2.0)

# Fixed values for specific generated penalties.
set_attribute(assignment, Attributes.ConstraintEncodingPenaltyHint(), 12.0)
set_attribute(capacity, Attributes.SlackVariableEncodingMethod(), Encoding.OneHot())
set_attribute(capacity, Attributes.SlackVariableEncodingPenaltyHint(), 9.0)
set_attribute(z, Attributes.VariableEncodingMethod(), Encoding.OneHot())
set_attribute(z, Attributes.VariableEncodingPenaltyHint(), 6.0)

optimize!(model)

rho_capacity = get_attribute(capacity, Attributes.ConstraintEncodingPenalty())
rho_assignment = get_attribute(assignment, Attributes.ConstraintEncodingPenalty())
eta_capacity = get_attribute(capacity, Attributes.SlackVariableEncodingPenalty())
theta_z = get_attribute(z, Attributes.VariableEncodingPenalty())
policy_metadata = get_attribute(model, Attributes.PenaltyPolicyMetadata())

# The capacity penalty is inferred by the automatic policy.
@assert rho_capacity !== nothing
@assert rho_assignment == 12.0
@assert eta_capacity == 9.0
@assert theta_z == 6.0
@assert policy_metadata["policy"] == "ObjectiveRangePenalty"
```

Very small `ϵ` values or broad objective ranges can produce large penalties.
Inspect the policy metadata before overriding the policy or pinning explicit
penalties.

### Continuous Variable Resolution

Bounded continuous variables need a finite binary representation before the
compiler can build the QUBO. Set
[`ToQUBO.Attributes.VariableEncodingBits`](@ref) or
[`ToQUBO.Attributes.DefaultVariableEncodingBits`](@ref) to choose that bit
count explicitly. When the bit count is unset, ToQUBO derives it from the
variable bounds and [`ToQUBO.Attributes.VariableEncodingATol`](@ref), falling
back to [`ToQUBO.Attributes.DefaultVariableEncodingATol`](@ref).

The tolerance rule is described in the booklet's [Representation Error](@ref)
section. Smaller tolerances or wider bounds generally allocate more target
binary variables. Slack variables generated from constraints use the analogous
[`ToQUBO.Attributes.SlackVariableEncodingATol`](@ref) and
[`ToQUBO.Attributes.SlackVariableEncodingBits`](@ref) settings. See
[Constraint Reformulation](@ref) for how inequality constraints generate these
slacks and where their finite resolution enters the penalty.

### Constraint Penalty Methods

Equality constraints are encoded with
[`ToQUBO.Attributes.QuadraticPenalty`](@ref) by default. This normally squares
the residual and lets the compiler infer a penalty coefficient when
[`ToQUBO.Attributes.ConstraintEncodingPenaltyHint`](@ref) is not set. When the
parsed residual is provably nonnegative, the compiler can instead add the
residual directly to avoid unnecessary higher-order terms while preserving the
same minimizer at zero. The same automatic penalty inference applies to this
sign-definite shortcut.

Use [`ToQUBO.Attributes.LinearPenalty`](@ref) only when you want an equality
constraint encoded as its signed residual. Since this form can make infeasible
assignments cheaper when the sign or magnitude is wrong, automatic penalty
inference is disabled. Every equality constraint that uses `LinearPenalty()`
must also have an explicit
[`ToQUBO.Attributes.ConstraintEncodingPenaltyHint`](@ref).

The method is motivated by the linear Ising penalty approach of Mirkarimi et
al.[^Mirkarimi2024PRR], its quantum annealing demonstration,[^Mirkarimi2024NJP]
and the accompanying Durham data and code archive.[^Mirkarimi2024Data]
Those papers highlight the main tradeoff reflected in this API: linear
penalties can avoid the extra couplings introduced by quadratic penalties, but
they are heuristic and are not guaranteed to exactly enforce every constraint.

```julia
using JuMP
using ToQUBO
using ToQUBO: Attributes

model = Model(ToQUBO.Optimizer)
@variable(model, x[1:2], Bin)
@objective(model, Min, 0)
c = @constraint(model, x[1] + x[2] == 1)

set_attribute(model, Attributes.DefaultConstraintEncodingMethod(), Attributes.LinearPenalty())
set_attribute(c, Attributes.ConstraintEncodingPenaltyHint(), -2.0)
```

For mixed models, keep the default method as
[`ToQUBO.Attributes.QuadraticPenalty`](@ref) and set
[`ToQUBO.Attributes.ConstraintEncodingMethod`](@ref) only on the constraints
that should use the linear residual.

[^Mirkarimi2024PRR]:
    Puya Mirkarimi, Ishaan Shukla, David C. Hoyle, Ross Williams, and Nicholas
    Chancellor. **Quantum optimization with linear Ising penalty functions for
    customer data science**. _Physical Review Research_ 6, 043241 (2024).
    [{doi}](https://doi.org/10.1103/PhysRevResearch.6.043241)

[^Mirkarimi2024NJP]:
    Puya Mirkarimi, David C. Hoyle, Ross Williams, and Nicholas Chancellor.
    **Experimental demonstration of improved quantum optimization with linear
    Ising penalties**. _New Journal of Physics_ 26, 103005 (2024).
    [{doi}](https://doi.org/10.1088/1367-2630/ad7e4a)

[^Mirkarimi2024Data]:
    Puya Mirkarimi, Ishaan Shukla, David C. Hoyle, Ross Williams, and Nicholas
    Chancellor. **Quantum optimization with linear Ising penalty functions for
    customer data science [dataset]**. Durham University data and code archive
    (2024). [{doi}](https://doi.org/10.15128/r2fq977t82m)

```@docs
ToQUBO.Attributes.VariableEncodingBits
ToQUBO.Attributes.DefaultVariableEncodingBits
ToQUBO.Attributes.VariableEncodingATol
ToQUBO.Attributes.DefaultVariableEncodingATol
ToQUBO.Attributes.VariableEncodingMethod
ToQUBO.Attributes.DefaultVariableEncodingMethod
ToQUBO.Attributes.VariableEncodingPenaltyHint
ToQUBO.Attributes.VariableEncodingPenalty
ToQUBO.Attributes.SlackVariableEncodingMethod
ToQUBO.Attributes.SlackVariableEncodingATol
ToQUBO.Attributes.SlackVariableEncodingBits
ToQUBO.Attributes.SlackVariableEncodingPenaltyHint
ToQUBO.Attributes.SlackVariableEncodingPenalty
ToQUBO.Attributes.ObjectiveRangePenalty
ToQUBO.Attributes.LegacyPenalty
ToQUBO.Attributes.PenaltyPolicy
ToQUBO.Attributes.PenaltyPolicyMetadata
ToQUBO.Attributes.PenaltyOffset
ToQUBO.Attributes.PenaltyScale
ToQUBO.Attributes.ConstraintPenaltyOffset
ToQUBO.Attributes.ConstraintPenaltyScale
ToQUBO.Attributes.QuadraticPenalty
ToQUBO.Attributes.LinearPenalty
ToQUBO.Attributes.DefaultConstraintEncodingMethod
ToQUBO.Attributes.ConstraintEncodingMethod
ToQUBO.Attributes.ConstraintEncodingPenaltyHint
ToQUBO.Attributes.ConstraintEncodingPenalty
```

## Discretization

```@docs
ToQUBO.Attributes.Discretize
```
