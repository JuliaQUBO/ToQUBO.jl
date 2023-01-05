function test_qba3_1()
    @testset "Number Partitioning" begin
        #=
        Quote from [1]:

        The Number Partitioning problem has numerous applications cited in the bibliography. A
        common version of this problem involves partitioning a set of numbers into two subsets
        such that the subset sums are as close to each other as possible.
        =#

        # :: Data ::
        S = Int[25, 7, 13, 31, 42, 17, 21, 10]
        m = 8

        # :: Results ::
        Q̄ = [
            -3525   350   650  1550  2100   850  1050   500
                0 -1113   182   434   588   238   294   140
                0     0 -1989   806  1092   442   546   260
                0     0     0 -4185  2604  1054  1302   620
                0     0     0     0 -5208  1428  1764   840
                0     0     0     0     0 -2533   714   340
                0     0     0     0     0     0 -3045   420
                0     0     0     0     0     0     0 -1560
        ]

        c̄ = 27_556

        x̄ = Set{Vector{Int}}([
            [0, 0, 0, 1, 1, 0, 0, 1],
            [0, 1, 1, 0, 1, 0, 1, 0],
            [1, 0, 0, 1, 0, 1, 0, 1],
            [1, 1, 1, 0, 0, 1, 1, 0],
        ])
        ȳ = -6889

        # :: Model ::
        model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

        @variable(model, x[1:m], Bin)
        @objective(model, Min, sum(S[j] * (2x[j] - 1) for j = 1:m)^2)

        optimize!(model)

        Q, _, c = ToQUBO.qubo(unsafe_backend(model), Matrix)

        # :: Reformulation ::
        @test c ≈ c̄
        @test Q ≈ 4Q̄

        # :: Solution ::
        x̂ = trunc.(Int, value.(x))
        ŷ = objective_value(model)

        @test x̂ ∈ x̄
        @test ŷ ≈ 4ȳ + c̄

        return nothing
    end
end