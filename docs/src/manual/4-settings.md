# Compiler Settings

```@docs
ToQUBO.Attributes.StableCompilation
```

## Compiler Messages

```@docs
ToQUBO.Attributes.Warnings
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

### Constraint Penalty Methods

Equality constraints are encoded with
[`ToQUBO.Attributes.QuadraticPenalty`](@ref) by default. This squares the
residual and lets the compiler infer a penalty coefficient when
[`ToQUBO.Attributes.ConstraintEncodingPenaltyHint`](@ref) is not set.

Use [`ToQUBO.Attributes.LinearPenalty`](@ref) only when you want an equality
constraint encoded as its signed residual. Since this form can make infeasible
assignments cheaper when the sign or magnitude is wrong, automatic penalty
inference is disabled. Every equality constraint that uses `LinearPenalty()`
must also have an explicit
[`ToQUBO.Attributes.ConstraintEncodingPenaltyHint`](@ref).

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

```@docs
ToQUBO.Attributes.VariableEncodingBits
ToQUBO.Attributes.DefaultVariableEncodingBits
ToQUBO.Attributes.VariableEncodingATol
ToQUBO.Attributes.DefaultVariableEncodingATol
ToQUBO.Attributes.VariableEncodingMethod
ToQUBO.Attributes.DefaultVariableEncodingMethod
ToQUBO.Attributes.VariableEncodingPenalty
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
