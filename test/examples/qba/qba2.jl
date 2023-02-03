function test_qba2()
    @testset "Illustrative Example" begin
        # Problem Data
        Q̄ = [
            -5  4  8  0
             0 -3  2  0
             0  0 -8 10
             0  0  0 -6
        ]

        ᾱ = 1
        β̄ = 0
        x̄ = Set{Vector{Int}}([[1, 0, 0, 1]])
        ȳ = -11

        # Model
        model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

        @variable(model, x[1:4], Bin)
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

        # Reformulation
        Q, α, β = ToQUBO.qubo(model, Matrix)

        @test α ≈ ᾱ
        @test β ≈ β̄
        @test Q ≈ Q̄

        # Solution
        x̂ = value.(x)
        ŷ = objective_value(model)

        @test x̂ ∈ x̄
        @test ŷ ≈ ȳ

        return nothing
    end
end