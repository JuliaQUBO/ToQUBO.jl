# Examples

## Knapsack

*Quisque auctor, quam non dignissim luctus, ipsum nisl cursus enim, id eleifend ipsum risus dapibus velit. Nunc dignissim aliquet lorem, ut fermentum diam. Sed nec lectus odio. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Nulla ultrices ut felis a pulvinar.*

### Standard Formulation
```math
\begin{array}{r l}
    \max        & \mathbf{c}\, \mathbf{x} \\
    \text{s.t.} & \mathbf{w}\, \mathbf{x} \le C \\
    ~           & \mathbf{x} \in \mathbb{B}^{n}
\end{array}
```

### MathOptInterface

*Maecenas fermentum venenatis laoreet. Sed iaculis, risus ac scelerisque consectetur, orci metus dapibus magna, sed tincidunt dolor sapien sed tortor.*

```@example moi-knapsack
import MathOptInterface as MOI
const MOIU = MOI.Utilities

using ToQUBO
using Anneal # Your favourite Annealer / Sampler / Solver

# References:
# [1] https://jump.dev/MathOptInterface.jl/stable/tutorials/example/

# Generic Model
model = MOI.instantiate(
   () -> ToQUBO.Optimizer(Anneal.Optimizer),
   with_bridge_type = Float64,
)

n = 3;
c = [1.0, 2.0, 3.0]
w = [0.3, 0.5, 1.0]
C = 3.2;

# -*- Variables -*- #
x = MOI.add_variables(model, n);

# -*- Objective -*- #
MOI.set(model, MOI.ObjectiveSense(), MOI.MAX_SENSE)

MOI.set(
   model,
   MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
   MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.(c, x), 0.0),
);

# -*- Constraints -*- #
MOI.add_constraint(
   model,
   MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.(w, x), 0.0),
   MOI.LessThan(C),
);

for xᵢ in x
   MOI.add_constraint(model, xᵢ, MOI.ZeroOne())
end

# Run Annealing
MOI.optimize!(model)

println(model)
```

<!-- ### Extra: D-Wave Examples

*Nulla ligula dui, maximus ut aliquam eu, consectetur at tellus. In hac habitasse platea dictumst. Praesent tempor porta risus. Curabitur eget vulputate est, eget ultrices libero.*

```@setup dwave-knapsack
import MathOptInterface as MOI
const MOIU = MOI.Utilities

using Anneal
using ToQUBO
```

```@example dwave-knapsack
import CSV
import DataFrames

# -*- Data -*-
df = CSV.read(
    "./knapsack/data/small.csv",
    DataFrames.DataFrame;
    header=[:cost, :weight]
)
```

*Donec quis sollicitudin ex. Pellentesque luctus dolor sit amet lacinia lacinia.*

```@example dwave-knapsack; continued=true
# -*- Model -*-
model = MOI.instantiate(
   ()->ToQUBO.Optimizer(SimulatedAnnealer.Optimizer),
   with_bridge_type = Float64,
)

n = size(df, 1)
c = collect(Float64, df[!, :cost])
w = collect(Float64, df[!, :weight])
C = round(0.8 * sum(w))

# -*- Variables -*- #
x = MOI.add_variables(model, n);

# -*- Objective -*- #
MOI.set(model, MOI.ObjectiveSense(), MOI.MAX_SENSE)

MOI.set(
   model,
   MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
   MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.(c, x), 0.0),
);

# -*- Constraints -*- #
MOI.add_constraint(
   model,
   MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.(w, x), 0.0),
   MOI.LessThan(C),
);

for xᵢ in x
   MOI.add_constraint(model, xᵢ, MOI.ZeroOne())
end
```

*Sed lorem dolor, mollis non vulputate ut, dignissim vitae enim. Curabitur egestas, elit a gravida gravida, enim magna consectetur massa, eget condimentum mi libero sed neque.*

```@example dwave-knapsack
MOI.optimize!(model)

println(MOI.get.(model, MOI.VariablePrimal()))
``` -->