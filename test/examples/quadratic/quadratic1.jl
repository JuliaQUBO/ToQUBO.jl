function test_quadratic1()
    @testset "3 variables, 1 constraint" begin
        # ~*~ Problem Data ~*~ #
        n = 3
        A = [
            -1  2  2
             2 -1  2
             2  2 -1
        ]
        b = 6

        # Penalty Choice
        ρ̄ = -16

        # ~*~ Solution Data ~*~ #
        Q̄ = [
            -209  740  740   32   64  128   64 -512    0    0    0 -1152 -512    0 -128 -256 -256 -256 -256 -128
               0 -209 -412  -96 -192 -384 -192  512 -256 -512 -256  1152    0 -128    0    0    0  256  256  128
               0    0 -209 -224 -448 -896 -448    0  256  512  256  1152  512  128  128  256  256    0    0    0
               0    0    0  176  -64 -128  -64    0    0    0    0     0    0  128  128    0    0    0    0  128
               0    0    0    0  320 -256 -128    0  256    0    0     0    0    0    0  256    0  256    0    0
               0    0    0    0    0  512 -256  512    0  512    0     0  512    0    0    0    0    0    0    0
               0    0    0    0    0    0  320    0    0    0  256     0    0    0    0    0  256    0  256    0
               0    0    0    0    0    0    0 -512    0    0    0     0    0    0    0    0    0    0    0    0
               0    0    0    0    0    0    0    0 -256    0    0     0    0    0    0    0    0    0    0    0
               0    0    0    0    0    0    0    0    0 -512    0     0    0    0    0    0    0    0    0    0
               0    0    0    0    0    0    0    0    0    0 -256     0    0    0    0    0    0    0    0    0
               0    0    0    0    0    0    0    0    0    0    0 -1152    0    0    0    0    0    0    0    0
               0    0    0    0    0    0    0    0    0    0    0     0 -512    0    0    0    0    0    0    0
               0    0    0    0    0    0    0    0    0    0    0     0    0 -128    0    0    0    0    0    0
               0    0    0    0    0    0    0    0    0    0    0     0    0    0 -128    0    0    0    0    0
               0    0    0    0    0    0    0    0    0    0    0     0    0    0    0 -256    0    0    0    0
               0    0    0    0    0    0    0    0    0    0    0     0    0    0    0    0 -256    0    0    0
               0    0    0    0    0    0    0    0    0    0    0     0    0    0    0    0    0 -256    0    0
               0    0    0    0    0    0    0    0    0    0    0     0    0    0    0    0    0    0 -256    0
               0    0    0    0    0    0    0    0    0    0    0     0    0    0    0    0    0    0    0 -128
        ]

        ᾱ = 1
        β̄ = -576

        x̄ = Set{Vector{Int}}([
            [0, 1, 1],
            [1, 0, 1],
            [1, 1, 0],
        ])
        ȳ = 2

        # ~*~ Model ~*~ #
        model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

        @variable(model, x[1:n], Bin)
        @objective(model, Max, x'A * x)
        @constraint(model, c1, x'A * x <= b)

        optimize!(model)

        # :: Reformulation ::
        m       = unsafe_backend(model)
        ρ       = MOI.get(m, ToQUBO.Penalty(), c1.index)
        Q, α, β = ToQUBO.qubo(m, Matrix)

        @test ρ ≈ ρ̄
        @test α ≈ ᾱ
        @test β ≈ β̄
        @test Q ≈ Q̄ broken = true

        # :: Solutions ::
        x̂ = trunc.(Int, value.(x))
        ŷ = objective_value(model)

        @test x̂ ∈ x̄
        @test ŷ ≈ ȳ
    end
end