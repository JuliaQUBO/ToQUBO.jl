# Examples

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
using Anneal # <- Your favourite Annealer / Sampler / Solver here

# Example from https://jump.dev/MathOptInterface.jl/stable/tutorials/example/

# Virtual QUBO Model
model = MOI.instantiate(
   () -> ToQUBO.Optimizer(SimulatedAnnealer.Optimizer),
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

# Run!
MOI.optimize!(model)

# Collect Solution
MOI.get(model, MOI.VariablePrimal(), x)
```

### JuMP + D-Wave Examples
We may now fill a few more knapsacks with [JuMP](https://github.com/jump-dev/JuMP.jl), using data from [D-Wave's Knapsack Example repo](https://github.com/dwave-examples/knapsack).

```@example dwave-knapsack
import CSV
import DataFrames

# git clone https://github.com/dwave-examples/knapsack
const DATA_PATH = joinpath("examples", "knapsack", "data")

# -> Load Data <-
df = CSV.read(
    joinpath(DATA_PATH, "small.csv"), 
    DataFrames.DataFrame;
    header=[:cost, :weight],
)
# Also available: "very_small.csv", "large.csv", "very_large.csv" and "huge.csv".
```

```@example dwave-knapsack
using JuMP
using ToQUBO
using Anneal # <- Your favourite Annealer / Sampler / Solver here

# -> Model <-
model = Model(() -> ToQUBO.Optimizer(SimulatedAnnealer.Optimizer))

n = size(df, 1)
c = collect(Float64, df[!, :cost])
w = collect(Float64, df[!, :weight])
C = round(0.8 * sum(w))

# -> Variables <-
@variable(model, x[i=1:n], Bin)

# -> Objective <-
@objective(model, Max, c' * x)

# -> Constraint <-
@constraint(model, w' * x <= C)

# ->-> Run! ->->
optimize!(model)

# Add Results as a new column
DataFrames.insertcols!(
   df,
   3, 
   :select => map(
      (ξ) -> (ξ > 0.0) ? "Yes" : "No",
      value.(x),
   ),
)
```