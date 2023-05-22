function test_linear1()
    @testset "3 variables, 1 constraint" begin
        # Problem Data
        n = 3
        a = [0.3, 0.5, 1.0]
        b = 1.6
        c = [1.0, 2.0, 3.0]

        # Penalty Choice
        ρ̄ = -7

        # Solution Data
        Q̄ = [
            610 -210 -420  -42  -84 -168  -336  -42
              0  947 -700  -70 -140 -280  -560  -70
              0    0 1543 -140 -280 -560 -1120 -140
              0    0    0  217  -28  -56  -112  -14
              0    0    0    0  420 -112  -224  -28
              0    0    0    0    0  784  -448  -56
              0    0    0    0    0    0  1344 -112
              0    0    0    0    0    0     0  217
        ]

        ᾱ = 1
        β̄ = -1792

        x̄ = Set{Vector{Int}}([[0, 1, 1]])
        ȳ = 5

        # Model
        model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

        @variable(model, x[1:n], Bin)
        @objective(model, Max, c'x)
        @constraint(model, c1, a'x <= b)

        optimize!(model)

        # Reformulation
        ρ       = MOI.get(model, Attributes.ConstraintEncodingPenalty(), c1)
        Q, α, β = ToQUBO.qubo(model, Matrix)

        @test ρ ≈ ρ̄
        @test α ≈ ᾱ
        @test β ≈ β̄
        @test Q ≈ Q̄

        # Solutions
        x̂ = trunc.(Int, value.(x))
        ŷ = objective_value(model)

        @test x̂ ∈ x̄
        @test ŷ ≈ ȳ

        return nothing
    end
end
