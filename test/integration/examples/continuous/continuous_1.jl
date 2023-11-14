"""

Let  x ∈ [0, 1]ⁿˣⁿ.

        ┌ -1  2  2 ┐
Let A = │  2 -1  2 │
        └  2  2 -1 ┘

Each variable is encoded according to a tolerance τ = 0.1, using the binary method.

This means that each variable will take 2 bits.

xᵢ = -1/2 + 1/3 xᵢ,₁ + 2/3 xᵢ,₂

where xᵢ,ⱼ ∈ 𝔹.

"""
function test_continuous_1()
    @testset "9 variables ∈ [0, 1]" begin
        # Problem Data
        n = 3
        A = [
            -1  2  2
             2 -1  2
             2  2 -1
        ]

        # Solution
        Q̄ = (1/3) * [
            -1  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0
             0 -2  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0
             0  0  2  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0
             0  0  0  4  0  0  0  0  0  0  0  0  0  0  0  0  0  0
             0  0  0  0  2  0  0  0  0  0  0  0  0  0  0  0  0  0
             0  0  0  0  0  4  0  0  0  0  0  0  0  0  0  0  0  0
             0  0  0  0  0  0  2  0  0  0  0  0  0  0  0  0  0  0
             0  0  0  0  0  0  0  4  0  0  0  0  0  0  0  0  0  0
             0  0  0  0  0  0  0  0 -1  0  0  0  0  0  0  0  0  0
             0  0  0  0  0  0  0  0  0 -2  0  0  0  0  0  0  0  0
             0  0  0  0  0  0  0  0  0  0  2  0  0  0  0  0  0  0
             0  0  0  0  0  0  0  0  0  0  0  4  0  0  0  0  0  0
             0  0  0  0  0  0  0  0  0  0  0  0  2  0  0  0  0  0
             0  0  0  0  0  0  0  0  0  0  0  0  0  4  0  0  0  0
             0  0  0  0  0  0  0  0  0  0  0  0  0  0  2  0  0  0
             0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  4  0  0
             0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0 -1  0
             0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0 -2
        ]

        ᾱ = 1
        β̄ = -9/2

        x̄ = [
            -1/2  1/2  1/2
             1/2 -1/2  1/2
             1/2  1/2 -1/2
        ]
        ȳ = 15/2

        # Model
        model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

        @variable(model, -1/2 <= x[1:n, 1:n] <= 1/2)
        @objective(model, Max, sum(A .* x))
        
        set_attribute(model, Attributes.DefaultVariableEncodingATol(), 0.1)
        set_attribute(model, Attributes.StableCompilation(), true)

        optimize!(model)

        # Reformulation
        n, L, Q, α, β = QUBOTools.qubo(model, :dense)

        Q̂ = Q + diagm(L)

        @test n == 18
        @test α ≈ ᾱ
        @test β ≈ β̄
        @test Q̂ ≈ Q̄

        # Solutions
        x̂ = value.(x)
        ŷ = objective_value(model)

        @test x̂ ≈ x̄
        @test ŷ ≈ ȳ

        return nothing
    end
end
