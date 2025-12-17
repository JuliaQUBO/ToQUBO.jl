# Gathering Results

After running `optimize!(model)`, you can retrieve various information about the solutions and the solving process.

## Solution Status

### Termination Status

The termination status indicates how the optimization process ended:

```julia
status = termination_status(model)
```

Common termination statuses include:
- `OPTIMAL`: The solver found an optimal solution
- `LOCALLY_SOLVED`: A locally optimal solution was found
- `TIME_LIMIT`: The solver stopped due to time limit
- `ITERATION_LIMIT`: The solver stopped due to iteration limit

### Primal Status

The primal status indicates the quality of the primal solution:

```julia
pstatus = primal_status(model)
```

A status of `FEASIBLE_POINT` indicates that a valid solution was found.

### Solution Summary

For a quick overview of the optimization result:

```julia
solution_summary(model)
```

## Retrieving Variable Values

### Single Solution

Get the value of a single variable:

```julia
x_value = value(x)
```

Get values of an array of variables:

```julia
x_values = value.(x)
```

### Multiple Solutions

Many QUBO solvers, especially quantum annealers and samplers, return multiple solutions. Access them using the `result` keyword:

```julia
# Number of solutions found
n_solutions = result_count(model)

# Access the i-th solution
for i in 1:n_solutions
    xi = value.(x, result = i)
    println("Solution $i: $xi")
end
```

!!! tip "Best Solution"
    By default (without specifying `result`), `value` returns the best solution found.

## Objective Value

### Single Solution

Get the objective value of the best solution:

```julia
obj = objective_value(model)
```

### Multiple Solutions

Get the objective value for a specific solution:

```julia
obj_i = objective_value(model, result = i)
```

## Compilation Information

ToQUBO.jl provides attributes to inspect the compilation process:

### Compilation Time

Get the time spent converting your model to QUBO form:

```julia
using ToQUBO: Attributes

comp_time = MOI.get(model, Attributes.CompilationTime())
```

### Compilation Status

Check the status of the compilation:

```julia
comp_status = MOI.get(model, Attributes.CompilationStatus())
```

### Source and Target Models

Access the intermediate models created during compilation:

```julia
# Original model (with MOI bridges applied)
source = MOI.get(model, Attributes.SourceModel())

# QUBO formulation
target = MOI.get(model, Attributes.TargetModel())
```

## Penalty Information

Constraints are converted to penalty terms in QUBO. You can retrieve the penalty coefficients used:

### Constraint Penalties

```julia
# Get the penalty used for a specific constraint
rho = MOI.get(model, Attributes.ConstraintEncodingPenalty(), constraint_ref)
```

### Variable Encoding Penalties

For encoded variables:

```julia
# Get the penalty used for variable encoding
theta = MOI.get(model, Attributes.VariableEncodingPenalty(), variable_ref)
```

## Example: Complete Results Retrieval

```@example results-retrieval
using JuMP
using ToQUBO
using QUBODrivers  # Provides ExactSampler and other solvers

# Create and solve a model
model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

@variable(model, x[1:3], Bin)
@constraint(model, c1, x[1] + x[2] <= 1)
@objective(model, Max, x[1] + 2*x[2] + 3*x[3])

optimize!(model)

# Check status
println("Termination: ", termination_status(model))
println("Primal: ", primal_status(model))

# Get best solution
if primal_status(model) == FEASIBLE_POINT
    println("Best solution: ", value.(x))
    println("Best objective: ", objective_value(model))
end

# Iterate over all solutions
println("\nAll solutions:")
for i in 1:result_count(model)
    println("  Solution $i: x = $(value.(x, result = i)), obj = $(objective_value(model, result = i))")
end
```

## Working with QUBOTools

ToQUBO.jl integrates with [QUBOTools.jl](https://github.com/JuliaQUBO/QUBOTools.jl) for advanced QUBO manipulation. You can extract the underlying QUBO model:

```julia
using QUBOTools

# Get the QUBO backend
qubo_model = QUBOTools.backend(model)
```

This allows you to:
- Export the QUBO to various file formats
- Analyze the QUBO structure
- Use additional QUBOTools functionality

## Next Steps

- Learn about [Compiler Settings](@ref) to customize the reformulation
- Explore the [Knapsack](@ref), [Prime Factorization](@ref), or [Portfolio Optimization](@ref) examples for practical applications
