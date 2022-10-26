function test_linear1()
    @testset "3 variables, 1 constraint" begin
        # ~*~ Problem Data ~*~ #
        n = 3
        a = [0.3, 0.5, 1.0]
        b = 1.6
        c = [1.0, 2.0, 3.0]

        # Penalty Choice
        ρ̄ = -7

        # ~*~ Solution Data ~*~ #
        Q̄ = [
             610 -105 -210 -21  -42  -84 -168 -21
            -105  947 -350 -35  -70 -140 -280 -35
            -210 -350 1543 -70 -140 -280 -560 -70
             -21  -35  -70 217  -14  -28  -56  -7
             -42  -70 -140 -14  420  -56 -112 -14
             -84 -140 -280 -28  -56  784 -224 -28
            -168 -280 -560 -56 -112 -224 1344 -56
             -21  -35  -70  -7  -14  -28  -56 217
        ]

        c̄ = -1792

        x̄ = Set{Vector{Int}}([[0, 1, 1]])

        ȳ = 5

        # ~*~ Model ~*~ #
        model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

        @variable(model, x[1:n], Bin)
        @objective(model, Max, c'x)
        @constraint(C1, model, a'x <= b)

        optimize!(model)

        Q, _, c = ToQUBO.PBO.qubo(unsafe_backend(model), Matrix)

        ρ = MOI.get.(unsafe_backend(model), ToQUBO.Penalty(), [C1])

        # :: Reformulation ::
        @test all(ρ .≈ ρ̄)

        @test c ≈ c̄
        @test Q ≈ Q̄

        # :: Solutions ::
        x̂ = trunc.(Int, value.(x))
        ŷ = objective_value(model)

        @test x̂ ∈ x̄
        @test ŷ ≈ ȳ
    end
end