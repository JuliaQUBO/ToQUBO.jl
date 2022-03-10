# Manual

## Quick Start Guide

```@example quick-start
using JuMP
using ToQUBO
using Anneal

model = Model(() -> ToQUBO.Optimizer(SimulatedAnnealer.Optimizer))

@variable(model, x[1:3], Bin)
@objective(model, Max, 1.0 * x[1] + 2.0 * x[2] + 3.0 * x[3])
@constraint(model, 0.3 * x[1] + 0.5 * x[2] + 1.0 * x[3] <= 3.2)

optimize!(model)

solution_summary(model)
```