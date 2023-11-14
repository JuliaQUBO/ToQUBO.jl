"""
The graph below has the following distances between nodes:

[1] ←---- ⃒1 ----→ [2]
 ↑ ↖            ↗  ↑
 |   5        2    |
 |     ↘    ↙      |
 4       [3]       |
 |     ↗           |
 |   3             |
 ↓ ↙               | 
[4] ←--------------6

        1 2 3 4
D = 1 ┌ 0 1 5 4 ┐
    2 │ 1 0 2 6 │
    3 │ 5 2 0 3 │
    4 └ 4 6 3 0 ┘

This formulation will create 16 binary variables, xᵢₖ ∈ 𝔹, for i, k ∈ {1, 2, 3, 4}.
xᵢₖ = 1 if the i-th node is in the k-th position of the tour, and 0 otherwise.

The objective is to minimize the total distance ∑ᵢ ∑ⱼ ∑ₖ Dᵢ,ⱼ xᵢ,ₖ xⱼ,₍ₖ₊₁₎

where xₙ₊₁ = x₁.

Each node must be visited exactly once, that is,

(ci[i]) ∑ₖ xᵢ,ₖ = 1 for i ∈ {1, 2, 3, 4}.

One the other hand, each position must be occupied exactly once, that is,

(ck[k]) ∑ᵢ xᵢ,ₖ = 1 for k ∈ {1, 2, 3, 4}.

The penalty functions will be

ci[i] => ∑ᵢ (∑ₖ xᵢ,ₖ - 1)²
ck[k] => ∑ₖ (∑ᵢ xᵢ,ₖ - 1)²

This results in a penalty hamiltonian

2ρ (n - ∑ₖ ∑ᵢ xᵢ,ₖ + 2 ∑ᵢ ∑ⱼ ∑ₖ xᵢ,ₖ xⱼ,ₖ)

Since Dᵢ,ⱼ ≥ 0, δ = n ∑ᵢ ∑ⱼ Dᵢ,ⱼ. ε = 1.

Therefore, ρ = δ / ε + 1 = 42n = 169

The QUBO matrix will then be

Qᵤ,ᵤ = 2ρ(2n - 1) 
Qᵤ,ᵥ = 4ρ + 

"""
function test_logical_tsp()
    @testset "TSP: 16 variables" begin
        #  Problem Data  #
        m = 4
        D = [
            0  1  5  4
            1  0  2  6
            5  2  0  3
            4  6  3  0
        ]

        # Penalty Choice
        ρ̄ = sum(D) * m + 1

        # Solution Data
        Q̄ = [
            -2ρ̄  2ρ̄  2ρ̄  2ρ̄  2ρ̄   1   5   4  2ρ̄   0   0   0  2ρ̄   1   5   4
              0 -2ρ̄  2ρ̄  2ρ̄   1  2ρ̄   2   6   0  2ρ̄   0   0   1  2ρ̄   2   6
              0   0 -2ρ̄  2ρ̄   5   2  2ρ̄   3   0   0  2ρ̄   0   5   2  2ρ̄   3
              0   0   0 -2ρ̄   4   6   3  2ρ̄   0   0   0  2ρ̄   4   6   3  2ρ̄
              0   0   0   0 -2ρ̄  2ρ̄  2ρ̄  2ρ̄  2ρ̄   1   5   4  2ρ̄   0   0   0
              0   0   0   0   0 -2ρ̄  2ρ̄  2ρ̄   1  2ρ̄   2   6   0  2ρ̄   0   0
              0   0   0   0   0   0 -2ρ̄  2ρ̄   5   2  2ρ̄   3   0   0  2ρ̄   0
              0   0   0   0   0   0   0 -2ρ̄   4   6   3  2ρ̄   0   0   0  2ρ̄
              0   0   0   0   0   0   0   0 -2ρ̄  2ρ̄  2ρ̄  2ρ̄  2ρ̄   1   5   4
              0   0   0   0   0   0   0   0   0 -2ρ̄  2ρ̄  2ρ̄   1  2ρ̄   2   6
              0   0   0   0   0   0   0   0   0   0 -2ρ̄  2ρ̄   5   2  2ρ̄   3
              0   0   0   0   0   0   0   0   0   0   0 -2ρ̄   4   6   3  2ρ̄
              0   0   0   0   0   0   0   0   0   0   0   0 -2ρ̄  2ρ̄  2ρ̄  2ρ̄
              0   0   0   0   0   0   0   0   0   0   0   0   0 -2ρ̄  2ρ̄  2ρ̄
              0   0   0   0   0   0   0   0   0   0   0   0   0   0 -2ρ̄  2ρ̄
              0   0   0   0   0   0   0   0   0   0   0   0   0   0   0 -2ρ̄
        ]

        ᾱ = 1
        β̄ = 2ρ̄ * m
        x̄ = Set{Matrix{Int}}([
            [0 0 0 1; 0 0 1 0; 0 1 0 0; 1 0 0 0],
            [1 0 0 0; 0 0 0 1; 0 0 1 0; 0 1 0 0],
            [0 1 0 0; 1 0 0 0; 0 0 0 1; 0 0 1 0],
            [0 0 1 0; 0 1 0 0; 1 0 0 0; 0 0 0 1],
        ])
        ȳ = 10

        # Model
        model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

        @variable(model, x[1:m, 1:m], Bin)
        @objective(
            model,
            Min,
            sum(D[i, j] * x[i, k] * x[j, (k%m)+1] for i = 1:m, j = 1:m, k = 1:m)
        )
        @constraint(model, ci[i = 1:m], sum(x[i, :]) == 1)
        @constraint(model, ck[k = 1:m], sum(x[:, k]) == 1)

        set_attribute(model, Attributes.StableCompilation(), true)

        optimize!(model)

        # Reformulation
        ρi = get_attribute.(ci, Attributes.ConstraintEncodingPenalty())
        ρk = get_attribute.(ck, Attributes.ConstraintEncodingPenalty())
        ρ  = [ρi; ρk]

        n, L, Q, α, β = QUBOTools.qubo(model, :dense)

        Q̂ = Q + diagm(L)

        @test n == m^2
        @test all(ρ .≈ ρ̄)
        @test α ≈ ᾱ
        @test β ≈ β̄
        @test Q̂ ≈ Q̄

        # Solutions
        x̂ = trunc.(Int, value.(x))
        ŷ = objective_value(model)

        @test x̂ ∈ x̄
        @test ŷ ≈ ȳ

        return nothing
    end
end
