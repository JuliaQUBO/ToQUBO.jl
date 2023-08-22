function test_linear2()
    @testset "11 variables, 3 constraints" begin
        # Problem Data
        m = 3
        n = 11
        A = [1 0 0 1 1 1 0 1 1 1 1; 0 1 0 1 0 1 1 0 1 1 1; 0 0 1 0 1 0 1 1 1 1 1]
        b = [1, 1, 1]
        c = [2, 4, 4, 4, 4, 4, 5, 4, 5, 6, 5]

        # Penalty Choice
        ρ̄ = fill(sum(abs.(c)) + 1, m)

        # Solution Data
        Q̄ = [
            -46    0    0   96   96   96    0   96   96   96   96
              0  -44    0   96    0   96   96    0   96   96   96
              0    0  -44    0   96    0   96   96   96   96   96
              0    0    0  -92   96  192   96   96  192  192  192
              0    0    0    0  -92   96   96  192  192  192  192
              0    0    0    0    0  -92   96   96  192  192  192
              0    0    0    0    0    0  -91   96  192  192  192
              0    0    0    0    0    0    0  -92  192  192  192
              0    0    0    0    0    0    0    0 -139  288  288
              0    0    0    0    0    0    0    0    0 -138  288
              0    0    0    0    0    0    0    0    0    0 -139
        ]

        ᾱ = 1
        β̄ = 144

        x̄ = Set{Vector{Int}}([
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
            [0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0],
        ])

        ȳ = 5

        # Model
        model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

        @variable(model, x[1:n], Bin)
        @objective(model, Min, c'x)
        @constraint(model, k, A * x .== b)

        optimize!(model)

        # Reformulation
        ρ       = MOI.get.(model, TQA.ConstraintEncodingPenalty(), k)
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