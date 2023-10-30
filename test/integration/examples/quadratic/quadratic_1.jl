raw"""

Let A = ┌ -1  1 ┐
        └  1 -1 ┘

The original model is

max x' A x
 st x' A x ≤ 1
    x ∈ 𝔹^2

that is,

max [x₁ x₂] ┌ -1  1 ┐ ┌ x₁ ┐
            └  1 -1 ┘ └ x₂ ┘
 st [x₁ x₂] ┌ -1  1 ┐ ┌ x₁ ┐ ≤ 1
            └  1 -1 ┘ └ x₂ ┘

or, expanding the matrix multiplication,

max -x₁ - x₂ + 2 x₁ x₂
 st -x₁ - x₂ + 2 x₁ x₂ ≤ 1
    x ∈ 𝔹^2

Adding a slack variable u, the reformulation is

max -x₁ - x₂ + 2 x₁ x₂
 st -x₁ - x₂ + 2 x₁ x₂ + u = 1
    x ∈ 𝔹^2
    u ∈ [0, 3] ⊂ ℤ

Expanding u as a sum of binary variables, u = u₁ + 2 u₂ where u₁, u₂ ∈ 𝔹.

This results in

max -x₁ - x₂ + 2 x₁ x₂
 st -x₁ - x₂ + 2 x₁ x₂ + u₁ + 2 u₂ = 1
    x₁, x₂ ∈ 𝔹
    u₁, u₂ ∈ 𝔹

The reformulation is

max -x₁ - x₂ + 2 x₁ x₂ + ρ (-x₁ - x₂ + 2 x₁ x₂ + u₁ + 2 u₂ - 1)²
 st x ∈ 𝔹^2

where ρ is a penalty parameter.

Expanding the square,

max -x₁ - x₂ + 2 x₁ x₂ + ρ (
        3 x₁ + 3 x₂ - u₁
        - 6 x₁ x₂ - 2 x₁ u₁ - 2 x₂ u₁ - 4 x₁ u₂ - 4 x₂ u₂ + 4 u₁ u₂
        + 4 x₁ x₂ u₁ + 8 x₁ x₂ u₂
        + 1
    )
 st x₁, x₂ ∈ 𝔹
    u₁, u₂ ∈ 𝔹

quadratizing u₁ x₁ x₂ and u₂ x₁ x₂ using positive term reduction (PTR-BG),
which adds the auxiliary variables w₁, w₂ yields

𝒬{x₁ x₂ u₁}(x₁, x₂, u₁; w₁) = w₁ + x₁ w₁ - x₂ w₁ - u₁ w₁ + x₂ u₁
𝒬{x₁ x₂ u₂}(x₁, x₂, u₂; w₂) = w₂ + x₁ w₂ - x₂ w₂ - u₂ w₂ + x₂ u₂

and then

max -x₁ - x₂ + 2 x₁ x₂ + ρ (
        3 x₁ + 3 x₂ - u₁
        - 6 x₁ x₂ - 2 x₁ u₁ - 2 x₂ u₁ - 4 x₁ u₂ - 4 x₂ u₂ + 4 u₁ u₂
        + 4 [w₁ + x₁ w₁ - x₂ w₁ - u₁ w₁ + x₂ u₁] + 8 [w₂ + x₁ w₂ - x₂ w₂ - u₂ w₂ + x₂ u₂]
        + 1
    )
 st x₁, x₂ ∈ 𝔹
    u₁, u₂ ∈ 𝔹
    w₁, w₂ ∈ 𝔹

or, in other words,

max -x₁ - x₂ + 2 x₁ x₂ + ρ (
        3 x₁ + 3 x₂ - u₁
        - 6 x₁ x₂ - 2 x₁ u₁ + 2 x₂ u₁ - 4 x₁ u₂ + 4 x₂ u₂ + 4 u₁ u₂
        + 4 w₁ + 4 x₁ w₁ - 4 x₂ w₁ - 4 u₁ w₁
        + 8 w₂ + 8 x₁ w₂ - 8 x₂ w₂ - 8 u₂ w₂
        + 1
    )
 st x₁, x₂ ∈ 𝔹
    u₁, u₂ ∈ 𝔹
    w₁, w₂ ∈ 𝔹

whose QUBO matrix is

              x₁      x₂  u₁  u₂  w₁  w₂
Q = x₁ ┌ -1 + 3ρ  2 - 6ρ -2ρ -4ρ  4ρ  8ρ ┐
    x₂ │         -1 + 3ρ  2ρ  4ρ -4ρ -8ρ │
    u₁ │                  -ρ  4ρ -4ρ     │
    u₂ │                             -8ρ │
    w₁ │                          4ρ     │
    w₂ └                              8ρ ┘

not to forget its offset β = ρ.

Let |ρ| > δ / ϵ where δ = 2 - (-2) = 4 and ϵ = 1. Then |ρ| > 4 ⟹ ρ = -5 since 
this is a maximization problem.

Possible solutions are x = [0, 0] and x = [1, 1] with objective value y = 0.


## PTR-BG

𝒬{x₁ x₂ x₃}(x₁, x₂, x₃; w) = w + x₁ w - x₂ w - x₃ w + x₂ x₃

"""
function test_quadratic_1()
    @testset "2 variables, 1 constraint" begin
        # Problem Data
        A = [
            -1  1
             1 -1
        ]
        b = 1

        # Penalty Choice
        ρ̄ = -5.0

        # Solution
        Q̄ = [
            -1+3ρ̄  2-6ρ̄ -2ρ̄ -4ρ̄  4ρ̄  8ρ̄
                0 -1+3ρ̄  2ρ̄  4ρ̄ -4ρ̄ -8ρ̄
                0     0  -ρ̄  4ρ̄ -4ρ̄   0
                0     0   0   0   0 -8ρ̄
                0     0   0   0  4ρ̄   0
                0     0   0   0   0  8ρ̄
        ]

        ᾱ = 1.0
        β̄ = ρ̄

        x̄ = Set{Vector{Int}}([[0, 0], [1, 1]])
        ȳ = 0.0

        # Model
        model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

        @variable(model, x[1:2], Bin)
        @objective(model, Max, x' * A * x)
        @constraint(model, c1, x' * A * x <= b)

        set_attribute(model, Attributes.StableQuadratization(), true)

        optimize!(model)

        # Reformulation
        ρ = get_attribute(c1, Attributes.ConstraintEncodingPenalty())

        n, L, Q, α, β = QUBOTools.qubo(model, :dense)

        Q̂ = Q + diagm(L)

        @test n == 6
        @test ρ ≈ ρ̄
        @test α ≈ ᾱ
        @test β ≈ β̄
        @test Q̂ ≈ Q̄

        # Solutions
        for i = 1:2
            x̂ = trunc.(Int, value.(x; result = i))
            ŷ = objective_value(model; result = i)

            @test x̂ ∈ x̄
            @test ŷ ≈ ȳ
        end

        return nothing
    end
end
