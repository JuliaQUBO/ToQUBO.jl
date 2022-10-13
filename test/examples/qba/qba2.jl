function test_qba2()
    @testset "Illustrative Example" begin
        Q̄ = [
            -5  2  4  0
             2 -3  1  0
             4  1 -8  5
             0  0  5 -6
        ]

        β̄ = 0
        x̄ = Set{Vector{Int}}([[1, 0, 0, 1]])
        ȳ = -11

        model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

        @variable(model, x[i = 1:4], Bin)
        @objective(
            model,
            Min,
            -5x[1] - 3x[2] - 8x[3] - 6x[4] +
            4x[1] * x[2] +
            8x[1] * x[3] +
            2x[2] * x[3] +
            10x[3] * x[4]
        )

        optimize!(model)

        Q, _, β = ToQUBO.PBO.qubo(unsafe_backend(model))

        x̂ = value.(x)
        ŷ = objective_value(model)

        # :: Reformulation ::
        @test β ≈ β̄
        @test Q ≈ Q̄

        # :: Solution ::
        @test x̂ ∈ x̄
        @test ŷ ≈ ȳ
    end
end