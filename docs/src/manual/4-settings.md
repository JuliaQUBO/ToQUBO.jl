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

### Penalty Heuristic

When a constraint, variable encoding, or slack-variable encoding needs a penalty
coefficient and no explicit hint is set, ToQUBO uses the automatic heuristic

```math
\rho = s \cdot \sigma \cdot \left(\frac{\delta}{\epsilon} + \beta\right)
```

where `s` is [`ToQUBO.Attributes.PenaltyScale`](@ref), `β` is
[`ToQUBO.Attributes.PenaltyOffset`](@ref), `σ` is `1` for minimization models
and `-1` for maximization models, `δ` is the objective gap estimate, and `ϵ` is
the smallest positive gap in the generated penalty function.

The precedence is:

1. Explicit hints such as
   [`ToQUBO.Attributes.ConstraintEncodingPenaltyHint`](@ref) are used as-is.
2. Constraint overrides
   [`ToQUBO.Attributes.ConstraintPenaltyScale`](@ref) and
   [`ToQUBO.Attributes.ConstraintPenaltyOffset`](@ref) apply to the source
   constraint and to the slack-variable encoding penalty generated for that
   constraint.
3. Global [`ToQUBO.Attributes.PenaltyScale`](@ref) and
   [`ToQUBO.Attributes.PenaltyOffset`](@ref) apply everywhere else.

The defaults are `PenaltyScale() == 1.0` and `PenaltyOffset() == 1.0`, matching
the previous heuristic. The coefficient is positive for minimization models and
negative for maximization models, so explicit hints should use the same sign as
the coefficient you want the compiler to apply.

Use the controls according to how much of the model you want to change:

- Use [`ToQUBO.Attributes.PenaltyScale`](@ref) and
  [`ToQUBO.Attributes.PenaltyOffset`](@ref) to change all automatically
  inferred penalties while preserving their relative dependence on the
  generated objective and penalty gaps.
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

For feasibility tuning, start by sweeping `PenaltyScale()` while keeping
explicit hints unset. If only one constraint needs adjustment, override that
constraint's automatic scale or offset. Pin exact penalty values only when you
have a known coefficient to apply.

```julia
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
```

Very small `ϵ` values can produce large penalties. That usually means the
penalty function has nearly tied infeasible states, so treat the heuristic as a
starting point and compare feasibility across several scales.

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
