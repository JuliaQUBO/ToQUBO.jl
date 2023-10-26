raw"""

Let A = ⌈ -1  2 ⌉
        ⌊  2 -1 ⌋

The original model is

max x' A x
 st x' A x ≤ 1

"""
function test_quadratic_1()
    @testset "2 variables, 1 constraint" begin
        # Problem Data
        A = [
            -1  2
             2 -1
        ]
        b = 1

        # Penalty Choice
        ρ̄ = -7.0

        # Solution
        Q̄ = [
            -1+3ρ̄   4+18ρ̄   -2ρ̄  -4ρ̄  -8ρ̄  -16ρ̄
                0  -1+3ρ̄    -2ρ̄  -4ρ̄  -8ρ̄  -16ρ̄
                0      0    -1ρ̄   4ρ̄   8ρ̄     0
                0      0      0   4ρ̄    0   16ρ̄
                0      0      0    0  16ρ̄     0
                0      0      0    0    0   32ρ̄
        ]

        ᾱ = 1.0
        β̄ = 1ρ̄

        x̄ = [0, 0]
        ȳ = 0.0

        # Model
        model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

        @variable(model, x[1:2], Bin)
        @objective(model, Max, x' * A * x)
        @constraint(model, c1, x' * A * x <= b)

        set_optimizer_attribute(model, Attributes.StableQuadratization(), true)

        optimize!(model)

        # Reformulation
        ρ = get_attribute(c1, Attributes.ConstraintEncodingPenalty())

        n, L, Q, α, β = QUBOTools.qubo(model, :dense)

        Q̂ = Q + diagm(L)

        @test n == 6
        @test ρ ≈ ρ̄
        @test α ≈ ᾱ
        @test β ≈ β̄

        display(collect(unsafe_backend(model).g[c1.index]))

        display(Q̂)
        display(Q̄)

        @test Q̂ ≈ Q̄

        # Solutions
        x̂ = trunc.(Int, value.(x))
        ŷ = objective_value(model)

        @test x̂ == x̄
        @test ŷ ≈ ȳ

        return nothing
    end
end
