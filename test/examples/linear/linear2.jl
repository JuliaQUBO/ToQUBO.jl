function test_linear2()
    @testset "2 ~ 11 variables, 3 constraints" begin
        # ~*~ Problem Data ~*~ #
        n = 11
        A = [1 0 0 1 1 1 0 1 1 1 1; 0 1 0 1 0 1 1 0 1 1 1; 0 0 1 0 1 0 1 1 1 1 1]
        b = [1, 1, 1]
        c = [2, 4, 4, 4, 4, 4, 5, 4, 5, 6, 5]

        # Penalty Choice
        ρ̄ = sum(abs.(c)) + 1

        # ~*~ Solution Data ~*~ #
        Q̄ = [
            -46    0    0   48   48   48    0   48   48   48   48
              0  -44    0   48    0   48   48    0   48   48   48
              0    0  -44    0   48    0   48   48   48   48   48
             48   48    0  -92   48   96   48   48   96   96   96
             48    0   48   48  -92   48   48   96   96   96   96
             48   48    0   96   48  -92   48   48   96   96   96
              0   48   48   48   48   48  -91   48   96   96   96
             48    0   48   48   96   48   48  -92   96   96   96
             48   48   48   96   96   96   96   96 -139  144  144
             48   48   48   96   96   96   96   96  144 -138  144
             48   48   48   96   96   96   96   96  144  144 -139
        ]

        c̄ = 144

        x̄ = Set{Vector{Int}}([
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
            [0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0],
        ])

        ȳ = 5

        # ~*~ Model ~*~ #
        model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

        @variable(model, x[1:n], Bin)
        @objective(model, Min, c'x)
        @constraint(model, A * x .== b)

        optimize!(model)

        vqm = unsafe_backend(model)

        ρ = last.(collect(vqm.ρ))

        _, Q, c = ToQUBO.PBO.qubo_normal_form(vqm)

        # :: Reformulation ::
        @test all(ρ .≈ ρ̄)
        
        @test c == c̄
        @test Q == Q̄

        # :: Solutions ::
        x̂ = trunc.(Int, value.(x))
        ŷ = objective_value(model)

        @test x̂ ∈ x̄
        @test ŷ ≈ ȳ
    end
end