
# -*- Definitions -*-
x = Dict{VI, Int}(
    VI(1) => 1,
    VI(2) => 2,
)

Q = Dict{Tuple{Int, Int}, Float64}(
    (1, 1) => 2.0,
    (2, 2) => 2.0,
    (1, 2) => -5.0
)

c = 1.0

# -*- Simulated Annealing -*-
annealer = SimulatedAnnealer{VI, Float64}(x, Q, c)

@test !MOI.is_empty(annealer)

MOI.optimize!(annealer)

@test MOI.get(annealer, MOI.VariablePrimal(1), VI(1)) == MOI.get(annealer, MOI.VariablePrimal(1), VI(2)) == 1

@test MOI.get(annealer, MOI.ObjectiveValue()) ≈ 0.0