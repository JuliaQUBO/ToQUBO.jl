raw"""

Factoring R in its prime factors p, q goes as

feasibility
st p * q == R
   p ∈ [2, a] ⊂ ℤ
   q ∈ [a, b] ⊂ ℤ

where a = ⌈√R⌉ and b = R ÷ 2.

For R = 15, we have a = 4 and b = 7.

Thus,

feasibility
st p * q == R
   p ∈ [2, 4] ⊂ ℤ
   q ∈ [4, 7] ⊂ ℤ

We penalize the constraint using ρ = 1, since we are looking for a feasible solution.

This yields

min (p * q - R)²
 st p ∈ [2, 4] ⊂ ℤ
    q ∈ [4, 7] ⊂ ℤ

Expanding p, q using binary variables gives us

p = 2 + p₁ + p₂
q = 4 + q₁ + 2q₂

where p₁, p₂, q₁, q₂ ∈ 𝔹.

Therefore, our model is

min [(2 + p₁ + p₂) * (4 + q₁ + 2q₂) - 15]²
 st p₁, p₂ ∈ 𝔹
    q₁, q₂ ∈ 𝔹

Expanding the product we have

[(2 + p₁ + p₂) * (4 + q₁ + 2q₂) - 15]² =
    49
    - 40 p₁ - 40 p₂ - 24 q₁ - 40 q₂
    + 32 p₁ p₂ + 15 p₁ q₁ + 40 p₁ q₂ + 15 p₂ q₁ + 40 p₂ q₂ + 16 q₁ q₂
    + 18 p₁ p₂ q₁ + 40 p₁ p₂ q₂ + 20 p₁ q₁ q₂ + 20 p₂ q₁ q₂
    + 8 p₁ p₂ q₁ q₂

Quadratizing this model using (PTR-BG) will require 6 auxiliary variables: w₁, w₂, w₃, w₄, w₅, w₆ ∈ 𝔹.

𝒬{p₁ p₂ q₁}(p₁, p₂, q₁; w₁) = w₁ + p₁ w₁ - p₂ w₁ - q₁ w₁ + p₂ q₁
𝒬{p₁ p₂ q₂}(p₁, p₂, q₂; w₂) = w₂ + p₁ w₂ - p₂ w₂ - q₂ w₂ + p₂ q₂
𝒬{p₁ q₁ q₂}(p₁, q₁, q₂; w₃) = w₃ + p₁ w₃ - q₁ w₃ - q₂ w₃ + q₁ q₂
𝒬{p₂ q₁ q₂}(p₂, q₁, q₂; w₄) = w₄ + p₂ w₄ - q₁ w₄ - q₂ w₄ + q₁ q₂

𝒬{p₁ p₂ q₁ q₂}(p₁ p₂ q₁ q₂; w₅, w₆) = q₁ q₂ + 2 w₅ + p₁ w₅ - p₂ w₅ - q₁ w₅ - q₂ w₅ + w₆ + p₂ w₆ - q₁ w₆ - q₂ w₆

This results in 

min 49 - 40 p₁ - 40 p₂ + 32 p₁ p₂ - 24 q₁ + 15 p₁ q₁ + 33 p₂ q₁ - 40 q₂ + 
    40 p₁ q₂ + 80 p₂ q₂ + 64 q₁ q₂ + 18 w₁ + 18 p₁ w₁ - 18 p₂ w₁ - 
    18 q₁ w₁ + 40 w₂ + 40 p₁ w₂ - 40 p₂ w₂ - 40 q₂ w₂ + 20 w₃ + 
    20 p₁ w₃ - 20 q₁ w₃ - 20 q₂ w₃ + 20 w₄ + 20 p₂ w₄ - 20 q₁ w₄ - 
    20 q₂ w₄ + 16 w₅ + 8 p₁ w₅ - 8 p₂ w₅ - 8 q₁ w₅ - 8 q₂ w₅ + 8 w₆ + 
    8 p₂ w₆ - 8 q₁ w₆ - 8 q₂ w₆
 st p₁, p₂ ∈ 𝔹
    q₁, q₂ ∈ 𝔹
    w₁, w₂, w₃, w₄, w₅, w₆ ∈ 𝔹

whose QUBO matrix is

          p₁  p₂  q₁  q₂  w₁  w₂  w₃  w₄  w₅ w₆
Q = p₁ ┌ -40  32  15  40  18  40  20       8    ┐
    p₂ │     -40  33  80 -18 -40      20  -8  8 │
    q₁ │         -24  64 -18     -20 -20  -8 -8 │
    q₂ │             -40     -40 -20 -20  -8 -8 │
    w₁ │                  18                    │
    w₂ │                      40                │
    w₃ │                          20            │
    w₄ │                              20        │
    w₅ │                                  16    │
    w₆ └                                      8 ┘

  

## PTR-BG

### n = 3
𝒬{x₁ x₂ x₃}(x₁, x₂, x₃; w) = w + x₁ w - x₂ w - x₃ w + x₂ x₃

### n = 4
𝒬{x₁ x₂ x₃ x₄}(x₁, x₂, x₃, x₄; w₁, w₂) = 2 w₁ + w₂ + w₁ x₁ - w₁ x₂ + w₂ x₂ - w₁ x₃ - w₂ x₃ - w₁ x₄ - w₂ x₄ + x₃ x₄
"""
function test_primes()
    @testset "Prime Factoring: 15 = 3 × 5" begin
        #  Problem Data  #
        R = 15
        a = ceil(Int, √R)
        b = R ÷ 2

        @test a == 4
        @test b == 7

        #  Solution Data  #
        ᾱ = 1
        β̄ = 49
        Q̄ = [
            -40   32   15   40   18   40   20    0   8   0
              0  -40   33   80  -18  -40    0   20  -8   8
              0    0  -24   64  -18    0  -20  -20  -8  -8
              0    0    0  -40    0  -40  -20  -20  -8  -8
              0    0    0    0   18    0    0    0   0   0
              0    0    0    0    0   40    0    0   0   0
              0    0    0    0    0    0   20    0   0   0
              0    0    0    0    0    0    0   20   0   0
              0    0    0    0    0    0    0    0  16   0
              0    0    0    0    0    0    0    0   0   8
        ]

        ρ̄ = 1
        p̄ = 3
        q̄ = 5

        model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

        @variable(model, 2 <= p <= a, Int)
        @variable(model, a <= q <= b, Int)
        @constraint(model, c1, p * q == R)

        set_attribute(model, Attributes.StableQuadratization(), true)

        optimize!(model)

        # Reformulation
        ρ = get_attribute(c1, Attributes.ConstraintEncodingPenalty())

        n, L, Q, α, β = QUBOTools.qubo(model, :dense)

        Q̂ = Q + diagm(L)

        @test n == 10
        @test ρ ≈ ρ̄
        @test α ≈ ᾱ
        @test β ≈ β̄
        @test Q̂ ≈ Q̄

        # Solutions
        p̂ = trunc(Int, value(p))
        q̂ = trunc(Int, value(q))

        @test p̂ == p̄
        @test q̂ == q̄

        return nothing
    end
end
