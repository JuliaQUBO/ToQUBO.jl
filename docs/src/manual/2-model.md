# Running a Model

This section describes how to create, configure, and run optimization models using ToQUBO.jl.

## Creating a Model

To use ToQUBO.jl, you need to create a JuMP model with the `ToQUBO.Optimizer` as the optimizer. The `ToQUBO.Optimizer` wraps an underlying QUBO solver that will actually solve the reformulated problem.

```julia
using JuMP
using ToQUBO
using QUBODrivers  # Provides QUBO solver interfaces

# Create a model with a QUBO solver (e.g., ExactSampler for small problems)
model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))
```

!!! note "Choosing a QUBO Solver"
    The inner optimizer must be a QUBO-compatible solver. Common choices include:
    - `ExactSampler.Optimizer` from [QUBODrivers.jl](https://github.com/JuliaQUBO/QUBODrivers.jl) for exact solutions on small problems
    - Quantum annealing backends like D-Wave
    - Simulated annealing solvers
    
    Replace the solver with your preferred QUBO backend.

The `ToQUBO.Optimizer` acts as a bridge between your JuMP model and QUBO solvers. It automatically translates your problem into QUBO form and passes it to the underlying solver.

## Defining Variables

ToQUBO.jl supports various variable types that are automatically encoded into binary variables:

### Binary Variables

Binary variables are natively supported since QUBO problems are defined over binary variables.

```julia
@variable(model, x, Bin)
@variable(model, y[1:n], Bin)
```

### Integer Variables

Integer variables within a bounded interval are encoded using binary expansions.

```julia
@variable(model, 0 <= z <= 10, Int)
```

### Continuous Variables

Continuous variables within a bounded interval are discretized and encoded.

```julia
@variable(model, 0.0 <= w <= 1.0)
```

!!! tip "Variable Bounds"
    All non-binary variables must have finite bounds for ToQUBO.jl to encode them properly.

## Defining Constraints

ToQUBO.jl supports linear and quadratic constraints, which are reformulated as penalty terms in the QUBO objective function.

### Linear Constraints

```julia
# Less than or equal
@constraint(model, 2*x[1] + 3*x[2] <= 5)

# Equal to
@constraint(model, x[1] + x[2] == 1)

# Greater than or equal (automatically converted)
@constraint(model, x[1] + x[2] >= 1)
```

### Quadratic Constraints

```julia
@constraint(model, x[1] * x[2] + x[3] <= 1)
```

## Defining the Objective Function

The objective function can be linear or quadratic. ToQUBO.jl supports both minimization and maximization.

```julia
# Linear objective
@objective(model, Max, 2*x[1] + 3*x[2] + 4*x[3])

# Quadratic objective
@objective(model, Min, x[1]*x[2] + x[2]*x[3] + x[1])
```

## Running the Optimization

Once your model is defined, call `optimize!` to solve it:

```julia
optimize!(model)
```

This function performs the following steps:
1. **Compilation**: ToQUBO.jl translates your JuMP model into QUBO form
2. **Solving**: The underlying QUBO solver finds solutions
3. **Translation**: Results are mapped back to your original variables

## Checking Solution Status

After optimization, check the termination status and primal status to verify the solve succeeded:

```julia
# Check if the solver found a solution
termination_status(model)

# Check the status of the primal solution
primal_status(model)

# Get a human-readable summary
solution_summary(model)
```

## Working with Multiple Solutions

Many QUBO solvers return multiple solutions. You can iterate over them:

```julia
# Get the number of solutions found
num_solutions = result_count(model)

# Access specific solutions
for i in 1:num_solutions
    xi = value.(x, result = i)
    obj = objective_value(model, result = i)
    println("Solution $i: x = $xi, objective = $obj")
end
```

## Example: Complete Workflow

Here's a complete example demonstrating the typical workflow:

```@example model-workflow
using JuMP
using ToQUBO
using QUBODrivers  # Provides ExactSampler and other solvers

# 1. Create model with a QUBO solver
model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

# 2. Define binary variables
@variable(model, x[1:3], Bin)

# 3. Define constraints
@constraint(model, x[1] + x[2] + x[3] <= 2)

# 4. Define objective
@objective(model, Max, x[1] + 2*x[2] + 3*x[3])

# 5. Solve
optimize!(model)

# 6. Check status and retrieve results
if termination_status(model) == OPTIMAL
    println("Optimal solution found!")
    println("x = ", value.(x))
    println("Objective = ", objective_value(model))
end
```

## Next Steps

- Learn about [Gathering Results](@ref) to extract solution data
- Explore [Compiler Settings](@ref) to fine-tune the reformulation process