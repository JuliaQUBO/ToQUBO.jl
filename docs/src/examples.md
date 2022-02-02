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

# References:
# [1] https://jump.dev/MathOptInterface.jl/stable/tutorials/example/

# Generic Model
model = MOIU.Model{Float64}()

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
```

*Donec pretium finibus est, nec ultricies lectus placerat in. Aliquam efficitur quam eget consequat feugiat. Fusce tempus risus in cursus consectetur.*

```@example moi-knapsack; continued=true
using ToQUBO

# Instantiate optimizer (annealer)
optimizer = SimulatedAnnealer{MOI.VariableIndex, Float64}()

# Attach optimizer to model
qubo_model = toqubo(model, optimizer; tol=0.01)

# Run Annealing
MOI.optimize!(qubo_model)
```

*Fusce elit urna, fermentum ac mauris vitae, hendrerit euismod nunc. Praesent gravida urna libero.*

```@example moi-knapsack
# Annealing Status
println(qubo_model)
```

### Extra: D-Wave Examples

*Nulla ligula dui, maximus ut aliquam eu, consectetur at tellus. In hac habitasse platea dictumst. Praesent tempor porta risus. Curabitur eget vulputate est, eget ultrices libero.*

```@setup dwave-knapsack
import MathOptInterface as MOI
const MOIU = MOI.Utilities
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
model = MOIU.Model{Float64}()

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
optimizer = SimulatedAnnealer{MOI.VariableIndex, Float64}()
qubo_model = toqubo(model, optimizer; tol=0.01)

MOI.optimize!(qubo_model)

println(qubo_model)
```

## Graph Coloring

*Phasellus eget mauris eu libero euismod pulvinar sollicitudin vel urna. Donec elit justo, viverra id lectus nec, faucibus vehicula justo. Nunc tincidunt magna at diam faucibus, non consequat ante finibus.*

### Standard Formulation
```math
\begin{array}{r l}
    \min        & \displaystyle \sum_{j = 1}^{n} \mathbf{c}_j \\
    \text{s.t.} & \displaystyle \sum_{i = 1}^{n} \mathbf{x}_{i, k} - n\, \mathbf{c}_k \le 0  ~~ \forall k \\
    ~           & \displaystyle \mathbf{A}_{i, j} \left({\mathbf{x}_{i, k} + \mathbf{x}_{j, k}}\right) \le 1 ~~ \forall i < j, k \\
    ~           & \displaystyle \sum_{k = 1}^{n} \mathbf{x}_{i, k} = 1 ~~ \forall i \\
    ~           & \displaystyle \mathbf{A}, \mathbf{x} \in \mathbb{B}^{n \times n}\\
    ~           & \displaystyle \mathbf{c} \in \mathbb{B}^{n}
\end{array}
```