# -*- Knapsack Problem -*-
include("./knapsack.jl")

annealer = SimulatedAnnealer{VI, Float64}()
model = toqubo(Knapsack.model, annealer; tol=0.01)

MOI.optimize!(model)

variables = MOI.get(model, MOI.ListOfVariableIndices())

@test MOI.get(model, MOI.PrimalStatus()) === MOI.FEASIBLE_POINT

@test MOI.get(model, MOI.ObjectiveValue()) ≈ Knapsack.objective_value

@test [MOI.get(model, MOI.VariablePrimal(), vᵢ) for vᵢ ∈ variables] ≈ Knapsack.solution