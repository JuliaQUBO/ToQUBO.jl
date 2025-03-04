"""

min f(x) = x₁ + 2x₂
st. x₁ + x₂ ≥ 2
    x₁, x₂ ∈ [0, 2] ⊂ ℤ


QUBO formulation:

(1.) Variable Encoding

x₁ ↤ x₁₁ + x₁₂
x₂ ↤ x₂₁ + x₂₂

min f(x) = x₁₁ + x₁₂ + 2 (x₂₁ + x₂₂)
st. x₁₁ + x₁₂ + x₂₁ + x₂₂ ≥ 2
    x₁₁, x₁₂, x₂₁, x₂₂ ∈ 𝔹

(2.) Slack variable s ∈ [0, 2]:

min f(x) = x₁₁ + x₁₂ + 2 (x₂₁ + x₂₂)
st. x₁₁ + x₁₂ + x₂₁ + x₂₂ - s - 2 = 0
    x₁₁, x₁₂, x₂₁, x₂₂ ∈ 𝔹
    s ∈ [0, 1] ⊂ ℤ

(3.) Encoding s using binary variables:

s ↤ s₁ + s₂

min f(x) = x₁₁ + x₁₂ + 2 (x₂₁ + x₂₂)
st. x₁₁ + x₁₂ + x₂₁ + x₂₂ - 2 - s₁ - s₂ = 0
    x₁₁, x₁₂, x₂₁, x₂₂, s₁, s₂ ∈ 𝔹

(4.) Moving the constraint to the objective as a penalty:

min f(x) = x₁₁ + x₁₂ + 2 (x₂₁ + x₂₂)
min g(x) = 4 - 3 x₁₁ - 3 x₁₂ - 3 x₂₁ - 3 x₂₂ + 5 s₁ + 5 s₂
         + 2 x₁₁ x₁₂ + 2 x₁₁ x₂₁ + 2 x₁₁ x₂₂ + 2 x₁₂ x₂₁ + 2 x₁₂ x₂₂ + 2 x₂₁ x₂₂
         - 2 s₁ x₁₁ - 2 s₁ x₁₂ - 2 s₁ x₂₁ - 2 s₁ x₂₂
         - 2 s₂ x₁₁ - 2 s₂ x₁₂ - 2 s₂ x₂₁ - 2 s₂ x₂₂ 
         + 2 s₁ s₂
st. x₁₁, x₁₂, x₂₁, x₂₂, s₁, s₂ ∈ 𝔹

(5.) Adding objectives together
min f(x) + ρ g(x; s)

"""
function test_integer_1()
    @testset "Greater than constraint penalty hint" begin   
        ρ̄ = 3.0
        ᾱ = 1.0
        β̄ = 4ρ̄

        F̄ = [
            1 0 0 0 0 0
            0 1 0 0 0 0
            0 0 2 0 0 0
            0 0 0 2 0 0
            0 0 0 0 0 0
            0 0 0 0 0 0
        ]

        Ḡ = [
            -3  2  2  2 -2 -2
             0 -3  2  2 -2 -2
             0  0 -3  2 -2 -2
             0  0  0 -3 -2 -2
             0  0  0  0  5  2
             0  0  0  0  0  5
        ]
        
        Q̄ = F̄ + ρ̄ * Ḡ

        x̄ = [2., 0.]
        ȳ = 2

        model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

        @variable(model, 0 <= x[1:2] <= 2, Int)
        @constraint(model, c, sum(x) >= 2)
        @objective(model, Min, x[1] + 2 * x[2])

        set_attribute(c, ToQUBO.Attributes.ConstraintEncodingPenaltyHint(), ρ̄)
        
        optimize!(model)

        n, L, Q, α, β = QUBOTools.qubo(unsafe_backend(model), :dense)

        ρ = get_attribute(c, ToQUBO.Attributes.ConstraintEncodingPenalty())

        @show Q̂ = Q + diagm(L)

        @test n == 6
        @test ρ ≈ ρ̄
        @test α ≈ ᾱ
        @test β ≈ β̄
        @test Q̂ ≈ Q̄

        # Solutions
        x̂ = value.(x)
        ŷ = objective_value(model)

        @test x̂ ≈ x̄
        @test ŷ ≈ ȳ
    end

    return nothing
end
