function test_logical_tsp()
    @testset "TSP: 16 variables" begin
        #  Problem Data  #
        n = 4
        D = [
            0  1  5  4
            1  0  2  6
            5  2  0  3
            4  6  3  0
        ]

        # Penalty Choice
        ρ̄ = fill(169, 2n)

        # Solution Data
        Q̄ = [
            -338  676    1  676    5    0  676    5    5    4
               0 -675  676  681  679    5  681  682    6    6
               0    0 -338    3  676    2    6  676    6    0
               0    0    0 -676  681  676  681   10  681    7
               0    0    0    0 -674  676    4  682  681    6
               0    0    0    0    0 -338    5    5  676    3
               0    0    0    0    0    0 -672  682  683  676
               0    0    0    0    0    0    0 -676  682  676
               0    0    0    0    0    0    0    0 -673  676
               0    0    0    0    0    0    0    0    0 -338
        ]

        ᾱ = 1
        β̄ = 1352
        x̄ = Set{Matrix{Int}}([
            [0 0 0 1; 0 0 1 0; 0 1 0 0; 1 0 0 0],
            [1 0 0 0; 0 0 0 1; 0 0 1 0; 0 1 0 0],
            [0 1 0 0; 1 0 0 0; 0 0 0 1; 0 0 1 0],
            [0 0 1 0; 0 1 0 0; 1 0 0 0; 0 0 0 1],
        ])
        ȳ = 10

        #  Model  #
        model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

        @variable(model, x[1:n, 1:n], Bin, Symmetric)
        @objective(
            model,
            Min,
            sum(D[i, j] * x[i, k] * x[j, (k%n)+1] for i = 1:n, j = 1:n, k = 1:n)
        )
        @constraint(model, ci[i = 1:n], sum(x[i, :]) == 1)
        @constraint(model, ck[k = 1:n], sum(x[:, k]) == 1)

        optimize!(model)

        # Reformulation
        ρi      = MOI.get.(model, TQA.ConstraintEncodingPenalty(), ci)
        ρk      = MOI.get.(model, TQA.ConstraintEncodingPenalty(), ck)
        ρ       = [ρi; ρk]
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