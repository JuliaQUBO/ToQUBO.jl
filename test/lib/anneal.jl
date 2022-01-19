
# -*- Definitions -*-
Q = Dict{Tuple{Int, Int}, Float64}(
    (1, 1) => 2.0,
    (2, 2) => 2.0,
    (1, 2) => -5.0
)

c = 1.0

annealer = SimulatedAnnealer{Float64}(Q, c)

# -*- Arithmetic: (+) -*-
@test !MOI.is_empty(annealer)

MOI.optimize!(annealer)

@test MOI.get(annealer, MOI.VariablePrimal(1), 1) == MOI.get(annealer, MOI.VariablePrimal(1), 2) == 1

@test MOI.get(annealer, MOI.ObjectiveValue()) ≈ 0.0