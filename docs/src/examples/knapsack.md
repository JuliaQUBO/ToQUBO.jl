## Knapsack
We start with some instances of the discrete [Knapsack Problem](https://en.wikipedia.org/wiki/Knapsack_problem) whose standard formulation is
```math
\begin{array}{r l}
    \max        & \mathbf{c}\, \mathbf{x} \\
    \text{s.t.} & \mathbf{w}\, \mathbf{x} \le C \\
    ~           & \mathbf{x} \in \mathbb{B}^{n}
\end{array}
```

### MathOptInterface
Using [MOI](https://github.com/jump-dev/MathOptInterface.jl) directly to build a simple model is pretty straightforward. All that one has to do is to use `MOI.instantiate` and define the model as usual.

```@example moi-knapsack
import MathOptInterface as MOI
const MOIU = MOI.Utilities

using ToQUBO
using DWave # <- Your favourite Annealer / Sampler / Solver here

# Example from https://jump.dev/MathOptInterface.jl/stable/tutorials/example/

# Virtual QUBO Model
model = MOI.instantiate(
   () -> ToQUBO.Optimizer(DWave.Neal.Optimizer),
   with_bridge_type = Float64,
)

n = 3;
c = [1.0, 2.0, 3.0]
w = [0.3, 0.5, 1.0]
C = 3.2;

x = MOI.add_variables(model, n);

for xᵢ in x
   MOI.add_constraint(model, xᵢ, MOI.ZeroOne())
end

MOI.set(model, MOI.ObjectiveSense(), MOI.MAX_SENSE)

MOI.set(
   model,
   MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
   MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.(c, x), 0.0),
);

MOI.add_constraint(
   model,
   MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.(w, x), 0.0),
   MOI.LessThan(C),
);

MOI.optimize!(model)

# Collect Solution
MOI.get.(model, MOI.VariablePrimal(), x)
```

### JuMP + D-Wave Examples
We may now fill a few more knapsacks using [JuMP](https://github.com/jump-dev/JuMP.jl). We will generate uniform random costs ``\mathbf{c}`` and weights ``\mathbf{w}`` then set the knapsack's capacity ``C`` to be a fraction of the total available weight i.e. ``80\%``.

This example was inspired by [D-Wave's knapsack example repository](https://github.com/dwave-examples/knapsack).

```@setup
using CSV
using DataFrames
using Random

# Generate Data
rng = MersenneTwister(1)

df = DataFrame(
   :cost   => rand(rng, 1:100, 16),
   :weight => rand(rng, 1:100, 16),
)

CSV.write("knapsack.csv", df)
```

```@example dwave-knapsack
using CSV
using DataFrames

df = CSV.read("knapsack.csv", DataFrame)
```

```@example dwave-knapsack
using JuMP
using ToQUBO
using DWave # <- Your favourite Annealer/Sampler/Solver here

model = Model(() -> ToQUBO.Optimizer(DWave.Neal.Optimizer))

n = size(df, 1)
c = collect(Float64, df[!, :cost])
w = collect(Float64, df[!, :weight])
C = round(0.8 * sum(w))

@variable(model, x[1:n], Bin)
@objective(model, Max, c' * x)
@constraint(model, w' * x <= C)

optimize!(model)

# Add Results as a new column
insertcols!(df, 3, :select => map((ξ) -> (ξ > 0.0) ? "Yes" : "No", value.(x)))
```