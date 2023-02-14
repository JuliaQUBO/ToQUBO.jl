# Manual

## Quick Start Guide
```@example quick-start
using JuMP
using ToQUBO
using DWaveNeal # <- Your favourite Annealer/Sampler/Solver here

model = Model(() -> ToQUBO.Optimizer(DWaveNeal.Optimizer))

@variable(model, x[1:3], Bin)

@objective(model, Max, 1.0 * x[1] + 2.0 * x[2] + 3.0 * x[3])

@constraint(model, 0.3 * x[1] + 0.5 * x[2] + 1.0 * x[3] <= 1.6)

optimize!(model)

solution_summary(model)
```

## Compiler Flags

### Architecture
```@docs
ToQUBO.Attributes.Architecture
```

### Quadratization
```@docs
ToQUBO.Attributes.Quadratize
ToQUBO.Attributes.QuadratizationMethod
ToQUBO.Attributes.StableQuadratization
```

### Variable & Constraint Encoding
```@docs
ToQUBO.Attributes.VariableEncodingMethod
ToQUBO.Attributes.VariableEncodingPenalty
ToQUBO.Attributes.ConstraintEncodingPenalty
```