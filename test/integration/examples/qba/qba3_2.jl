function test_qba3_2()
    @testset "Max-Cut" begin
        #=
        Quote from [1]:

        The Max Cut problem is one of the most famous problems in combinatorial optimization.
        Given an undirected graph G(V, E) with a vertex set V and an edge set E, the Max-Cut
        problem seeks to partition V into two sets such that the number of edges between the
        two sets (considered to be severed by the cut), is a large as possible.

        Graph G:
        (1)-(2)
         |   |
        (3)-(4)
          \ /
          (5)
        =#

        ⊻(x::VariableRef, y::VariableRef) = x + y - 2 * x * y

        # Problem Data
        G = Dict{Tuple{Int,Int},Float64}(
            (1, 2) => 1.0,
            (1, 3) => 1.0,
            (2, 4) => 1.0,
            (3, 4) => 1.0,
            (3, 5) => 1.0,
            (4, 5) => 1.0,
        )
        m = 5

        # Results
        Q̄ = [
            2 -2 -2  0  0
            0  2  0 -2  0
            0  0  3 -2 -2
            0  0  0  3 -2
            0  0  0  0  2
        ]

        c̄ = 0
        x̄ = Set{Vector{Int}}([
            [0, 1, 1, 0, 1],
            [1, 0, 0, 1, 1],
            [0, 1, 1, 0, 0],
            [1, 0, 0, 1, 0],
        ])
        ȳ = 5

        # Model
        model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

        @variable(model, x[1:m], Bin)
        @objective(model, Max, sum(Gᵢⱼ * (x[i] ⊻ x[j]) for ((i, j), Gᵢⱼ) in G))

        optimize!(model)

        Q, _, c = ToQUBO.qubo(model, Matrix)

        # Reformulation
        @test c ≈ c̄
        @test Q ≈ Q̄

        # Solutions
        x̂ = trunc.(Int, value.(x))
        ŷ = objective_value(model)

        @test x̂ ∈ x̄
        @test ŷ ≈ ȳ

        return nothing
    end
end
