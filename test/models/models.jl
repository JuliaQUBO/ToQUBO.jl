# -*- Knapsack Problem -*-
include("./knapsack.jl")

qubo_model = toqubo(Knapsack.model)

println(qubo_model)
println(qubo_model.qubo_model)

@test true