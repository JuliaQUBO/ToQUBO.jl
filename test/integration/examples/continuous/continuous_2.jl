"""

min f(x) = x₁ + 2x₂ + 3x₃
    s.t. x₁ + x₂ + x₃ ≥ 4
         x₁, x₂, x₃ ∈ [0, 2] ⊂ ℤ


QUBO formulation:

x₁ ↤ x₁,₁ + x₁,₂
x₂ ↤ x₂,₁ + x₂,₂
x₃ ↤ x₃,₁ + x₃,₂

min f(x) = x₁,₁ + x₁,₂ + 2 (x₂,₁ + x₂,₂) + 3 (x₃,₁ + x₃,₂)
      s.t. x₁,₁ + x₁,₂ + x₂,₁ + x₂,₂ + x₃,₁ + x₃,₂ ≥ 4
           x₁,₁, x₁,₂, x₂,₁, x₂,₂, x₃,₁, x₃,₂ ∈ 𝔹

Adding a slack variable s ∈ [0, 2]:

min f(x) = x₁,₁ + x₁,₂ + 2 (x₂,₁ + x₂,₂) + 3 (x₃,₁ + x₃,₂)
      s.t. x₁,₁ + x₁,₂ + x₂,₁ + x₂,₂ + x₃,₁ + x₃,₂ - s - 4 = 0
           x₁,₁, x₁,₂, x₂,₁, x₂,₂, x₃,₁, x₃,₂ ∈ 𝔹
           s ∈ [0, 2] ⊂ ℤ

Encoding s using binary variables:

min f(x) = x₁,₁ + x₁,₂ + 2 (x₂,₁ + x₂,₂) + 3 (x₃,₁ + x₃,₂)
      s.t. x₁,₁ + x₁,₂ + x₂,₁ + x₂,₂ + x₃,₁ + x₃,₂ - 4 - s₁ - 2 s₂ = 0
           x₁,₁, x₁,₂, x₂,₁, x₂,₂, x₃,₁, x₃,₂, s₁, s₂ ∈ 𝔹

Moving the constraint to the objective as a penalty:

min f(x) = x₁,₁ + x₁,₂ + 2 (x₂,₁ + x₂,₂) + 3 (x₃,₁ + x₃,₂) + ρ (x₁,₁ + x₁,₂ + x₂,₁ + x₂,₂ + x₃,₁ + x₃,₂ - 4 - s₁ - 2 s₂)²
      s.t. x₁,₁, x₁,₂, x₂,₁, x₂,₂, x₃,₁, x₃,₂, s₁, s₂ ∈ 𝔹

 (x₁,₁ + x₁,₂ + x₂,₁ + x₂,₂ + x₃,₁ + x₃,₂ - 4 - s₁ - s₂)^2 = 
  - 7 x₁,₁ - 7 x₁,₂ - 7 x₂,₁ - 7 x₂,₂ - 7 x₃,₁ - 7 x₃,₂ + 9 s₁ + 9 s₂
  x₁,₁ x₁,₂ + x₁,₁ x₂,₁ + x₁,₁ x₂,₂ + x₁,₁ x₃,₁ + x₁,₁ x₃,₂ - 2 s₁ x₁,₁ - 2 s₂ x₁,₁ +
  x₁,₂ x₁,₁ + x₁,₂ x₂,₁ + x₁,₂ x₂,₂ + x₁,₂ x₃,₁ + x₁,₂ x₃,₂ - 2 s₁ x₁,₂ - 2 s₂ x₁,₂ +
  x₂,₁ x₁,₁ + x₂,₁ x₁,₂ + x₂,₁ x₂,₂ + x₂,₁ x₃,₁ + x₂,₁ x₃,₂ - 2 s₁ x₂,₁ - 2 s₂ x₂,₁ +
  x₂,₂ x₁,₁ + x₂,₂ x₁,₂ + x₂,₂ x₂,₁ + x₂,₂ x₃,₁ + x₂,₂ x₃,₂ - 2 s₁ x₂,₂ - 2 s₂ x₂,₂ +
  x₃,₁ x₁,₁ + x₃,₁ x₁,₂ + x₃,₁ x₂,₁ + x₃,₁ x₂,₂ + x₃,₁ x₃,₂ - 2 s₁ x₃,₁ - 2 s₂ x₃,₁ +
  x₃,₂ x₁,₁ + x₃,₂ x₁,₂ + x₃,₂ x₂,₁ + x₃,₂ x₂,₂ + x₃,₂ x₃,₁ - 2 s₁ x₃,₂ - 2 s₂ x₃,₂ +
  + 2 s₁ s₂ + 16

"""
function test_continuous_2()
    @testset "Greater than constraint penalty hint" begin   
        ρ̄ = 3.0
        ᾱ = 1.0
        β̄ = 16ρ̄

        F̄ = [
            1 0 0 0 0 0 0 0
            0 1 0 0 0 0 0 0
            0 0 2 0 0 0 0 0
            0 0 0 2 0 0 0 0
            0 0 0 0 3 0 0 0
            0 0 0 0 0 3 0 0
            0 0 0 0 0 0 0 0
            0 0 0 0 0 0 0 0
        ]

        Ḡ = [
            -7  2 2 2 2 2 -2 -2
             0 -7 2 2 2 2 -2 -2
             0 0 -7 2 2 2 -2 -2
             0 0 0 -7 2 2 -2 -2
             0 0 0 0 -7 2 -2 -2
             0 0 0 0 0 -7 -2 -2
             0 0 0 0 0  0  9  2
             0 0 0 0 0  0  0  9
        ]
        
        Q̄ = F̄ + ρ̄ * Ḡ

        x̄ = [2.0, 2.0, 0.0]
        ȳ = 6

        model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

        @variable(model, 0 <= x[1:3] <= 2, Int)
        @constraint(model, c, sum(x) >= 4)
        @objective(model, Min, sum(i * x[i] for i = 1:3))

        set_attribute(c, ToQUBO.Attributes.ConstraintEncodingPenaltyHint(), ρ̄)
        
        optimize!(model)

        n, L, Q, α, β = QUBOTools.qubo(model, :dense)

        ρ = get_attribute(c, ToQUBO.Attributes.ConstraintEncodingPenalty())

        Q̂ = Q + diagm(L)

        @test n == 8
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
