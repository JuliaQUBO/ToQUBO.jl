# Knapsack

We start with some instances of the discrete [Knapsack Problem](https://en.wikipedia.org/wiki/Knapsack_problem) whose standard formulation is

```math
\begin{array}{r l}
    \max        & \mathbf{c}\, \mathbf{x} \\
    \text{s.t.} & \mathbf{w}\, \mathbf{x} \le C \\
    ~           & \mathbf{x} \in \mathbb{B}^{n}
\end{array}
```

Now, lets fill a few knapsacks using [JuMP](https://github.com/jump-dev/JuMP.jl).
We will generate uniform random costs ``\mathbf{c}`` and weights ``\mathbf{w}`` then set the knapsack's capacity ``C`` to be a fraction of the total available weight i.e. ``80\%``.

This example was inspired by [D-Wave's knapsack example repository](https://github.com/dwave-examples/knapsack).

```@setup dwave-knapsack
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
using DWave

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
df[:,:select] = map((xi) -> (xi > 0.0) ? "✅" : "❌", value.(x))

df
```
