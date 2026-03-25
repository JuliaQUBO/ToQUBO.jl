# Knapsack

The [Knapsack Problem](https://en.wikipedia.org/wiki/Knapsack_problem) is a classic combinatorial optimization problem that has been extensively studied in computer science and operations research.

!!! tip "Solving with Quantum Annealers"
    The knapsack problem is a common benchmark for QUBO-based solvers, including quantum annealers and physics-inspired heuristics. As an NP-hard problem, it is useful for comparing how different solvers behave as instances grow, although runtime and solution quality remain strongly instance-dependent.

We start with some instances of the discrete Knapsack Problem whose standard formulation is

```math
\begin{array}{r l}
    \max        & \mathbf{c}\, \mathbf{x} \\
    \text{s.t.} & \mathbf{w}\, \mathbf{x} \le C \\
    ~           & \mathbf{x} \in \mathbb{B}^{n}
\end{array}
```

First, consider the following items

| Item (``i``) | Value (``c_{i}``) | Weight (``w_{i}``) |
|:------------:|:-----------------:|:------------------:|
|       1      |         1         |       0.3          |
|       2      |         2         |       0.5          |
|       3      |         3         |       1.0          |

to be carried in a knapsack with capacity ``C = 1.6``.

Writing down the data above as a linear program, we have

```math
\begin{array}{r l}
    \max        & x_{1} + 2 x_{2} + 3 x_{3} \\
    \text{s.t.} & 0.3 x_{1} + 0.5 x_{2} + x_{3} \le 1.6 \\
    ~           & \mathbf{x} \in \mathbb{B}^{3}
\end{array}
```

## Simple JuMP Model

Writing this in [JuMP](https://github.com/jump-dev/JuMP.jl) we end up with

```@example knapsack
using JuMP
using ToQUBO
using PySA

model = Model(() -> ToQUBO.Optimizer(PySA.Optimizer))

@variable(model, x[1:3], Bin)
@objective(model, Max, x[1] + 2 * x[2] + 3 * x[3])
@constraint(model, 0.3 * x[1] + 0.5 * x[2] + x[3] ≤ 1.6)

optimize!(model)

solution_summary(model)
```

The final decision is to take items ``2`` and ``3``, i.e., ``x_{1} = 0, x_{2} = 1, x_{3} = 1``.

```@example knapsack
value.(x)
```

## Using DataFrames

Now, lets fill a few more knapsacks.
First, we generate uniform random costs ``\mathbf{c}`` and weights ``\mathbf{w}`` then set the knapsack's capacity ``C`` to be a fraction of the total available weight i.e. ``80\%``.

This example was inspired by [D-Wave's knapsack example repository](https://github.com/dwave-examples/knapsack).

```@setup knapsack
using PySA

PySA.np.random.seed(0)
```

```@setup knapsack
using CSV
using DataFrames
using Random

# Generate Data
rng = MersenneTwister(1)

df = DataFrame(
   :cost   => rand(rng, 1:100, 8),
   :weight => rand(rng, 1:100, 8),
)

CSV.write("knapsack.csv", df)
```

```@example knapsack
using CSV
using DataFrames

df = CSV.read("knapsack.csv", DataFrame)
```

```@example knapsack
using JuMP
using ToQUBO
using PySA

model = Model(() -> ToQUBO.Optimizer(PySA.Optimizer))

n = size(df, 1)
c = collect(Float64, df[!, :cost])
w = collect(Float64, df[!, :weight])
C = round(0.8 * sum(w))

@variable(model, x[1:n], Bin)
@objective(model, Max, c' * x)
@constraint(model, w' * x <= C)

optimize!(model)

# Add Results as a new column
df[:,:select] = map(xi -> ifelse(xi > 0, "✅", "❌"), value.(x))

df
```

## Checking Capacity

```@example knapsack
println("Total weight : $(w' * value.(x)) / $(C)")
```
