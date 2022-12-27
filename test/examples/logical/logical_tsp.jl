function test_logical_tsp()
    @testset "TSP: 16 variables" begin
        # ~*~ Problem Data ~*~ #
        n = 4
        D = [
             0 10 10 10
            10  0 10 10
            10 10  0 10
            10 10 10  0
        ]

        # Penalty Choice
        ρ̄ = -16

        # ~*~ Solution Data ~*~ #
        Q̄ = [
             15 -28 -28 -32
              0  15 -28 -32
              0   0  15 -32
              0   0   0  16
        ]

        ᾱ = 1
        β̄ = -16

        x̄ = Set{Vector{Int}}([[0, 0, 0]])
        ȳ = 0

        # ~*~ Model ~*~ #
        model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

        @variable(model, x[1:n, 1:n], Bin, Symmetric)
        @objective(model, Min, sum(D[i, j] * x[i, k] * x[j, (k % n) + 1] for i = 1:n, j = 1:n, k = 1:n))
        @constraint(model, ci[i = 1:n], sum(x[i, :]) == 1)
        @constraint(model, ck[k = 1:n], sum(x[:, k]) == 1)

        optimize!(model)

        # :: Reformulation ::
        qubo_model = unsafe_backend(model)

        ρi      = MOI.get.(qubo_model, ToQUBO.Penalty(), collect(map(i->i.index, ci)))
        ρk      = MOI.get.(qubo_model, ToQUBO.Penalty(), collect(map(i->i.index, ck)))
        ρ       = [ρi; ρk]
        Q, α, β = ToQUBO.qubo(qubo_model, Matrix)

        @show ρ # ≈ ρ̄
        @show α # ≈ ᾱ
        @show β # ≈ β̄
        @show Q # ≈ Q̄

        # :: Solutions ::
        x̂ = trunc.(Int, value.(x))
        ŷ = objective_value(model)

        @show x̂ # ∈ x̄
        @show ŷ # ≈ ȳ
    end
end